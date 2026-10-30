#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% class_run.escript <dir> <out.json>: a class of 40 marked the way the product marks it (31 Oct 2026, after the
%% 12-judge panel). <dir> is make_class.py's output. All 40 two-page papers go through witness_photo:mark/4 at once
%% (the edge marks each paper as its photos arrive), then every question not mastered goes to witness_patterns:run/3
%% (Muse Wonder) with the items the API builds for POST pile/<id>/patterns. Measured: the minutes from the last photo
%% to a marked class and to its patterns, the cost of each, the name read from each page, each question against the
%% truth make_class.py wrote before the run, and each pattern group's size and how many of its lines share one drawn
%% idea. The key comes from MODEL_API_KEY and is never printed.
main([Dir, Out]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    {ok, EJ} = file:read_file(filename:join(Dir, "exam.json")), Exam = json:decode(EJ),
    {ok, TJ} = file:read_file(filename:join(Dir, "truth.json")), Truth = json:decode(TJ),
    Texts = maps:from_list([{N, T} || #{<<"n">> := N, <<"text">> := T} <- maps:get(<<"questions">>, Exam)]),
    Sitting = #{level => maps:get(<<"level">>, Exam), scheme => maps:get(<<"scheme">>, Exam),
                questions => [#{n => N, text => T, marks => M} || #{<<"n">> := N, <<"text">> := T, <<"marks">> := M} <- maps:get(<<"questions">>, Exam)]},
    T0 = erlang:monotonic_time(millisecond),
    Me = self(),
    %% a paper whose scoring fails still answers, so the class never waits on it
    Pids = [spawn(fun() -> Me ! {self(), try mark(Key, Dir, Sitting, T, T0)
                                         catch Cl:Er -> #{paper => maps:get(<<"paper">>, T), student => maps:get(<<"student">>, T),
                                                          error => unicode:characters_to_binary(io_lib:format("~0p", [{Cl, Er}]))} end} end) || T <- Truth],
    Papers = [receive {P, R} -> R after 1800000 -> #{error => <<"timeout">>} end || P <- Pids],
    MarkedMs = erlang:monotonic_time(millisecond) - T0,
    Items = [#{student => maps:get(student, P), sitting => maps:get(paper, P), n => maps:get(n, Q), question => maps:get(maps:get(n, Q), Texts, <<>>),
               result => maps:get(result, Q), diagnosis => maps:get(diagnosis, Q, <<>>),
               idea => maps:get(misconception, fp(Q), <<>>), turned_around => false,
               drawn => maps:get(drawn, Q)}
             || P <- Papers, Q <- maps:get(questions, P, []), witness_mark:needs_level(Q)],
    {Patterns, PatCost} = case witness_patterns:run(Key, #{title => maps:get(<<"title">>, Exam), level => maps:get(<<"level">>, Exam)},
                                                    [maps:remove(drawn, I) || I <- Items]) of
        {ok, Rep, C} -> {Rep, C};
        E -> {#{error => unicode:characters_to_binary(io_lib:format("~0p", [E]))}, 0}
    end,
    PatternsMs = erlang:monotonic_time(millisecond) - T0,
    Groups = [group(G, Items) || G <- maps:get(patterns, Patterns, [])],
    Qs = lists:append([maps:get(questions, P, []) || P <- Papers]),
    MarkCost = lists:sum([maps:get(cost, P, 0) || P <- Papers]),
    Summary = #{papers => length(Papers), marked => length([x || #{questions := [_ | _]} <- Papers]),
                names_read_right => length([x || #{name_right := true} <- Papers]),
                questions => length(Qs), sound => length([x || #{sound := true} <- Qs]),
                no_calculation => #{total => length([x || #{drawn := <<"no_calculation">>} <- Qs]),
                                    asked_nothing_named => length([x || #{drawn := <<"no_calculation">>, asked := true, named := <<>>} <- Qs])},
                wrong_named => length([x || #{drawn := D, named := Nm} <- Qs, D =/= <<"right">>, D =/= <<"no_calculation">>, Nm =/= <<>>]),
                wrong_total => length([x || #{drawn := D} <- Qs, D =/= <<"right">>, D =/= <<"no_calculation">>]),
                review_items => length(Items),
                minutes_to_marked => round1(MarkedMs / 60000), minutes_to_patterns => round1(PatternsMs / 60000),
                marking_cost_usd => MarkCost, patterns_cost_usd => PatCost, class_cost_usd => MarkCost + PatCost,
                groups => [maps:with([idea, lines, top_drawn, top_share], G) || G <- Groups]},
    Meta = #{commit => list_to_binary(string:trim(os:cmd("git rev-parse HEAD"))), path => <<"witness_photo:mark/4, witness_patterns:run/3">>,
             run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second)))},
    ok = file:write_file(Out, json:encode(#{meta => Meta, summary => Summary, papers => Papers, patterns => Patterns#{groups_scored => Groups}})),
    io:setopts([{encoding, unicode}]),
    io:format("~ts~n", [json:encode(maps:remove(groups, Summary))]),
    [io:format("  ~b lines, ~b% ~ts: ~ts~n", [maps:get(lines, G), round(100 * maps:get(top_share, G)), maps:get(top_drawn, G), maps:get(idea, G)]) || G <- Groups],
    ok.

mark(Key, Dir, Sitting, #{<<"paper">> := Id, <<"student">> := Name, <<"questions">> := Drawn}, T0) ->
    Page = fun(N) -> list_to_binary(filename:join(Dir, binary_to_list(Id) ++ "_p" ++ integer_to_list(N) ++ ".jpg")) end,
    R = try witness_photo:mark(Key, [#{n => 1, url => Page(1)}, #{n => 2, url => Page(2)}], Sitting, #{fetch => fun(F) -> file:read_file(F) end})
        catch Cl:Er -> {error, {Cl, Er}} end,
    Ms = erlang:monotonic_time(millisecond) - T0,
    case R of
        {ok, #{questions := Qs} = M} ->
            Read = maps:get(name, maps:get(student, M, #{}), <<>>),
            #{paper => Id, student => Name, name_read => Read, name_right => norm(Read) =:= norm(Name), done_ms => Ms,
              cost => maps:get(cost_usd, M, 0), questions => [score(Q, maps:get(integer_to_binary(maps:get(n, Q)), Drawn, <<"right">>)) || Q <- Qs]};
        E -> #{paper => Id, student => Name, done_ms => Ms, error => unicode:characters_to_binary(io_lib:format("~0p", [E]))}
    end.

score(Q, Drawn) ->
    Fp = fp(Q),
    Mastered = maps:get(result, Q) =:= <<"mastered">>,
    Q#{drawn => Drawn, sound => Mastered =:= (Drawn =:= <<"right">>),
       named => maps:get(misconception, Fp, <<>>), asked => maps:get(ask, Fp, <<>>) =/= <<>>}.

%% a group's lines are the items it names; how many share one drawn idea is the measure of the grouping
group(G, Items) ->
    Of = [{maps:get(sitting, X), maps:get(n, X)} || X <- maps:get(items, G, [])],
    Drawn = [maps:get(drawn, I) || I <- Items, lists:member({maps:get(sitting, I), maps:get(n, I)}, Of)],
    Counts = lists:foldl(fun(D, A) -> maps:update_with(D, fun(C) -> C + 1 end, 1, A) end, #{}, Drawn),
    {Top, TopN} = case lists:reverse(lists:keysort(2, maps:to_list(Counts))) of [] -> {<<>>, 0}; [T | _] -> T end,
    #{idea => maps:get(idea, G), lines => length(Drawn), drawn => Counts, top_drawn => Top,
      top_share => case Drawn of [] -> 0.0; _ -> TopN / length(Drawn) end, students => length(maps:get(students, G, []))}.

%% a mastered question carries fingerprint => null
fp(Q) -> case maps:get(fingerprint, Q, null) of M when is_map(M) -> M; _ -> #{} end.

norm(B) -> string:lowercase(string:trim(unicode:characters_to_binary(B))).
round1(X) -> round(X * 10) / 10.
