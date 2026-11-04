-module(witness_reaudit_tests).
-include_lib("eunit/include/eunit.hrl").

%% 28 Oct re-audit: the class patterns, the badge recommendation and the exam read from the teacher's file.

items() ->
    [#{student => <<"Amara">>, n => 3, question => <<"Simplify 16/64">>, diagnosis => <<"Cancelled the 6s.">>, turned_around => true},
     #{student => <<"Ben">>, n => 3, question => <<"Simplify 16/64">>, diagnosis => <<"Struck out the matching digits.">>, turned_around => false},
     #{student => <<"Ben">>, n => 1, question => <<"3/4 ÷ 1/2"/utf8>>, diagnosis => <<"Flipped the first fraction.">>, turned_around => false}].

patterns_count_from_the_papers_not_the_model_test() ->
    T = <<"{\"patterns\":[{\"idea\":\"Flips the wrong fraction\",\"lines\":[3],\"reteach\":\"Keep, change, flip.\"},"
          "{\"idea\":\"Cancels digits\",\"lines\":[1,2,2,9],\"reteach\":\"Divide by a common factor.\"},{\"idea\":\"\",\"lines\":[1]},"
          "{\"idea\":\"Nothing\",\"lines\":[]}],\"tomorrow\":\"Start with 16/64.\",\"next_exam\":[{\"text\":\"Simplify 18/48\",\"marks\":2},{\"text\":\"\"}]}">>,
    {ok, #{patterns := [Big, Small], tomorrow := <<"Start with 16/64.">>, next_exam := [#{text := <<"Simplify 18/48">>, marks := 2}]}} =
        witness_patterns:parse(T, items()),
    %% a line out of range is dropped; the students and the turned-around count are read off the papers
    ?assertMatch(#{idea := <<"Cancels digits">>, students := [<<"Amara">>, <<"Ben">>], questions := [3], turned_around := 1}, Big),
    ?assertMatch(#{idea := <<"Flips the wrong fraction">>, students := [<<"Ben">>], questions := [1], turned_around := 0}, Small),
    ?assertEqual({error, no_patterns}, witness_patterns:parse(<<"no">>, items())),
    P = witness_patterns:prompt(#{title => <<"Fractions">>, level => <<"Year 7">>}, items()),
    ?assertEqual(P, unicode:characters_to_binary(P)),
    [?assertNotEqual(nomatch, binary:match(P, X)) || X <- [<<"1. Student 1, question 3 (Simplify 16/64; turned around since)">>, <<"3/4 ÷ 1/2"/utf8>>, <<"what to reteach tomorrow">>,
                                                    %% 30 Oct rehearsal: three different reasons for one answer came back as one group
                                                    <<"never by the answer">>]],
    ?assertEqual(nomatch, binary:match(P, <<"Amara">>)),          %% 31 Oct (privacy): no name reaches the model
    ?assertEqual({error, nothing_to_master}, witness_patterns:run(<<"k">>, #{}, [])).

recommendation_reads_every_piece_of_evidence_test() ->
    Q = #{n => 3, question => <<"Simplify 16/64">>, diagnosis => <<"Cancelled the 6s.">>, focus => <<"Common factors">>,
          mastery => #{status => <<"completed">>, asks => #{lo => true, paper => true, teacher => false},
                       activity => [#{title => <<"Fix the stock order">>, right => 5, asked => 6}],
                       explain => #{lo => #{text => <<"Divide by 16.">>, verdict => #{understood => true, why => <<"names the factor">>}}},
                       fresh => #{status => <<"marked">>, question => #{result => <<"mastered">>, marks => 2, out_of => 2}},
                       thread => [#{from => student, text => <<"?">>}, #{from => teacher, text => <<"!">>}]}},
    P = witness_recommend:prompt(Q),
    [?assertNotEqual(nomatch, binary:match(P, X)) || X <- [<<"Simplify 16/64">>, <<"Common factors">>, <<"Fix the stock order: 5 of 6 right first time">>,
                                                           <<"<<<Divide by 16.>>> (Lo judged it understood: names the factor)">>, <<"marked mastered, 2 of 2">>,
                                                           <<"EXPLAINED BACK TO THE TEACHER: not asked for">>, <<"QUESTIONS THE STUDENT ASKED: 1">>,
                                                           <<"A finished level alone is not proof">>]],
    ?assertEqual({ok, #{recommend => <<"not_yet">>, why => <<"w">>, missing => <<"m">>}},
                 witness_recommend:parse(<<"{\"recommend\":\"not_yet\",\"why\":\"w\",\"missing\":\"m\"}">>)),
    ?assertEqual({error, no_recommendation}, witness_recommend:parse(<<"{\"recommend\":\"maybe\"}">>)).

the_exam_is_read_as_the_teacher_wrote_it_test() ->
    T = <<"```json\n{\"title\":\"Algebra quiz\",\"level\":\"Year 8\",\"questions\":[{\"n\":1,\"text\":\"Expand 3(x + 4)\",\"marks\":2},"
          "{\"n\":\"two\",\"text\":\"x\"},{\"n\":2,\"text\":\"Solve 5x - 2 = 18\",\"marks\":0}],\"scheme\":\"Q1: 1 mark each term\"}\n```">>,
    ?assertEqual({ok, #{title => <<"Algebra quiz">>, level => <<"Year 8">>, scheme => <<"Q1: 1 mark each term">>,
                        questions => [#{n => 1, text => <<"Expand 3(x + 4)">>, marks => 2}, #{n => 2, text => <<"Solve 5x - 2 = 18">>, marks => 1}]}},
                 witness_read:parse(T)),
    ?assertEqual({error, unreadable}, witness_read:parse(<<"{\"readable\":false}">>)),
    ?assertEqual({error, unreadable}, witness_read:parse(<<"{\"questions\":[],\"scheme\":\"\"}">>)),
    ?assertNotEqual(nomatch, binary:match(witness_read:prompt(), <<"Never invent a question">>)).

%% 30 Oct rehearsal: the fingerprint's named idea rides on each line, so diagnoses that share words stay apart
patterns_line_carries_the_named_idea_test() ->
    P = witness_patterns:prompt(#{title => <<"Percentages">>}, [#{student => <<"Leo">>, n => 4, question => <<"Q">>, diagnosis => <<"D">>,
                                                                 idea => <<"kept the first base">>}]),
    ?assertNotEqual(nomatch, binary:match(P, <<"D [named idea: kept the first base]">>)).

%% 31 Oct rehearsal: a line read "Lo asks first" and the reteach said "Ask Lo first to explain how he got $100"
patterns_know_lo_is_the_tutor_test() ->
    P = witness_patterns:prompt(#{title => <<"Percentages">>}, [#{student => <<"Leo">>, n => 4, question => <<"Q">>,
                                                                 diagnosis => <<"Only the answer is on the page. Lo asks first.">>}]),
    ?assertNotEqual(nomatch, binary:match(P, <<"Lo is the app's tutor, never a student">>)),
    ?assertNotEqual(nomatch, binary:match(P, <<"never he or she">>)).

%% 4 Nov (security review): ffmpeg reads a signed link over https only and a file here as a file only, so an uploaded
%% playlist cannot point it at the metadata address or at a file on the machine
ffmpeg_reads_each_input_by_its_own_protocol_only_test() ->
    ?assertEqual(["-v", "error", "-protocol_whitelist", "https,tls,tcp,crypto", "-i", "https://bucket/clip.mp4", "out.jpg"],
                 witness_media:fenced(["-v", "error", "-i", "https://bucket/clip.mp4", "out.jpg"])),
    ?assertEqual(["-y", "-protocol_whitelist", "file,crypto", "-i", "/tmp/witness-1.m4a", "out.wav"],
                 witness_media:fenced(["-y", "-i", "/tmp/witness-1.m4a", "out.wav"])).
