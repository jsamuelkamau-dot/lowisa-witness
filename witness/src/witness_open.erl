%%%-------------------------------------------------------------------
%%% witness_open — the same marking on open weights (hackathon, 2026-10-27).
%%%
%%% Muse Spark Open (Meta's open-weight release, 15 Oct 2026) is served by Baseten, Modal, Fireworks and others behind
%%% OpenAI-compatible chat completions, or run on a school's own hardware. This marks a sitting through any such
%%% endpoint: the clip becomes one frame a second (witness_media:frames/3), each frame labelled with its second, and
%%% the model gets the very prompt Muse Spark gets (witness_mark:prompt/1), so the result has the same shape and the
%%% desk, the queue, the release and the mastery levels need nothing new. There is no SAM timeline on this path:
%%% the steps keep the seconds the model read.
%%%
%%%   mark(Cfg, Clip, Sitting) -> {ok, Result} | {error, Why}
%%%       Cfg = #{url := "https://.../v1", key := Key, model := Model}   Clip = #{url := SignedUrl}
%%%   request(Model, Prompt, Frames, Fps) -> map()   (pure, for tests)
%%%-------------------------------------------------------------------
-module(witness_open).
-export([mark/3, request/4]).

-define(FPS, 1).
-define(MAX_FRAMES, 120).
-define(TIMEOUT_MS, 300000).

mark(#{url := Base, key := Key, model := Model}, #{url := Clip}, Sitting) ->
    case witness_media:frames(Clip, ?FPS, ?MAX_FRAMES) of
        {ok, []} -> {error, no_frames};
        {ok, Frames0} ->
            %% the finished page too: a one-a-second sample can stop mid-word (27 Oct, live: "= 18" for "= 18 km/h")
            Frames = case witness_media:last(Clip) of {ok, L} -> Frames0 ++ [{last, L}]; _ -> Frames0 end,
            Body = iolist_to_binary(json:encode(request(Model, witness_mark:prompt(Sitting), Frames, ?FPS))),
            case post(Base, Key, Body) of
                {ok, #{<<"choices">> := [#{<<"message">> := #{<<"content">> := Text}} | _]} = R} ->
                    case witness_mark:parse(Text) of
                        {ok, #{questions := Qs, pauses := Ps}} ->
                            {ok, #{questions => Qs, pauses => Ps, lines => [], frames => length(Frames), engine => Model,
                                   cost_usd => witness_meta:cost({tokens, Model}, maps:get(<<"usage">>, R, #{}))}};
                        E -> E
                    end;
                {ok, Other} -> {error, {no_choice, maps:keys(Other)}};
                E -> E
            end;
        E -> E
    end.

request(Model, Prompt, Frames, Fps) ->
    Label = fun({last, _}, _) -> <<"the last frame: the finished work">>;
               (_, I) -> iolist_to_binary(["frame at ", integer_to_binary(round((I - 1) / Fps)), " s"]) end,
    Labelled = lists:append([[#{type => text, text => Label(F, I)},
                              #{type => image_url, image_url => #{url => <<"data:image/jpeg;base64,", (base64:encode(case F of {last, B} -> B; B -> B end))/binary>>}}]
                             || {I, F} <- lists:zip(lists:seq(1, length(Frames)), Frames)]),
    Intro = iolist_to_binary([Prompt, "\n\nThe video is given as ", integer_to_binary(length(Frames)), " frames, ",
                              integer_to_binary(Fps), " a second, each labelled with its second; use those seconds for every time."]),
    #{model => Model, max_completion_tokens => 8000,
      messages => [#{role => user, content => [#{type => text, text => Intro} | Labelled]}]}.

post(Base, Key, Body) ->
    Url = str(Base) ++ "/chat/completions",
    Opts = [{timeout, ?TIMEOUT_MS}, {connect_timeout, 10000}, {ssl, witness_meta:ssl_opts()}],
    case httpc:request(post, {Url, [{"authorization", "Bearer " ++ str(Key)}], "application/json", Body}, Opts, [{body_format, binary}]) of
        {ok, {{_, C, _}, _, Resp}} when C >= 200, C < 300 -> {ok, json:decode(Resp)};
        {ok, {{_, C, _}, _, Resp}} -> {error, {C, binary:part(Resp, 0, min(300, byte_size(Resp)))}};
        {error, R} -> {error, R}
    end.

str(B) when is_binary(B) -> binary_to_list(B);
str(L) when is_list(L) -> L.
