%%%-------------------------------------------------------------------
%%% witness_measure — the pilot's numbers, measured, never estimated (hackathon, 2026-10-27).
%%%
%%% For one exam: how often the teacher agreed with Witness on the questions they reviewed, how many right answers
%%% reached by wrong thinking Witness caught that the teacher kept (a photo of the final answer marks those right),
%%% how long marking took on the server, and how long the teacher spent on each paper at the desk (the desk sends the
%%% seconds a paper was open with each review), how many questions were turned around, and how the re-checks a few
%%% days later came out (witness_recheck). Pure: the exam's sittings in, the numbers out.
%%%
%%%   exam([{Id, Row}]) -> map()
%%%-------------------------------------------------------------------
-module(witness_measure).
-export([exam/1]).

exam(Ss) ->
    Marked = [R || {_, R = #{result := #{questions := _}}} <- Ss],
    Qs = [Q || R <- Marked, Q <- maps:get(questions, maps:get(result, R))],
    Reviewed = [Q || Q <- Qs, maps:get(reviewed, Q, false)],
    Agree = [Q || Q <- Reviewed, maps:get(teacher_result, Q, maps:get(result, Q)) =:= maps:get(result, Q)],
    Wrong = [Q || Q <- Qs, maps:get(result, Q) =:= <<"right_answer_wrong_thinking">>],
    WrongKept = [Q || Q <- Wrong, maps:get(reviewed, Q, false), maps:get(teacher_result, Q, maps:get(result, Q)) =:= <<"right_answer_wrong_thinking">>],
    MarkS = [(M - S) / 1000 || #{started_ms := S, marked_ms := M} <- Marked, is_integer(S), is_integer(M), M >= S],
    DeskS = [num(S) || R <- Marked, S <- [maps:get(desk_s, R, undefined)], is_number(S)],
    Asks = [A || R <- Marked, A <- maps:get(asks, maps:get(examiner, R, #{}), [])],
    Answered = [A || A = #{answer := _} <- Asks],
    #{papers => length(Ss), marked => length(Marked), questions => length(Qs),
      reviewed => length(Reviewed), teacher_agreed => length(Agree),
      agreement => ratio(length(Agree), length(Reviewed)),
      changed_by_teacher => [#{n => maps:get(n, Q), witness => maps:get(result, Q), teacher => maps:get(teacher_result, Q)} || Q <- Reviewed, not lists:member(Q, Agree)],
      wrong_thinking_caught => length(Wrong), wrong_thinking_kept_by_teacher => length(WrongKept),
      marking_seconds => stats(MarkS), teacher_seconds_per_paper => stats(DeskS),
      examiner_asks => length(Asks), examiner_answered => length(Answered),
      examiner_own_work => length([A || #{answer := #{verdict := #{own_work := true}}} = A <- Answered]),
      cost_usd => lists:sum([num(maps:get(cost_usd, maps:get(result, R), 0)) || R <- Marked]),
      %% 31 Oct (judges' panel): what the teacher saw turned around, and whether it held a few days later
      turned_around => length([Q || Q <- Qs, maps:get(status, maps:get(mastery, Q, #{}), <<>>) =:= <<"badge">>]),
      rechecks => witness_recheck:measure(Qs)}.

stats([]) -> #{n => 0};
stats(L) -> S = lists:sort(L), #{n => length(L), mean => round1(lists:sum(L) / length(L)), median => round1(lists:nth((length(S) + 1) div 2, S)), max => round1(lists:last(S))}.

ratio(_, 0) -> null;
ratio(A, B) -> round(A / B * 1000) / 1000.

round1(X) -> round(X * 10) / 10.
num(N) when is_number(N) -> N;
num(_) -> 0.
