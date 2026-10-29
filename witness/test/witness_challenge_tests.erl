-module(witness_challenge_tests).
-include_lib("eunit/include/eunit.hrl").

q() -> #{n => 3, result => <<"wrong">>, diagnosis => <<"Treated +50% then -50% as cancelling out.">>, question => <<"A product costs $100...">>}.

the_draft_is_read_only_when_it_is_whole_test() ->
    ?assertMatch({ok, #{q := <<"Water">>, options := [_, _, _], answer := 0, checks := <<"c">>}},
                 witness_challenge:parse_suggestion(<<"Here: {\"q\":\"Water\",\"options\":[\"910\",\"1000\",\"1090\"],\"answer\":0,\"checks\":\"c\"}">>)),
    ?assertEqual({error, no_suggestion}, witness_challenge:parse_suggestion(<<"{\"q\":\"W\",\"options\":[\"910\"],\"answer\":0}">>)),
    ?assertEqual({error, no_suggestion}, witness_challenge:parse_suggestion(<<"{\"q\":\"W\",\"options\":[\"a\",\"b\"],\"answer\":5}">>)),
    ?assertEqual({error, no_suggestion}, witness_challenge:parse_suggestion(<<"no json">>)).

the_draft_asks_for_the_same_idea_in_a_new_situation_test() ->
    P = witness_challenge:suggest_prompt(q(), <<"use water">>),
    [?assertNotEqual(nomatch, binary:match(P, W)) || W <- [<<"SAME principle in a DIFFERENT real-world situation">>, <<"cancelling out">>,
                                                          <<"use water">>, <<"old way of thinking">>]].

the_reason_is_judged_against_the_slip_test() ->
    Q = witness_challenge:set(q(), #{<<"q">> => <<"Water falls 30% then rises 30%">>, <<"options">> => [<<"910">>, <<"1000">>], <<"answer">> => 0}, 1),
    P = witness_challenge:judge_prompt(Q, {1, <<"they cancel">>}),
    [?assertNotEqual(nomatch, binary:match(P, W)) || W <- [<<"cancelling out">>, <<"THE RIGHT OPTION: 1">>, <<"THE STUDENT PICKED: 2">>, <<"they cancel">>]],
    ?assertEqual({ok, #{understood => false, why => <<"Still cancels.">>}}, witness_challenge:parse_verdict(<<"{\"understood\":false,\"why\":\"Still cancels.\"}">>)).

a_wrong_pick_is_kept_as_wrong_and_shown_with_the_right_one_test() ->
    Q = witness_challenge:set(q(), #{<<"q">> => <<"W">>, <<"options">> => [<<"910">>, <<"1000">>, <<"1090">>], <<"answer">> => 0}, 1),
    Q1 = witness_challenge:answer(Q, #{<<"pick">> => 1, <<"why">> => <<"They cancel.">>}, #{understood => false, why => <<"x">>}, 2),
    #{challenge := C} = maps:get(mastery, Q1),
    ?assertMatch(#{reply := #{pick := 1, right := false, verdict := #{understood := false}}}, C),
    ?assertEqual(#{challenge => #{q => <<"W">>, options => [<<"910">>, <<"1000">>, <<"1090">>], at => 1,
                                 reply => #{pick => 1, right => false, answer => 0}}}, witness_challenge:view(maps:get(mastery, Q1))),
    ?assertEqual(#{}, witness_challenge:view(#{})).
