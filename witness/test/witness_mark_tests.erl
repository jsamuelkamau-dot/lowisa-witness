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

%% 27 Oct, live: a question with "÷" made the prompt invalid UTF-8 and every sitting of the exam failed to send.
prompt_is_utf8_in_any_script_test() ->
    Qs = [#{n => 1, text => <<"3/4 ÷ 1/2"/utf8>>, marks => 2}, #{n => 2, text => <<"Écris 2x = 8 · x ≥ 4"/utf8>>},
          #{n => 3, text => <<"हल करें: 16/64"/utf8>>}, #{n => 4, text => <<"Tafuta thamani ya x²"/utf8>>}],
    P = witness_mark:prompt(#{questions => Qs, scheme => <<"√ ½ ∑ — à la règle"/utf8>>}),
    ?assertEqual(P, unicode:characters_to_binary(P)),
    [?assertNotEqual(nomatch, binary:match(P, T)) || T <- [<<"3/4 ÷ 1/2"/utf8>>, <<"हल करें"/utf8>>, <<"x²"/utf8>>, <<"√ ½ ∑"/utf8>>]],
    ?assert(is_binary(iolist_to_binary(json:encode(#{input => P})))).

%% 27 Oct benchmark: answers written with no working came back "mastered" at 1 of 2 marks
mastered_with_a_missing_mark_is_not_mastered_test() ->
    {ok, #{questions := [A, B]}} = witness_mark:parse(<<"{\"questions\":[{\"n\":1,\"result\":\"mastered\",\"marks\":1,\"out_of\":2,\"confidence\":0.95},"
                                                         "{\"n\":2,\"result\":\"mastered\",\"marks\":2,\"out_of\":2,\"confidence\":0.95}]}">>),
    ?assertMatch(#{result := <<"part_way">>, confidence := 0.5, diagnosis := <<"Not every mark was earned", _/binary>>}, A),
    ?assertMatch(#{result := <<"mastered">>, confidence := 0.95, diagnosis := <<>>}, B),
    P = witness_mark:prompt(#{}),
    ?assertNotEqual(nomatch, binary:match(P, <<"an answer written with no working">>)),
    ?assertNotEqual(nomatch, binary:match(P, <<"\"mastered\" always has full marks">>)).
