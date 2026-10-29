%%%-------------------------------------------------------------------
%%% witness_proof — the Proof of Thinking record (hackathon, 2026-10-27).
%%%
%%% One dated record per paper: how each answer was written (its steps in order, with the second each was finished
%%% and what was crossed out), the marks with the model's confidence beside the teacher's word, the examiner's
%%% questions with the student's own answers, and a still and a six-second clip of the desk at each moment that
%%% matters. The video itself is deleted once the paper is marked; this record is what remains. A question the
%%% teacher saw turned around counts as mastered, the same as one right the first time, and shows its journey (the
%%% plan, 28 Oct re-audit). Spoken answers keep their recording for the teacher. Pure: a sitting row in, the record out.
%%%
%%%   record(Id, Row, Pile, Viewer) -> map()      Viewer = teacher | student (the student never sees verdict text)
%%%-------------------------------------------------------------------
-module(witness_proof).
-export([record/4]).

record(Id, Row, Pile, Viewer) ->
    R = maps:get(result, Row, #{}),
    Texts = maps:from_list([{maps:get(n, Q), maps:get(text, Q, <<>>)} || Q <- maps:get(questions, Pile, []), is_map(Q)]),
    Stills = maps:from_list([{N, S} || #{n := N} = S <- maps:get(stills, R, [])]),
    Qs = [question(Q, Texts, Stills, maps:get(created_ms, Row, null)) || Q <- maps:get(questions, R, [])],
    Asks = [ask(A, Viewer) || A <- maps:get(asks, maps:get(examiner, Row, #{}), [])],
    %% 29 Oct (From Exam to Mastery): a photographed paper keeps its pages; a filmed one (Witness) keeps no video
    Source = case maps:get(kind, Row, <<"video">>) of
        <<"photo">> -> #{source => <<"photo">>, pages => length(maps:get(files, Row, []))};
        _ -> #{source => <<"video">>, video => <<"deleted once the paper was marked">>}
    end,
    maps:merge(Source, #{record => <<"proof_of_thinking">>, id => Id,
      exam => maps:get(title, Pile, <<>>), level => maps:get(level, Pile, <<>>), kind => maps:get(kind, Pile, <<"paper">>),
      student => maps:get(student, Row, <<>>),
      sat_ms => maps:get(created_ms, Row, null), marked_ms => maps:get(marked_ms, Row, null), released_ms => maps:get(released_ms, Row, null),
      questions => Qs, examiner => Asks,
      marks => lists:sum([num(maps:get(marks, Q, 0)) || Q <- Qs]), out_of => lists:sum([num(maps:get(out_of, Q, 0)) || Q <- Qs]),
      mastered => length([Q || Q <- Qs, mastered(Q)]), turned_around => length([Q || Q <- Qs, maps:is_key(turned_around, Q)]),
      pauses => maps:get(pauses, R, []), returns => maps:get(returns, R, []), lines => length(maps:get(lines, R, [])),
      engine => maps:get(engine, R, <<"muse-spark-1.3">>),
      read_by => read_by(R, Qs, Asks)}).

%% The models that did something for this paper, and only those (28 Oct, the demo record named Voice Transcribe on a
%% paper where nothing was said out loud): a record that is proof never claims a reading that did not happen.
read_by(R, Qs, Asks) ->
    Open = maps:get(engine, R, <<"muse-spark-1.3">>) =/= <<"muse-spark-1.3">>,
    [W || {true, W} <- [{maps:get(lines, R, []) =/= [], <<"SAM 3.1 (the ink, line by line)">>},
                        {not Open, <<"Muse Spark (the marking)">>},
                        {Open, <<"Muse Spark Open on open weights (the marking)">>},
                        {Asks =/= [], <<"Muse Wonder (the examiner)">>},
                        {lists:any(fun(#{answer := #{spoken := true}}) -> true; (_) -> false end, Asks), <<"Muse Voice Transcribe (spoken answers)">>},
                        {lists:any(fun(Q) -> maps:is_key(drawn, Q) end, Qs), <<"Muse Image (the corrected step)">>}]].

question(Q, Texts, Stills, SatMs) ->
    N = maps:get(n, Q, 0),
    Still = maps:get(N, Stills, #{}),
    M = maps:get(mastery, Q, #{}),
    Turned = case M of
        #{status := <<"badge">>, badge := #{at := At} = Bd} -> #{from_ms => SatMs, at => At, note => maps:get(note, Bd, <<>>)};
        _ -> undefined
    end,
    Base = maps:with([n, result, teacher_result, marks, teacher_marks, out_of, confidence, moment_s, diagnosis, final_answer, focus, capabilities, slip], Q),
    Steps = [maps:with([t, wrote, crossed_out], S) || S <- maps:get(steps, Q, []), is_map(S)],
    Extra = maps:from_list([{K, V} || {K, V} <- [{still, maps:get(asset, Still, undefined)}, {clip, maps:get(clip, Still, undefined)},
                                                  {step, maps:get(step, Still, undefined)},
                                                  {turned_around, Turned},
                                                  {comment, maps:get(text, maps:get(comment, Q, #{}), undefined)},
                                                  {drawn, case maps:get(drawn, Q, #{}) of #{status := <<"done">>} = D -> maps:with([asset, lines, changed], D); _ -> undefined end},
                                                  {mastery, case maps:get(mastery, Q, undefined) of #{status := S} -> S; _ -> undefined end}],
                                      V =/= undefined]),
    maps:merge(Base#{question => maps:get(N, Texts, <<>>), steps => Steps}, Extra).

ask(A, Viewer) ->
    Base = maps:with([k, n, ask, wrote], A),
    case {maps:get(answer, A, undefined), Viewer} of
        {undefined, _} -> Base#{answered => false};
        {Ans, teacher} -> Base#{answered => true, answer => maps:with([text, spoken, verdict, at, audio], Ans)};
        {Ans, student} -> Base#{answered => true, answer => maps:with([text, spoken, at], Ans)}
    end.

%% mastered on the paper (by the teacher's word over the model's), or turned around since
mastered(#{turned_around := _}) -> true;
mastered(Q) -> maps:get(teacher_result, Q, maps:get(result, Q, <<>>)) =:= <<"mastered">>.

num(N) when is_number(N) -> N;
num(_) -> 0.
