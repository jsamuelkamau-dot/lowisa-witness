-module(witness_sam_tests).
-include_lib("eunit/include/eunit.hrl").

%% Two frames in SAM 3.1's own shape (masks shortened): digit 0 is seen in both, digit 1 appears in frame 22.
-define(TEXT, <<"<21f>0<|box;x1=69;y1=544;x2=83;y2=577;w=720;h=1600;c=0.71|><|mask;x=0;y=0;c=0.71;data=2,2,~abc|>\n"
                "<22f>0<|box;x1=70;y1=544;x2=84;y2=577;w=720;h=1600;c=0.72|><|mask;x=0;y=0;data=2,2,~abc|>,"
                "1<|box;x1=126;y1=540;x2=149;y2=575;w=720;h=1600;c=0.70|><|mask;x=0;y=0;data=2,2,~abc|>\n">>).

records_test() ->
    R = witness_sam:records(?TEXT),
    ?assertEqual(3, length(R)),
    [{21, 0, B} | _] = R,
    ?assertEqual(#{x1 => 69, y1 => 544, x2 => 83, y2 => 577, w => 720, h => 1600, c => 0.71}, B).

tracks_and_order_test() ->
    T = witness_sam:tracks(witness_sam:records(?TEXT)),
    ?assertMatch(#{0 := #{first := 21, last := 22, seen := 2}, 1 := #{first := 22, seen := 1}}, T),
    ?assertMatch([{21, 0, #{x1 := 69}}, {22, 1, #{x1 := 126}}], witness_sam:appeared(T)).

empty_answer_test() ->
    ?assertEqual([], witness_sam:records(<<>>)),
    ?assertEqual([], witness_sam:appeared(witness_sam:tracks([]))).

out_of_order_frames_keep_first_box_test() ->
    T = witness_sam:tracks([{9, 4, #{x1 => 9}}, {3, 4, #{x1 => 3}}]),
    ?assertMatch(#{4 := #{first := 3, last := 9, box := #{x1 := 3}}}, T).

unknown_fields_never_become_atoms_test() ->
    [{0, 3, B}] = witness_sam:records(<<"<0f>3<|box;x1=1;y1=2;x2=3;y2=4;w=9;h=9;zz_never_an_atom_7731=5|>">>),
    ?assertEqual(#{x1 => 1, y1 => 2, x2 => 3, y2 => 4, w => 9, h => 9}, B),
    ?assertError(badarg, binary_to_existing_atom(<<"zz_never_an_atom_7731">>)).
