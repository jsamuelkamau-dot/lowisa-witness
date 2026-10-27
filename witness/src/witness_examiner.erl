%%%-------------------------------------------------------------------
%%% witness_examiner — two questions back, about the student's own work (hackathon, 2026-10-27).
%%%
%%% When a paper is marked, Muse Wonder picks at most two steps the student wrote and asks about each: the step where
%%% the thinking went wrong, or the one the marking is least sure of. "Why did you divide by 4 here?" The student
%%% answers out loud (Voice Transcribe hears it, in the languages they actually speak) or in writing, and Muse Spark
%%% judges the answer against that step. You cannot copy an answer and then explain your own crossing-out, so the
%%% answers show understanding and that the student did the work.
%%%
%%%   prompt(Sitting, Questions) / parse(Text) -> {ok, [#{k, n, step, ask}]}
%%%   run(Key, Sitting, Questions) -> {ok, Asks, Cost}
%%%   judge_prompt(Ask, Q, Answer) / judge(Text) -> {ok, #{own_work, understood, why}}
%%%-------------------------------------------------------------------
-module(witness_examiner).
-export([prompt/2, parse/1, run/3, judge_prompt/3, judge/1, judge_run/4]).

-define(WONDER, <<"muse-wonder-1.0">>).
-define(SPARK, <<"muse-spark-1.3">>).
-define(MAX_ASKS, 2).

prompt(Sitting, Qs) ->
    Level = str(maps:get(level, Sitting, <<"any level">>)),
    Papers = [[ "QUESTION ", integer_to_binary(maps:get(n, Q, 0)), " (", str(maps:get(result, Q, <<>>)),
                case maps:get(confidence, Q, null) of C when is_number(C) -> [", marking ", integer_to_binary(round(C * 100)), "% sure"]; _ -> "" end,
                ")", case str(maps:get(diagnosis, Q, <<>>)) of <<>> -> ""; D -> [" — where it went wrong: ", D] end, "\n",
                [["  step ", integer_to_binary(I), ": ", case maps:get(crossed_out, S, false) of true -> "(crossed out) "; _ -> "" end,
                  str(maps:get(wrote, S, <<>>)), "\n"] || {I, S} <- lists:zip(lists:seq(1, length(steps(Q))), steps(Q))]]
              || Q <- Qs],
    unicode:characters_to_binary([
        "You are an examiner. A student (", Level, ") has just finished a paper on paper; their work was marked from a\n"
        "video of their desk. Ask them AT MOST TWO short questions out loud, each about ONE step they wrote themselves.\n"
        "Choose, in this order: the step where the thinking went wrong; a right answer reached by wrong thinking; the step\n"
        "the marking is least sure of; a step they crossed out. If everything is mastered, ask about the hardest step.\n"
        "Each question names their own ink (\"You wrote 120 × 1.5. Why did you multiply here?\"), is answerable in one\n"
        "or two spoken sentences, never gives the answer away, never says it was wrong, and is in the language the\n"
        "paper is written in.\n\n", Papers, "\n"
        "Return JSON only: {\"asks\":[{\"n\":2,\"step\":1,\"ask\":\"...\"}]}"]).

parse(Text) ->
    case json_in(Text) of
        #{<<"asks">> := L} when is_list(L) ->
            Asks = [#{n => N, step => case maps:get(<<"step">>, A, 1) of S when is_integer(S) -> S; _ -> 1 end, ask => clean(Ask)}
                    || A <- L, is_map(A), N <- [maps:get(<<"n">>, A, null)], is_integer(N), Ask <- [maps:get(<<"ask">>, A, <<>>)], clean(Ask) =/= <<>>],
            {ok, [A#{k => K} || {K, A} <- lists:zip(lists:seq(1, length(lists:sublist(Asks, ?MAX_ASKS))), lists:sublist(Asks, ?MAX_ASKS))]};
        _ -> {error, no_asks}
    end.

run(Key, Sitting, Qs) ->
    Req = #{model => ?WONDER, reasoning => #{effort => <<"low">>}, max_output_tokens => 6000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(Sitting, Qs)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, #{<<"status">> := <<"incomplete">>}} -> {error, incomplete};
        {ok, R} ->
            case parse(witness_meta:text_of(R)) of
                {ok, Asks} -> {ok, [A#{wrote => wrote(Qs, A)} || A <- Asks], witness_meta:cost({tokens, ?WONDER}, maps:get(<<"usage">>, R, #{}))};
                E -> E
            end;
        E -> E
    end.

%% Spark judges one answer against the step it asks about: is it the student's own reasoning, and do they now see it?
judge_prompt(Ask, Q, Answer) ->
    unicode:characters_to_binary([
        "An examiner asked a student about a step from their own paper. Judge their answer.\n",
        "QUESTION ON THE PAPER: ", integer_to_binary(maps:get(n, Q, 0)), "\n",
        "THE STEP THEY WROTE: ", str(maps:get(wrote, Ask, <<>>)), "\n",
        "THE MARKING SAID: ", str(maps:get(result, Q, <<>>)), case str(maps:get(diagnosis, Q, <<>>)) of <<>> -> ""; D -> [" — ", D] end, "\n",
        "THE EXAMINER ASKED: ", str(maps:get(ask, Ask, <<>>)), "\n",
        "THEIR ANSWER (heard, may mix languages): ", Answer, "\n\n",
        "own_work: does the answer explain this step the way someone who wrote it would (their reason, even a wrong\n"
        "one), rather than a vague or borrowed answer? understood: do they now show the right idea? Return JSON only:\n"
        "{\"own_work\":true,\"understood\":false,\"why\":\"one plain sentence for the teacher\"}"]).

judge(Text) ->
    case json_in(Text) of
        #{<<"own_work">> := O, <<"understood">> := U} = J -> {ok, #{own_work => O =:= true, understood => U =:= true, why => str(maps:get(<<"why">>, J, <<>>))}};
        _ -> {error, no_verdict}
    end.

judge_run(Key, Ask, Q, Answer) ->
    Req = #{model => ?SPARK, reasoning => #{effort => <<"low">>}, max_output_tokens => 3000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => judge_prompt(Ask, Q, Answer)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} -> case judge(witness_meta:text_of(R)) of {ok, V} -> {ok, V, witness_meta:cost({tokens, ?SPARK}, maps:get(<<"usage">>, R, #{}))}; E -> E end;
        E -> E
    end.

wrote(Qs, #{n := N, step := S}) ->
    case [Q || Q = #{n := Qn} <- Qs, Qn =:= N] of
        [Q | _] -> case lists:nth(max(1, min(S, max(1, length(steps(Q))))), steps(Q) ++ [#{wrote => <<>>}]) of #{wrote := W} -> W; _ -> <<>> end;
        [] -> <<>>
    end.

steps(Q) -> [S || S <- maps:get(steps, Q, []), is_map(S)].

json_in(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

clean(B) when is_binary(B) -> string:slice(string:trim(B), 0, 400);
clean(_) -> <<>>.
str(B) when is_binary(B) -> B;
str(N) when is_integer(N) -> integer_to_binary(N);
str(_) -> <<>>.
