%%%-------------------------------------------------------------------
%%% witness_sitting — one sitting, start to finish (hackathon, 2026-10-27).
%%%
%%%   mark(Key, Clip, Sitting) -> {ok, Result} | {error, Why}
%%%       Clip = #{name, bytes}    uploaded to Meta's Files API, frame times read from the clip
%%%            | #{url, fps}       a signed link Meta reads directly (the host never holds the bytes); frame times
%%%                                from the clip's own table read in byte ranges, fps only when that fails
%%%       Sitting as witness_mark:prompt/1
%%%       Result = #{questions => [Q with steps placed on the page], pauses, lines, cost_usd, frames}
%%%
%%% The clip is uploaded once; SAM 3.1 (written lines, tracked forward) and Muse Spark (the marking) read it
%%% at the same time; the steps are then placed on SAM's lines. If SAM fails the marking still stands,
%%% without places on the page; if Spark fails there is no marking and the sitting is an error.
%%%-------------------------------------------------------------------
-module(witness_sitting).
-export([mark/3, finish/3, finish/4]).

-define(SPARK, <<"muse-spark-1.3">>).

mark(Key, #{url := Url} = Clip, Sitting) ->
    Times = case witness_mp4:frame_times_ranged(fun(O, L) -> witness_meta:range(Url, O, L) end) of
        {ok, T} when T =/= [] -> T;
        _ -> {fps, maps:get(fps, Clip, 30)}
    end,
    read(Key, {url, Url}, Times, Sitting);
mark(Key, #{name := Name, bytes := Bytes}, Sitting) ->
    case witness_meta:upload(Key, Name, <<"video/mp4">>, Bytes) of
        {ok, Fid} ->
            Times = case witness_mp4:frame_times(Bytes) of {ok, T} when T =/= [] -> T; _ -> [0.0] end,
            read(Key, Fid, Times, Sitting);
        E -> E
    end.

read(Key, Video, Times, Sitting) ->
    Self = self(),
    %% on paper SAM follows the written lines ("word"); in a practical it follows the hands
    Concept = case maps:get(kind, Sitting, <<"paper">>) of <<"practical">> -> <<"hand">>; _ -> <<"word">> end,
    %% SAM only places the steps on the page: whatever happens to its call, the marking is not lost with it
    Sam = spawn_link(fun() -> Self ! {sam, self(), try witness_meta:sam_video(Key, Video, Concept, #{direction => forward})
                                                     catch C:R -> {error, {sam_crashed, C, R}} end} end),
    Spark = witness_meta:read_video(Key, ?SPARK, Video, witness_mark:prompt(Sitting), #{effort => <<"medium">>}),
    SamRes = receive {sam, Sam, R} -> R after 300000 -> {error, sam_timeout} end,
    case finish(Spark, SamRes, Times, printed_lines(Video)) of
        {ok, #{questions := Qs} = Marked} -> {ok, second_reading(Key, Video, Sitting, Marked#{questions => witness_mark:fit(Qs, Sitting)})};
        E -> E
    end.

%% When Spark is unsure of a question, the paper is read once more at high effort (witness_mark:reconcile/2); a second
%% reading that fails leaves the first as it was.
second_reading(Key, Video, Sitting, #{questions := Qs} = Marked) ->
    case witness_mark:unsure(Qs) of
        false -> Marked;
        true ->
            case witness_meta:read_video(Key, ?SPARK, Video, witness_mark:prompt(Sitting), #{effort => <<"high">>}) of
                {ok, Text, Usage} ->
                    case witness_mark:parse(Text) of
                        {ok, #{questions := Qs2}} ->
                            Second = witness_mark:fit(Qs2, Sitting),
                            Rec = witness_mark:reconcile(Qs, Second),
                            Cost = maps:get(cost_usd, Marked, 0.0) + witness_meta:cost({tokens, ?SPARK}, Usage),
                            third_reading(Key, Video, Sitting, Marked#{read_twice => true}, Qs, Second, Rec, Cost);
                        _ -> Marked
                    end;
                _ -> Marked
            end
    end.

%% Where the two readings split, a third reading decides (witness_mark:decide/4); one that fails leaves the split with
%% the teacher.
third_reading(Key, Video, Sitting, Marked, First, Second, Rec, Cost) ->
    case witness_mark:split(Rec) of
        false -> Marked#{questions => witness_mark:decide(Rec, First, Second, []), cost_usd => Cost};
        true ->
            case witness_meta:read_video(Key, ?SPARK, Video, witness_mark:prompt(Sitting), #{effort => <<"high">>}) of
                {ok, Text, Usage} ->
                    Third = case witness_mark:parse(Text) of {ok, #{questions := Qs3}} -> witness_mark:fit(Qs3, Sitting); _ -> [] end,
                    Marked#{questions => witness_mark:decide(Rec, First, Second, Third), read_thrice => Third =/= [],
                            cost_usd => Cost + witness_meta:cost({tokens, ?SPARK}, Usage)};
                _ -> Marked#{questions => witness_mark:decide(Rec, First, Second, []), cost_usd => Cost}
            end
    end.

%% Which of SAM's lines are the printed paper, read from the clip's first and last frames (a link only; ffmpeg reads it
%% over HTTP). Without ffmpeg or the frames, none are: the steps are placed on every line, as before.
printed_lines({url, Url}) ->
    fun(Lines) ->
        case [{W, H} || #{box := #{w := W, h := H}} <- Lines, is_integer(W), is_integer(H)] of
            [] -> [];
            [{W, H} | _] ->
                case witness_media:available() andalso {witness_media:gray(Url, first, W, H), witness_media:gray(Url, last, W, H)} of
                    {{ok, First}, {ok, Last}} -> try witness_timeline:printed(Lines, First, Last, W) catch _:_ -> [] end;
                    _ -> []
                end
        end
    end;
printed_lines(_) -> fun(_) -> [] end.

finish(Spark, SamRes, Times) -> finish(Spark, SamRes, Times, fun(_) -> [] end).

finish({ok, Text, Usage}, SamRes, Times, Printed) ->
    case witness_mark:parse(Text) of
        {ok, #{questions := Qs, pauses := Ps} = M} ->
            {Lines, Frames} = case SamRes of
                {ok, SamText, F} -> {try witness_timeline:lines(witness_sam:records(SamText), witness_mp4:sam_times(Times, F))
                                     catch _:_ -> [] end, F};
                _ -> {[], 0}
            end,
            PerQ = witness_timeline:merge_all([maps:get(steps, Q) || Q <- Qs], witness_timeline:written(Lines, Printed(Lines))),
            Placed = [Q#{steps => S} || {Q, S} <- lists:zip(Qs, PerQ)],
            Cost = witness_meta:cost({tokens, ?SPARK}, Usage) + case Frames of 0 -> 0.0; _ -> witness_meta:cost(sam_video, Frames) end,
            {ok, #{questions => Placed, pauses => Ps, returns => maps:get(returns, M, []), lines => Lines, frames => Frames, cost_usd => Cost}};
        E -> E
    end;
finish(E, _, _, _) -> E.
