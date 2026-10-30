-module(witness_check_tests).
-include_lib("eunit/include/eunit.hrl").

passes_only_when_both_students_come_out_right_test() ->
    ?assertMatch({ok, #{passes := true, problems := []}}, witness_check:parse(<<"{\"caught\":true,\"cleared\":true,\"on_idea\":true,\"work_task\":true,\"why\":\"ok\",\"problems\":[]}">>)),
    %% the misconception slips through: fails, with what to change
    {ok, V} = witness_check:parse(<<"```json\n{\"caught\":false,\"cleared\":true,\"problems\":[{\"lesson\":2,\"fix\":\"Add a fraction where cancelling digits fails.\"}]}\n```">>),
    ?assertMatch(#{passes := false, caught := false, problems := [#{lesson := 2}]}, V),
    %% failing with nothing named still gives the writer one thing to change
    ?assertMatch({ok, #{passes := false, problems := [#{lesson := null}]}}, witness_check:parse(<<"{\"caught\":true,\"cleared\":false}">>)),
    ?assertMatch({ok, #{passes := false}}, witness_check:parse(<<"{\"caught\":true,\"cleared\":true,\"on_idea\":false}">>)),
    ?assertEqual({error, no_verdict}, witness_check:parse(<<"no">>)).

prompt_names_both_students_and_is_utf8_test() ->
    P = witness_check:prompt(#{question => <<"Simplify 16/64 ÷ 1"/utf8>>, working => <<"16/64 = 1/4">>, diagnosis => <<"Cancelled the 6s.">>,
                               focus => <<"She loves football.">>,
                               level => #{title => <<"Common factors">>, lessons => [#{title => <<"At the stadium">>, beats => [<<"Your step: 16/64">>]}]}}),
    ?assertEqual(P, unicode:characters_to_binary(P)),
    [?assertNotEqual(nomatch, binary:match(P, T)) || T <- [<<"STILL HOLDS">>, <<"HAS THE IDEA RIGHT">>, <<"LESSON 1: At the stadium">>,
                                                           <<"- Your step: 16/64">>, <<"She loves football.">>, <<"÷"/utf8>>]].

%% 28 Oct audit: the fractions level passed with lesson 3 "Digit Cancel Counterexample", an exercise, not a work task
lesson_three_must_be_a_work_task_test() ->
    ?assertMatch({ok, #{passes := false, work_task := false}},
                 witness_check:parse(<<"{\"caught\":true,\"cleared\":true,\"on_idea\":true,\"work_task\":false,\"problems\":[{\"lesson\":3,\"fix\":\"Make it pricing a real order.\"}]}">>)),
    %% a verdict that does not answer it does not pass
    ?assertMatch({ok, #{passes := false}}, witness_check:parse(<<"{\"caught\":true,\"cleared\":true,\"on_idea\":true}">>)),
    P = witness_check:prompt(#{question => <<"Simplify 16/64">>, level => #{title => <<"L">>, lessons => []}}),
    ?assertNotEqual(nomatch, binary:match(P, <<"counterexample, a quiz or a review is not a work task">>)).


%% 30 Oct rehearsal: "the shop loses $25" by charging $100 for a $75 price passed the check; a false claim now stops it
a_false_claim_stops_the_level_test() ->
    ?assertMatch({ok, #{passes := false, true_claims := false}},
                 witness_check:parse(<<"{\"caught\":true,\"cleared\":true,\"on_idea\":true,\"work_task\":true,\"true_claims\":false,\"problems\":[{\"lesson\":3,\"fix\":\"Charging $100 for a $75 price gains the shop $25.\"}]}">>)),
    ?assertNotEqual(nomatch, binary:match(witness_check:prompt(#{}), <<"who gains, loses, pays or saves">>)).
