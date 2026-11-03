#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% open_run.escript <tag> <with_scheme: yes|no> <out.json> <page.jpg>... : one paper marked by Muse Spark Open on partner
%% inference (Baseten's Model API, an OpenAI-compatible endpoint) through the product's own photo path: the same
%% witness_photo:mark/4 the live edge runs, with each reading sent through witness_open:read_content/3, as witness_api
%% does when an exam is marked on open weights (3 Nov 2026). OPEN_URL, OPEN_MODEL and OPEN_KEY are read, the key never
%% printed. The cost is at the endpoint's list price per million tokens ($1.25 in, $4.25 out), every input token counted
%% at the full price (the endpoint's cached-input price, $0.15, is lower, so this is an upper bound).
main([Tag, WithScheme, Out | Files]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Cfg = #{url => list_to_binary(os:getenv("OPEN_URL")), key => list_to_binary(os:getenv("OPEN_KEY")),
            model => list_to_binary(os:getenv("OPEN_MODEL")), price => {1.25, 4.25}},
    Here = "C:/lw-witness-scratch/film5/test",
    {ok, QJ} = file:read_file(Here ++ "/qs.json"),
    Qs = [#{n => N, text => T, marks => M} || #{<<"n">> := N, <<"text">> := T, <<"marks">> := M} <- json:decode(QJ)],
    Scheme = case WithScheme of "yes" -> {ok, S} = file:read_file(Here ++ "/scheme.txt"), S; _ -> <<>> end,
    Sitting = case Files of
                  [_] -> #{level => <<"Form 3 (about 15 years old)">>, scheme => Scheme, questions => Qs};
                  _ -> #{level => <<"Grade 5">>, question_count => 30}
              end,
    Calls = ets:new(calls, [public, ordered_set]),
    Read = fun(_K, Content, Effort) ->
        T0 = erlang:monotonic_time(millisecond),
        R = witness_open:read_content(Cfg, Content, Effort),
        Ms = erlang:monotonic_time(millisecond) - T0,
        ets:insert(Calls, {erlang:unique_integer([monotonic]), #{effort => Effort, ms => Ms,
                     usage => case R of {ok, _, U} -> U; _ -> #{} end, ok => element(1, R) =:= ok,
                     error => case R of {error, E} -> list_to_binary(io_lib:format("~0p", [E])); _ -> null end}}),
        R
    end,
    Pages = [#{n => N, url => list_to_binary(F)} || {N, F} <- lists:enumerate(Files)],
    T0 = erlang:monotonic_time(millisecond),
    R = witness_photo:mark(<<"unused">>, Pages, Sitting, #{fetch => fun(F) -> file:read_file(F) end, read => Read,
                                                          price => witness_open:price_of(Cfg)}),
    Secs = (erlang:monotonic_time(millisecond) - T0) / 1000,
    Log = [C || {_, C} <- ets:tab2list(Calls)],
    Body = case R of
        {ok, M} -> #{status => ok, cost_usd => maps:get(cost_usd, M, null), questions => maps:get(questions, M),
                     read_twice => maps:get(read_twice, M, false), checked => maps:get(checked, M, false)};
        {error, Why} -> #{status => error, why => list_to_binary(io_lib:format("~0p", [Why]))}
    end,
    ok = file:write_file(Out, json:encode(Body#{tag => list_to_binary(Tag), engine => maps:get(model, Cfg),
                                                endpoint => maps:get(url, Cfg), scheme => WithScheme =:= "yes",
                                                marking_seconds => Secs, calls => Log,
                                                commit => list_to_binary(string:trim(os:cmd("git rev-parse --short HEAD")))})),
    io:format("~s ~p in ~.1f s, ~p calls~n", [Tag, maps:get(status, Body), Secs, length(Log)]).
