#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% fingerprint_eval.escript <dir of papers from heldout/make_items.py> <out.json> [runs]
%%
%% The held-out check of the Misconception Fingerprint (30 Oct 2026, after the judges' panel). Each one-page paper is
%% marked by Muse Spark through the product's own code (witness_photo:mark/4, the same prompt and the same rule in
%% witness_mark:fingerprint/4), and scored against what was expected before the run (heldout/items.py):
%%
%%   mastered  right work               -> pass when marked mastered
%%   name      the ink shows the idea   -> named_right (named, and the name or reasoning has one of the item's keys),
%%                                         named_other (named something else), asked (held back: cautious, not harmful)
%%   ask       the ink cannot tell      -> asked (pass) or named_without_evidence (the harmful error: a false label)
%%   hold      adversarial ink          -> pass when not marked mastered
%%
%% The Meta key comes from MODEL_API_KEY and is never printed. Papers are marked six at a time.
main([Dir, Out]) -> main([Dir, Out, "1"]);
main([Dir, Out, RunsS]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Specs = lists:sort(filelib:wildcard(filename:join(Dir, "*.json"))),
    Jobs = [{S, R} || S <- Specs, R <- lists:seq(1, list_to_integer(RunsS))],
    Results = pmap(fun({S, R}) -> one(Key, S, R) end, Jobs, 6),
    Summary = summary(Results),
    ok = file:write_file(Out, json:encode(#{summary => Summary, results => Results})),
    io:format("~ts~n", [json:encode(Summary)]);
main(_) -> io:format("usage: fingerprint_eval.escript papers_dir out.json [runs]~n"), halt(2).

one(Key, SpecFile, Run) ->
    {ok, J} = file:read_file(SpecFile),
    Spec = json:decode(J),
    Id = maps:get(<<"id">>, Spec), Expect = maps:get(<<"expect">>, Spec), Keys = maps:get(<<"keys">>, Spec),
    Sitting = #{level => maps:get(<<"level">>, Spec), scheme => maps:get(<<"scheme">>, Spec),
                questions => [#{n => maps:get(<<"n">>, Q), text => maps:get(<<"text">>, Q), marks => maps:get(<<"marks">>, Q)}
                              || Q <- maps:get(<<"questions">>, Spec)]},
    Jpg = filename:rootname(SpecFile) ++ ".jpg",
    T0 = erlang:monotonic_time(millisecond),
    R = try witness_photo:mark(Key, [#{n => 1, url => list_to_binary(Jpg)}], Sitting, #{fetch => fun(F) -> file:read_file(F) end})
        catch C:E -> {error, {C, E}} end,
    Ms = erlang:monotonic_time(millisecond) - T0,
    case R of
        {ok, #{questions := [Q | _]} = M} ->
            F = case maps:get(fingerprint, Q, null) of #{} = Fp -> Fp; _ -> #{} end,
            Named = maps:get(misconception, F, <<>>), Ask = maps:get(ask, F, <<>>),
            Text = string:lowercase(<<Named/binary, " ", (maps:get(reasoning, F, <<>>))/binary, " ", (maps:get(possible, F, <<>>))/binary>>),
            Hit = lists:any(fun(K) -> binary:match(Text, string:lowercase(K)) =/= nomatch end, Keys),
            Res = maps:get(result, Q),
            #{id => Id, run => Run, expect => Expect, result => Res, ms => Ms, cost_usd => maps:get(cost_usd, M, 0.0),
              steps_as_read => [maps:get(wrote, S) || S <- maps:get(steps, Q, [])],
              fingerprint => F, diagnosis => maps:get(diagnosis, Q, <<>>),
              outcome => outcome(Expect, Res, Named, Ask, Hit)};
        Other ->
            #{id => Id, run => Run, expect => Expect, outcome => <<"error">>, ms => Ms,
              error => unicode:characters_to_binary(io_lib:format("~0p", [Other]))}
    end.

outcome(<<"mastered">>, <<"mastered">>, _, _, _) -> <<"pass">>;
outcome(<<"mastered">>, _, _, _, _) -> <<"not_mastered">>;
outcome(<<"hold">>, <<"mastered">>, _, _, _) -> <<"marked_mastered">>;
outcome(<<"hold">>, _, _, _, _) -> <<"pass">>;
outcome(_, <<"mastered">>, _, _, _) -> <<"marked_mastered">>;
outcome(<<"name">>, _, <<>>, _, _) -> <<"asked">>;
outcome(<<"name">>, _, _, _, true) -> <<"named_right">>;
outcome(<<"name">>, _, _, _, false) -> <<"named_other">>;
outcome(<<"ask">>, _, <<>>, <<_, _/binary>>, _) -> <<"asked">>;
outcome(<<"ask">>, _, <<>>, _, _) -> <<"neither">>;
outcome(<<"ask">>, _, _, _, _) -> <<"named_without_evidence">>.

summary(Rs) ->
    By = fun(E) -> [R || R = #{expect := X} <- Rs, X =:= E] end,
    Count = fun(L) -> maps:from_list([{O, length([x || #{outcome := O1} <- L, O1 =:= O])} || O <- lists:usort([O2 || #{outcome := O2} <- L])]) end,
    #{papers => length(Rs), cost_usd => lists:sum([maps:get(cost_usd, R, 0.0) || R <- Rs]),
      median_ms => median([maps:get(ms, R) || R <- Rs]),
      mastered => Count(By(<<"mastered">>)), name => Count(By(<<"name">>)), ask => Count(By(<<"ask">>)), hold => Count(By(<<"hold">>))}.

median([]) -> 0;
median(L) -> lists:nth((length(L) + 1) div 2, lists:sort(L)).

%% N at a time, results in the order of the jobs
pmap(F, Jobs, N) ->
    Self = self(),
    Indexed = lists:zip(lists:seq(1, length(Jobs)), Jobs),
    run(F, Indexed, N, 0, Self, #{}),
    [maps:get(I, get(results)) || {I, _} <- Indexed].

run(_, [], _, 0, _, Acc) -> put(results, Acc);
run(F, Queue, N, Busy, Self, Acc) when Busy < N, Queue =/= [] ->
    [{I, J} | Rest] = Queue,
    spawn(fun() -> Self ! {done, I, try F(J) catch C:E -> #{outcome => <<"error">>, error => unicode:characters_to_binary(io_lib:format("~0p", [{C, E}]))} end} end),
    run(F, Rest, N, Busy + 1, Self, Acc);
run(F, Queue, N, Busy, Self, Acc) ->
    receive {done, I, R} -> io:format("."), run(F, Queue, N, Busy - 1, Self, Acc#{I => R}) end.
