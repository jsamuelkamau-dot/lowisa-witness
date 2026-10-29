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
-export([chat_request/3, ssl_opts/0, upload/4, sam_video/3, sam_video/4, read_video/5, read_content/4, fetch/1, video/1, responses/2, text_of/1, cost/2, multipart/4, range/3,
         image/2, transcribe/2, transcribe_body/2]).

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
sam_video(Key, FileId, Prompt) -> sam_video(Key, FileId, Prompt, #{}).

%% Opts: direction (forward | backward | both, default both). Tracked both ways, a line's first sighting is
%% pulled earlier than its ink, so the timeline asks for forward.
sam_video(Key, FileId, Prompt, Opts) ->
    Meta0 = #{include_confidence => <<"true">>},
    Meta = case maps:get(direction, Opts, both) of both -> Meta0; D -> Meta0#{propagation_direction => atom_to_binary(D)} end,
    Req = #{model => <<"sam-3.1">>, metadata => Meta,
            input => [#{type => message, role => user, content => [
                #{type => input_text, text => Prompt}, video(FileId)]}]},
    case responses(Key, Req) of
        {ok, R} -> {ok, text_of(R), maps:get(<<"video_frames_processed">>, maps:get(<<"usage">>, R, #{}), 0)};
        E -> E
    end.

%% read_video(Key, Model, FileId, Prompt, Opts): Muse Spark reads every frame and the sound track in one call.
%%   Opts: effort (low|medium|high, default medium), max_output_tokens (default 16000: 28 Oct re-audit, live: at medium
%%   effort Spark's thinking used 3,800-4,800 of 6,000 and some replies ran out before the JSON; high effort needs more;
%%   only the tokens used are paid for).
read_video(Key, Model, FileId, Prompt, Opts) ->
    Req = #{model => Model, reasoning => #{effort => maps:get(effort, Opts, <<"medium">>)},
            max_output_tokens => maps:get(max_output_tokens, Opts, 16000),
            input => [#{type => message, role => user, content => [
                #{type => input_text, text => Prompt}, video(FileId)]}]},
    case responses(Key, Req) of
        {ok, R} -> {ok, text_of(R), maps:get(<<"usage">>, R, #{})};
        E -> E
    end.

%% read_content(Key, Model, Content, Opts) -> {ok, Text, Usage}: one reading of any content parts (a photographed paper's
%% labelled pages, 29 Oct).
read_content(Key, Model, Content, Opts) ->
    Req = #{model => Model, reasoning => #{effort => maps:get(effort, Opts, <<"medium">>)},
            max_output_tokens => maps:get(max_output_tokens, Opts, 16000),
            input => [#{type => message, role => user, content => Content}]},
    case responses(Key, Req) of
        {ok, R} -> {ok, text_of(R), maps:get(<<"usage">>, R, #{})};
        E -> E
    end.

%% fetch(Url) -> {ok, Bytes}: a file behind a signed link (a photographed page), at most 12 MB.
fetch(Url) ->
    case httpc:request(get, {str(Url), []}, [{timeout, 30000}, {connect_timeout, 10000}, {ssl, ssl_opts()}], [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, Body}} when byte_size(Body) =< 12582912 -> {ok, Body};
        {ok, {{_, 200, _}, _, _}} -> {error, too_big};
        {ok, {{_, S, _}, _, _}} -> {error, {fetch_status, S}};
        E -> E
    end.

%% image(Key, Prompt) -> {ok, Bytes, Format}: Muse Image draws one picture (27 Oct, live: /images/generations answers
%% one b64_json WebP at 1024 square for $0.01).
image(Key, Prompt) ->
    Req = #{model => <<"muse-image-1.0">>, prompt => Prompt, n => 1, size => <<"1024x1024">>},
    case http(Key, "/images/generations", "application/json", iolist_to_binary(json:encode(Req))) of
        {ok, #{<<"data">> := [#{<<"b64_json">> := B} | _]} = R} -> {ok, base64:decode(B), maps:get(<<"output_format">>, R, <<"webp">>)};
        {ok, Other} -> {error, {no_image, maps:keys(Other)}};
        E -> E
    end.

%% transcribe(Key, Wav) -> {ok, Text, Seconds}: Muse Voice Transcribe on one recorded answer. Its file door is
%% /asr/transcribe, a JSON `request` part and an `audio` part (27 Oct, live; /audio/transcriptions is not served and
%% the audio must be WAV, which witness_media:wav/1 makes).
transcribe(Key, Wav) ->
    Boundary = "----witness" ++ integer_to_list(erlang:unique_integer([positive])),
    case http(Key, "/asr/transcribe", "multipart/form-data; boundary=" ++ Boundary, transcribe_body(Boundary, Wav)) of
        {ok, #{<<"transcript">> := T} = R} -> {ok, T, num(maps:get(<<"audioDurationMs">>, R, 0)) / 1000};
        {ok, Other} -> {error, {no_transcript, maps:keys(Other)}};
        E -> E
    end.

transcribe_body(Boundary, Wav) ->
    B = list_to_binary(Boundary),
    Req = json:encode(#{model => <<"muse-voice-transcribe-1.0">>, audioEncoding => <<"WAV">>, sampleRateHertz => 16000}),
    iolist_to_binary([
        "--", B, "\r\nContent-Disposition: form-data; name=\"request\"\r\nContent-Type: application/json\r\n\r\n", Req, "\r\n",
        "--", B, "\r\nContent-Disposition: form-data; name=\"audio\"; filename=\"answer.wav\"\r\nContent-Type: audio/wav\r\n\r\n",
        Wav, "\r\n--", B, "--\r\n"]).

%% video(Ref): a clip is either a Files API id or {url, SignedUrl}. Both SAM 3.1 and Muse Spark read a signed S3 link
%% (27 Oct, live), so a host can hand Meta the stored clip without ever holding its bytes.
video({url, Url}) -> #{type => input_video, video_url => Url};
video(FileId) -> #{type => input_video, file_id => FileId}.

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
        {ok, {{_, Code, _}, _, Resp}} when Code >= 200, Code < 300 ->
            try {ok, json:decode(Resp)} catch _:_ -> {error, {Code, not_json}} end;
        {ok, {{_, Code, _}, _, Resp}} ->
            Msg = try json:decode(Resp) of #{<<"error">> := #{<<"message">> := M}} -> M; _ -> Resp catch _:_ -> Resp end,
            {error, {Code, Msg}};
        {error, R} -> {error, R}
    end.

%% api.meta.ai answers with a *.meta.ai certificate; Erlang's default hostname check refuses wildcards
%% (27 Oct, live: hostname_check_failed), so the HTTPS matching rules are asked for explicitly.
%% range(Url, Offset, Length) -> {ok, Bytes}: one byte range of a clip behind a signed link (its frame table).
range(Url, Off, Len) ->
    Hdr = [{"range", "bytes=" ++ integer_to_list(Off) ++ "-" ++ integer_to_list(Off + Len - 1)}],
    case httpc:request(get, {str(Url), Hdr}, [{timeout, 30000}, {connect_timeout, 10000}, {ssl, ssl_opts()}], [{body_format, binary}]) of
        {ok, {{_, 206, _}, _, Body}} -> {ok, Body};
        {ok, {{_, 200, _}, _, Body}} when byte_size(Body) >= Off -> {ok, binary:part(Body, Off, min(Len, byte_size(Body) - Off))};
        {ok, {{_, S, _}, _, _}} -> {error, {range_status, S}};
        E -> E
    end.

ssl_opts() ->
    [{verify, verify_peer}, {cacerts, public_key:cacerts_get()},
     {customize_hostname_check, [{match_fun, public_key:pkix_verify_hostname_match_fun(https)}]}].

str(B) when is_binary(B) -> binary_to_list(B);
str(L) when is_list(L) -> L.
