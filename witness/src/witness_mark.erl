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

%% Practical mode: the same engine on a practical task (a science practical, a technical or workplace task). The
%% teacher's rubric is a list of procedure steps, each marked like a question, so the desk, the queue, the release
%% and the mastery levels all work unchanged; SAM follows the hands (witness_sitting) instead of the ink.
prompt(#{kind := <<"practical">>} = Sitting) ->
    Steps = unicode:characters_to_binary(["The procedure the teacher will mark (each step is marked like a question):\n" |
        [io_lib:format("~p. ~ts (~p marks)~n", [maps:get(n, Q), maps:get(text, Q), maps:get(marks, Q, 1)]) || Q <- maps:get(questions, Sitting, [])]]),
    Scheme = case maps:get(scheme, Sitting, <<>>) of
        <<>> -> <<"No rubric was given beyond the steps: give full marks for a step done correctly and safely.">>;
        S -> <<"The teacher's rubric (follow it exactly, including safety):\n", S/binary>>
    end,
    unicode:characters_to_binary([
        "You are assessing a student doing a practical task, from a video of their bench or desk (",
        maps:get(level, Sitting, <<"any level">>), "). Only their hands and the apparatus are in view.\n",
        Steps, "\n", Scheme, "\n\n",
        "Watch the whole video. For every procedure step judge what they DID, in order, as well as the result:\n"
        "- \"steps\" are what you saw, each with the second it was finished: an action (\"poured 50 ml into the beaker\")\n"
        "  or a reading they wrote or said (\"thermometer 21 °C\"); crossed_out is true for an action they undid or\n"
        "  a reading they struck out and wrote again;\n"
        "- \"mastered\" is done correctly and safely; \"part_way\" is done but not to the standard (an imprecise reading,\n"
        "  a step out of order that still worked); \"not_yet\" is missed, wrong or unsafe; a right result reached by a\n"
        "  wrong procedure (reading a scale from above, a measurement that was lucky) is \"right_answer_wrong_thinking\";\n"
        "- the diagnosis is ONE plain sentence naming exactly what was done wrong and why it matters; empty when\n"
        "  mastered; moment_s is the second it happened; confidence is how sure you are, 0 to 1; final_answer is the\n"
        "  step's result (a reading, an outcome), or empty.\n"
        "Return JSON only:\n"
        "{\"questions\":[{\"n\":1,\"final_answer\":\"...\",\"steps\":[{\"t\":0,\"wrote\":\"...\",\"crossed_out\":false}],"
        "\"result\":\"mastered|right_answer_wrong_thinking|part_way|not_yet\",\"marks\":0,\"out_of\":1,"
        "\"diagnosis\":\"...\",\"moment_s\":null,\"confidence\":0.9}],\"pauses\":[{\"from_s\":0,\"to_s\":0}]}\n"
        "List a pause only when nothing happened for 5 seconds or more."]);
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
        "- read every step in the order it was written, with the second it was finished; \"wrote\" is the ink exactly as\n"
        "  written (copy it, never describe it: \"16/64 = 1/4\", not \"cancelled the 6s\"); crossed_out is true only for a\n"
        "  step the student struck out to replace it, never for marks drawn as part of the working; a step whose result\n"
        "  or any part was struck through and then written again is crossed_out true, even when only one number is struck\n"
        "  (\"20 x 50 = 1000\" with the 1000 struck, then \"20/100 x 50 = 10\" below it);\n"
        "- a right final answer reached by a wrong method is \"right_answer_wrong_thinking\" (for example cancelling\n"
        "  digits that are not common factors, or two mistakes that cancel each other out);\n"
        "- \"mastered\" is right with right thinking (a slip the student corrected themselves still counts as mastered);\n"
        "- \"part_way\" is a right start that did not reach the answer; \"not_yet\" is a wrong answer or a wrong method;\n"
        "- an answer written with no working is \"part_way\" even when it is right, when the ink shows ONLY the final\n"
        "  value (\"80 km/h\") and the question needs a step that appears nowhere (a division, a conversion, a formula):\n"
        "  the thinking was never seen; the diagnosis says only the answer was written, so the teacher asks how it was\n"
        "  found. A line that shows its own calculation IS working (\"0.4 x 0.3 = 0.12\", \"3 / 8 = 0.375\"), and a\n"
        "  one-step answer that is itself the method (expanding \"4(x - 3)\" to \"4x - 12\") is judged on its own;\n"
        "- \"mastered\" always has full marks; when a mark is missing it is not mastered;\n"
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
    Marks = num(maps:get(<<"marks">>, Q, 0)), OutOf = num(maps:get(<<"out_of">>, Q, 1)),
    %% "mastered" with a mark missing says two things at once (27 Oct benchmark: three answers written with no
    %% working came back mastered at 1 of 2): it is not mastered, and the teacher looks at it first
    Torn = Result0 =:= <<"mastered">> andalso maps:is_key(<<"marks">>, Q) andalso is_number(Marks) andalso is_number(OutOf)
               andalso Marks < OutOf,
    Result = case {lists:member(Result0, results()), Torn} of {_, true} -> <<"part_way">>; {true, _} -> Result0; _ -> <<"not_yet">> end,
    Diagnosis = case {str(maps:get(<<"diagnosis">>, Q, <<>>)), Torn} of
        {<<>>, true} -> <<"Not every mark was earned: the working needs a look.">>;
        {D, _} -> D
    end,
    #{n => num(maps:get(<<"n">>, Q, maps:get(<<"q">>, Q, 0))),
      final_answer => str(maps:get(<<"final_answer">>, Q, <<>>)),
      steps => [#{t => num(maps:get(<<"t">>, S, null)), wrote => str(maps:get(<<"wrote">>, S, <<>>)),
                  crossed_out => maps:get(<<"crossed_out">>, S, false) =:= true}
                || S <- list(maps:get(<<"steps">>, Q, [])), is_map(S)],
      result => Result,
      marks => Marks,
      out_of => OutOf,
      diagnosis => case Result of <<"mastered">> -> <<>>; _ -> Diagnosis end,
      moment_s => case Result of <<"mastered">> -> null; _ -> num(maps:get(<<"moment_s">>, Q, null)) end,
      %% an unknown result is never trusted: it goes to the top of the teacher's queue
      confidence => case {Result =:= Result0, Torn} of
          {true, _} -> clamp(num(maps:get(<<"confidence">>, Q, 0)));
          {false, true} -> min(0.5, clamp(num(maps:get(<<"confidence">>, Q, 0))));
          {false, false} -> 0.0
      end}.

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
