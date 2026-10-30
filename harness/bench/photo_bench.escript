#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% photo_bench.escript <cases.json> <out.json>: the benchmark papers marked the way the product marks a photographed
%% paper (31 Oct 2026, after the 12-judge panel: "the demoed photo path's only benchmark ran before witness_photo and
%% witness_page existed"). Each paper's finished page (its clip's last frame, <id>_last.jpg beside the cases) goes
%% through witness_photo:mark/4, the code the edge runs, and every question is scored against the truth written for
%% the case before any run, by bench.escript's rule (exact; sound = mastered or not agrees). The key comes from
%% MODEL_API_KEY and is never printed.
main([CasesFile, Out]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    {ok, J} = file:read_file(CasesFile),
    Dir = filename:dirname(CasesFile),
    Cases = [C || C = #{<<"id">> := Id} <- json:decode(J), filelib:is_regular(filename:join(Dir, binary_to_list(Id) ++ "_last.jpg"))],
    Me = self(),
    Pids = [spawn(fun() -> Me ! {self(), run(Key, Dir, C)} end) || C <- Cases],
    Results = [receive {P, R} -> R after 900000 -> #{error => <<"timeout">>} end || P <- Pids],
    Qs = lists:append([maps:get(questions, R, []) || R <- Results]),
    Summary = #{papers => length(Results), questions => length(Qs),
                exact => length([x || #{exact := true} <- Qs]), sound => length([x || #{sound := true} <- Qs]),
                cost_usd => lists:sum([maps:get(cost, R, 0) || R <- Results]),
                median_ms => median([maps:get(ms, R) || R <- Results, is_map_key(ms, R)])},
    Meta = #{commit => list_to_binary(string:trim(os:cmd("git rev-parse HEAD"))), path => <<"witness_photo:mark/4">>,
             run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second)))},
    ok = file:write_file(Out, json:encode(#{meta => Meta, summary => Summary, results => Results})),
    io:format("~ts~n", [json:encode(Summary)]).

run(Key, Dir, #{<<"id">> := Id, <<"sitting">> := S0, <<"truth">> := Truth}) ->
    Jpg = filename:join(Dir, binary_to_list(Id) ++ "_last.jpg"),
    Sitting = #{level => maps:get(<<"level">>, S0), kind => maps:get(<<"kind">>, S0, <<"paper">>),
                questions => [#{n => N, text => T, marks => M} || #{<<"n">> := N, <<"text">> := T, <<"marks">> := M} <- maps:get(<<"questions">>, S0)]},
    Sitting1 = case S0 of #{<<"scheme">> := Sc} -> Sitting#{scheme => Sc}; _ -> Sitting end,
    T0 = erlang:monotonic_time(millisecond),
    R = try witness_photo:mark(Key, [#{n => 1, url => list_to_binary(Jpg)}], Sitting1, #{fetch => fun(F) -> file:read_file(F) end})
        catch Cl:Er -> {error, {Cl, Er}} end,
    Ms = erlang:monotonic_time(millisecond) - T0,
    Base = #{id => Id, ms => Ms},
    case R of
        {ok, #{questions := Qs} = Res} ->
            Scored = [score(Q, lists:nth(maps:get(n, Q), Truth)) || Q <- Qs, is_integer(maps:get(n, Q, x)), maps:get(n, Q) >= 1, maps:get(n, Q) =< length(Truth)],
            Base#{cost => maps:get(cost_usd, Res, 0), questions => Scored, missing => length(Truth) - length(Scored)};
        {error, {unreadable, W}} ->
            Base#{unreadable => W, cost => 0,
                  questions => [#{n => N, truth => T, result => <<"unreadable">>, exact => T =:= <<"unreadable">>, sound => T =:= <<"unreadable">>}
                                || {N, T} <- lists:zip(lists:seq(1, length(Truth)), Truth)]};
        E -> Base#{error => unicode:characters_to_binary(io_lib:format("~0p", [E]))}
    end.

%% bench.escript's rule, unchanged
score(Q, Truth) ->
    Res = maps:get(result, Q), Marks = maps:get(marks, Q, 0), Of = maps:get(out_of, Q, 1),
    Mastered = Res =:= <<"mastered">>,
    {Exact, Sound} = case Truth of
        <<"unreadable">> -> {false, false};
        <<"no_working">> -> {not (Mastered andalso Marks =:= Of), not (Mastered andalso Marks =:= Of)};
        <<"mastered">> -> {Res =:= Truth, Mastered};
        _ -> {Res =:= Truth, not Mastered}
    end,
    #{n => maps:get(n, Q), truth => Truth, result => Res, marks => Marks, out_of => Of, exact => Exact, sound => Sound}.

median([]) -> 0;
median(L) -> lists:nth((length(L) + 1) div 2, lists:sort(L)).
