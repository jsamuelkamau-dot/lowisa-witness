#!/usr/bin/env escript
%%! -pa C:/lw-witness/_build/default/lib/witness/ebin
%% Muse Image draws Daniel's corrected step for question 24 (film v11), through the product's own witness_draw. It read
%% the film's marking of his paper and the exam's questions from the team's working folder (the paths below); the result
%% is harness/probes/results-03nov/drawn-daniel-q24.json and .webp.
main([]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = list_to_binary(os:getenv("MODEL_API_KEY")),
    {ok, J} = file:read_file("C:/lw-witness-scratch/film5/test/lmark_film11.json"),
    Qs = maps:get(<<"questions">>, maps:get(<<"result">>, maps:get(<<"sitting_reply">>, json:decode(J)))),
    [Q24] = [Q || Q <- Qs, maps:get(<<"n">>, Q) =:= 24],
    {ok, QJ} = file:read_file("C:/lw-witness-scratch/film5/test/qs.json"),
    Listed = [#{n => N, text => T} || #{<<"n">> := N, <<"text">> := T} <- json:decode(QJ)],
    Q = #{n => 24, steps => [#{wrote => maps:get(<<"wrote">>, S)} || S <- maps:get(<<"steps">>, Q24)],
          diagnosis => maps:get(<<"diagnosis">>, Q24)},
    {ok, #{bytes := B, format := F, lines := L, changed := C}, Cost} = witness_draw:run(Key, Q, #{questions => Listed}),
    Out = "C:/lw-witness-scratch/film7/drawn-q24." ++ binary_to_list(F),
    ok = file:write_file(Out, B),
    ok = file:write_file("C:/lw-witness-scratch/film7/drawn-q24.json", json:encode(#{lines => L, changed => C, cost_usd => Cost, file => list_to_binary(Out)})),
    io:format("~s ~p lines, changed ~p, $~.4f~n", [Out, length(L), C, Cost]).
