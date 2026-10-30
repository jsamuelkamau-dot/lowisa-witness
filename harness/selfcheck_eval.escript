#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% selfcheck_eval.escript <out.json> [runs]
%%
%% The self-check, measured (31 Oct 2026, after the 12-judge panel: "measured on two levels"). Muse Wonder checks each
%% of the twenty levels in selfcheck/levels.json through the product's own code (witness_check:run/2), `runs` times
%% each. A clean level should pass; a level with a planted fault should be held, and the check should name the kind:
%%   false_claim -> true_claims false      no_catch -> caught false
%%   not_work_task -> work_task false      off_idea -> on_idea false
%% The summary gives the clean pass rate (false holds are its complement), the faulty hold rate, and how often the
%% planted fault was the one named, each with a Wilson 95% interval. MODEL_API_KEY is read, never printed.
main([Out]) -> main([Out, "3"]);
main([Out, RunsS]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Here = filename:dirname(escript:script_name()),
    {ok, J} = file:read_file(filename:join([Here, "selfcheck", "levels.json"])),
    #{<<"ideas">> := Ideas, <<"levels">> := Levels} = json:decode(J),
    Jobs = [{L, R} || L <- Levels, R <- lists:seq(1, list_to_integer(RunsS))],
    Results = pmap(fun({L, R}) -> one(Key, Ideas, L, R) end, Jobs, 5),
    Summary = summary(Results),
    Meta = #{commit => list_to_binary(string:trim(os:cmd("git rev-parse HEAD"))),
             prompt_sha256 => binary:encode_hex(crypto:hash(sha256, witness_check:prompt(#{})), lowercase),
             runs => list_to_integer(RunsS), levels => length(Levels), run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second)))},
    ok = file:write_file(Out, json:encode(#{meta => Meta, summary => Summary, results => Results})),
    io:format("~n~ts~n", [json:encode(Summary)]).

one(Key, Ideas, #{<<"id">> := Id, <<"idea">> := I, <<"fault">> := Fault, <<"level">> := L}, Run) ->
    Idea = maps:get(I, Ideas),
    In = #{question => maps:get(<<"question">>, Idea), working => maps:get(<<"working">>, Idea), diagnosis => maps:get(<<"diagnosis">>, Idea),
           level => #{title => maps:get(<<"title">>, L), lessons => [#{title => maps:get(<<"title">>, Ls), beats => maps:get(<<"beats">>, Ls)} || Ls <- maps:get(<<"lessons">>, L)]}},
    T0 = erlang:monotonic_time(millisecond),
    R = try witness_check:run(Key, In) catch C:E -> {error, {C, E}} end,
    Ms = erlang:monotonic_time(millisecond) - T0,
    Base = #{id => Id, run => Run, fault => Fault, ms => Ms},
    case R of
        {ok, V, Cost} ->
            Flag = case Fault of
                <<"false_claim">> -> not maps:get(true_claims, V);
                <<"no_catch">> -> not maps:get(caught, V);
                <<"not_work_task">> -> not maps:get(work_task, V);
                <<"off_idea">> -> not maps:get(on_idea, V);
                _ -> null
            end,
            Base#{passes => maps:get(passes, V), named_the_fault => Flag, cost_usd => Cost,
                  verdict => maps:with([caught, cleared, on_idea, work_task, true_claims, why, problems, false_claims, plays], V)};
        Other -> Base#{error => unicode:characters_to_binary(io_lib:format("~0p", [Other]))}
    end.

summary(Rs) ->
    Ok = [R || R = #{passes := _} <- Rs],
    Clean = [R || R = #{fault := null} <- Ok],
    Faulty = [R || R = #{fault := F} <- Ok, F =/= null],
    #{results => length(Rs), errors => length(Rs) - length(Ok), cost_usd => lists:sum([maps:get(cost_usd, R, 0.0) || R <- Ok]),
      clean_passed => wilson(length([x || #{passes := true} <- Clean]), length(Clean)),
      faulty_held => wilson(length([x || #{passes := false} <- Faulty]), length(Faulty)),
      fault_named => wilson(length([x || #{named_the_fault := true} <- Faulty]), length(Faulty)),
      by_fault => maps:from_list([{F, #{held => length([x || #{fault := F1, passes := false} <- Faulty, F1 =:= F]),
                                        named => length([x || #{fault := F1, named_the_fault := true} <- Faulty, F1 =:= F]),
                                        of => length([x || #{fault := F1} <- Faulty, F1 =:= F])}}
                                  || F <- lists:usort([F || #{fault := F} <- Faulty])])}.

wilson(_, 0) -> #{k => 0, n => 0};
wilson(K, N) ->
    Z = 1.96, P = K / N, D = 1 + Z * Z / N,
    C = (P + Z * Z / (2 * N)) / D, H = Z * math:sqrt(P * (1 - P) / N + Z * Z / (4 * N * N)) / D,
    #{k => K, n => N, rate => round(P * 1000) / 1000, low => round(max(0.0, C - H) * 1000) / 1000, high => round(min(1.0, C + H) * 1000) / 1000}.

pmap(F, Jobs, N) ->
    Self = self(),
    Indexed = lists:zip(lists:seq(1, length(Jobs)), Jobs),
    loop(F, Indexed, N, 0, Self, #{}),
    [maps:get(I, get(results)) || {I, _} <- Indexed].

loop(_, [], _, 0, _, Acc) -> put(results, Acc);
loop(F, Queue, N, Busy, Self, Acc) when Busy < N, Queue =/= [] ->
    [{I, J} | Rest] = Queue,
    spawn(fun() -> Self ! {done, I, try F(J) catch C:E -> #{error => unicode:characters_to_binary(io_lib:format("~0p", [{C, E}]))} end} end),
    loop(F, Rest, N, Busy + 1, Self, Acc);
loop(F, Queue, N, Busy, Self, Acc) ->
    receive {done, I, R} -> io:format("."), loop(F, Queue, N, Busy - 1, Self, Acc#{I => R}) end.
