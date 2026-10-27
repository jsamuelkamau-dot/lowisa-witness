-module(witness_mark_tests).
-include_lib("eunit/include/eunit.hrl").

%% Muse Spark's answer on the day-1 synthetic clip (27 Oct), as it came back.
-define(DAY1, <<"{\"questions\":[{\"q\":1,\"final_answer\":\"3/2\",\"steps\":[{\"t\":6,\"wrote\":\"1. 3/4 ÷ 1/2 = 3/8\",\"crossed_out\":true},"
                "{\"t\":13,\"wrote\":\"= 3/4 x 2/1 = 6/4 = 3/2\",\"crossed_out\":false}],\"result\":\"mastered\",\"diagnosis\":\"\","
                "\"moment_s\":9,\"confidence\":0.9},{\"q\":3,\"final_answer\":\"1/4\",\"steps\":[{\"t\":32,\"wrote\":\"3. 16/64\","
                "\"crossed_out\":false},{\"t\":37,\"wrote\":\"= 1/4\",\"crossed_out\":false}],\"result\":\"right_answer_wrong_thinking\","
                "\"diagnosis\":\"Cancelled the common digit 6 from numerator and denominator instead of dividing by a common factor.\","
                "\"moment_s\":35,\"confidence\":0.9}],\"pauses\":[{\"from_s\":25,\"to_s\":30}]}"/utf8>>).

parse_day1_test() ->
    {ok, #{questions := [Q1, Q3], pauses := [P]}} = witness_mark:parse(?DAY1),
    ?assertMatch(#{n := 1, result := <<"mastered">>, diagnosis := <<>>, moment_s := null, confidence := 0.9}, Q1),
    ?assertMatch([#{t := 6, crossed_out := true}, #{t := 13, crossed_out := false}], maps:get(steps, Q1)),
    ?assertMatch(#{n := 3, result := <<"right_answer_wrong_thinking">>, moment_s := 35, final_answer := <<"1/4">>}, Q3),
    ?assertNotEqual(nomatch, binary:match(maps:get(diagnosis, Q3), <<"digit 6">>)),
    ?assertEqual(#{from_s => 25, to_s => 30}, P),
    ?assertNot(witness_mark:needs_level(Q1)),
    ?assert(witness_mark:needs_level(Q3)).

fenced_and_unknown_result_test() ->
    T = <<"Here you go:\n```json\n{\"questions\":[{\"n\":2,\"result\":\"maybe\",\"confidence\":0.99}]}\n```">>,
    {ok, #{questions := [Q]}} = witness_mark:parse(T),
    %% an answer outside the four results is never trusted: not yet, and first in the teacher's queue
    ?assertMatch(#{n := 2, result := <<"not_yet">>, confidence := +0.0, steps := []}, Q),
    ?assert(witness_mark:needs_level(Q)),
    ?assertEqual({error, no_marking}, witness_mark:parse(<<"no json here">>)),
    ?assertEqual({error, no_marking}, witness_mark:parse(<<"{\"other\":1}">>)).

confidence_is_clamped_test() ->
    {ok, #{questions := [Q]}} = witness_mark:parse(<<"{\"questions\":[{\"n\":1,\"result\":\"part_way\",\"confidence\":7}]}">>),
    ?assertEqual(1.0, maps:get(confidence, Q)).

prompt_carries_scheme_and_questions_test() ->
    P = witness_mark:prompt(#{questions => [#{n => 1, text => <<"Simplify 16/64">>, marks => 2}],
                              scheme => <<"1 mark method, 1 mark answer">>, level => <<"Year 7">>}),
    [?assertNotEqual(nomatch, binary:match(P, S)) || S <- [<<"Simplify 16/64 (2 marks)">>, <<"1 mark method">>,
                                                           <<"Year 7">>, <<"right_answer_wrong_thinking">>, <<"THINKING">>]],
    ?assertNotEqual(nomatch, binary:match(witness_mark:prompt(#{}), <<"printed on the paper">>)).
