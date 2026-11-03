#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% trace_paper.escript <out.json> <page.jpg>... : one real paper through the product's own code, every Meta call
%% written down (3 Nov 2026, judges' panel: "commit one end-to-end trace of a real paper").
%%
%% The same steps the live photo path takes: Muse Spark says which edge of each photo is the top (witness_photo:orient),
%% the code turns the page (witness_media:turn), Muse Spark marks the paper in parts at once with its answers-only check
%% and any second and third readings (witness_photo:mark), and the evidence rule runs on every answer. Each call to Meta
%% is wrapped and logged: the step, the model, the effort, the time, the tokens (input, cached, output, reasoning) and
%% its cost at Meta's published prices; then, per question, what the code decided. MODEL_API_KEY is read, never printed.
%% Run from the repository root after sh scripts/test.sh (it uses the compiled code in _build). A turned page is
%% written to the temp folder, never beside the trace (the printed paper is not ours to publish).
-define(SPARK, <<"muse-spark-1.3">>).

main([Out | Files]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Log = ets:new(log, [public, ordered_set]),
    T0 = erlang:monotonic_time(millisecond),
    Note = fun(Step, Effort, Ms, Usage, Text) ->
        U = fun(K1, K2) -> deep(Usage, K1, K2) end,
        ets:insert(Log, {erlang:unique_integer([monotonic]),
                         #{step => Step, model => ?SPARK, effort => Effort, at_ms => erlang:monotonic_time(millisecond) - T0 - Ms, ms => Ms,
                           input_tokens => U(<<"input_tokens">>, none), cached_tokens => U(<<"input_tokens_details">>, <<"cached_tokens">>),
                           output_tokens => U(<<"output_tokens">>, none), reasoning_tokens => U(<<"output_tokens_details">>, <<"reasoning_tokens">>),
                           cost_usd => witness_meta:cost({tokens, ?SPARK}, Usage), reply_bytes => byte_size(Text)}})
    end,
    Pages = [#{n => N, url => list_to_binary(F)} || {N, F} <- lists:enumerate(Files)],
    %% 1. which edge is the top
    OrientRead = fun(K, Content) ->
        S = erlang:monotonic_time(millisecond),
        R = witness_meta:read_content(K, ?SPARK, Content, #{effort => <<"low">>}),
        case R of {ok, Tx, Us} -> Note(orient, <<"low">>, erlang:monotonic_time(millisecond) - S, Us, Tx); _ -> ok end,
        R
    end,
    {ok, Turns, _, Count} = witness_photo:orient(Key, Pages, #{read => OrientRead}),
    %% 2. the code turns each page that needs it
    Turned = [case maps:get(N, Turns, 0) of
                  0 -> P;
                  D -> {ok, B} = witness_media:turn(U, D, ".jpg"),
                       F = filename:join(case os:getenv("TEMP") of false -> "/tmp"; T -> T end, "witness-trace-turned-" ++ integer_to_list(N) ++ ".jpg"),
                       ok = file:write_file(F, B), P#{url => list_to_binary(F), turned => D}
              end || #{n := N, url := U} = P <- Pages],
    %% 3. the marking, every reading logged
    CacheKey = <<"witness-paper-", (integer_to_binary(erlang:phash2([maps:get(url, P) || P <- Turned])))/binary>>,
    MarkRead = fun(K, Content, Effort) ->
        S = erlang:monotonic_time(millisecond),
        R = witness_meta:read_content(K, ?SPARK, Content, #{effort => Effort, cache_key => CacheKey}),
        Step = case lists:last(Content) of
                   #{type := input_text, text := <<"\n\nIGNORE the marking", _/binary>>} -> answers_only_check;
                   _ -> case Effort of <<"medium">> -> first_reading; _ -> second_or_third_reading end
               end,
        case R of
            {ok, Tx, Us} ->
                Note(Step, Effort, erlang:monotonic_time(millisecond) - S, Us, Tx),
                %% a reply that is not a marking is kept beside the trace, to read (the live path marks the paper again)
                case Step =/= answers_only_check andalso witness_mark:parse(Tx) of
                    {error, _} -> file:write_file(filename:join(filename:dirname(Out), "unreadable-reply-" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".txt"), Tx);
                    _ -> ok
                end;
            _ -> ok
        end,
        R
    end,
    {ok, M} = witness_photo:mark(Key, [maps:with([n, url], P) || P <- Turned], #{question_count => Count},
                                 #{fetch => fun(F) -> file:read_file(F) end, read => MarkRead}),
    Secs = (erlang:monotonic_time(millisecond) - T0) / 1000,
    Calls = [C || {_, C} <- ets:tab2list(Log)],
    Qs = [#{n => maps:get(n, Q), final_answer => maps:get(final_answer, Q, <<>>), result => maps:get(result, Q),
            confidence => maps:get(confidence, Q, null), read_twice => maps:get(read_twice, Q, false),
            read_thrice => maps:get(read_thrice, Q, false), read_again_as => maps:get(read_again_as, Q, null),
            accept_all => maps:get(result, Q) =:= <<"mastered">> andalso is_number(maps:get(confidence, Q, 0)) andalso maps:get(confidence, Q, 0) >= 0.9,
            idea_named => fp(Q, misconception),
            idea_proposed_and_held => fp(Q, possible),
            diagnosis => maps:get(diagnosis, Q, <<>>)} || Q <- maps:get(questions, M)],
    Commit = list_to_binary(string:trim(os:cmd("git rev-parse --short HEAD"))),
    Summary = #{seconds => Secs, calls => length(Calls), cost_usd => lists:sum([maps:get(cost_usd, C) || C <- Calls]),
                pages => length(Pages), turned => maps:filter(fun(_, D) -> D =/= 0 end, Turns), questions => length(Qs),
                parts => maps:get(parts, M, 1), checked => maps:get(checked, M, false),
                accept_all => length([x || #{accept_all := true} <- Qs]),
                held_for_lo => length([x || #{diagnosis := D} <- Qs, binary:match(D, <<"Lo asks">>) =/= nomatch])},
    ok = file:write_file(Out, json:encode(#{commit => Commit, engine => ?SPARK,
                                            run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second))),
                                            summary => Summary, calls => Calls, questions => Qs})),
    io:format("~ts~n", [json:encode(Summary)]).

fp(Q, K) -> case maps:get(fingerprint, Q, null) of #{} = F -> maps:get(K, F, <<>>); _ -> <<>> end.

deep(U, K1, none) -> case maps:get(K1, U, null) of N when is_number(N) -> N; _ -> null end;
deep(U, K1, K2) -> case maps:get(K1, U, #{}) of #{} = D -> case maps:get(K2, D, null) of N when is_number(N) -> N; _ -> null end; _ -> null end.
