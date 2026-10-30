#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% bench.escript <cases.json> [id ...]: marks every benchmark clip through witness_sitting (SAM 3.1 + Muse Spark, the
%% same code the edge runs) and scores each question against its truth. The Meta key comes from $MK, never printed.
%%   exact  = the result is the truth
%%   sound  = mastered vs not mastered agrees (what decides whether a student gets a mastery level)
%%   no_working truth: sound when it is not given full marks as mastered (only an answer was written)
main([CasesFile | Only]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = list_to_binary(os:getenv("MODEL_API_KEY")),
    {ok, J} = file:read_file(CasesFile),
    Dir = filename:dirname(CasesFile),
    Runs0 = [{Id, Clip, C} || C = #{<<"id">> := Id} <- json:decode(J), Clip <- clips(Dir, Id),
                             Only =:= [] orelse lists:member(binary_to_list(Id), Only)],
    %% REPEAT=N marks every clip N times at once (a class sending together)
    Runs = lists:append(lists:duplicate(list_to_integer(os:getenv("REPEAT", "1")), Runs0)),
    T0 = erlang:monotonic_time(millisecond),
    Results = lists:append([batch(Key, B) || B <- chunks(Runs, list_to_integer(os:getenv("CHUNK", "4")))]),
    io:format("wall clock ~.1f s for ~p papers~n", [(erlang:monotonic_time(millisecond) - T0) / 1000, length(Runs)]),
    ok = file:write_file(filename:join(Dir, os:getenv("OUT", "bench_results.json")), json:encode(Results)),
    report(Results).

clips(Dir, Id) ->
    [P || S <- ["", "_messy"], P <- [filename:join(Dir, binary_to_list(Id) ++ S ++ ".mp4")], filelib:is_regular(P)].

chunks([], _) -> [];
chunks(L, N) when length(L) =< N -> [L];
chunks(L, N) -> {A, B} = lists:split(N, L), [A | chunks(B, N)].

batch(Key, Runs) ->
    Me = self(),
    Pids = [spawn(fun() -> Me ! {self(), run(Key, R)} end) || R <- Runs],
    [receive {P, Res} -> Res after 900000 -> #{clip => <<"timeout">>} end || P <- Pids].

run(Key, {Id, Clip, C}) ->
    #{<<"sitting">> := S0, <<"truth">> := Truth} = C,
    Sitting = #{level => maps:get(<<"level">>, S0), kind => maps:get(<<"kind">>, S0),
                questions => [#{n => N, text => T, marks => M} || #{<<"n">> := N, <<"text">> := T, <<"marks">> := M} <- maps:get(<<"questions">>, S0)]},
    Sitting1 = case S0 of #{<<"scheme">> := Sc} -> Sitting#{scheme => Sc}; _ -> Sitting end,
    {ok, Bin} = file:read_file(Clip),
    T0 = erlang:monotonic_time(millisecond),
    R = (catch witness_sitting:mark(Key, #{name => list_to_binary(filename:basename(Clip)), bytes => Bin}, Sitting1)),
    Ms = erlang:monotonic_time(millisecond) - T0,
    Base = #{id => Id, clip => list_to_binary(filename:basename(Clip)), bytes => byte_size(Bin), ms => Ms},
    case R of
        {ok, #{questions := Qs} = Res} ->
            Scored = [score(Q, lists:nth(maps:get(n, Q), Truth)) || Q <- Qs, is_integer(maps:get(n, Q, x)), maps:get(n, Q) =< length(Truth)],
            Base#{cost => maps:get(cost_usd, Res, 0), lines => length(maps:get(lines, Res, [])), questions => Scored,
                  missing => length(Truth) - length(Scored)};
        %% a video that does not show the work is refused, not marked: right only when nothing could be seen
        {error, {unreadable, W}} ->
            Base#{unreadable => W, cost => 0,
                  questions => [#{n => N, truth => T, result => <<"unreadable">>, marks => 0, out_of => 0, confidence => null,
                                  diagnosis => W, steps => [], exact => T =:= <<"unreadable">>, sound => T =:= <<"unreadable">>}
                                || {N, T} <- lists:zip(lists:seq(1, length(Truth)), Truth)]};
        E -> Base#{error => iolist_to_binary(io_lib:format("~0p", [E]))}
    end.

score(Q, Truth) ->
    Res = maps:get(result, Q), Marks = maps:get(marks, Q, 0), Of = maps:get(out_of, Q, 1),
    Mastered = Res =:= <<"mastered">>,
    {Exact, Sound} = case Truth of
        <<"unreadable">> -> {false, false};
        <<"no_working">> -> {not (Mastered andalso Marks =:= Of), not (Mastered andalso Marks =:= Of)};
        <<"mastered">> -> {Res =:= Truth, Mastered};
        _ -> {Res =:= Truth, not Mastered}
    end,
    #{n => maps:get(n, Q), truth => Truth, result => Res, marks => Marks, out_of => Of, exact => Exact, sound => Sound,
      confidence => maps:get(confidence, Q, null), diagnosis => maps:get(diagnosis, Q, <<>>),
      steps => [maps:get(wrote, St, <<>>) || St <- maps:get(steps, Q, []), is_map(St)]}.

report(Results) ->
    Qs = lists:append([maps:get(questions, R, []) || R <- Results]),
    Errs = [R || R <- Results, maps:is_key(error, R)],
    io:format("~n~-26s ~-24s ~-28s ~s~n", ["clip", "question: truth", "result", "ok"]),
    [[io:format("~-26s Q~p: ~-20s ~-28s ~s~n", [maps:get(clip, R), maps:get(n, Q), maps:get(truth, Q), maps:get(result, Q),
                                                 case {maps:get(exact, Q), maps:get(sound, Q)} of {true, _} -> "exact"; {false, true} -> "sound"; _ -> "WRONG" end])
      || Q <- maps:get(questions, R, [])] || R <- Results],
    [io:format("~-26s ERROR ~ts~n", [maps:get(clip, R), binary:part(maps:get(error, R), 0, min(300, byte_size(maps:get(error, R))))]) || R <- Errs],
    N = length(Qs),
    io:format("~nquestions ~p  exact ~p  sound ~p  wrong ~p  missing ~p  errors ~p~n",
              [N, length([1 || #{exact := true} <- Qs]), length([1 || #{sound := true} <- Qs]), length([1 || #{sound := false} <- Qs]),
               lists:sum([maps:get(missing, R, 0) || R <- Results]), length(Errs)]),
    Costs = [maps:get(cost, R) || R <- Results, maps:is_key(cost, R)],
    Secs = [maps:get(ms, R) / 1000 || R <- Results, maps:is_key(cost, R)],
    case Costs of [] -> ok; _ -> io:format("cost per paper: mean $~.4f, max $~.4f   time per paper: mean ~.1f s, max ~.1f s~n",
                                           [lists:sum(Costs) / length(Costs), lists:max(Costs), lists:sum(Secs) / length(Secs), lists:max(Secs)]) end.
