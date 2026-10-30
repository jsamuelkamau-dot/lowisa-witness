#!/usr/bin/env escript
%% schema_check.escript <ebin dir>: each call the library makes with a strict json_schema, made once, live (31 Oct
%% 2026): whether the API took the schema (or the call fell back), and whether the reply parsed into the right shape.
%% MODEL_API_KEY is read, never printed.
main([Ebin]) ->
    true = code:add_patha(Ebin),
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Level = #{title => <<"Same-Sized Pieces First">>, lessons => [
        #{title => <<"Half a pizza and a third">>, beats => [<<"Your step: 1/2 + 1/3 = 2/5.">>, <<"Check: is 2/5 less than 1/2? Options: yes, no. Right: yes.">>]},
        #{title => <<"Make the pieces the same size">>, beats => [<<"1/2 + 1/3 = 3/6 + 2/6 = 5/6.">>, <<"Check: 1/4 + 1/2. Options: 2/6, 3/4. Right: 3/4.">>]},
        #{title => <<"Mix the paint order">>, beats => [<<"Task: 1/3 tin of white and 1/4 tin of blue: 7/12 of a tin.">>]}]},
    Q = #{diagnosis => <<"takes the second change of the original amount">>, question => <<"A product costs $100, up 50% then down 50%.">>,
          mastery => #{challenge => #{q => <<"1,000 L falls 30% then rises 30%.">>, options => [<<"910 L">>, <<"1,000 L">>], answer => 0, at => 0},
                       recheck => #{status => <<"open">>, q => <<"After a 20% rise a coat costs $60. Before?">>, answer => 50}}},
    Calls = [
        {self_check, fun() -> witness_check:run(Key, #{question => <<"Work out 1/2 + 1/3.">>, working => <<"1/2 + 1/3 = 2/5">>, diagnosis => <<"adds the tops and the bottoms">>, level => Level}) end},
        {fingerprint, fun() -> witness_fingerprint:run(Key, #{question => <<"$100 up 50% then down 50%">>, final_answer => <<"$100">>, steps => [#{wrote => <<"Half up, half down. Same price.">>}],
                                                              fingerprint => #{ask => <<"Write what you had after each step.">>, reasoning => <<"r">>}}, <<"Both halves are of 100. Half of 100 is 50.">>) end},
        {guard, fun() -> witness_guard:check(Key, <<"Great work. Now try 20% off $60.">>) end},
        {challenge_suggest, fun() -> witness_challenge:suggest(Key, Q, <<>>) end},
        {challenge_judge, fun() -> witness_challenge:judge(Key, Q, {0, <<"700 x 1.3 = 910">>}) end},
        {recheck_write, fun() -> witness_recheck:write(Key, Q) end},
        {recheck_judge, fun() -> witness_recheck:judge(Key, Q, {50, <<"60 / 1.2 = 50">>}) end},
        {recommend, fun() -> witness_recommend:run(Key, Q) end},
        {patterns, fun() -> witness_patterns:run(Key, #{title => <<"Percentages">>}, [#{student => <<"A">>, sitting => <<"s">>, n => 4, question => <<"q">>, diagnosis => <<"cancels">>, idea => <<"cancels">>, turned_around => false},
                                                                                    #{student => <<"B">>, sitting => <<"t">>, n => 4, question => <<"q">>, diagnosis => <<"fixed $50">>, idea => <<"fixed $50">>, turned_around => false}]) end}],
    [io:format("~p: ~ts~n", [N, case (try F() catch Cl:Er -> {Cl, Er} end) of
                                    {ok, _, C} -> io_lib:format("ok ($~.5f)", [float(C)]);
                                    {ok, C} when is_number(C) -> io_lib:format("ok ($~.5f)", [float(C)]);
                                    {unsafe, _, _} -> "unsafe";
                                    Other -> io_lib:format("~0p", [Other])
                                end]) || {N, F} <- Calls].
