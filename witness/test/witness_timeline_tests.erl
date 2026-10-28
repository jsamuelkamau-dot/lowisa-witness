-module(witness_timeline_tests).
-include_lib("eunit/include/eunit.hrl").

box(Kind, Body) -> <<(byte_size(Body) + 8):32, Kind/binary, Body/binary>>.

%% A minimal MP4: one video track at timescale 1000, 3 frames of 100 ms then 2 frames of 500 ms.
mp4() ->
    Hdlr = box(<<"hdlr">>, <<0:32, 0:32, "vide", 0:96, 0>>),
    Mdhd = box(<<"mdhd">>, <<0:8, 0:24, 0:32, 0:32, 1000:32, 0:32, 0:32>>),
    Stts = box(<<"stts">>, <<0:8, 0:24, 2:32, 3:32, 100:32, 2:32, 500:32>>),
    Trak = box(<<"trak">>, box(<<"mdia">>, <<Mdhd/binary, Hdlr/binary, (box(<<"minf">>, box(<<"stbl">>, Stts)))/binary>>)),
    <<(box(<<"ftyp">>, <<"isom">>))/binary, (box(<<"moov">>, Trak))/binary>>.

frame_times_test() ->
    {ok, T} = witness_mp4:frame_times(mp4()),
    ?assertEqual([0.0, 0.1, 0.2, 0.3, 0.8], T),
    ?assertEqual(0.2, witness_mp4:at(T, 2)),
    ?assertEqual(0.8, witness_mp4:at(T, 99)),
    ?assertMatch({error, _}, witness_mp4:frame_times(<<"not a clip">>)).

%% SAM numbers its own sampled frames: frame I of N sampled is the clip's frame I * Real / N
sam_times_test() ->
    {ok, T} = witness_mp4:frame_times(mp4()),            %% [0.0, 0.1, 0.2, 0.3, 0.8]
    ?assertEqual(T, witness_mp4:sam_times(T, 5)),
    ?assertEqual([0.0, 0.2, 0.3], witness_mp4:sam_times(T, 3)),
    ?assertEqual({fps, 30}, witness_mp4:sam_times({fps, 30}, 3)),
    ?assertEqual(T, witness_mp4:sam_times(T, 0)).

%% the same table read in byte ranges, from a clip whose media comes first (a 64-bit mdat header) as phones write them
frame_times_ranged_test() ->
    <<Ftyp:12/binary, Moov/binary>> = mp4(),
    Mdat = <<1:32, "mdat", (16 + 1000):64, 0:8000>>,
    Clip = <<Ftyp/binary, Mdat/binary, Moov/binary>>,
    Reads = put(reads, 0),
    Get = fun(O, L) -> put(reads, get(reads) + 1), {ok, binary:part(Clip, O, min(L, byte_size(Clip) - O))} end,
    ?assertEqual(witness_mp4:frame_times(mp4()), witness_mp4:frame_times_ranged(Get)),
    ?assertEqual(4, get(reads) - case Reads of undefined -> 0; N -> N end),   %% three headers and the moov
    ?assertEqual({error, no_moov}, witness_mp4:frame_times_ranged(fun(O, L) -> {ok, binary:part(Ftyp, O, min(L, max(0, 12 - O)))} end)),
    ?assertEqual({error, gone}, witness_mp4:frame_times_ranged(fun(_, _) -> {error, gone} end)).

b(X1, X2, Y) -> #{x1 => X1, y1 => Y, x2 => X2, y2 => Y + 30, w => 720, h => 1600}.

lines_start_end_and_order_test() ->
    Times = [float(I) || I <- lists:seq(0, 20)],
    %% line 7 is written from frame 2 to frame 6 (its box grows), then only re-seen; line 3 starts at frame 10
    Recs = [{F, 7, b(100, 100 + 40 * min(F - 1, 5), 500)} || F <- lists:seq(2, 15)] ++
           [{F, 3, b(100, 100 + 40 * (F - 9), 600)} || F <- lists:seq(10, 12)],
    [L1, L2] = witness_timeline:lines(Recs, Times),
    ?assertMatch(#{id := 7, start_s := 2.0, end_s := 6.0, box := #{x2 := 300}}, L1),
    ?assertMatch(#{id := 3, start_s := 10.0, end_s := 12.0}, L2).

merge_places_each_step_on_its_line_test() ->
    Lines = [#{id => 1, start_s => 1.0, end_s => 6.0, box => b(1, 2, 500)},
             #{id => 2, start_s => 9.0, end_s => 15.0, box => b(1, 2, 600)}],
    Steps = [#{t => 6, wrote => <<"3/4 ÷ 1/2 = 3/8"/utf8>>, crossed_out => true},
             #{t => 13, wrote => <<"= 6/4">>, crossed_out => false},
             #{t => 30, wrote => <<"later">>, crossed_out => false},
             #{t => null, wrote => <<"no time">>, crossed_out => false}],
    [A, B, C, D] = witness_timeline:merge(Steps, Lines),
    ?assertMatch(#{line := 1, box := #{y1 := 500}}, A),
    ?assertMatch(#{line := 2}, B),
    ?assertMatch(#{line := 2}, C),                      %% the nearest line when none was being written
    ?assertNot(maps:is_key(line, D)),
    ?assertEqual(Steps, witness_timeline:merge(Steps, [])).

%% The live case (27 Oct): line A seen late (11.2 s) though written by 7 s, line B seen 9.7-13.3 s; steps at
%% 7 s and 15 s must take A then B (page order), not both B.
late_sighting_keeps_page_order_test() ->
    Lines = [#{id => 1, start_s => 11.2, end_s => 11.2, box => b(67, 431, 536)},
             #{id => 0, start_s => 9.7, end_s => 13.3, box => b(124, 584, 616)},
             #{id => 2, start_s => 17.1, end_s => 20.3, box => b(73, 337, 774)}],
    Steps = [#{t => T, wrote => W, crossed_out => false} || {T, W} <- [{7, <<"a">>}, {15, <<"b">>}, {20, <<"c">>}]],
    ?assertEqual([1, 0, 2], [maps:get(line, S) || S <- witness_timeline:merge(Steps, Lines)]),
    ?assertEqual([], witness_timeline:align({}, {})).

merge_all_reads_the_page_once_test() ->
    Lines = [#{id => I, start_s => float(10 * I), end_s => float(10 * I + 5), box => b(1, 2, 100 * I)} || I <- [1, 2, 3]],
    Q1 = [#{t => 14, wrote => <<"q1">>, crossed_out => false}, #{t => 24, wrote => <<"r1">>, crossed_out => false}],
    Q2 = [#{t => 25, wrote => <<"q2">>, crossed_out => false}],
    [[A, B], [C]] = witness_timeline:merge_all([Q1, Q2], Lines),
    ?assertEqual({1, 2, 3}, {maps:get(line, A), maps:get(line, B), maps:get(line, C)}).

%% 28 Oct, live: Spark wrote one line as two steps, the second going on with the first; the second took the next line
%% down (question 2's) and the student's own step was cut from the wrong place
a_step_that_goes_on_writing_stays_on_its_line_test() ->
    L = fun(Id, Y, A, B) -> #{id => Id, start_s => A, end_s => B, box => #{x1 => 0, y1 => Y, x2 => 10, y2 => Y + 20}} end,
    Lines = [L(0, 186, 2.1, 24.5), L(1, 253, 9.6, 15.2), L(2, 301, 12.4, 15.5)],
    Steps = [#{t => 3, wrote => <<"1. 16/64 = 1/4">>}, #{t => 6, wrote => <<"1. 16/64 = 1/4 (the 6s cancel)">>},
             #{t => 11, wrote => <<"2. 1/2 = 2/4">>}, #{t => 14, wrote => <<"2/4 + 1/4 = 3/4">>}],
    ?assertEqual([0, 0, 1, 2], [maps:get(line, S) || S <- witness_timeline:merge(Steps, Lines)]),
    ?assertEqual([], witness_timeline:merge([], Lines)).


%% 29 Oct, live: SAM followed the printed questions too, and question 1's step was placed on them. A line that already
%% held ink in the first frame and gained little is the printed paper; the steps go on the lines written in the clip.
gray(W, H, Inked) ->
    << <<(case lists:any(fun({X1, Y1, X2, Y2}) -> X >= X1 andalso X < X2 andalso Y >= Y1 andalso Y < Y2 end, Inked) of
              true -> 40; false -> 230 end)>> || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1) >>.

printed_lines_test() ->
    Box = fun(X1, Y1, X2, Y2) -> #{x1 => X1, y1 => Y1, x2 => X2, y2 => Y2, w => 100, h => 100} end,
    Title = #{id => 0, start_s => 9.0, end_s => 9.5, box => Box(10, 5, 90, 15)},       %% printed, seen late by SAM
    Q1 = #{id => 1, start_s => 2.0, end_s => 6.0, box => Box(10, 30, 60, 40)},
    Q2 = #{id => 2, start_s => 12.0, end_s => 16.0, box => Box(10, 50, 70, 60)},
    First = gray(100, 100, [{10, 5, 90, 15}]),                                          %% only the print
    Last = gray(100, 100, [{10, 5, 90, 15}, {10, 30, 60, 40}, {10, 50, 70, 60}]),
    ?assertEqual(1.0, witness_timeline:ink(First, 100, maps:get(box, Title))),
    ?assertEqual(0.0, witness_timeline:ink(First, 100, maps:get(box, Q1))),
    Lines = [Title, Q1, Q2],
    ?assertEqual([0], witness_timeline:printed(Lines, First, Last, 100)),
    Steps = [[#{t => 8, wrote => <<"16/64 = 1/4">>}], [#{t => 14, wrote => <<"1/2 + 1/4 = 3/4">>}]],
    %% with the printed line in, question 1 lands on it (the bug); without it, each step is on its own line
    ?assertMatch([[0], _], [[maps:get(line, S) || S <- Q] || Q <- witness_timeline:merge_all(Steps, Lines)]),
    ?assertEqual([[1], [2]], [[maps:get(line, S) || S <- Q] || Q <- witness_timeline:merge_all(Steps, witness_timeline:written(Lines, [0]))]),
    %% a page filmed after it was written looks all printed: nothing is dropped
    ?assertEqual(Lines, witness_timeline:written(Lines, [0, 1, 2])),
    ?assertEqual(Lines, witness_timeline:written(Lines, [])).
