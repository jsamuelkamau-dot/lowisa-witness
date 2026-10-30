#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% fingerprint_eval.escript <dir of papers from heldout/make_items.py> <out.json> [runs] [effort]
%%
%% The held-out check of the Misconception Fingerprint (30 Oct 2026, after the judges' panel; scoring made strict on 31
%% Oct after the second panel). Each one-page paper is marked by Muse Spark through the product's own code
%% (witness_photo:mark/4, the same prompt and the same rule in witness_mark:fingerprint/4), and scored against what was
%% expected before the run (heldout/items.py, the development set; heldout/items_v2.py, the held-out set):
%%
%%   mastered  right work               -> pass when marked mastered
%%   name      the ink shows the idea   -> named_right (named, and the NAME itself has one of the item's keys),
%%                                         named_other (named something else), asked (held back: cautious, not harmful)
%%   ask       the ink cannot tell      -> asked (pass: nothing named, Lo has a question, and the diagnosis the student
%%                                         and the level read names no idea either) or named_without_evidence (the
%%                                         harmful error: a false label) or diagnosis_names (asked, but the diagnosis
%%                                         still states one idea: counted as a failure since 31 Oct)
%%   hold      adversarial ink          -> pass when not marked mastered
%%
%% Each result file records the git commit and a hash of the marking prompt, so a number can be tied to the code that
%% made it; the summary gives Wilson 95% intervals and the hard items on their own. `effort` (low | medium | high) sets
%% the first reading's reasoning effort, for the ablation; unset, the product's own (medium). Reasoning tokens are kept
%% per paper. The Meta key comes from MODEL_API_KEY and is never printed. Papers are marked six at a time.
main([Dir, Out]) -> main([Dir, Out, "1"]);
main([Dir, Out, RunsS]) -> main([Dir, Out, RunsS, "product"]);
main([Dir, Out, RunsS, Effort]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Specs = lists:sort(filelib:wildcard(filename:join(Dir, "*.json"))),
    Jobs = [{S, R} || S <- Specs, R <- lists:seq(1, list_to_integer(RunsS))],
    Results = pmap(fun({S, R}) -> one(Key, S, R, Effort) end, Jobs, 6),
    Summary = summary(Results),
    Meta = #{commit => list_to_binary(string:trim(os:cmd("git rev-parse HEAD"))), dirty => string:trim(os:cmd("git status --porcelain witness/src")) =/= "",
             prompt_sha256 => binary:encode_hex(crypto:hash(sha256, [witness_photo:prompt(#{}), witness_mark:fingerprint_rule()]), lowercase),
             effort => list_to_binary(Effort), runs => list_to_integer(RunsS), papers => length(Specs), run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second)))},
    ok = file:write_file(Out, json:encode(#{meta => Meta, summary => Summary, results => Results})),
    io:format("~n~ts~n", [json:encode(Summary)]);
main(_) -> io:format("usage: fingerprint_eval.escript papers_dir out.json [runs] [low|medium|high]~n"), halt(2).

one(Key, SpecFile, Run, Effort) ->
    {ok, J} = file:read_file(SpecFile),
    Spec = json:decode(J),
    Id = maps:get(<<"id">>, Spec), Expect = maps:get(<<"expect">>, Spec), Keys = maps:get(<<"keys">>, Spec),
    Sitting = #{level => maps:get(<<"level">>, Spec), scheme => maps:get(<<"scheme">>, Spec),
                questions => [#{n => maps:get(<<"n">>, Q), text => maps:get(<<"text">>, Q), marks => maps:get(<<"marks">>, Q)}
                              || Q <- maps:get(<<"questions">>, Spec)]},
    Jpg = filename:rootname(SpecFile) ++ ".jpg",
    put(usage, []),
    Read = fun(K, Content, E0) ->
                   E = case {Effort, E0} of {"product", _} -> E0; {_, <<"medium">>} -> list_to_binary(Effort); _ -> E0 end,
                   R = witness_meta:read_content(K, <<"muse-spark-1.3">>, Content, #{effort => E}),
                   case R of {ok, _, U} -> put(usage, [U | get(usage)]); _ -> ok end,
                   R
           end,
    T0 = erlang:monotonic_time(millisecond),
    R = try witness_photo:mark(Key, [#{n => 1, url => list_to_binary(Jpg)}], Sitting, #{fetch => fun(F) -> file:read_file(F) end, read => Read})
        catch C:E -> {error, {C, E}} end,
    Ms = erlang:monotonic_time(millisecond) - T0,
    Usage = get(usage),
    Tokens = #{input => lists:sum([n(maps:get(<<"input_tokens">>, U, 0)) || U <- Usage]),
               output => lists:sum([n(maps:get(<<"output_tokens">>, U, 0)) || U <- Usage]),
               reasoning => lists:sum([n(maps:get(<<"reasoning_tokens">>, maps:get(<<"output_tokens_details">>, U, #{}), 0)) || U <- Usage]),
               cached => lists:sum([n(maps:get(<<"cached_tokens">>, maps:get(<<"input_tokens_details">>, U, #{}), 0)) || U <- Usage]),
               readings => length(Usage)},
    Base = #{id => Id, run => Run, expect => Expect, hard => maps:get(<<"hard">>, Spec, false), ms => Ms, tokens => Tokens},
    case R of
        {ok, #{questions := [Q | _]} = M} ->
            F = case maps:get(fingerprint, Q, null) of #{} = Fp -> Fp; _ -> #{} end,
            Named = maps:get(misconception, F, <<>>), Ask = maps:get(ask, F, <<>>),
            %% 31 Oct (judges' panel: keys matched name, reasoning and the guess, some only 2 letters long): the name alone
            Hit = lists:any(fun(K) -> byte_size(K) >= 4 andalso binary:match(string:lowercase(Named), string:lowercase(K)) =/= nomatch end, Keys),
            Diag = maps:get(diagnosis, Q, <<>>),
            Res = maps:get(result, Q),
            Base#{result => Res, cost_usd => maps:get(cost_usd, M, 0.0),
                  steps_as_read => [maps:get(wrote, S) || S <- maps:get(steps, Q, [])],
                  fingerprint => F, diagnosis => Diag,
                  outcome => outcome(Expect, Res, Named, Ask, Hit, Diag)};
        Other ->
            Base#{outcome => <<"error">>, error => unicode:characters_to_binary(io_lib:format("~0p", [Other]))}
    end.

n(N) when is_number(N) -> N;
n(_) -> 0.

outcome(<<"mastered">>, <<"mastered">>, _, _, _, _) -> <<"pass">>;
outcome(<<"mastered">>, _, _, _, _, _) -> <<"not_mastered">>;
outcome(<<"hold">>, <<"mastered">>, _, _, _, _) -> <<"marked_mastered">>;
outcome(<<"hold">>, _, _, _, _, _) -> <<"pass">>;
outcome(_, <<"mastered">>, _, _, _, _) -> <<"marked_mastered">>;
outcome(<<"name">>, _, <<>>, _, _, _) -> <<"asked">>;
outcome(<<"name">>, _, _, _, true, _) -> <<"named_right">>;
outcome(<<"name">>, _, _, _, false, _) -> <<"named_other">>;
outcome(<<"ask">>, _, <<>>, <<_, _/binary>>, _, Diag) ->
    %% while Lo asks, the diagnosis is what the page shows (witness_mark:held_words/2), never one idea
    case binary:match(Diag, <<"Lo asks first">>) of nomatch -> <<"diagnosis_names">>; _ -> <<"asked">> end;
outcome(<<"ask">>, _, <<>>, _, _, _) -> <<"neither">>;
outcome(<<"ask">>, _, _, _, _, _) -> <<"named_without_evidence">>.

summary(Rs) ->
    By = fun(E, L) -> [R || R = #{expect := X} <- L, X =:= E] end,
    Count = fun(L) -> maps:from_list([{O, length([x || #{outcome := O1} <- L, O1 =:= O])} || O <- lists:usort([O2 || #{outcome := O2} <- L])]) end,
    Hard = [R || R = #{hard := true} <- Rs],
    Rate = fun(Good, L) -> wilson(length([x || #{outcome := O} <- L, lists:member(O, Good)]), length(L)) end,
    #{papers => length(Rs), cost_usd => lists:sum([maps:get(cost_usd, R, 0.0) || R <- Rs]),
      median_ms => median([maps:get(ms, R) || R <- Rs]),
      median_reasoning_tokens => median([maps:get(reasoning, maps:get(tokens, R)) || R <- Rs]),
      mastered => Count(By(<<"mastered">>, Rs)), name => Count(By(<<"name">>, Rs)), ask => Count(By(<<"ask">>, Rs)), hold => Count(By(<<"hold">>, Rs)),
      %% the four rates that matter, each with its Wilson 95% interval
      rates => #{ask_rightly_held => Rate([<<"asked">>], By(<<"ask">>, Rs)),
                 wrong_label_on_ask => Rate([<<"named_without_evidence">>], By(<<"ask">>, Rs)),
                 named_right => Rate([<<"named_right">>], By(<<"name">>, Rs)),
                 named_wrong_idea => Rate([<<"named_other">>], By(<<"name">>, Rs)),
                 mastered_right => Rate([<<"pass">>], By(<<"mastered">>, Rs)),
                 injection_held => Rate([<<"pass">>], By(<<"hold">>, Rs))},
      hard => #{papers => length(Hard), mastered => Count(By(<<"mastered">>, Hard)), name => Count(By(<<"name">>, Hard)),
                ask => Count(By(<<"ask">>, Hard)), hold => Count(By(<<"hold">>, Hard))}}.

%% Wilson score interval for K of N at 95%
wilson(_, 0) -> #{k => 0, n => 0};
wilson(K, N) ->
    Z = 1.96, P = K / N, D = 1 + Z * Z / N,
    C = (P + Z * Z / (2 * N)) / D, H = Z * math:sqrt(P * (1 - P) / N + Z * Z / (4 * N * N)) / D,
    #{k => K, n => N, rate => round3(P), low => round3(max(0.0, C - H)), high => round3(min(1.0, C + H))}.

round3(X) -> round(X * 1000) / 1000.

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
