-module(witness_examiner_tests).
-include_lib("eunit/include/eunit.hrl").

qs() ->
    [#{n => 1, result => <<"not_yet">>, confidence => 0.95, diagnosis => <<"Multiplied distance by time.">>,
       steps => [#{wrote => <<"120 x 1.5 = 180 km/h">>, crossed_out => false}]},
     #{n => 2, result => <<"right_answer_wrong_thinking">>, confidence => 0.9, diagnosis => <<"Added mass and acceleration.">>,
       steps => [#{wrote => <<"F = 2 + 2 = 4 N">>, crossed_out => false}]}].

prompt_names_the_students_own_steps_test() ->
    P = witness_examiner:prompt(#{level => <<"Grade 9">>}, qs()),
    ?assertNotEqual(nomatch, binary:match(P, <<"step 1: <<<120 x 1.5 = 180 km/h>>>">>)),
    ?assertNotEqual(nomatch, binary:match(P, <<"AT MOST TWO">>)),
    ?assertNotEqual(nomatch, binary:match(P, <<"never says it was wrong">>)),
    ?assertNotEqual(nomatch, binary:match(P, <<"95% sure">>)).

parse_keeps_two_and_numbers_them_test() ->
    T = <<"Here: {\"asks\":[{\"n\":1,\"step\":1,\"ask\":\"Why did you multiply?\"},{\"n\":2,\"ask\":\"Why add?\"},{\"n\":2,\"ask\":\"Third?\"},{\"n\":\"x\",\"ask\":\"bad\"}]}">>,
    {ok, [A, B]} = witness_examiner:parse(T),
    ?assertMatch(#{k := 1, n := 1, step := 1, ask := <<"Why did you multiply?">>}, A),
    ?assertMatch(#{k := 2, n := 2, step := 1}, B),
    ?assertEqual({error, no_asks}, witness_examiner:parse(<<"no json">>)).

judge_reads_the_verdict_test() ->
    ?assertEqual({ok, #{own_work => true, understood => false, why => <<"w">>}}, witness_examiner:judge(<<"{\"own_work\":true,\"understood\":false,\"why\":\"w\"}">>)),
    ?assertEqual({error, no_verdict}, witness_examiner:judge(<<"{}">>)),
    P = witness_examiner:judge_prompt(#{wrote => <<"F = 2 + 2">>, ask => <<"Why add?">>}, hd(tl(qs())), <<"Sasa naona, multiply">>),
    ?assertNotEqual(nomatch, binary:match(P, <<"THE STEP THEY WROTE: <<<F = 2 + 2>>>">>)).

draw_lines_are_checked_and_capped_test() ->
    {ok, #{lines := L, changed := 2}} = witness_draw:parse_lines(<<"{\"lines\":[\"3x - 5 = 10\",\"3x = 10 + 5\",\" \",\"3x = 15\",\"x = 5\",\"a\",\"b\",\"c\"],\"changed\":2}">>),
    ?assertEqual([<<"3x - 5 = 10">>, <<"3x = 10 + 5">>, <<"3x = 15">>, <<"x = 5">>, <<"a">>], L),
    ?assertMatch({ok, #{changed := 1}}, witness_draw:parse_lines(<<"{\"lines\":[\"x = 5\"],\"changed\":9}">>)),
    ?assertEqual({error, no_lines}, witness_draw:parse_lines(<<"{\"lines\":[]}">>)),
    P = witness_draw:picture_prompt([<<"3x = 15">>, <<"x = 5">>], 2),
    ?assertNotEqual(nomatch, binary:match(P, <<"\"x = 5\"">>)),
    ?assertEqual(nomatch, binary:match(P, <<"2. x = 5">>)),
    ?assertNotEqual(nomatch, binary:match(P, <<"The second line is the corrected step">>)),
    %% a question number in front of a line is not part of the working; a number that is the working stays
    {ok, #{lines := [<<"F = m x a">>, <<"F = 2 x 2 = 4 N">>]}} = witness_draw:parse_lines(<<"{\"lines\":[\"F = m x a\",\"2. F = 2 x 2 = 4 N\"],\"changed\":2}">>),
    {ok, #{lines := [<<"0.5 m">>]}} = witness_draw:parse_lines(<<"{\"lines\":[\"0.5 m\"]}">>).

transcribe_sends_a_request_and_an_audio_part_test() ->
    B = witness_meta:transcribe_body("BB", <<"RIFFwav">>),
    ?assertNotEqual(nomatch, binary:match(B, <<"name=\"request\"">>)),
    ?assertNotEqual(nomatch, binary:match(B, <<"\"audioEncoding\":\"WAV\"">>)),
    ?assertNotEqual(nomatch, binary:match(B, <<"name=\"audio\"; filename=\"answer.wav\"\r\nContent-Type: audio/wav\r\n\r\nRIFFwav">>)).
