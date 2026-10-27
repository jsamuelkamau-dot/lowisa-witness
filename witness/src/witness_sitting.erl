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
-export([mark/3]).

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
    Sam = spawn_link(fun() -> Self ! {sam, self(), witness_meta:sam_video(Key, Video, <<"word">>, #{direction => forward})} end),
    Spark = witness_meta:read_video(Key, ?SPARK, Video, witness_mark:prompt(Sitting), #{effort => <<"medium">>}),
    SamRes = receive {sam, Sam, R} -> R after 300000 -> {error, sam_timeout} end,
    finish(Spark, SamRes, Times).

finish({ok, Text, Usage}, SamRes, Times) ->
    case witness_mark:parse(Text) of
        {ok, #{questions := Qs, pauses := Ps}} ->
            {Lines, Frames} = case SamRes of
                {ok, SamText, F} -> {witness_timeline:lines(witness_sam:records(SamText), witness_mp4:sam_times(Times, F)), F};
                _ -> {[], 0}
            end,
            PerQ = witness_timeline:merge_all([maps:get(steps, Q) || Q <- Qs], Lines),
            Placed = [Q#{steps => S} || {Q, S} <- lists:zip(Qs, PerQ)],
            Cost = witness_meta:cost({tokens, ?SPARK}, Usage) + case Frames of 0 -> 0.0; _ -> witness_meta:cost(sam_video, Frames) end,
            {ok, #{questions => Placed, pauses => Ps, lines => Lines, frames => Frames, cost_usd => Cost}};
        E -> E
    end;
finish(E, _, _) -> E.
