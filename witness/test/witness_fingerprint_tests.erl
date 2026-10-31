-module(witness_fingerprint_tests).
-include_lib("eunit/include/eunit.hrl").

%% The owner's three learners (30 Oct), as the marking returns them.
marked(Steps, Fp) ->
    J = #{<<"questions">> => [#{<<"n">> => 4, <<"final_answer">> => <<"$100">>, <<"result">> => <<"not_yet">>, <<"marks">> => 0, <<"out_of">> => 3,
                                <<"steps">> => [#{<<"wrote">> => S} || S <- Steps], <<"diagnosis">> => <<"d">>, <<"confidence">> => 0.9,
                                <<"fingerprint">> => Fp}]},
    {ok, #{questions := [Q]}} = witness_mark:parse(iolist_to_binary(json:encode(J))),
    Q.

learner_a_is_named_from_the_ink_test() ->
    Q = marked([<<"+50% - 50% = 0%">>], #{<<"reasoning">> => <<"Adds the two percentages as if they were fixed amounts.">>,
        <<"evidence">> => [<<"+50% - 50% = 0%">>], <<"misconception">> => <<"treats +50% and -50% as cancelling">>,
        <<"intervention">> => <<"Two percentage changes on different starting amounts; predict what happens when the order changes.">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<"treats +50% and -50% as cancelling">>, ask := <<>>, evidence := [<<"+50% - 50% = 0%">>]}}, Q),
    ?assertNot(witness_fingerprint:pending(Q)).

learner_b_is_named_from_the_ink_test() ->
    Q = marked([<<"100 + 50 = 150">>, <<"150 - 50 = 100">>], #{<<"reasoning">> => <<"Takes the second 50% of the original $100.">>,
        <<"evidence">> => [<<"150 - 50 = 100">>], <<"misconception">> => <<"takes the second percentage of the original amount">>,
        <<"intervention">> => <<"Only: which amount is the second 50% of?">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<"takes the second percentage of the original amount">>}}, Q).

learner_c_is_asked_not_labelled_test() ->
    Q = marked([<<"Half up, half down. Same price.">>], #{<<"reasoning">> => <<"An intuition with no numbers.">>,
        <<"evidence">> => [<<"Half up, half down. Same price.">>], <<"misconception">> => <<>>, <<"intervention">> => <<>>,
        <<"ask">> => <<"You wrote half up, half down. Half of what, each time?">>}),
    ?assertMatch(#{fingerprint := #{misconception := <<>>, ask := <<"You wrote half up, half down. Half of what, each time?">>}}, Q),
    ?assert(witness_fingerprint:pending(Q)).

a_label_without_evidence_becomes_a_question_test() ->
    Q = marked([<<"$100">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [], <<"misconception">> => <<"cancelling">>,
                               <<"intervention">> => <<"i">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<>>, ask := <<"Talk me through", _/binary>>}}, Q).

a_mastered_question_has_no_fingerprint_test() ->
    J = #{<<"questions">> => [#{<<"n">> => 1, <<"result">> => <<"mastered">>, <<"marks">> => 1, <<"out_of">> => 1,
                                <<"fingerprint">> => #{<<"misconception">> => <<"x">>, <<"evidence">> => [<<"y">>]}}]},
    {ok, #{questions := [Q]}} = witness_mark:parse(iolist_to_binary(json:encode(J))),
    ?assertEqual(null, maps:get(fingerprint, Q)).

the_answer_completes_the_fingerprint_then_lo_stops_asking_test() ->
    Q = marked([<<"Half up, half down. Same price.">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [<<"Half up, half down.">>],
        <<"misconception">> => <<>>, <<"intervention">> => <<>>, <<"ask">> => <<"Half of what, each time?">>}),
    ?assertEqual({error, empty}, witness_fingerprint:answer(Q, <<"  ">>, undefined, 1)),
    {ok, Read} = witness_fingerprint:parse(<<"{\"reasoning\":\"Halves $100 both times.\",\"evidence\":[\"said: half of 100 both times\"],",
        "\"misconception\":\"takes the second percentage of the original amount\",\"intervention\":\"Find the base.\",\"ask\":\"\"}">>),
    Q1 = witness_fingerprint:answer(Q, <<"Half of 100 both times.">>, Read, 2),
    ?assertMatch(#{fingerprint := #{misconception := <<"takes the second percentage of the original amount">>, ask := <<>>,
                                   said := [#{ask := <<"Half of what, each time?">>, text := <<"Half of 100 both times.">>}]}}, Q1),
    ?assertEqual({error, not_asked}, witness_fingerprint:answer(Q1, <<"more">>, undefined, 3)),
    %% still unclear twice: Lo asks no more and the level is built from what is known
    Q2 = witness_fingerprint:answer(Q, <<"Not sure.">>, #{ask => <<"And the second half?">>, misconception => <<>>}, 2),
    ?assert(witness_fingerprint:pending(Q2)),
    Q3 = witness_fingerprint:answer(Q2, <<"Still not sure.">>, #{ask => <<"Again?">>, misconception => <<>>}, 3),
    ?assertNot(witness_fingerprint:pending(Q3)),
    ?assertMatch(#{fingerprint := #{ask := <<>>, said := [_, _]}}, Q3).

the_prompt_has_the_ink_the_question_and_the_answer_test() ->
    Q = (marked([<<"Half up, half down.">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [<<"Half up, half down.">>],
        <<"ask">> => <<"Half of what?">>}))#{question => <<"A product costs $100...">>},
    P = witness_fingerprint:prompt(Q, <<"Of 100.">>),
    [?assertNotEqual(nomatch, binary:match(P, W)) || W <- [<<"A product costs $100">>, <<"Half up, half down.">>, <<"Half of what?">>, <<"Of 100.">>]].

%% 30 Oct (judges' panel): the rule is the code's. Muse Spark's own output for Learner C, as recorded live
%% (evidence/misconceptions/learner-c-mental-model.json): it named an idea AND asked. While Lo asks, nothing is named;
%% the guess waits as `possible` for the teacher, and the student is shown the page's reasoning, not the label.
the_recorded_learner_c_reply_names_nothing_while_lo_asks_test() ->
    J = #{<<"questions">> => [#{<<"n">> => 4, <<"final_answer">> => <<"A $100">>, <<"result">> => <<"not_yet">>, <<"marks">> => 0, <<"out_of">> => 3,
            <<"steps">> => [#{<<"wrote">> => <<"A $100">>}, #{<<"wrote">> => <<"Half up, half down. Same price.">>}],
            <<"diagnosis">> => <<"Thought a 50% increase and a 50% decrease cancel to return to the original price.">>, <<"confidence">> => 0.9,
            <<"fingerprint">> => #{<<"ask">> => <<"You wrote 'Half up, half down' – half of what amount each time?"/utf8>>,
                                   <<"evidence">> => [<<"A $100">>, <<"Half up, half down. Same price.">>],
                                   <<"intervention">> => <<"Have the student work each step in dollars.">>,
                                   <<"misconception">> => <<"percentage changes cancel">>,
                                   <<"reasoning">> => <<"Reasoned that half up then half down must return to the same price without calculating each change.">>}}]},
    {ok, #{questions := [Q]}} = witness_mark:parse(iolist_to_binary(json:encode(J))),
    #{fingerprint := F} = Q,
    ?assertEqual(<<>>, maps:get(misconception, F)),
    ?assertEqual(<<"percentage changes cancel">>, maps:get(possible, F)),
    ?assert(witness_fingerprint:pending(Q)),
    %% the final answer alone is no evidence; the intuition is the student's own line
    ?assertEqual([<<"Half up, half down. Same price.">>], maps:get(evidence, F)),
    %% the diagnosis says only what the page shows (the reasoning itself can name the guess); the one-idea reading waits
    ?assertEqual(<<"The page shows the answer A $100 but not which calculation led to it. Lo asks first.">>, maps:get(diagnosis, Q)),
    ?assertEqual(<<"Thought a 50% increase and a 50% decrease cancel to return to the original price.">>, maps:get(diagnosis_draft, Q)).

%% evidence the model wrote itself is not the student's ink: the label goes, Lo asks
evidence_not_on_the_page_is_dropped_test() ->
    Q = marked([<<"$100">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [<<"they think percentages cancel">>],
                               <<"misconception">> => <<"cancelling">>, <<"intervention">> => <<"i">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<>>, evidence := [], possible := <<"cancelling">>, ask := <<"Talk me through", _/binary>>}}, Q).

%% the reading may use another dash, quote or spacing than the quote: it is still the same line of ink
the_same_line_with_another_minus_sign_is_still_the_ink_test() ->
    Q = marked([<<"150 ", 16#2212/utf8, " 50 = 100">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [<<"150-50=100">>],
        <<"misconception">> => <<"takes the second change of the original">>, <<"intervention">> => <<"i">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<"takes the second change of the original">>, evidence := [<<"150-50=100">>]}}, Q).

%% when Lo's answer settles it, the question's diagnosis is what was found, so the level, the self-check, the class
%% patterns and the challenge all read it; the marking's first reading is kept
the_settled_fingerprint_becomes_the_diagnosis_test() ->
    Q = marked([<<"Half up, half down. Same price.">>], #{<<"reasoning">> => <<"Could be cancelling, or both halves of $100.">>,
        <<"evidence">> => [<<"Half up, half down.">>], <<"misconception">> => <<"cancel">>, <<"intervention">> => <<>>, <<"ask">> => <<"Half of what, each time?">>}),
    {ok, Read} = witness_fingerprint:parse(<<"{\"reasoning\":\"Takes both halves of the original $100.\",\"evidence\":[\"said: both halves of 100\"],"
        "\"misconception\":\"second change taken of the original amount\",\"intervention\":\"Find the base.\",\"ask\":\"\"}">>),
    Q1 = witness_fingerprint:answer(Q, <<"Both halves of 100.">>, Read, 2),
    ?assertEqual(<<"second change taken of the original amount">>, maps:get(diagnosis, Q1)),
    ?assertEqual(<<"The page shows the answer $100 but not which calculation led to it. Lo asks first.">>, maps:get(diagnosis_first, Q1)),
    ?assertNot(maps:is_key(possible, maps:get(fingerprint, Q1))),
    %% a reply that names an idea and still asks names nothing yet
    {ok, Unsure} = witness_fingerprint:parse(<<"{\"reasoning\":\"r\",\"evidence\":[\"said: x\"],\"misconception\":\"m\",\"intervention\":\"\",\"ask\":\"And then?\"}">>),
    ?assertMatch(#{misconception := <<>>, possible := <<"m">>, ask := <<"And then?">>}, Unsure).

%% the marking prompt holds no answer it is tested on (judges' panel: the three learners were quoted in it)
the_rule_quotes_none_of_the_three_learners_test() ->
    R = string:lowercase(iolist_to_binary(witness_mark:fingerprint_rule())),
    [?assertEqual(nomatch, binary:match(R, W)) || W <- [<<"50%">>, <<"150">>, <<"half up">>, <<"same price">>]].

%% a differential diagnosis: when the model says another wrong idea would write the same ink, nothing is named and Lo
%% asks, whatever name it offered
a_rival_idea_holds_the_name_and_lo_asks_test() ->
    Q = marked([<<"40 - 10 = 30">>, <<"30 + 10 = 40">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [<<"30 + 10 = 40">>],
        <<"rivals">> => [<<"25% is always $10">>], <<"misconception">> => <<"second change of the original">>, <<"intervention">> => <<"i">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<>>, possible := <<"second change of the original">>, rivals := [<<"25% is always $10">>],
                                   ask := <<"Write or say what you had after each step", _/binary>>}}, Q),
    ?assert(witness_fingerprint:pending(Q)).

%% an answer that is a number, with no quoted line that shows a calculation: the working is not on the page, so Lo asks,
%% whatever the model named (30 Oct, held-out check: Spark named the intuition as cancelling every time)
a_numeric_answer_with_no_calculation_on_the_page_is_asked_test() ->
    Q = marked([<<"Half up, half down. Same price.">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [<<"Half up, half down. Same price.">>],
        <<"rivals">> => [], <<"misconception">> => <<"opposite percentage changes cancel">>, <<"intervention">> => <<"i">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<>>, possible := <<"opposite percentage changes cancel">>}}, Q),
    ?assert(witness_fingerprint:pending(Q)),
    %% one number is not a calculation; two are
    ?assertEqual(1, witness_mark:numbers(<<"Tails is due after 5 heads">>)),
    ?assertEqual(3, witness_mark:numbers(<<"+50% - 50% = 0%">>)),
    ?assertEqual(2, witness_mark:numbers(<<"0.25 is bigger than 0.3">>)).

%% 31 Oct (judges' panel, an offline probe): a quote that a read line is only PART of kept the model's invented ending
%% as "their own writing"; now a quote must be in a line read from the page, give or take a reading's small slips
an_invented_ending_on_a_real_line_is_not_evidence_test() ->
    Q = marked([<<"Half up, half down. Same price.">>], #{<<"reasoning">> => <<"r">>,
        <<"evidence">> => [<<"Half up, half down. Same price. So +50% - 50% = 0%, they cancel">>],
        <<"rivals">> => [], <<"misconception">> => <<"percentages cancel">>, <<"intervention">> => <<"i">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<>>, evidence := []}}, Q),
    ?assert(witness_fingerprint:pending(Q)).

a_reading_slip_or_two_joined_lines_still_count_test() ->
    Lines = [witness_mark:norm(L) || L <- [<<"100 + 50 = 150">>, <<"150 - 50 = 100">>]],
    ?assert(witness_mark:quote_in_ink(<<"100 + 50 = 150; 150 - 50 = 100">>, Lines, <<"$100">>)),
    ?assert(witness_mark:quote_in_ink(<<"150 - 5O = 100">>, Lines, <<"$100">>)),
    ?assertNot(witness_mark:quote_in_ink(<<"150 - 50 = 100, so they cancel out">>, Lines, <<"$100">>)),
    ?assertNot(witness_mark:quote_in_ink(<<"$100">>, [witness_mark:norm(<<"$100">>)], <<"$100">>)).

%% 31 Oct (physics test, an exam it had never seen): an answer that IS the working, a written explanation or a
%% calculation, is the student's own reasoning; a bare result stays no evidence
an_explanation_in_words_is_its_own_working_test() ->
    Ship = <<"The ship floats because it is very light and the nail sinks because it is heavier. Heavy objects sink and light objects float.">>,
    Calc = <<"P = 100 x 0.5 = 50 Pa">>,
    ?assert(witness_mark:quote_in_ink(Ship, [witness_mark:norm(Ship)], Ship)),
    ?assert(witness_mark:quote_in_ink(<<"Heavy objects sink and light objects float.">>, [witness_mark:norm(Ship)], Ship)),
    ?assert(witness_mark:quote_in_ink(Calc, [witness_mark:norm(Calc)], Calc)),
    ?assertNot(witness_mark:quote_in_ink(<<"Joules">>, [witness_mark:norm(<<"Joules">>)], <<"Joules">>)),
    ?assertNot(witness_mark:quote_in_ink(<<"It attracts all metals.">>, [witness_mark:norm(<<"It attracts all metals.">>)], <<"It attracts all metals.">>)),
    J = #{<<"questions">> => [#{<<"n">> => 24, <<"final_answer">> => Ship, <<"result">> => <<"not_yet">>, <<"marks">> => 0, <<"out_of">> => 2,
                                <<"steps">> => [#{<<"wrote">> => Ship}], <<"diagnosis">> => <<"Thought floating depends on weight alone.">>, <<"confidence">> => 0.9,
                                <<"fingerprint">> => #{<<"reasoning">> => <<"r">>, <<"evidence">> => [Ship], <<"rivals">> => [],
                                                       <<"misconception">> => <<"heavy things sink, light things float">>, <<"intervention">> => <<"i">>, <<"ask">> => <<>>}},
                              #{<<"n">> => 23, <<"final_answer">> => <<"There is less oxygen higher up.">>, <<"result">> => <<"not_yet">>, <<"marks">> => 0, <<"out_of">> => 1,
                                <<"steps">> => [#{<<"wrote">> => <<"There is less oxygen higher up.">>}], <<"diagnosis">> => <<"d">>, <<"confidence">> => 0.9,
                                <<"fingerprint">> => #{<<"reasoning">> => <<"r">>, <<"evidence">> => [], <<"rivals">> => [<<"a">>],
                                                       <<"misconception">> => <<>>, <<"intervention">> => <<"i">>, <<"ask">> => <<"What presses down?">>}}]},
    {ok, #{questions := [Q24, Q23]}} = witness_mark:parse(iolist_to_binary(json:encode(J))),
    ?assertMatch(#{fingerprint := #{misconception := <<"heavy things sink, light things float">>, ask := <<>>}}, Q24),
    ?assertEqual(<<"Thought floating depends on weight alone.">>, maps:get(diagnosis, Q24)),
    %% while Lo asks about an answer in words, the page is not said to hold "only the answer"
    ?assertEqual(<<"The page shows the answer in the student's own words, but not yet which idea is behind it. Lo asks first.">>, maps:get(diagnosis, Q23)).

%% a calculation is an operation, an "=" or a comparison between numbers, never how many numerals a line holds
a_calculation_is_an_operation_not_a_count_of_numbers_test() ->
    [?assert(witness_mark:calculation(L)) || L <- [<<"+50% - 50% = 0%">>, <<"100 + 50 = 150">>, <<"16/64">>, <<"2.5 x 10 = 25">>,
                                                    <<"25% of 40 = 10">>, <<"25 is bigger than 3">>, <<"0.30 > 0.25">>, <<"150 − 50 = 100"/utf8>>]],
    [?assertNot(witness_mark:calculation(L)) || L <- [<<"50 up, 50 down">>, <<"Tails is due after 5 heads and 5 tails">>,
                                                       <<"Half up, half down. Same price.">>, <<"$100">>, <<"Off then on, same amount. $40.">>]],
    Q = marked([<<"50 up, 50 down">>], #{<<"reasoning">> => <<"r">>, <<"evidence">> => [<<"50 up, 50 down">>],
        <<"rivals">> => [], <<"misconception">> => <<"percentages cancel">>, <<"intervention">> => <<"i">>, <<"ask">> => <<>>}),
    ?assertMatch(#{fingerprint := #{misconception := <<>>, possible := <<"percentages cancel">>}}, Q).

%% the examiner asks about what was not mastered when there is any (30 Oct, rehearsal: it asked about mastered 1 and 2)
the_examiner_asks_about_what_was_not_mastered_test() ->
    Qs = [#{n => 1, result => <<"mastered">>}, #{n => 4, result => <<"not_yet">>}, #{n => 5, result => <<"mastered">>}],
    ?assertEqual([4], [N || #{n := N} <- witness_examiner:focus(Qs)]),
    ?assertEqual(2, length(witness_examiner:focus([#{n => 1, result => <<"mastered">>}, #{n => 2, result => <<"mastered">>}]))).

%% 31 Oct (physics test, no scheme): "part way" at 1 of 1 said two things at once; part of the idea never holds every
%% mark, while a right answer by wrong thinking keeps its mark
part_way_never_holds_every_mark_test() ->
    Q = fun(R, M, Of) -> #{<<"n">> => 5, <<"final_answer">> => <<"x">>, <<"result">> => R, <<"marks">> => M, <<"out_of">> => Of,
                           <<"steps">> => [], <<"diagnosis">> => <<"d">>, <<"confidence">> => 0.9, <<"fingerprint">> => null} end,
    {ok, #{questions := [A, B, C, D]}} = witness_mark:parse(iolist_to_binary(json:encode(#{<<"questions">> =>
        [Q(<<"part_way">>, 1, 1), Q(<<"part_way">>, 3, 3), Q(<<"right_answer_wrong_thinking">>, 1, 1), Q(<<"part_way">>, 1, 2)]}))),
    ?assertMatch(#{marks := 0, out_of := 1}, A),
    ?assertMatch(#{marks := 2, out_of := 3}, B),
    ?assertMatch(#{marks := 1, out_of := 1}, C),
    ?assertMatch(#{marks := 1, out_of := 2}, D).
