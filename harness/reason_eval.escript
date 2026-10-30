#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% reason_eval.escript <out.json> [runs]
%%
%% The challenge reason judge, measured (31 Oct 2026, after the 12-judge panel). Each labelled reason in
%% reasons/reasons.json goes through the product's own judge (witness_challenge:judge/3, Muse Spark), `runs` times.
%% A false accept is a reason that does not hold, judged understood: the error that would let a badge through.
%% Results by kind (worked, explained, rule of thumb, old idea, words only). MODEL_API_KEY is read, never printed.
main([Out]) -> main([Out, "3"]);
main([Out, RunsS]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Here = filename:dirname(escript:script_name()),
    {ok, J} = file:read_file(filename:join([Here, "reasons", "reasons.json"])),
    #{<<"challenges">> := Cs, <<"reasons">> := Rs} = json:decode(J),
    Jobs = [{I, R, Run} || {I, R} <- lists:zip(lists:seq(1, length(Rs)), Rs), Run <- lists:seq(1, list_to_integer(RunsS))],
    Results = [one(Key, Cs, I, R, Run) || {I, R, Run} <- Jobs],
    Ok = [X || X = #{understood := _} <- Results],
    Wrong = [X || X = #{holds := false} <- Ok], Right = [X || X = #{holds := true} <- Ok],
    Summary = #{results => length(Results), errors => length(Results) - length(Ok),
                false_accepts => wilson(length([x || #{understood := true} <- Wrong]), length(Wrong)),
                false_rejects => wilson(length([x || #{understood := false} <- Right]), length(Right)),
                by_kind => maps:from_list([{K, #{accepted => length([x || #{kind := K1, understood := true} <- Ok, K1 =:= K]),
                                                 of => length([x || #{kind := K1} <- Ok, K1 =:= K])}}
                                           || K <- lists:usort([K || #{kind := K} <- Ok])]),
                cost_usd => lists:sum([maps:get(cost_usd, X, 0.0) || X <- Ok])},
    Meta = #{commit => list_to_binary(string:trim(os:cmd("git rev-parse HEAD"))), runs => list_to_integer(RunsS),
             run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second)))},
    ok = file:write_file(Out, json:encode(#{meta => Meta, summary => Summary, results => Results})),
    io:format("~ts~n", [json:encode(Summary)]).

one(Key, Cs, I, #{<<"c">> := C, <<"pick">> := Pick, <<"why">> := Why, <<"holds">> := Holds, <<"kind">> := Kind}, Run) ->
    #{<<"diagnosis">> := D, <<"q">> := QT, <<"options">> := Os, <<"answer">> := A} = maps:get(C, Cs),
    Q = #{diagnosis => D, mastery => #{challenge => #{q => QT, options => Os, answer => A, at => 0}}},
    Base = #{i => I, run => Run, challenge => C, kind => Kind, holds => Holds, pick_right => Pick =:= A},
    case catch witness_challenge:judge(Key, Q, {Pick, Why}) of
        {ok, #{understood := U, why := W}, Cost} -> Base#{understood => U, why => W, cost_usd => Cost};
        Other -> Base#{error => unicode:characters_to_binary(io_lib:format("~0p", [Other]))}
    end.

wilson(_, 0) -> #{k => 0, n => 0};
wilson(K, N) ->
    Z = 1.96, P = K / N, D = 1 + Z * Z / N,
    C = (P + Z * Z / (2 * N)) / D, H = Z * math:sqrt(P * (1 - P) / N + Z * Z / (4 * N * N)) / D,
    #{k => K, n => N, rate => round(P * 1000) / 1000, low => round(max(0.0, C - H) * 1000) / 1000, high => round(min(1.0, C + H) * 1000) / 1000}.
