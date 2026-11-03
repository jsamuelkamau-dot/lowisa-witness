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

%% 27 Oct, 10-question benchmark: one-line calculations ("0.4 x 0.3 = 0.12") came back part way as "only the answer"
no_working_means_only_the_final_value_test() ->
    P = witness_mark:prompt(#{}),
    ?assertNotEqual(nomatch, binary:match(P, <<"ONLY the final\n  value">>)),
    ?assertNotEqual(nomatch, binary:match(P, <<"A line that shows its own calculation IS working">>)).

%% 27 Oct, emulator: a video of no paper was marked "to master" on every question; now nothing is marked
a_video_that_does_not_show_the_paper_is_not_marked_test() ->
    ?assertEqual({error, {unreadable, <<"A cartoon house; no paper.">>}},
                 witness_mark:parse(<<"{\"readable\":false,\"why\":\"A cartoon house; no paper.\"}">>)),
    ?assertMatch({ok, #{questions := [_]}}, witness_mark:parse(<<"{\"readable\":true,\"questions\":[{\"n\":1,\"result\":\"not_yet\"}]}">>)),
    ?assertNotEqual(nomatch, binary:match(witness_mark:prompt(#{}), <<"\"readable\":false">>)),
    ?assertNotEqual(nomatch, binary:match(witness_mark:prompt(#{}), <<"left\nempty IS readable">>)),
    ?assertNotEqual(nomatch, binary:match(witness_mark:prompt(#{kind => <<"practical">>}), <<"\"readable\":false">>)).

%% 28 Oct, the live demo run: three 2-mark questions came back out of 1 (the reply template said "out_of":1)
each_question_is_scored_out_of_its_own_worth_test() ->
    Sitting = #{questions => [#{n => 1, marks => 2}, #{n => 2, marks => 2}, #{n => 3, marks => 4}]},
    Qs = [#{n => 1, result => <<"right_answer_wrong_thinking">>, marks => 0, out_of => 1},
          #{n => 2, result => <<"mastered">>, marks => 1, out_of => 1},
          #{n => 3, result => <<"part_way">>, marks => 1, out_of => 2},
          #{n => 4, result => <<"not_yet">>, marks => 0, out_of => 3}],
    ?assertMatch([#{marks := 0, out_of := 2}, #{marks := 2, out_of := 2}, #{marks := 2, out_of := 4}, #{marks := 0, out_of := 3}],
                 witness_mark:fit(Qs, Sitting)),
    %% questions read off the paper (none given) keep the model's own scale
    ?assertEqual(Qs, witness_mark:fit(Qs, #{})),
    P = witness_mark:prompt(#{questions => [#{n => 1, text => <<"Simplify 16/64">>, marks => 2}]}),
    ?assertNotEqual(nomatch, binary:match(P, <<"out_of is what the question is worth">>)),
    ?assertEqual(nomatch, binary:match(P, <<"\"out_of\":1">>)).

%% 28 Oct audit: the plan's second reading when Spark is unsure was never built
an_unsure_question_is_read_twice_test() ->
    Sure = #{n => 1, result => <<"mastered">>, confidence => 0.95, steps => [a]},
    Unsure = #{n => 2, result => <<"mastered">>, confidence => 0.5, steps => [placed], diagnosis => <<>>},
    Agree = #{n => 3, result => <<"not_yet">>, confidence => 0.6, steps => [p3], diagnosis => <<"d">>},
    ?assertNot(witness_mark:unsure([Sure])),
    ?assert(witness_mark:unsure([Sure, Unsure])),
    Second = [Sure#{result => <<"not_yet">>, confidence => 0.9},                          %% a sure reading the second contradicts
              #{n => 2, result => <<"part_way">>, confidence => 0.8, steps => [unplaced], diagnosis => <<"Skipped a step.">>},
              #{n => 3, result => <<"not_yet">>, confidence => 0.85}],
    [A, B, C] = witness_mark:reconcile([Sure, Unsure, Agree], Second),
    %% 3 Nov (judges' panel): two readings must agree, sure or not; a contradicted sure reading is a split, never mastered
    ?assertMatch(#{result := <<"not_yet">>, confidence := 0.4, steps := [a], split := true}, A),
    %% split: never mastered, low confidence, the teacher decides, steps still placed on the page
    ?assertMatch(#{result := <<"part_way">>, confidence := 0.4, steps := [placed], read_twice := true}, B),
    ?assertNotEqual(nomatch, binary:match(maps:get(diagnosis, B), <<"Two readings of the work disagreed">>)),
    %% agreed: the surer confidence
    ?assertMatch(#{result := <<"not_yet">>, confidence := 0.85, steps := [p3], read_twice := true}, C).

%% 28 Oct audit: the plan's timeline listed going back to an earlier question; never built
going_back_to_an_earlier_question_is_kept_test() ->
    T = <<"{\"questions\":[{\"n\":1,\"result\":\"mastered\"}],\"pauses\":[],\"returns\":[{\"to_q\":1,\"from_q\":3,\"at_s\":63},"
          "{\"to_q\":3,\"from_q\":2,\"at_s\":70},{\"to_q\":\"one\",\"from_q\":2,\"at_s\":5}]}">>,
    %% only a real move backwards, with question numbers, is kept
    ?assertMatch({ok, #{returns := [#{to_q := 1, from_q := 3, at_s := 63}]}}, witness_mark:parse(T)),
    ?assertMatch({ok, #{returns := []}}, witness_mark:parse(<<"{\"questions\":[]}">>)),
    ?assertNotEqual(nomatch, binary:match(witness_mark:prompt(#{}), <<"List a return only when the student went back">>)).


%% 28 Oct re-audit, live: right one-word answers came back 1 of 2 on one reading and 2 of 2 on the other; every split ended
%% part way at 40%. A third reading decides: two of three agreeing stand, three different stay with the teacher.
a_split_is_decided_by_a_third_reading_test() ->
    One = #{n => 1, result => <<"part_way">>, confidence => 0.5, steps => [placed], diagnosis => <<"Not every mark was earned.">>},
    Two = #{n => 2, result => <<"mastered">>, confidence => 0.5, steps => [placed2], diagnosis => <<>>},
    First = [One, Two],
    Second = [#{n => 1, result => <<"mastered">>, confidence => 0.9, steps => [x], diagnosis => <<>>},
              #{n => 2, result => <<"not_yet">>, confidence => 0.8, steps => [y], diagnosis => <<"Flipped it.">>}],
    Rec = witness_mark:reconcile(First, Second),
    ?assert(witness_mark:split(Rec)),
    Third = [#{n => 1, result => <<"mastered">>, confidence => 0.95, steps => [z], diagnosis => <<>>},
             #{n => 2, result => <<"part_way">>, confidence => 0.7, steps => [w], diagnosis => <<"d">>}],
    [A, B] = witness_mark:decide(Rec, First, Second, Third),
    %% two agree: mastered at the surer confidence, the first reading's steps kept
    ?assertMatch(#{result := <<"mastered">>, confidence := 0.95, steps := [placed], read_thrice := true}, A),
    ?assertNot(maps:is_key(split, A)),
    %% three different: the teacher decides
    ?assertMatch(#{confidence := 0.4, read_thrice := true}, B),
    ?assertNotEqual(nomatch, binary:match(maps:get(diagnosis, B), <<"Three readings of the work disagreed">>)),
    %% no third reading (it failed): the split stays as two readings left it, without the internal flag
    [C, _] = witness_mark:decide(Rec, First, Second, []),
    ?assertMatch(#{confidence := 0.4}, C), ?assertNot(maps:is_key(split, C)),
    ?assertNot(witness_mark:split(witness_mark:decide(Rec, First, Second, Third))).

%% 3 Nov (judges' panel): with no unsure question a paper had one reading, so a letter read wrongly at 90% sure went into
%% "Accept all". A reading of the answers alone checks it: an answer read differently is no longer sure
a_sure_answer_read_differently_is_no_longer_sure_test() ->
    Qs = [#{n => 33, result => <<"mastered">>, confidence => 0.9, final_answer => <<"C">>},
          #{n => 34, result => <<"mastered">>, confidence => 0.95, final_answer => <<"D Cow peas circled">>},
          #{n => 35, result => <<"mastered">>, confidence => 0.95, final_answer => <<"It helps our clothes to be neat and beautiful">>},
          #{n => 36, result => <<"mastered">>, confidence => 0.95, final_answer => <<"4 x 400 metres">>},
          #{n => 37, result => <<"mastered">>, confidence => 0.95, final_answer => <<"Abu">>}],
    Text = <<"```json\n{\"questions\":[{\"n\":33,\"final_answer\":\"D\"},{\"n\":34,\"final_answer\":\"D\"},"
             "{\"n\":35,\"final_answer\":\"it helps clothes look neat\"},{\"n\":36,\"final_answer\":\"4x400 metres\"}]}\n```">>,
    [Q33, Q34, Q35, Q36, Q37] = witness_mark:checked(Qs, Text),
    %% C against D: unsure now, so the full second reading compares it
    ?assertMatch(#{confidence := 0.6, read_again_as := <<"D">>}, Q33),
    ?assert(witness_mark:unsure([Q33])),
    %% the same letter with its printed words; a long answer in words is left to the full reading; spacing set aside
    ?assertEqual(0.95, maps:get(confidence, Q34)),
    ?assertEqual(0.95, maps:get(confidence, Q35)),
    ?assertEqual(0.95, maps:get(confidence, Q36)),
    %% a question the check left out is not as sure as two readings make it: kept out of "Accept all"
    ?assert(maps:get(confidence, Q37) < 0.9),
    ?assertNot(witness_mark:unsure([Q37])),
    %% no check at all (it failed): nothing joins "Accept all"
    ?assert(lists:all(fun(Q) -> maps:get(confidence, Q) < 0.9 end, witness_mark:checked(Qs, error))),
    ?assert(lists:all(fun(Q) -> maps:get(confidence, Q) < 0.9 end, witness_mark:checked(Qs, <<"no json">>))),
    ?assert(witness_mark:same_answer(<<"(b) Airtight sack">>, <<"B">>)),
    ?assertNot(witness_mark:same_answer(<<"B">>, <<"D">>)),
    ?assertNot(witness_mark:same_answer(<<"iron">>, <<"vitamin D">>)),
    %% numbers must be the same numbers (judges' panel: "2.4" and "24" agreed once every non-letter was set aside)
    ?assert(witness_mark:same_answer(<<"4 x 400 metres">>, <<"4x400 metres">>)),
    ?assert(witness_mark:same_answer(<<"10:55 pm">>, <<"B - 10:55pm">>)),
    ?assertNot(witness_mark:same_answer(<<"2.4">>, <<"24">>)),
    ?assertNot(witness_mark:same_answer(<<"-5">>, <<"5">>)),
    ?assertNot(witness_mark:same_answer(<<"1/2">>, <<"12">>)),
    ?assertNot(witness_mark:same_answer(<<"150 rabbits">>, <<"1500 rabbits">>)),
    ?assert(witness_mark:same_answer(<<"150 rabbits">>, <<"150">>)),
    %% a sentence that starts with "a" is not option A
    ?assertNot(witness_mark:same_answer(<<"a dog">>, <<"a cat">>)),
    ?assert(witness_mark:same_answer(<<"a secondary colour">>, <<"secondary colour">>)),
    %% judges' panel, round 6: the same capital letter with different words after it, and a word inside another word
    ?assertNot(witness_mark:same_answer(<<"A dog">>, <<"A cat">>)),
    ?assert(witness_mark:same_answer(<<"D Cow peas circled">>, <<"D. Cow peas">>)),
    ?assertNot(witness_mark:same_answer(<<"red">>, <<"infrared">>)),
    ?assert(witness_mark:same_answer(<<"Bowling square">>, <<"bowling square">>)).
