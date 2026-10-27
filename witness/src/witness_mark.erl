%%%-------------------------------------------------------------------
%%% witness_mark — marking the path, not only the answer (hackathon, 2026-10-27).
%%%
%%% Muse Spark watches the whole sitting and returns, for every question: what was written step by step
%%% (with times and crossings-out), the final answer, marks against the teacher's scheme, one of four
%%% results, a one-sentence diagnosis of the exact misconception and the second it happened, and how sure
%%% it is. Day 1 showed the prompt matters: asked plainly at low effort, Spark called 16/64 = 1/4 by
%%% cancelling the 6s "right"; asked to judge the thinking at medium effort it named the slip at 35 s.
%%%
%%%   prompt(Sitting) -> binary              Sitting = #{questions => [#{n, text, marks}], scheme => binary,
%%%                                                      level => binary, language => binary}  (all optional)
%%%   parse(ModelText) -> {ok, Marking} | {error, Why}
%%%       Marking = #{questions => [Q], pauses => [#{from_s, to_s}]}
%%%       Q = #{n, final_answer, steps => [#{t, wrote, crossed_out}], result, marks, out_of, diagnosis,
%%%             moment_s, confidence}
%%%   needs_level(Q) -> boolean              a mastery level is offered for "not yet" and "wrong thinking"
%%%-------------------------------------------------------------------
-module(witness_mark).
-export([prompt/1, parse/1, needs_level/1, results/0]).

results() -> [<<"mastered">>, <<"right_answer_wrong_thinking">>, <<"part_way">>, <<"not_yet">>].

prompt(Sitting) ->
    Qs = case maps:get(questions, Sitting, []) of
        [] -> <<"The questions are printed on the paper.">>;
        %% characters_to_binary, never iolist_to_binary: io_lib's ~ts hands back characters, and iolist_to_binary wrote
        %% "÷" as one Latin-1 byte, so every question with a symbol or a non-English letter failed to send (27 Oct, live)
        List -> unicode:characters_to_binary(["The questions:\n" | [io_lib:format("~p. ~ts (~p marks)~n", [maps:get(n, Q), maps:get(text, Q), maps:get(marks, Q, 1)]) || Q <- List]])
    end,
    Scheme = case maps:get(scheme, Sitting, <<>>) of
        <<>> -> <<"No mark scheme was given: give 1 mark for a fully correct question, judged by its method as well as its answer.">>;
        S -> <<"The teacher's mark scheme (follow it exactly, including method marks):\n", S/binary>>
    end,
    Level = maps:get(level, Sitting, <<"any level">>),
    iolist_to_binary([
        "You are marking a student's paper from a video of their desk while they worked (", Level, ").\n",
        Qs, "\n", Scheme, "\n\n",
        "Watch the whole video. For every question, judge the THINKING as well as the final answer:\n"
        "- read every step in the order it was written, with the second it was finished, and note crossings-out;\n"
        "- a right final answer reached by a wrong method is \"right_answer_wrong_thinking\" (for example cancelling\n"
        "  digits that are not common factors, or two mistakes that cancel each other out);\n"
        "- \"mastered\" is right with right thinking (a slip the student corrected themselves still counts as mastered);\n"
        "- \"part_way\" is a right start that did not reach the answer; \"not_yet\" is a wrong answer or a wrong method;\n"
        "- the diagnosis is ONE plain sentence naming the exact misconception, never just \"wrong\"; empty when mastered;\n"
        "- moment_s is the second the thinking went wrong (null when mastered);\n"
        "- confidence is how sure you are of the result, 0 to 1.\n"
        "Return JSON only:\n"
        "{\"questions\":[{\"n\":1,\"final_answer\":\"...\",\"steps\":[{\"t\":0,\"wrote\":\"...\",\"crossed_out\":false}],"
        "\"result\":\"mastered|right_answer_wrong_thinking|part_way|not_yet\",\"marks\":0,\"out_of\":1,"
        "\"diagnosis\":\"...\",\"moment_s\":null,\"confidence\":0.9}],\"pauses\":[{\"from_s\":0,\"to_s\":0}]}\n"
        "List a pause only when nothing was written for 5 seconds or more."]).

parse(Text) ->
    case decode(Text) of
        #{<<"questions">> := Qs} = M when is_list(Qs) ->
            {ok, #{questions => [question(Q) || Q <- Qs, is_map(Q)],
                   pauses => [#{from_s => num(maps:get(<<"from_s">>, P, 0)), to_s => num(maps:get(<<"to_s">>, P, 0))}
                              || P <- list(maps:get(<<"pauses">>, M, [])), is_map(P)]}};
        _ -> {error, no_marking}
    end.

question(Q) ->
    Result0 = maps:get(<<"result">>, Q, <<>>),
    Result = case lists:member(Result0, results()) of true -> Result0; false -> <<"not_yet">> end,
    Diagnosis = str(maps:get(<<"diagnosis">>, Q, <<>>)),
    #{n => num(maps:get(<<"n">>, Q, maps:get(<<"q">>, Q, 0))),
      final_answer => str(maps:get(<<"final_answer">>, Q, <<>>)),
      steps => [#{t => num(maps:get(<<"t">>, S, null)), wrote => str(maps:get(<<"wrote">>, S, <<>>)),
                  crossed_out => maps:get(<<"crossed_out">>, S, false) =:= true}
                || S <- list(maps:get(<<"steps">>, Q, [])), is_map(S)],
      result => Result,
      marks => num(maps:get(<<"marks">>, Q, 0)),
      out_of => num(maps:get(<<"out_of">>, Q, 1)),
      diagnosis => case Result of <<"mastered">> -> <<>>; _ -> Diagnosis end,
      moment_s => case Result of <<"mastered">> -> null; _ -> num(maps:get(<<"moment_s">>, Q, null)) end,
      %% an unknown result is never trusted: it goes to the top of the teacher's queue
      confidence => case Result =:= Result0 of true -> clamp(num(maps:get(<<"confidence">>, Q, 0))); false -> 0.0 end}.

needs_level(#{result := R}) -> R =:= <<"not_yet">> orelse R =:= <<"right_answer_wrong_thinking">>.

%% The model is asked for JSON only; a code fence or a sentence around the object is tolerated.
decode(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {Start, _} ->
            End = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [Start]),
            try json:decode(binary:part(T, Start, End - Start + 1)) catch _:_ -> undefined end
    end.

list(L) when is_list(L) -> L;
list(_) -> [].
num(N) when is_number(N) -> N;
num(null) -> null;
num(B) when is_binary(B) -> case string:to_float(B) of {F, _} when is_float(F) -> F; _ -> case string:to_integer(B) of {I, _} when is_integer(I) -> I; _ -> null end end;
num(_) -> null.
str(B) when is_binary(B) -> B;
str(null) -> <<>>;
str(N) when is_number(N) -> iolist_to_binary(io_lib:format("~p", [N]));
str(_) -> <<>>.
clamp(N) when is_number(N) -> max(0.0, min(1.0, N / 1));
clamp(_) -> 0.0.
