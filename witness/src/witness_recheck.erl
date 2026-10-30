%%%-------------------------------------------------------------------
%%% witness_recheck — the re-check a few days after "Turned around" (31 Oct, judges' panel).
%%%
%%% The panel's learning scientist: "mastered" rested on one immediate challenge with the same structure, answered
%%% minutes after a lesson in the same words, and nothing checked it later. Now the teacher's badge starts a clock. Once
%%% it is due (?DAYS days by default, or at once when the teacher sends it), Muse Spark writes ONE new problem on the same
%%% idea but with a different STRUCTURE (worked backwards, unequal changes, a new quantity), to be answered with the
%%% student's own number and how they got it: no options to pick from. The number is checked by code; the working is
%%% read by Muse Spark for the teacher. Until it passes, the badge reads "Repaired: re-check on <date>"; once it passes,
%%% "Still right N days later". A re-check that does not pass tells the teacher and keeps the badge the teacher's.
%%%
%%% On a question's mastery (witness_mastery):
%%%   recheck => #{due_ms, status => scheduled | open | passed | not_yet,
%%%                q, unit, answer (never shown to the student before they answer), made_ms,
%%%                reply => #{value, working, right, at, verdict => #{understood, why}}}
%%%
%%% schedule/2, send_now/2, opened/3, answer/4, view/1, measure/1 are pure; write/2 and judge/3 call Muse Spark.
%%%-------------------------------------------------------------------
-module(witness_recheck).
-export([schedule/2, schedule/3, send_now/2, due/2, opened/3, answer/4, view/1, measure/1,
         write_prompt/1, parse_item/1, write/2, judge_prompt/2, parse_verdict/1, judge/3, value_of/1, close/2]).

-define(MODEL, <<"muse-spark-1.3">>).
-define(DAYS, 7).
-define(DAY_MS, 86400000).
-define(MAX_WORKING, 1500).

m(Q) -> maps:get(mastery, Q, #{}).
put_m(Q, M) -> Q#{mastery => M}.

%% The badge is issued: the re-check is due in Days days (the exam's setting, else ?DAYS).
schedule(Q, At) -> schedule(Q, At, ?DAYS).
schedule(Q, At, Days) ->
    M = m(Q),
    case M of
        #{recheck := #{status := S}} when S =:= <<"passed">>; S =:= <<"open">> -> Q;
        _ -> put_m(Q, M#{recheck => #{status => <<"scheduled">>, due_ms => At + max(0, Days) * ?DAY_MS, set_ms => At}})
    end.

%% The teacher sends it now (a class that meets again tomorrow, or a teacher who wants to see it).
send_now(Q, At) ->
    case m(Q) of
        #{recheck := #{status := <<"scheduled">>} = R} = M -> put_m(Q, M#{recheck => R#{due_ms => At}});
        #{recheck := _} -> {error, not_scheduled};
        _ -> {error, no_badge}
    end.

due(Q, At) -> case m(Q) of #{recheck := #{status := <<"scheduled">>, due_ms := D}} -> At >= D; _ -> false end.

%% Muse Spark's new problem becomes the open re-check.
opened(Q, #{q := Text, answer := A} = Item, At) ->
    case due(Q, At) of
        false -> {error, not_due};
        true ->
            M = m(Q),
            put_m(Q, M#{recheck => (maps:get(recheck, M))#{status => <<"open">>, q => Text, answer => A, unit => maps:get(unit, Item, <<>>),
                                                           made_ms => At}})
    end.

%% The student's own number and how they got it. Right when it matches the answer to the cent (or 0.5% of it).
answer(Q, B, Verdict, At) ->
    Working = clean(maps:get(<<"working">>, B, <<>>), ?MAX_WORKING),
    case {m(Q), value_of(maps:get(<<"value">>, B, null))} of
        {#{recheck := #{status := <<"open">>, answer := A} = R} = M, V} when is_number(V) ->
            case Working of
                <<>> -> {error, empty};
                _ ->
                    Right = close(V, A),
                    Reply0 = #{value => V, working => Working, right => Right, at => At},
                    Reply = case Verdict of #{} -> Reply0#{verdict => Verdict}; _ -> Reply0 end,
                    Passed = Right andalso case Verdict of #{understood := false} -> false; _ -> true end,
                    put_m(Q, M#{recheck => R#{status => case Passed of true -> <<"passed">>; false -> <<"not_yet">> end, reply => Reply}})
            end;
        {#{recheck := #{status := <<"open">>}}, _} -> {error, bad_value};
        {#{recheck := #{reply := _}}, _} -> {error, answered};
        _ -> {error, not_asked}
    end.

close(V, A) when is_number(V), is_number(A) -> abs(V - A) =< max(0.005, abs(A) * 0.005);
close(_, _) -> false.

%% A typed answer as a number: "$1,234.50", "910 L", "-7", "37.5".
value_of(N) when is_number(N) -> N;
value_of(B) when is_binary(B) ->
    case re:run(binary:replace(B, <<",">>, <<>>, [global]), <<"-?[0-9]+(?:\\.[0-9]+)?">>, [{capture, first, binary}]) of
        {match, [D]} -> case string:to_float(D) of {F, <<>>} -> F; _ -> binary_to_integer(D) end;
        nomatch -> none
    end;
value_of(_) -> none.

%% What the student sees: when it is due, the problem, and after they answer, the right value and whether they had it.
view(#{recheck := #{status := <<"scheduled">>, due_ms := D}}) -> #{recheck => #{status => <<"scheduled">>, due_ms => D}};
view(#{recheck := #{status := <<"open">>} = R}) -> #{recheck => maps:with([status, q, unit, made_ms], R)};
%% 31 Oct (rehearsal): "days later" was said of a re-check the teacher sent the same day; `days` is how long after the
%% badge it was opened, so the phone says it only when it is true
view(#{recheck := #{reply := #{value := V, right := Rt}} = R} = M) ->
    Days = case {maps:get(made_ms, R, null), maps:get(badge, M, #{})} of
        {Made, #{at := Turned}} when is_integer(Made), is_integer(Turned) -> max(0, (Made - Turned) div 86400000);
        _ -> null
    end,
    #{recheck => (maps:with([status, q, unit, made_ms], R))#{reply => #{value => V, right => Rt, answer => maps:get(answer, R)}, days => Days}};
view(_) -> #{}.

%% For witness_measure: how the re-checks stand on a set of questions.
measure(Qs) ->
    Rs = [R || Q <- Qs, #{recheck := R} <- [m(Q)]],
    #{scheduled => length([x || #{status := <<"scheduled">>} <- Rs]), open => length([x || #{status := <<"open">>} <- Rs]),
      passed => length([x || #{status := <<"passed">>} <- Rs]), not_yet => length([x || #{status := <<"not_yet">>} <- Rs]),
      days_after_badge => [round((At - S) / ?DAY_MS * 10) / 10 || #{set_ms := S, reply := #{at := At}} <- Rs]}.

%% ---------------------------------------------------------------- Muse Spark writes the problem

write_prompt(Q) ->
    M = m(Q),
    Before = case maps:get(challenge, M, undefined) of #{q := C} -> ["THE TEACHER'S CHALLENGE ALREADY ANSWERED: ", C, "\n"]; _ -> "" end,
    unicode:characters_to_binary([
        "A student got an exam question wrong, worked through a lesson on the idea, and answered a teacher's challenge on it. ",
        "Days later, write ONE new problem that checks the idea has lasted.\n\n",
        "THE EXAM QUESTION: ", str(maps:get(question, Q, maps:get(text, Q, <<>>))), "\n",
        "THE IDEA THEY HAD WRONG: ", str(maps:get(diagnosis, Q, <<>>)), "\n", Before,
        "\nThe problem uses the SAME idea in a DIFFERENT STRUCTURE from both of those: worked backwards (find the starting ",
        "amount from the end), unequal changes, a different quantity, or two steps in a new order; never the same numbers ",
        "or the same shape. It has one exact numeric answer the student types, with no options, and everything it needs is in ",
        "it. Plain and short, for the same level. Work the answer out yourself, step by step, before you write it.\n",
        "Return JSON only: {\"q\":\"the problem\",\"answer\":123.45,\"unit\":\"$ or L or empty\",\"working\":\"your steps, for the teacher\"}"]).

parse_item(Text) ->
    case decode(Text) of
        #{<<"q">> := QT, <<"answer">> := A} = J when is_binary(QT), is_number(A) ->
            case clean(QT, 600) of
                <<>> -> {error, no_item};
                Qc -> {ok, #{q => Qc, answer => A, unit => clean(maps:get(<<"unit">>, J, <<>>), 12), working => clean(maps:get(<<"working">>, J, <<>>), 800)}}
            end;
        _ -> {error, no_item}
    end.

write(Key, Q) ->
    case call(Key, write_prompt(Q), <<"medium">>, {<<"recheck">>, witness_meta:object(#{q => #{type => string}, answer => #{type => number}, unit => #{type => string}, working => #{type => string}})}) of
        {ok, Text, Cost} -> case parse_item(Text) of {ok, I} -> {ok, I, Cost}; E -> E end;
        E -> E
    end.

%% ---------------------------------------------------------------- Muse Spark reads the working, for the teacher

judge_prompt(Q, {Value, Working}) ->
    #{q := Text, answer := A} = maps:get(recheck, m(Q)),
    unicode:characters_to_binary([
        "Days after a lesson, a student answered a new problem on an idea they once had wrong. Judge their working.\n",
        witness_text:rule(),
        "THE IDEA THEY HAD WRONG: ", str(maps:get(diagnosis, Q, <<>>)), "\n",
        "THE PROBLEM: ", Text, "\n",
        "THE RIGHT ANSWER: ", num(A), "\n",
        "THEIR ANSWER: ", num(Value), "\n",
        "HOW THEY GOT IT, IN THEIR OWN WORDS: ", witness_text:data(Working), "\n\n",
        "Does the working apply the right idea to these numbers (not luck, not the old way, not the rule named without being ",
        "used)? Judge the reasoning, not the wording. ",
        "Return JSON only: {\"understood\":true,\"why\":\"one sentence for the teacher\"}"]).

parse_verdict(Text) ->
    case decode(Text) of
        #{<<"understood">> := U} = J -> {ok, #{understood => U =:= true, why => clean(maps:get(<<"why">>, J, <<>>), 400)}};
        _ -> {error, no_verdict}
    end.

judge(Key, Q, {Value, Working}) ->
    case call(Key, judge_prompt(Q, {Value, Working}), <<"medium">>, {<<"working">>, witness_meta:object(#{understood => #{type => boolean}, why => #{type => string}})}) of
        {ok, Text, Cost} -> case parse_verdict(Text) of {ok, V} -> {ok, V, Cost}; E -> E end;
        E -> E
    end.

call(Key, Prompt, Effort, {Name, Schema}) ->
    Req = #{model => ?MODEL, reasoning => #{effort => Effort}, max_output_tokens => 6000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => Prompt}]}]},
    case witness_meta:structured(Key, Req, Name, Schema) of
        {ok, R} -> {ok, witness_meta:text_of(R), witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{}))};
        E -> E
    end.

decode(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

num(N) when is_integer(N) -> integer_to_binary(N);
num(N) when is_float(N) -> float_to_binary(N, [{decimals, 4}, compact]);
num(_) -> <<"?">>.
clean(B, Max) when is_binary(B) -> string:slice(string:trim(B), 0, Max);
clean(_, _) -> <<>>.
str(B) when is_binary(B) -> B;
str(L) when is_list(L) -> unicode:characters_to_binary(L);
str(_) -> <<>>.
