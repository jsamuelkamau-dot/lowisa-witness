%%%-------------------------------------------------------------------
%%% witness_meta — the Meta Model API for Witness (hackathon, 2026-10-27).
%%%
%%% Chat completions are OpenAI-compatible (measured 27 Oct: the same body, stream_options usage on the
%%% finishing chunk, prompt_cache_key accepted), so a host that already streams OpenAI only needs
%%% chat_request/3 for the URL and body. Everything else Witness asks of Meta goes through here:
%%%
%%%   upload(Key, Name, Mime, Bytes)        Files API, purpose user_data -> {ok, FileId}
%%%   sam_video(Key, FileId, Prompt)        SAM 3.1 concept tracking on a clip -> {ok, Text, Frames}
%%%   read_video(Key, Model, FileId, Prompt, Opts)
%%%                                         Muse Spark reads a clip (frames and sound) -> {ok, Text, Usage}
%%%   cost(Kind, Usage)                     US dollars for one call, from the published prices
%%%
%%% Keys come from the host (witness_host); nothing here reads configuration.
%%%-------------------------------------------------------------------
-module(witness_meta).
-export([chat_request/3, ssl_opts/0, upload/4, sam_video/3, read_video/5, responses/2, text_of/1, cost/2, multipart/4]).

-define(API, "https://api.meta.ai/v1").
-define(TIMEOUT_MS, 300000).

%% Published prices (dev.meta.ai/docs/pricing-rate-limits, read 27 Oct 2026), US dollars.
-define(SAM_FRAME, 0.0002).
-define(SAM_MIN_FRAMES, 50).
-define(SAM_IMAGE, 0.0025).
-define(IMAGE, 0.01).
-define(TRANSCRIBE_HOUR, 0.18).

%% chat_request(ModelId, Messages, Opts) -> {Url, Body}
%%   Opts as the host's OpenAI call: max_output_tokens, cache_key, reasoning_effort.
%%   Muse Spark reasons before it answers and those tokens share the budget (21 Oct: 50 tokens -> no text),
%%   so a turn without its own effort is asked for low.
chat_request(Id, Messages, Opts) ->
    Body0 = #{model => Id, max_completion_tokens => maps:get(max_output_tokens, Opts, 4096), messages => Messages,
              stream => true, stream_options => #{include_usage => true},
              reasoning_effort => maps:get(reasoning_effort, Opts, <<"low">>)},
    Body = case maps:get(cache_key, Opts, undefined) of undefined -> Body0; CK -> Body0#{prompt_cache_key => CK} end,
    {?API "/chat/completions", Body}.

upload(Key, Name, Mime, Bytes) ->
    Boundary = "----witness" ++ integer_to_list(erlang:unique_integer([positive])),
    Body = multipart(Boundary, Name, Mime, Bytes),
    case http(Key, "/files", "multipart/form-data; boundary=" ++ Boundary, Body) of
        {ok, #{<<"id">> := Id}} -> {ok, Id};
        {ok, Other} -> {error, {no_file_id, Other}};
        E -> E
    end.

multipart(Boundary, Name, Mime, Bytes) ->
    B = list_to_binary(Boundary),
    iolist_to_binary([
        "--", B, "\r\nContent-Disposition: form-data; name=\"purpose\"\r\n\r\nuser_data\r\n",
        "--", B, "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"", Name, "\"\r\n",
        "Content-Type: ", Mime, "\r\n\r\n", Bytes, "\r\n--", B, "--\r\n"]).

%% SAM 3.1 takes one short noun phrase per request ("number", "paper"); "handwriting" and "text" found nothing
%% on our test clip, "number" followed digits in the order they were written. At most 16 objects a frame.
sam_video(Key, FileId, Prompt) ->
    Req = #{model => <<"sam-3.1">>, metadata => #{include_confidence => <<"true">>},
            input => [#{type => message, role => user, content => [
                #{type => input_text, text => Prompt}, #{type => input_video, file_id => FileId}]}]},
    case responses(Key, Req) of
        {ok, R} -> {ok, text_of(R), maps:get(<<"video_frames_processed">>, maps:get(<<"usage">>, R, #{}), 0)};
        E -> E
    end.

%% read_video(Key, Model, FileId, Prompt, Opts): Muse Spark reads every frame and the sound track in one call.
%%   Opts: effort (low|medium|high, default medium), max_output_tokens (default 6000).
read_video(Key, Model, FileId, Prompt, Opts) ->
    Req = #{model => Model, reasoning => #{effort => maps:get(effort, Opts, <<"medium">>)},
            max_output_tokens => maps:get(max_output_tokens, Opts, 6000),
            input => [#{type => message, role => user, content => [
                #{type => input_text, text => Prompt}, #{type => input_file, file_id => FileId}]}]},
    case responses(Key, Req) of
        {ok, R} -> {ok, text_of(R), maps:get(<<"usage">>, R, #{})};
        E -> E
    end.

responses(Key, Req) -> http(Key, "/responses", "application/json", iolist_to_binary(json:encode(Req))).

text_of(#{<<"output">> := Out}) ->
    iolist_to_binary([T || #{<<"content">> := Cs} <- Out, is_list(Cs), #{<<"type">> := <<"output_text">>, <<"text">> := T} <- Cs]);
text_of(_) -> <<>>.

%% cost(Kind, Usage) -> dollars
cost(sam_video, Frames) -> max(Frames, ?SAM_MIN_FRAMES) * ?SAM_FRAME;
cost(sam_image, N) -> N * ?SAM_IMAGE;
cost(image, N) -> N * ?IMAGE;
cost(transcribe, Seconds) -> Seconds / 3600 * ?TRANSCRIBE_HOUR;
cost({tokens, Model}, #{} = U) ->
    {In, Out} = price(Model),
    num(maps:get(<<"input_tokens">>, U, maps:get(<<"prompt_tokens">>, U, 0))) * In / 1.0e6
        + num(maps:get(<<"output_tokens">>, U, maps:get(<<"completion_tokens">>, U, 0))) * Out / 1.0e6.

price(<<"muse-wonder", _/binary>>) -> {4.0, 20.0};
price(_) -> {1.25, 4.25}.

num(N) when is_number(N) -> N;
num(_) -> 0.

http(Key, Path, Mime, Body) ->
    Opts = [{timeout, ?TIMEOUT_MS}, {connect_timeout, 10000}, {ssl, ssl_opts()}],
    Req = {?API ++ Path, [{"authorization", "Bearer " ++ str(Key)}], Mime, Body},
    case httpc:request(post, Req, Opts, [{body_format, binary}]) of
        {ok, {{_, Code, _}, _, Resp}} when Code >= 200, Code < 300 -> {ok, json:decode(Resp)};
        {ok, {{_, Code, _}, _, Resp}} ->
            Msg = try json:decode(Resp) of #{<<"error">> := #{<<"message">> := M}} -> M; _ -> Resp catch _:_ -> Resp end,
            {error, {Code, Msg}};
        {error, R} -> {error, R}
    end.

%% api.meta.ai answers with a *.meta.ai certificate; Erlang's default hostname check refuses wildcards
%% (27 Oct, live: hostname_check_failed), so the HTTPS matching rules are asked for explicitly.
ssl_opts() ->
    [{verify, verify_peer}, {cacerts, public_key:cacerts_get()},
     {customize_hostname_check, [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]}].

str(B) when is_binary(B) -> binary_to_list(B);
str(L) when is_list(L) -> L.
