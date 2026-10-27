-module(witness_api_tests).
-include_lib("eunit/include/eunit.hrl").
-behaviour(witness_host).
-export([meta_key/0, put_url/4, get_url/2, drop_clip/2, save/3, load/2, spend/3, run/1, marker/0]).

%% An in-memory host: rows and events in an ets table, marking run at once, a canned marker.
meta_key() -> <<"test-key">>.
put_url(Uid, Id, Mime, Size) -> ev({put, Uid, Id, Mime, Size}), {ok, <<"https://store.example.com/", Id/binary>>, #{<<"content-type">> => Mime}}.
get_url(_Uid, Id) -> {ok, <<"https://store.example.com/", Id/binary, "?signed">>}.
drop_clip(Uid, Id) -> ev({drop, Uid, Id}), ok.
save(Uid, Id, Row) -> ets:insert(witness_api_t, {{row, Uid, Id}, Row}), ok.
load(Uid, Id) -> case ets:lookup(witness_api_t, {row, Uid, Id}) of [{_, R}] -> {ok, R}; [] -> none end.
spend(Uid, F, Usd) -> ev({spend, Uid, F, Usd}), ok.
run(Fun) -> Fun(), ok.
marker() ->
    fun(<<"test-key">>, #{url := Url, fps := Fps}, Sitting) ->
        ev({marked, Url, Fps, Sitting}),
        case persistent_term:get(witness_api_fail, false) of
            true -> {error, boom};
            false -> {ok, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], cost_usd => 0.08}}
        end
    end.

ev(E) -> ets:insert(witness_api_t, {erlang:unique_integer([monotonic]), E}).
events() -> [E || {K, E} <- lists:sort(ets:tab2list(witness_api_t)), is_integer(K)].

setup() -> case ets:whereis(witness_api_t) of undefined -> ok; _ -> ets:delete(witness_api_t) end, ets:new(witness_api_t, [named_table, public]), persistent_term:put(witness_api_fail, false).

r(M, P, B, Uid) -> witness_api:route(M, P, B, Uid, ?MODULE).

start_mark_view_test() ->
    setup(),
    {201, #{id := Id, put := Put}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"mime">> => <<"video/mp4">>, <<"size">> => 1000}, <<"u1">>),
    ?assertEqual(<<"https://store.example.com/", Id/binary>>, Put),
    ?assertMatch({200, #{status := <<"uploading">>}}, r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>)),
    Body = #{<<"fps">> => 24, <<"level">> => <<"Year 7">>, <<"questions">> => [#{<<"n">> => 1, <<"text">> => <<" Simplify 16/64 ">>, <<"marks">> => 2}]},
    ?assertMatch({202, #{status := <<"marking">>}}, r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], Body, <<"u1">>)),
    {200, V} = r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>),
    ?assertMatch(#{status := <<"marked">>, result := #{questions := [#{result := <<"mastered">>}]}}, V),
    [_, {marked, Url, 24, S}, {drop, <<"u1">>, Id}, {spend, <<"u1">>, <<"witness_sitting">>, 0.08}] = events(),
    ?assertEqual(<<"https://store.example.com/", Id/binary, "?signed">>, Url),
    ?assertMatch(#{level := <<"Year 7">>, questions := [#{n := 1, text := <<"Simplify 16/64">>, marks := 2}]}, S),
    %% marking again does not run it twice
    ?assertMatch({200, #{status := <<"marked">>}}, r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>)),
    ?assertEqual(4, length(events())).

another_account_sees_nothing_test() ->
    setup(),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u2">>)),
    ?assertMatch({404, _}, r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u2">>)).

failure_drops_the_clip_and_says_little_test() ->
    setup(), persistent_term:put(witness_api_fail, true),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>),
    {200, V} = r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>),
    ?assertMatch(#{status := <<"failed">>, error := _}, V),
    ?assertNot(maps:is_key(reason, V)),
    ?assert(lists:member({drop, <<"u1">>, Id}, events())),
    ?assertNot(lists:keymember(spend, 1, events())),
    persistent_term:put(witness_api_fail, false).

refusals_test() ->
    setup(),
    ?assertMatch({400, #{code := <<"bad_type">>}}, r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"mime">> => <<"image/png">>, <<"size">> => 10}, <<"u1">>)),
    ?assertMatch({400, #{code := <<"bad_size">>}}, r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 0}, <<"u1">>)),
    ?assertMatch({400, #{code := <<"bad_size">>}}, r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 600 * 1024 * 1024}, <<"u1">>)),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"nope">>], #{}, <<"u1">>)).

sitting_of_cleans_input_test() ->
    S = witness_api:sitting_of(#{<<"questions">> => [#{<<"n">> => 1, <<"marks">> => 999}, #{<<"n">> => <<"x">>}, 7], <<"scheme">> => 5}),
    ?assertEqual(#{questions => [#{n => 1, text => <<>>, marks => 1}], scheme => <<>>, level => <<"any level">>}, S).
