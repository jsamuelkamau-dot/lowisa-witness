#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% parts_run.escript <private photo dir> <runs> <out.json>
%%
%% A long paper read in one go, or in parts at once (witness_photo:mark/4, 3 Nov). The real Grade 5 student's maths
%% paper (30 questions, four photos, pages upright, the answer sheet without the teacher's ink) is marked <runs> times
%% each way on this code: "one reading" gives mark/4 no question count, so it reads the whole paper at once as before
%% 3 Nov; "parts" gives it the count the quick look makes (30), so it reads questions 1-10, 11-20 and 21-30 at the same
%% time. Each run records the time, the parts, the rereadings and its agreement with the teacher's own marks.
%% The key comes from MODEL_API_KEY and is never printed.
-define(TEACHER_WRONG, [11, 12, 14, 24, 26, 29]).
main([Dir, RunsS, Out]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Files = ["blurred/57.jpg", "upright/58.jpg", "blurred/59.jpg", "noink/43.jpg"],
    Pages = [#{n => N, url => list_to_binary(filename:join(Dir, F)), mime => <<"image/jpeg">>} || {N, F} <- lists:zip([1, 2, 3, 4], Files)],
    Opts = #{fetch => fun(P) -> file:read_file(P) end, gray => fun(_) -> {error, none} end, tint => fun(_) -> none end},
    Runs = [run(Way, Key, Pages, Opts, R) || R <- lists:seq(1, list_to_integer(RunsS)), Way <- [one_reading, parts]],
    ok = file:write_file(Out, json:encode(#{run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second))),
                                             engine => <<"muse-spark-1.3">>, paper => <<"maths, 30 questions, 4 photos">>,
                                             teacher_wrong => ?TEACHER_WRONG, runs => Runs})),
    [io:format("~p run ~p: ~p s, parts ~p, agree ~p/30, caught ~p/6~n", [W, R, S, P, A, C])
     || #{way := W, run := R, seconds := S, parts := P, agree := A, caught := C} <- Runs].

run(Way, Key, Pages, Opts, R) ->
    Sitting = case Way of one_reading -> #{}; parts -> #{question_count => 30} end,
    T0 = erlang:monotonic_time(millisecond),
    case witness_photo:mark(Key, Pages, Sitting, Opts) of
        {ok, M} ->
            Secs = round((erlang:monotonic_time(millisecond) - T0) / 1000),
            Qs = maps:get(questions, M),
            Wrong = [N || #{n := N, result := Res} <- Qs, Res =/= <<"mastered">>],
            Found = [N || #{n := N} <- Qs],
            Agree = length([N || N <- lists:seq(1, 30), lists:member(N, Wrong) =:= lists:member(N, ?TEACHER_WRONG), lists:member(N, Found)]),
            #{way => Way, run => R, seconds => Secs, parts => maps:get(parts, M, 1), read_twice => maps:get(read_twice, M, false),
              read_thrice => maps:get(read_thrice, M, false), questions_back => length(Found), marked_wrong => Wrong,
              agree => Agree, caught => length([N || N <- ?TEACHER_WRONG, lists:member(N, Wrong)]), cost_usd => maps:get(cost_usd, M, null)};
        E -> #{way => Way, run => R, error => iolist_to_binary(io_lib:format("~0p", [E])), seconds => null, parts => null, agree => 0, caught => 0}
    end.
