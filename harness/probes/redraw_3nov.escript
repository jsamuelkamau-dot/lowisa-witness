#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% redraw_3nov.escript <out_dir>
%%
%% The three corrected steps from panel31_probe.escript (step 4) drawn again by Muse Image on 3 Nov 2026, with the same
%% learners, the same question and the same witness_draw:run/3. The 31 Oct files were damaged when they were committed
%% (git stripped the CR from every CR LF byte pair; see results-31oct/NOTE.md), so these replace them. Results go to
%% <out_dir>/redraw-03nov.json beside the images; the key comes from MODEL_API_KEY and is never printed.
main([Dir]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    Sitting = #{level => <<"Year 9">>, questions => [#{n => 4, text => <<"A product costs $100. Its price increases by 50%, then decreases by 50%. What is its final price? A $100 B $75 C $50 D $150">>, marks => 3}]},
    Learners = [{<<"a">>, [<<"+50% - 50% = 0%">>, <<"so it stays at $100.">>], <<"percentage changes cancel">>},
                {<<"b">>, [<<"100 + 50 = 150">>, <<"150 - 50 = 100">>], <<"50% taken as a fixed $50">>},
                {<<"c">>, [<<"Half up, half down. Same price.">>], <<"takes the second change of the original amount">>}],
    R = [begin
             Q = #{n => 4, final_answer => <<"A $100">>, result => <<"not_yet">>, diagnosis => D,
                   steps => [#{t => null, wrote => W, crossed_out => false} || W <- Steps]},
             case (try witness_draw:run(Key, Q, Sitting) catch Cl:Er -> {Cl, Er} end) of
                 {ok, #{bytes := Bytes, format := Fmt, lines := Lines, changed := Ch}, Cost} ->
                     File = <<"drawn-learner-", L/binary, ".", (bin(Fmt))/binary>>,
                     ok = file:write_file(filename:join(Dir, File), Bytes),
                     #{learner => L, file => File, bytes => byte_size(Bytes), lines => Lines, changed => Ch, cost_usd => Cost};
                 Other -> #{learner => L, error => bin(io_lib:format("~0p", [Other]))}
             end
         end || {L, Steps, D} <- Learners],
    io:format("drawn: ~p~n", [[{maps:get(learner, X), maps:is_key(file, X)} || X <- R]]),
    ok = file:write_file(filename:join(Dir, "redraw-03nov.json"),
                         json:encode(#{run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second))), muse_image => R})).

bin(B) when is_binary(B) -> B;
bin(A) when is_atom(A) -> atom_to_binary(A);
bin(L) -> iolist_to_binary(L).
