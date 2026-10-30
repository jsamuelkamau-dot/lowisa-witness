%%%-------------------------------------------------------------------
%%% witness_patterns — the class's patterns across one exam (hackathon, 2026-10-28).
%%%
%%% The submission: "the teacher gets a class report of the weakest topics and what to reteach tomorrow" (Muse Wonder
%%% over the whole class). The plan: "the teacher sees patterns ('14 students flip the divisor'), and the next exam can
%%% bring back the question types the class turned around." Muse Wonder reads every question still to master in the
%%% exam (who, which question, what went wrong, and whether it has been turned around since), groups the same
%%% misconception across students, and writes what to reteach tomorrow and questions for the next exam.
%%%
%%%   prompt(Exam, Items) -> binary
%%%       Exam = #{title, level}, Items = [#{student, n, question, result, diagnosis, turned_around}]
%%%   parse(ModelText, Items) -> {ok, Report} | {error, no_patterns}
%%%       Report = #{patterns => [#{idea, students, questions, turned_around, reteach}], tomorrow, next_exam => [#{text, marks}]}
%%%       (students and counts come from the items, never from the model's arithmetic)
%%%   run(Key, Exam, Items) -> {ok, Report, CostUsd} | {error, Why}
%%%-------------------------------------------------------------------
-module(witness_patterns).
-export([prompt/2, parse/2, run/3]).

-define(MODEL, <<"muse-wonder-1.0">>).

prompt(Exam, Items) ->
    %% 30 Oct rehearsal: the fingerprint's named idea goes on the line, so two diagnoses that share words but not the
    %% reasoning ("they cancel" and "kept the first base") are told apart
    %% 31 Oct (privacy): the model never needs a name to group reasoning, so each student is a number here; the names
    %% come back from the items (group/3), never from the model
    Who = maps:from_list(lists:zip(lists:usort([maps:get(student, It, <<>>) || It <- Items]), lists:seq(1, length(lists:usort([maps:get(student, It, <<>>) || It <- Items]))))),
    Lines = [io_lib:format("~b. Student ~b, question ~b (~ts~ts): ~ts~ts~n", [I, maps:get(maps:get(student, It, <<>>), Who), maps:get(n, It, 0), maps:get(question, It, <<>>),
                                                                       case maps:get(turned_around, It, false) of true -> "; turned around since"; false -> "" end,
                                                                       maps:get(diagnosis, It, <<>>),
                                                                       case maps:get(idea, It, <<>>) of <<>> -> ""; Idea -> [" [named idea: ", Idea, "]"] end])
             || {I, It} <- lists:zip(lists:seq(1, length(Items)), Items)],
    unicode:characters_to_binary([
        "You help a teacher after an exam. Below is every question a student did not master, one a line, numbered, with ",
        "what went wrong in their working.\n\nTHE EXAM: ", str(maps:get(title, Exam, <<>>)),
        case str(maps:get(level, Exam, <<>>)) of <<>> -> ""; L -> [" (", L, ")"] end, "\n\n", Lines, "\n",
        "1. Group the lines by the SAME misconception (the same wrong idea, even on different questions). Name each idea in ",
        "plain words a teacher would say to the class, most common first. A line belongs to one group. Group by the ",
        "reasoning each line names, never by the answer: lines with the same wrong answer but different reasoning are ",
        "different groups, because each needs a different repair. A line's [named idea], when it has one, is the idea it ",
        "was diagnosed with. Two named ideas worded differently are ONE group when they describe the same wrong step and ",
        "the same repair would fix both (in another topic, \"multiplies only the first term in the bracket\" and \"forgets ",
        "the second term when expanding\" are one idea); ideas that need different repairs are different groups. When unsure ",
        "whether one repair fixes both, keep them apart.\n",
        "2. For each group, one sentence on what to reteach tomorrow, with a concrete example to use in class.\n",
        %% 31 Oct, rehearsal: a line read "Lo asks first" and the reteach said "Ask Lo first to explain how he got $100"
        "Lo is the app's tutor, never a student: a line that says Lo asks first means that student has not yet said how ",
        "they got their answer. Write about students as \"the student\" or \"these students\", never he or she.\n",
        "3. In two or three sentences, the plan for tomorrow's lesson: what first, what to practise.\n",
        "4. Up to four questions for the next exam that bring back these ideas in a new form, with their marks.\n",
        "Return JSON only: {\"patterns\":[{\"idea\":\"...\",\"lines\":[1,3],\"reteach\":\"...\"}],\"tomorrow\":\"...\",",
        "\"next_exam\":[{\"text\":\"...\",\"marks\":2}]}"]).

parse(Text, Items) ->
    case decode(Text) of
        #{<<"patterns">> := Ps} = J when is_list(Ps) ->
            N = length(Items),
            Groups = [group(P, Items, N) || P <- Ps, is_map(P)],
            Next = [#{text => str(maps:get(<<"text">>, X, <<>>)), marks => marks(maps:get(<<"marks">>, X, 1))}
                    || X <- lists:sublist(list(maps:get(<<"next_exam">>, J, [])), 4), is_map(X), str(maps:get(<<"text">>, X, <<>>)) =/= <<>>],
            Kept = [G || G <- Groups, G =/= none],
            {ok, #{patterns => lists:sort(fun(A, B) -> length(maps:get(students, A)) >= length(maps:get(students, B)) end, Kept),
                   tomorrow => str(maps:get(<<"tomorrow">>, J, <<>>)), next_exam => Next}};
        _ -> {error, no_patterns}
    end.

%% a group's students, questions and turned-around count are read off the items its lines name
group(P, Items, N) ->
    Lines = lists:usort([L || L <- list(maps:get(<<"lines">>, P, [])), is_integer(L), L >= 1, L =< N]),
    case {str(maps:get(<<"idea">>, P, <<>>)), Lines} of
        {<<>>, _} -> none;
        {_, []} -> none;
        {Idea, _} ->
            Its = [lists:nth(L, Items) || L <- Lines],
            #{idea => Idea, reteach => str(maps:get(<<"reteach">>, P, <<>>)),
              students => lists:usort([maps:get(student, I, <<>>) || I <- Its]),
              %% 31 Oct (judges' panel): the papers and questions of the group, for one teacher action on all of them
              items => lists:usort([#{sitting => S, n => maps:get(n, I, 0)} || I <- Its, S <- [maps:get(sitting, I, none)], is_binary(S)]),
              questions => lists:usort([maps:get(n, I, 0) || I <- Its]),
              turned_around => length([I || I <- Its, maps:get(turned_around, I, false) =:= true])}
    end.

run(_Key, _Exam, []) -> {error, nothing_to_master};
run(Key, Exam, Items) ->
    %% at 4,000 tokens Wonder thought for all of them (27 Oct); medium effort with room to answer, as the self-check
    Req = #{model => ?MODEL, max_output_tokens => 16000, reasoning => #{effort => <<"medium">>},
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(Exam, Items)}]}]},
    O = fun witness_meta:object/1,
    Shape = O(#{patterns => #{type => array, items => O(#{idea => #{type => string}, lines => #{type => array, items => #{type => integer}}, reteach => #{type => string}})}, tomorrow => #{type => string}, next_exam => #{type => array, items => O(#{text => #{type => string}, marks => #{type => integer}})}}),
    case witness_meta:structured(Key, Req, <<"class_patterns">>, Shape) of
        {ok, #{<<"status">> := <<"incomplete">>}} -> {error, incomplete};
        {ok, R} ->
            Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
            case parse(witness_meta:text_of(R), Items) of {ok, Rep} -> {ok, Rep, Cost}; E -> E end;
        E -> E
    end.

marks(N) when is_integer(N), N > 0, N =< 100 -> N;
marks(_) -> 1.

decode(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

str(B) when is_binary(B) -> B;
str(L) when is_list(L) -> unicode:characters_to_binary(L);
str(_) -> <<>>.
list(L) when is_list(L) -> L;
list(_) -> [].
