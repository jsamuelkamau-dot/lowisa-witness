%%%-------------------------------------------------------------------
%%% witness_proof — the Proof of Thinking record (hackathon, 2026-10-27).
%%%
%%% One dated record per paper: how each answer was written (its steps in order, with the second each was finished
%%% and what was crossed out), the marks with the model's confidence beside the teacher's word, the examiner's
%%% questions with the student's own answers, and a still of the desk at each moment that matters. The video itself
%%% is deleted once the paper is marked; this record is what remains. Pure: a sitting row in, the record out.
%%%
%%%   record(Id, Row, Pile, Viewer) -> map()      Viewer = teacher | student (the student never sees verdict text)
%%%-------------------------------------------------------------------
-module(witness_proof).
-export([record/4]).

record(Id, Row, Pile, Viewer) ->
    R = maps:get(result, Row, #{}),
    Texts = maps:from_list([{maps:get(n, Q), maps:get(text, Q, <<>>)} || Q <- maps:get(questions, Pile, []), is_map(Q)]),
    Stills = maps:from_list([{N, A} || #{n := N, asset := A} <- maps:get(stills, R, [])]),
    Qs = [question(Q, Texts, Stills) || Q <- maps:get(questions, R, [])],
    Asks = [ask(A, Viewer) || A <- maps:get(asks, maps:get(examiner, Row, #{}), [])],
    #{record => <<"proof_of_thinking">>, id => Id,
      exam => maps:get(title, Pile, <<>>), level => maps:get(level, Pile, <<>>), kind => maps:get(kind, Pile, <<"paper">>),
      student => maps:get(student, Row, <<>>),
      sat_ms => maps:get(created_ms, Row, null), marked_ms => maps:get(marked_ms, Row, null), released_ms => maps:get(released_ms, Row, null),
      questions => Qs, examiner => Asks,
      marks => lists:sum([num(maps:get(marks, Q, 0)) || Q <- Qs]), out_of => lists:sum([num(maps:get(out_of, Q, 0)) || Q <- Qs]),
      pauses => maps:get(pauses, R, []), lines => length(maps:get(lines, R, [])),
      video => <<"deleted once the paper was marked">>,
      read_by => [<<"SAM 3.1 (the ink, line by line)">>, <<"Muse Spark (the marking)">>, <<"Muse Wonder (the examiner)">>,
                  <<"Muse Voice Transcribe (spoken answers)">>]}.

question(Q, Texts, Stills) ->
    N = maps:get(n, Q, 0),
    Base = maps:with([n, result, teacher_result, marks, teacher_marks, out_of, confidence, moment_s, diagnosis, final_answer, focus], Q),
    Steps = [maps:with([t, wrote, crossed_out], S) || S <- maps:get(steps, Q, []), is_map(S)],
    Extra = maps:from_list([{K, V} || {K, V} <- [{still, maps:get(N, Stills, undefined)},
                                                  {comment, maps:get(text, maps:get(comment, Q, #{}), undefined)},
                                                  {drawn, case maps:get(drawn, Q, #{}) of #{status := <<"done">>} = D -> maps:with([asset, lines, changed], D); _ -> undefined end},
                                                  {mastery, case maps:get(mastery, Q, undefined) of #{status := S} -> S; _ -> undefined end}],
                                      V =/= undefined]),
    maps:merge(Base#{question => maps:get(N, Texts, <<>>), steps => Steps}, Extra).

ask(A, Viewer) ->
    Base = maps:with([k, n, ask, wrote], A),
    case {maps:get(answer, A, undefined), Viewer} of
        {undefined, _} -> Base#{answered => false};
        {Ans, teacher} -> Base#{answered => true, answer => maps:with([text, spoken, verdict, at], Ans)};
        {Ans, student} -> Base#{answered => true, answer => maps:with([text, spoken, at], Ans)}
    end.

num(N) when is_number(N) -> N;
num(_) -> 0.
