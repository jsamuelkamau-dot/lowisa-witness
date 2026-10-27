%%%-------------------------------------------------------------------
%%% witness_timeline — the order a paper was written in (hackathon, 2026-10-27).
%%%
%%% Two Meta readings of the same clip meet here:
%%%   - SAM 3.1 "word" tracked FORWARD gives each written line as one object: where it is, the first frame it
%%%     can be seen and the frame it stopped growing (on the test clip all 6 lines came back, in writing
%%%     order; tracked both ways the first sightings were pulled earlier than the ink).
%%%   - Muse Spark gives what each step says, when, and whether it was crossed out.
%%% Each Spark step is placed on a SAM line, in page order and closest in time, so every step carries the
%%% place on the page the teacher's replay jumps to.
%%%
%%%   lines(Records, Times) -> [Line]         Line = #{id, start_s, end_s, box}  (box = the line when finished)
%%%   merge(Steps, Lines) -> [Step]           Step from Spark #{t, wrote, crossed_out}, gains line and box
%%%   merge_all([Steps], Lines) -> [[Step]]   every question's steps at once, so the page is read in one order
%%%-------------------------------------------------------------------
-module(witness_timeline).
-export([lines/2, merge/2, merge_all/2, align/2]).

%% A line has stopped growing once its box area no longer rises by more than this share.
-define(GROWTH, 0.02).
%% What leaving one of SAM's lines without any step costs, in seconds of time distance.
-define(SKIP, 3.0).

lines(Records, Times) ->
    ById = lists:foldl(fun({F, Id, B}, Acc) -> maps:update_with(Id, fun(L) -> [{F, B} | L] end, [{F, B}], Acc) end,
                       #{}, Records),
    Ls = [line(Id, lists:keysort(1, Seen), Times) || {Id, Seen} <- maps:to_list(ById)],
    lists:sort(fun(A, B) -> maps:get(start_s, A) =< maps:get(start_s, B) end, Ls).

line(Id, [{F0, B0} | _] = Seen, Times) ->
    {EndF, _} = lists:foldl(fun({F, B}, {LastGrow, Area}) ->
        A = area(B),
        case A > Area * (1 + ?GROWTH) of true -> {F, A}; false -> {LastGrow, max(A, Area)} end
    end, {F0, area(B0)}, Seen),
    {_, Final} = lists:last(Seen),
    #{id => Id, start_s => witness_mp4:at(Times, F0), end_s => witness_mp4:at(Times, EndF), box => Final}.

area(#{x1 := X1, y1 := Y1, x2 := X2, y2 := Y2}) -> max(0, X2 - X1) * max(0, Y2 - Y1).

merge(Steps, []) -> Steps;
merge(Steps, Lines0) ->
    %% Steps come in writing order and a page is written top to bottom, so steps are laid on the lines in page
    %% order (never back up the page) and time chooses among the lines in reach (27 Oct, live: SAM sees a line
    %% once it reads as a word, seconds after the ink, so placing by time alone put 6 steps on one line).
    Lines = list_to_tuple(lists:sort(fun(A, B) -> y(A) =< y(B) end, Lines0)),
    Timed = list_to_tuple([S || S = #{t := T} <- Steps, is_number(T)]),
    place(Steps, align(Timed, Lines), Lines).

%% The whole page in one pass: question 2's first line comes after question 1's last.
merge_all(PerQuestion, Lines) ->
    split(merge(lists:append(PerQuestion), Lines), [length(S) || S <- PerQuestion]).

split(_, []) -> [];
split(All, [N | Ns]) -> {A, B} = lists:split(N, All), [A | split(B, Ns)].

place([], _, _) -> [];
place([S = #{t := T} | Rest], [J | Plan], Lines) when is_number(T) ->
    L = element(J, Lines),
    [S#{line => maps:get(id, L), box => maps:get(box, L)} | place(Rest, Plan, Lines)];
place([S | Rest], Plan, Lines) -> [S | place(Rest, Plan, Lines)].

%% align(Steps, Lines) -> [line index per step], never decreasing, least total cost (dynamic programming).
%% Every line SAM found holds ink some step wrote, so a line left without a step costs ?SKIP seconds' worth.
%% Rows hold, for each line J, {least cost of the steps so far with this step on J, line of the step before}.
align(Steps, Lines) when tuple_size(Steps) =:= 0; tuple_size(Lines) =:= 0 -> [];
align(Steps, Lines) ->
    NL = tuple_size(Lines), Js = lists:seq(1, NL),
    Cost = fun(I, J) -> cost(maps:get(t, element(I, Steps)), element(J, Lines)) end,
    First = [{Cost(1, J) + ?SKIP * (J - 1), 0} || J <- Js],
    Rows = lists:foldl(fun(I, [Prev | _] = Acc) ->
        P = list_to_tuple(Prev),
        Row = [begin
                   {C, Bj} = lists:min([{element(1, element(K, P)) + ?SKIP * max(0, J - K - 1), K} || K <- lists:seq(1, J)]),
                   {C + Cost(I, J), Bj}
               end || J <- Js],
        [Row | Acc]
    end, [First], lists:seq(2, tuple_size(Steps))),
    {_, End} = lists:min([{C + ?SKIP * (NL - J), J} || {J, {C, _}} <- lists:zip(Js, hd(Rows))]),
    back(Rows, End, []).

back([_], J, Acc) -> [J | Acc];
back([Row | Rest], J, Acc) -> {_, Prev} = lists:nth(J, Row), back(Rest, Prev, [J | Acc]).

y(#{box := #{y1 := Y}}) -> Y.

%% How far a step's time is from a line's writing window. SAM's first sighting lags the ink, so the window
%% reaches back a few seconds; a hundredth of the distance to the window's middle breaks ties.
cost(T, #{start_s := A, end_s := B}) ->
    Lo = A - 6.0, Hi = B + 1.0,
    Out = case T >= Lo andalso T =< Hi of true -> 0.0; false -> min(abs(T - Lo), abs(T - Hi)) end,
    Out + 0.01 * abs(T - (Lo + Hi) / 2).
