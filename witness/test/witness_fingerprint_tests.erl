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
