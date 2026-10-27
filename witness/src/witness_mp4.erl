%%%-------------------------------------------------------------------
%%% witness_mp4 — when each frame of a clip was shown (hackathon, 2026-10-27).
%%%
%%% SAM 3.1 numbers frames from 0; a phone records at a variable rate (the emulator's 44 s test clip held
%%% 314 frames), so a frame number is turned into seconds with the clip's own sample table (stts) rather
%%% than a guessed frame rate. Reads the first video track; no decoding.
%%%
%%%   frame_times(Mp4Bytes) -> {ok, [Seconds]} | {error, Why}
%%%   frame_times_ranged(Get) -> the same for a clip held elsewhere; Get(Offset, Length) -> {ok, Bytes} reads a byte
%%%       range (the top-level box headers, then the moov box), so the host never fetches the video itself.
%%%       Live, 27 Oct: a phone upload marked with a guessed 30 fps put every line in the first 3 s of a 28 s clip
%%%       of 127 frames; the clip's own table put them where the ink was written.
%%%-------------------------------------------------------------------
-module(witness_mp4).
-export([frame_times/1, frame_times_ranged/1, at/2]).

-define(MAX_MOOV, 64 * 1024 * 1024).
-define(MAX_HOPS, 16).

frame_times(Bin) ->
    try
        Moov = find(Bin, [<<"moov">>]),
        Trak = hd([T || {<<"trak">>, T} <- boxes(Moov), is_video(T)]),
        Mdhd = find(Trak, [<<"mdia">>, <<"mdhd">>]),
        Scale = timescale(Mdhd),
        Stts = find(Trak, [<<"mdia">>, <<"minf">>, <<"stbl">>, <<"stts">>]),
        {ok, times(Stts, Scale)}
    catch _:Why -> {error, Why}
    end.

frame_times_ranged(Get) -> moov_at(Get, 0, 0).

moov_at(_, _, Hops) when Hops >= ?MAX_HOPS -> {error, no_moov};
moov_at(Get, Off, Hops) ->
    case Get(Off, 16) of
        {ok, <<1:32, "moov", Size:64, _/binary>>} -> read_moov(Get, Off, Size);
        {ok, <<Size:32, "moov", _/binary>>} when Size >= 8 -> read_moov(Get, Off, Size);
        {ok, <<1:32, _:4/binary, Size:64, _/binary>>} when Size >= 16 -> moov_at(Get, Off + Size, Hops + 1);
        {ok, <<Size:32, _:4/binary, _/binary>>} when Size >= 8 -> moov_at(Get, Off + Size, Hops + 1);
        {ok, _} -> {error, no_moov};
        E -> E
    end.

read_moov(_, _, Size) when Size > ?MAX_MOOV -> {error, moov_too_big};
read_moov(Get, Off, Size) ->
    case Get(Off, Size) of
        {ok, B} when byte_size(B) =:= Size -> frame_times(B);
        {ok, _} -> {error, short_read};
        E -> E
    end.

%% at(Times, Frame) -> seconds of a SAM frame number (the last time when the number runs past the table).
%% Times may also be {fps, N} for a clip recorded at a steady rate (a phone camera), when its bytes are not at hand.
at({fps, Fps}, F) when is_number(Fps), Fps > 0 -> F / Fps;
at(Times, F) when F >= 0, F < length(Times) -> lists:nth(F + 1, Times);
at(Times, _) -> lists:last(Times).

boxes(<<>>) -> [];
boxes(<<1:32, Kind:4/binary, Size:64, Rest/binary>>) when Size >= 16 ->
    Len = Size - 16, <<Body:Len/binary, More/binary>> = Rest, [{Kind, Body} | boxes(More)];
boxes(<<0:32, Kind:4/binary, Rest/binary>>) -> [{Kind, Rest}];
boxes(<<Size:32, Kind:4/binary, Rest/binary>>) when Size >= 8 ->
    Len = Size - 8, <<Body:Len/binary, More/binary>> = Rest, [{Kind, Body} | boxes(More)];
boxes(_) -> [].

find(Bin, []) -> Bin;
find(Bin, [Kind | Path]) ->
    case [B || {K, B} <- boxes(Bin), K =:= Kind] of
        [B | _] -> find(B, Path);
        [] -> throw({no_box, Kind})
    end.

is_video(Trak) ->
    try find(Trak, [<<"mdia">>, <<"hdlr">>]) of <<_:8/binary, Type:4/binary, _/binary>> -> Type =:= <<"vide">>
    catch _:_ -> false
    end.

timescale(<<0, _:3/binary, _:8/binary, Scale:32, _/binary>>) -> Scale;
timescale(<<1, _:3/binary, _:16/binary, Scale:32, _/binary>>) -> Scale.

times(<<_Ver:8, _Flags:24, N:32, Entries/binary>>, Scale) ->
    {Out, _} = lists:foldl(fun({Count, Delta}, {Acc, T}) ->
        Ts = [(T + I * Delta) / Scale || I <- lists:seq(0, Count - 1)],
        {[Ts | Acc], T + Count * Delta}
    end, {[], 0}, [{C, D} || <<C:32, D:32>> <= binary:part(Entries, 0, N * 8)]),
    lists:append(lists:reverse(Out)).
