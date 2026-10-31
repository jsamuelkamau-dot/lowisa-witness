#!/usr/bin/env escript
%%! -pa C:/lw-witness/_build/default/lib/witness/ebin
%% local_mark.escript <tag> <with_scheme: yes|no> : Daniel's physics paper marked by Muse Spark through the product's own
%% code (witness_photo:mark/4) as it is NOW in C:\lw-witness, before any ship. MODEL_API_KEY is read, never printed.
main([Tag, WithScheme]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = list_to_binary(os:getenv("MODEL_API_KEY")),
    Here = "C:/lw-witness-scratch/film5/test",
    {ok, QJ} = file:read_file(Here ++ "/qs.json"),
    Qs = [#{n => N, text => T, marks => M} || #{<<"n">> := N, <<"text">> := T, <<"marks">> := M} <- json:decode(QJ)],
    Scheme = case WithScheme of "yes" -> {ok, S} = file:read_file(Here ++ "/scheme.txt"), S; _ -> <<>> end,
    Sitting = #{level => <<"Form 3 (about 15 years old)">>, scheme => Scheme, questions => Qs},
    T0 = erlang:monotonic_time(millisecond),
    R = witness_photo:mark(Key, [#{n => 1, url => <<"C:/lw-witness-scratch/film5/out/paper_blank_fixed.jpg">>}], Sitting,
                           #{fetch => fun(F) -> file:read_file(F) end}),
    Secs = (erlang:monotonic_time(millisecond) - T0) / 1000,
    {ok, M} = R,
    Out = #{tag => list_to_binary(Tag), marking_seconds => Secs, cost_usd => maps:get(cost_usd, M, null),
            sitting_reply => #{read => maps:get(student, M, #{}), result => #{questions => maps:get(questions, M)}}},
    ok = file:write_file(Here ++ "/lmark_" ++ Tag ++ ".json", json:encode(Out)),
    io:format("~s marked in ~.1f s~n", [Tag, Secs]).
