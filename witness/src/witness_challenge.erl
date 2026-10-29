%%%-------------------------------------------------------------------
%%% witness_challenge — the teacher's new challenge on a question the student turned around (owner, 30 Oct).
%%%
%%% Owner (30 Oct): "After LoWisa helps the learner understand the initial problem, the teacher can present new
%%% challenges that measure whether the learner has genuinely understood the principle rather than memorised the
%%% answer", and the learner receives it. The teacher writes it, or has Muse Spark draft one (the same idea in a new
%%% situation, the old slip as one of the options) and edits it before it goes. The student picks an answer on the
%%% phone and says why; Muse Spark reads the why against the slip, for the teacher. The badge stays the teacher's.
%%%
%%% Each question's mastery (witness_mastery) may carry
%%%   challenge => #{q, options, answer (0-based), at,
%%%                  reply => #{pick, why, right, at, verdict => #{understood, why}}}
%%% and past => the challenges before it (a new one replaces the last; at most ?MAX_PAST kept).
%%%
%%% set/3, answer/4 and view/1 are pure; suggest/2 and judge/2 call Muse Spark (prompts and parsers pure, exported).
%%%-------------------------------------------------------------------
-module(witness_challenge).
-export([set/3, answer/4, view/1, suggest_prompt/2, parse_suggestion/1, judge_prompt/2, parse_verdict/1, suggest/3, judge/3,
         evidence/1]).

-define(MODEL, <<"muse-spark-1.3">>).
-define(MAX_Q, 600).
-define(MAX_OPTION, 200).
-define(MAX_WHY, 1000).
-define(MAX_PAST, 5).

m(Q) -> maps:get(mastery, Q, #{status => <<"not_started">>}).

%% The teacher sets a challenge: a question, 2 to 5 different options and which one is right.
set(Q, B, At) ->
    Text = clean(maps:get(<<"q">>, B, <<>>), ?MAX_Q),
    Opts = [clean(O, ?MAX_OPTION) || O <- listy(maps:get(<<"options">>, B, []))],
    Answer = maps:get(<<"answer">>, B, -1),
    Distinct = length(lists:usort([string:casefold(O) || O <- Opts])) =:= length(Opts),
    case witness_mastery:needs(Q) of
        false -> {error, not_to_master};
        true when Text =:= <<>> -> {error, empty};
        true when length(Opts) < 2; length(Opts) > 5 -> {error, bad_challenge};
        true ->
            case lists:member(<<>>, Opts) orelse not Distinct orelse not is_integer(Answer) orelse Answer < 0 orelse Answer >= length(Opts) of
                true -> {error, bad_challenge};
                false ->
                    M = m(Q),
                    Past = case maps:get(challenge, M, undefined) of
                        undefined -> maps:get(past, M, []);
                        Old -> lists:sublist([Old | maps:get(past, M, [])], ?MAX_PAST)
                    end,
                    Q#{mastery => M#{challenge => #{q => Text, options => Opts, answer => Answer, at => At}, past => Past}}
            end
    end.

%% The student answers it once: the option they pick and why. The verdict (Spark's, or undefined) is the teacher's.
answer(Q, B, Verdict, At) ->
    M = m(Q),
    Pick = maps:get(<<"pick">>, B, -1),
    Why = clean(maps:get(<<"why">>, B, <<>>), ?MAX_WHY),
    case maps:get(challenge, M, undefined) of
        undefined -> {error, not_asked};
        #{reply := _} -> {error, answered};
        #{options := Opts, answer := A} = C ->
            case {is_integer(Pick) andalso Pick >= 0 andalso Pick < length(Opts), Why} of
                {false, _} -> {error, bad_pick};
                {_, <<>>} -> {error, empty};
                _ ->
                    Reply0 = #{pick => Pick, why => Why, right => Pick =:= A, at => At},
                    Reply = case Verdict of #{} -> Reply0#{verdict => Verdict}; _ -> Reply0 end,
                    Q#{mastery => M#{challenge => C#{reply => Reply}}}
            end
    end.

%% What the student sees: the question and the options; which is right only once they have answered (never the
%% verdict on their reason: that is the teacher's to read).
view(#{challenge := C}) ->
    Base = maps:with([q, options, at], C),
    case C of
        #{reply := #{pick := P, right := R}, answer := A} -> #{challenge => Base#{reply => #{pick => P, right => R, answer => A}}};
        _ -> #{challenge => Base}
    end;
view(_) -> #{}.

%% For Spark's badge recommendation: the challenge and how it went, one line.
evidence(M) ->
    case maps:get(challenge, M, undefined) of
        undefined -> "not set";
        #{q := Text, reply := #{why := Why, right := R} = Rp} ->
            [$", Text, "\" answered ", case R of true -> "right"; false -> "wrong" end, ", saying \"", Why, $",
             case maps:get(verdict, Rp, undefined) of
                 #{understood := U, why := W} -> [" (Spark: ", case U of true -> "the reason holds"; false -> "the reason does not hold" end, ": ", W, ")"];
                 _ -> ""
             end];
        #{q := Text} -> [$", Text, "\" set, not answered yet"]
    end.

%% ---------------------------------------------------------------- Muse Spark drafts one for the teacher

suggest_prompt(Q, Note) ->
    unicode:characters_to_binary([
        "A teacher wants one new question to check that a student has genuinely understood an idea they got wrong in an ",
        "exam, after a lesson on it, rather than memorised the answer to that exam question.\n\n",
        "THE EXAM QUESTION: ", str(maps:get(question, Q, maps:get(text, Q, <<>>))), "\n",
        "WHAT WENT WRONG: ", str(maps:get(diagnosis, Q, <<>>)), "\n",
        case str(maps:get(focus, Q, <<>>)) of <<>> -> ""; F -> ["THE TEACHER'S FOCUS NOTE: ", F, "\n"] end,
        case Note of <<>> -> ""; _ -> ["THE TEACHER ASKS FOR: ", Note, "\n"] end,
        "\nWrite ONE multiple-choice question that tests the SAME principle in a DIFFERENT real-world situation, with ",
        "different numbers or facts, so the old answer cannot be reused. 3 options. One is right; one is exactly what the ",
        "student's old way of thinking gives; one other common slip. Every fact the question needs is in it. Short and ",
        "plain, for the student's level. Work the right answer out yourself before you write it.\n",
        "Return JSON only: {\"q\":\"the question\",\"options\":[\"...\",\"...\",\"...\"],\"answer\":0,",
        "\"checks\":\"one sentence for the teacher: what a right answer with the right reason shows\"}"]).

parse_suggestion(Text) ->
    case decode(Text) of
        #{<<"q">> := QT, <<"options">> := Os, <<"answer">> := A} = J when is_binary(QT), is_list(Os), is_integer(A) ->
            Opts = [clean(O, ?MAX_OPTION) || O <- Os, is_binary(O)],
            case QT =/= <<>> andalso length(Opts) >= 2 andalso length(Opts) =< 5 andalso A >= 0 andalso A < length(Opts)
                 andalso not lists:member(<<>>, Opts) of
                true -> {ok, #{q => clean(QT, ?MAX_Q), options => Opts, answer => A, checks => clean(maps:get(<<"checks">>, J, <<>>), 300)}};
                false -> {error, no_suggestion}
            end;
        _ -> {error, no_suggestion}
    end.

suggest(Key, Q, Note) ->
    case call(Key, suggest_prompt(Q, Note), <<"medium">>) of
        {ok, Text, Cost} -> case parse_suggestion(Text) of {ok, S} -> {ok, S, Cost}; E -> E end;
        E -> E
    end.

%% ---------------------------------------------------------------- Muse Spark reads the student's reason

judge_prompt(Q, {Pick, Why}) ->
    #{q := Text, options := Opts, answer := A} = maps:get(challenge, m(Q)),
    unicode:characters_to_binary([
            "A student got an exam question wrong, had a lesson on it, and now answers a new question that tests the same ",
            "principle in a new situation.\n\n",
            "WHAT WENT WRONG IN THE EXAM: ", str(maps:get(diagnosis, Q, <<>>)), "\n",
            "THE NEW QUESTION: ", Text, "\n",
            "THE OPTIONS: ", lists:join("; ", [[integer_to_list(I), ". ", O] || {I, O} <- lists:zip(lists:seq(1, length(Opts)), Opts)]), "\n",
            "THE RIGHT OPTION: ", integer_to_list(A + 1), "\n",
            "THE STUDENT PICKED: ", integer_to_list(Pick + 1), "\n",
            "THEIR REASON, IN THEIR OWN WORDS: ", Why, "\n\n",
            "Does the reason show they now apply the right principle (not luck, not the old way)? Judge the reasoning, not ",
            "the wording. Return JSON only: {\"understood\":true,\"why\":\"one sentence for the teacher\"}"]).

parse_verdict(Text) ->
    case decode(Text) of
        #{<<"understood">> := U} = J -> {ok, #{understood => U =:= true, why => clean(maps:get(<<"why">>, J, <<>>), 400)}};
        _ -> {error, no_verdict}
    end.

judge(Key, Q, {Pick, Why}) ->
    case maps:get(challenge, m(Q), undefined) of
        #{} ->
            case call(Key, judge_prompt(Q, {Pick, Why}), <<"low">>) of
                {ok, Text, Cost} -> case parse_verdict(Text) of {ok, V} -> {ok, V, Cost}; E -> E end;
                E -> E
            end;
        _ -> {error, not_asked}
    end.

call(Key, Prompt, Effort) ->
    Req = #{model => ?MODEL, reasoning => #{effort => Effort}, max_output_tokens => 4000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => Prompt}]}]},
    case witness_meta:responses(Key, Req) of
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

clean(B, Max) when is_binary(B) -> string:slice(string:trim(B), 0, Max);
clean(_, _) -> <<>>.
listy(L) when is_list(L) -> L;
listy(_) -> [].
str(B) when is_binary(B) -> B;
str(L) when is_list(L) -> unicode:characters_to_binary(L);
str(_) -> <<>>.
