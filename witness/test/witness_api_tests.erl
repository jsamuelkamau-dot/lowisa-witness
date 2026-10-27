-module(witness_api_tests).
-include_lib("eunit/include/eunit.hrl").
-behaviour(witness_host).
-export([meta_key/0, put_url/4, get_url/2, drop_clip/2, save/3, load/2, list/2, spend/3, run/1, marker/0, checker/0, design/2, judger/0,
         put_asset/4, asset_url/2, stiller/0, examiner/0, answer_judge/0, drawer/0, hearer/0, open_engine/0, open_marker/0, retry_waits/0]).

%% An in-memory host: rows and events in an ets table, marking run at once, a canned marker.
meta_key() -> <<"test-key">>.
put_url(Uid, Id, Mime, Size) -> ev({put, Uid, Id, Mime, Size}), {ok, <<"https://store.example.com/", Id/binary>>, #{<<"content-type">> => Mime}}.
get_url(_Uid, Id) -> {ok, <<"https://store.example.com/", Id/binary, "?signed">>}.
drop_clip(Uid, Id) -> ev({drop, Uid, Id}), ok.
save(Uid, Key, Row) -> ets:insert(witness_api_t, {{row, Uid, Key}, Row}), ok.
load(Uid, Key) -> case ets:lookup(witness_api_t, {row, Uid, Key}) of [{_, R}] -> {ok, R}; [] -> none end.
list(Uid, Kind) -> [{Id, R} || {{row, U, {K, Id}}, R} <- ets:tab2list(witness_api_t), U =:= Uid, K =:= Kind].
spend(Uid, F, Usd) -> ev({spend, Uid, F, Usd}), ok.
run(Fun) -> Fun(), ok.
retry_waits() -> [0, 0].
marker() ->
    fun(<<"test-key">>, #{url := Url, fps := Fps}, Sitting) ->
        ev({marked, Url, Fps, Sitting}),
        case persistent_term:get(witness_api_fail, false) of
            true -> {error, boom};
            {unreadable, _} = U -> {error, U};
            %% Meta busy for the next N marking calls (forever when N is always)
            {busy, always} -> {error, {503, <<"busy">>}};
            {busy, N} when N > 0 -> persistent_term:put(witness_api_fail, {busy, N - 1}), {error, {503, <<"busy">>}};
            {busy, 0} -> {ok, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], cost_usd => 0.08}};
            false -> {ok, persistent_term:get(witness_api_result, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], cost_usd => 0.08})}
        end
    end.

design(<<"broke">>, _) -> {gate, 402, #{success => false, code => <<"credits_exhausted">>}};
design(Uid, Req) -> ev({design, Uid, Req}), {ok, <<"{\"title\":\"Common factors\"}">>}.

judger() ->
    fun(<<"test-key">>, #{n := N}, Text) -> ev({judged, N, Text}), {ok, #{understood => binary:match(Text, <<"factor">>) =/= nomatch, why => <<"w">>, next => <<"n">>}} end.

checker() ->
    fun(<<"test-key">>, In) ->
        ev({checked, In}),
        {ok, #{passes => false, caught => false, cleared => true, on_idea => true, why => <<"the checks let digit-cancelling pass">>,
               problems => [#{lesson => 3, fix => <<"use 19/95, where cancelling the 9s gives 1/5, not 1/5... make it fail">>}]}, 0.04}
    end.

put_asset(Uid, Name, Bytes, Mime) -> ets:insert(witness_api_t, {{asset, Uid, Name}, {Bytes, Mime}}), ok.
asset_url(Uid, Name) -> case ets:lookup(witness_api_t, {asset, Uid, Name}) of [_] -> {ok, <<"https://store.example.com/a/", Name/binary>>}; [] -> {error, none} end.

%% The new seams stay off unless a test turns them on, so the older tests' event lists are unchanged.
on(K) -> persistent_term:get({witness_api_on, K}, false).
stiller() -> fun(Url, T) -> case on(stills) of true -> ev({still, Url, T}), {ok, <<255, 216, "jpeg">>}; false -> {error, off} end end.
examiner() ->
    fun(<<"test-key">>, Sitting, Qs) ->
        case {on(examiner), persistent_term:get(witness_api_exbusy, 0)} of
            {true, B} when B > 0 -> persistent_term:put(witness_api_exbusy, B - 1), ev(examiner_busy), {error, {503, <<"busy">>}};
            {true, _} -> ev({examiner, maps:get(level, Sitting, none), [maps:get(n, Q) || Q <- Qs]}),
                    {ok, [#{k => 1, n => 3, step => 1, wrote => <<"16/64 = 1/4">>, ask => <<"You wrote 16/64 = 1/4. Why did you cross out the 6s?">>},
                          #{k => 2, n => 1, step => 1, wrote => <<"3/2">>, ask => <<"How did you get 3/2?">>}], 0.02};
            {false, _} -> {error, off}
        end
    end.
answer_judge() -> fun(<<"test-key">>, #{k := K}, _Q, Text) -> ev({answer_judged, K, Text}), {ok, #{own_work => true, understood => binary:match(Text, <<"factor">>) =/= nomatch, why => <<"w">>}, 0.002} end.
drawer() -> fun(<<"test-key">>, #{n := N}, Sitting) -> ev({drawn, N, [maps:get(n, Q) || Q <- maps:get(questions, Sitting, [])]}), {ok, #{bytes => <<"RIFFwebp">>, format => <<"webp">>, lines => [<<"16/64">>, <<"= 1/4 (divide by 16)">>], changed => 2}, 0.019} end.
hearer() -> fun(<<"test-key">>, <<"audio-bytes">>) -> {ok, <<"Because I divided by the common factor 16.">>, 4.0};
                (_, <<"busy">>) -> {error, {429, <<"slow down">>}}; (_, _) -> {error, unreadable} end.

open_engine() -> case on(open) of true -> #{url => <<"https://open.example.com/v1">>, key => <<"k">>, model => <<"muse-spark-open">>}; false -> undefined end.
open_marker() -> fun(#{model := M}, #{url := Url}, Sitting) -> ev({open_marked, M, Url, maps:get(engine, Sitting)}), {ok, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], engine => M, cost_usd => 0.07}} end.

ev(E) -> ets:insert(witness_api_t, {erlang:unique_integer([monotonic]), E}).
events() -> [E || {K, E} <- lists:sort(ets:tab2list(witness_api_t)), is_integer(K)].

setup() -> case ets:whereis(witness_api_t) of undefined -> ok; _ -> ets:delete(witness_api_t) end, ets:new(witness_api_t, [named_table, public]), persistent_term:put(witness_api_fail, false), persistent_term:erase(witness_api_result),
           [persistent_term:erase({witness_api_on, K}) || K <- [stills, examiner, open]], persistent_term:erase(witness_api_exbusy).

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
    ?assertEqual(#{questions => [#{n => 1, text => <<>>, marks => 1}], scheme => <<>>, level => <<"any level">>, kind => <<"paper">>, engine => <<"meta">>}, S),
    ?assertMatch(#{kind := <<"practical">>}, witness_api:sitting_of(#{<<"kind">> => <<"practical">>})),
    ?assertMatch(#{kind := <<"paper">>}, witness_api:sitting_of(#{<<"kind">> => <<"anything">>})).

q(N, Res, Conf) -> #{n => N, result => Res, confidence => Conf, marks => case Res of <<"mastered">> -> 2; _ -> 0 end, out_of => 2,
                    diagnosis => <<"d">>, moment_s => 3, steps => []}.

pile_queue_review_release_test() ->
    setup(),
    {201, #{id := P}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions quiz">>, <<"level">> => <<"Year 7">>,
                                                     <<"questions">> => [#{<<"n">> => 1, <<"text">> => <<"3/4 / 1/2">>, <<"marks">> => 2}],
                                                     <<"scheme">> => <<"method 1, answer 1">>}, <<"t1">>),
    ?assertMatch({400, #{code := <<"no_title">>}}, r(<<"POST">>, [<<"pile">>], #{}, <<"t1">>)),
    Mark = fun(Student, Qs) ->
        persistent_term:put(witness_api_result, #{questions => Qs, pauses => [], lines => [], cost_usd => 0.08}),
        {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"pile">> => P, <<"student">> => Student}, <<"t1">>),
        {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"t1">>),
        S
    end,
    SA = Mark(<<"Amara">>, [q(1, <<"mastered">>, 0.95), q(2, <<"right_answer_wrong_thinking">>, 0.9)]),
    SB = Mark(<<"Ben">>, [q(1, <<"not_yet">>, 0.4), q(2, <<"part_way">>, 0.9)]),
    %% the pile's questions and scheme were the marking's input
    [{marked, _, 30, In} | _] = [E || E = {marked, _, _, _} <- events()],
    ?assertMatch(#{level := <<"Year 7">>, scheme := <<"method 1, answer 1">>, questions := [#{n := 1, marks := 2}]}, In),
    {200, #{pile := Pile, sittings := Ss, queue := Queue}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"t1">>),
    ?assertMatch(#{title := <<"Fractions quiz">>, id := P}, Pile),
    ?assertMatch([#{id := SA, student := <<"Amara">>, marks := 2, out_of := 4, to_master := 1},
                  #{id := SB, student := <<"Ben">>, to_master := 1}], Ss),
    %% anything not mastered first, least certain first among them; mastered last
    ?assertEqual([{SB, 1}, {SA, 2}, {SB, 2}, {SA, 1}], [{maps:get(sitting, I), maps:get(n, I)} || I <- Queue]),
    %% a mastered answer the model is unsure of still comes after every answer that needs teaching
    ?assertEqual([<<"not_yet">>, <<"mastered">>], [maps:get(result, I) || I <- witness_api:queue([
        {<<"x">>, #{result => #{questions => [#{n => 1, result => <<"mastered">>, confidence => 0.5}, #{n => 2, result => <<"not_yet">>, confidence => 0.99}]}}}])]),
    %% the teacher's word beside the model's, and the focus note
    {200, #{question := Rq}} = r(<<"POST">>, [<<"sitting">>, SB, <<"review">>], #{<<"n">> => 1, <<"result">> => <<"part_way">>, <<"marks">> => 1,
                                                                                <<"focus">> => <<" Why only the divisor flips ">>}, <<"t1">>),
    ?assertMatch(#{result := <<"not_yet">>, teacher_result := <<"part_way">>, teacher_marks := 1, focus := <<"Why only the divisor flips">>, reviewed := true}, Rq),
    {200, #{question := Same}} = r(<<"POST">>, [<<"sitting">>, SB, <<"review">>], #{<<"n">> => 1, <<"marks">> => 9}, <<"t1">>),
    ?assertEqual(1, maps:get(teacher_marks, Same)),                          %% more than the question is worth: ignored
    ?assertMatch({404, _}, r(<<"POST">>, [<<"sitting">>, SB, <<"review">>], #{<<"n">> => 7}, <<"t1">>)),
    {200, #{sittings := [_, #{id := SB, marks := 1, to_master := 0}], queue := Q2}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"t1">>),
    ?assertEqual(3, length(Q2)),
    %% release: both papers go out, the pile says so
    ?assertMatch({200, #{released := 2}}, r(<<"POST">>, [<<"pile">>, P, <<"release">>], #{}, <<"t1">>)),
    ?assertMatch({200, #{status := <<"released">>, student := <<"Amara">>}}, r(<<"GET">>, [<<"sitting">>, SA], #{}, <<"t1">>)),
    ?assertMatch({200, #{piles := [#{id := P, papers := 2, released := true}]}}, r(<<"GET">>, [<<"piles">>], #{}, <<"t1">>)),
    %% another teacher sees none of it
    ?assertMatch({404, _}, r(<<"GET">>, [<<"pile">>, P], #{}, <<"t2">>)),
    ?assertMatch({200, #{piles := []}}, r(<<"GET">>, [<<"piles">>], #{}, <<"t2">>)),
    ?assertMatch({404, #{code := <<"no_pile">>}}, r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"pile">> => P}, <<"t2">>)).

review_before_marking_is_refused_test() ->
    setup(),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    ?assertMatch({409, #{code := <<"not_marked">>}}, r(<<"POST">>, [<<"sitting">>, S, <<"review">>], #{<<"n">> => 1}, <<"u1">>)).

join_code_puts_the_students_paper_in_the_teachers_pile_test() ->
    setup(),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions quiz">>, <<"level">> => <<"Year 7">>}, <<"teacher">>),
    ?assertEqual(6, byte_size(Code)),
    ?assertMatch({200, #{piles := [#{code := Code}]}}, r(<<"GET">>, [<<"piles">>], #{}, <<"teacher">>)),
    %% the student checks the code (any case, spaces around it), then sits
    ?assertMatch({200, #{pile := #{title := <<"Fractions quiz">>, level := <<"Year 7">>}}},
                 r(<<"POST">>, [<<"join">>], #{<<"code">> => <<" ", (string:lowercase(Code))/binary, " ">>}, <<"stud">>)),
    ?assertMatch({404, #{code := <<"no_code">>}}, r(<<"POST">>, [<<"join">>], #{<<"code">> => <<"ZZZZZZ">>}, <<"stud">>)),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amara">>}, <<"stud">>),
    %% the clip is signed under the teacher, the paper is in the teacher's pile
    ?assert(lists:member({put, <<"teacher">>, S, <<"video/mp4">>, 10}, events())),
    {200, #{sittings := [#{id := S, student := <<"Amara">>}]}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    %% the student marks their own paper, and sees it with the teacher until it is released
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    ?assertMatch({200, #{papers := [#{id := S, status := <<"with_teacher">>}]}}, r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>)),
    {200, #{papers := [Before]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>),
    ?assertNot(maps:is_key(result, Before)),
    {200, _} = r(<<"POST">>, [<<"pile">>, P, <<"release">>], #{}, <<"teacher">>),
    ?assertMatch({200, #{papers := [#{id := S, status := <<"released">>, title := <<"Fractions quiz">>, result := #{questions := [_]}}]}},
                 r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>)),
    %% nobody else reaches it: not another student, not through the teacher's routes
    ?assertMatch({200, #{papers := []}}, r(<<"GET">>, [<<"mine">>], #{}, <<"other">>)),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"pile">>, P], #{}, <<"stud">>)),
    ?assertMatch({404, _}, r(<<"POST">>, [<<"sitting">>, S, <<"review">>], #{<<"n">> => 1}, <<"stud">>)).

self_check_runs_off_the_request_test() ->
    setup(),
    ?assertMatch({400, #{code := <<"no_level">>}}, r(<<"POST">>, [<<"check">>], #{}, <<"stud">>)),
    Body = #{<<"question">> => <<"Simplify 16/64">>, <<"working">> => <<"16/64 = 1/4">>, <<"diagnosis">> => <<"Cancelled the 6s.">>,
             <<"focus">> => <<"football">>,
             <<"level">> => #{<<"title">> => <<"Common factors">>, <<"lessons">> => [#{<<"title">> => <<"Your step, at the stadium">>, <<"beats">> => [<<"a">>, 7, <<"b">>]}]}},
    {202, #{id := Id, status := <<"checking">>}} = r(<<"POST">>, [<<"check">>], Body, <<"stud">>),
    [{checked, In}] = [E || E = {checked, _} <- events()],
    ?assertMatch(#{diagnosis := <<"Cancelled the 6s.">>, focus := <<"football">>, level := #{lessons := [#{beats := [<<"a">>, <<"b">>]}]}}, In),
    ?assertMatch({200, #{status := <<"done">>, verdict := #{passes := false, problems := [#{lesson := 3}]}}}, r(<<"GET">>, [<<"check">>, Id], #{}, <<"stud">>)),
    ?assert(lists:member({spend, <<"stud">>, <<"witness_check">>, 0.04}, events())),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"check">>, Id], #{}, <<"other">>)).

design_door_passes_one_call_and_the_wall_test() ->
    setup(),
    B = #{<<"requestId">> => <<"mob-course-1-s">>, <<"reasoningEffort">> => <<"medium">>, <<"maxOutputTokens">> => 12000,
          <<"messages">> => [#{<<"role">> => <<"system">>, <<"content">> => <<"Design.">>}, #{<<"role">> => <<"user">>, <<"content">> => <<"One level">>},
                             #{<<"role">> => <<"assistant">>, <<"content">> => <<"dropped">>}]},
    ?assertMatch({200, #{success := true, text := <<"{\"title\":\"Common factors\"}">>}}, r(<<"POST">>, [<<"design">>], B, <<"stud">>)),
    [{design, <<"stud">>, Req}] = [E || E = {design, _, _} <- events()],
    ?assertMatch(#{request_id := <<"mob-course-1-s">>, effort := <<"medium">>, max_tokens := 12000,
                   messages := [#{role := <<"system">>}, #{role := <<"user">>}]}, Req),
    %% the learner with no credits meets the host's own wall, as from any paid call
    ?assertMatch({402, #{code := <<"credits_exhausted">>}}, r(<<"POST">>, [<<"design">>], B, <<"broke">>)),
    ?assertMatch({400, _}, r(<<"POST">>, [<<"design">>], #{}, <<"stud">>)),
    %% an unknown effort or size falls back to the safe ones
    {200, _} = r(<<"POST">>, [<<"design">>], B#{<<"reasoningEffort">> => <<"max">>, <<"maxOutputTokens">> => 999999}, <<"stud">>),
    ?assertMatch([_, {design, _, #{effort := <<"low">>, max_tokens := 8000}}], [E || E = {design, _, _} <- events()]).

after_release_the_teacher_chooses_and_issues_the_badge_test() ->
    setup(),
    {201, #{code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>}, <<"teacher">>),
    persistent_term:put(witness_api_result, #{questions => [q(1, <<"mastered">>, 0.9), q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amara">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    M = fun(Who, N, Action, Body) -> r(<<"POST">>, [<<"mastery">>, S, integer_to_binary(N), Action], Body, Who) end,
    %% nothing before release; nobody else at all
    ?assertMatch({409, #{code := <<"not_released">>}}, M(<<"stud">>, 3, <<"event">>, #{<<"event">> => <<"built">>})),
    ?assertMatch({404, _}, M(<<"other">>, 3, <<"ask">>, #{<<"text">> => <<"hi">>})),
    {200, _} = r(<<"POST">>, [<<"pile">>, maps:get(pile, element(2, load(<<"teacher">>, {sitting, S}))), <<"release">>], #{}, <<"teacher">>),
    %% the student builds and plays the level; asks the teacher from a step; the teacher answers
    {200, #{mastery := Built}} = M(<<"stud">>, 3, <<"event">>, #{<<"event">> => <<"built">>, <<"path">> => <<"custom-topic-x">>,
        <<"check">> => #{<<"passes">> => false, <<"problems">> => [<<"lesson 2: the checks are all lucky cancels">>, 7]}}),
    ?assertMatch(#{status := <<"ready">>, path := <<"custom-topic-x">>}, Built),
    ?assertNot(maps:is_key(check, Built)),                                 %% the self-check is the teacher's to read
    {200, _} = M(<<"stud">>, 3, <<"ask">>, #{<<"text">> => <<"Why does 12/24 not work?">>}),
    {200, #{mastery := #{thread := [_, #{from := teacher}]}}} = M(<<"teacher">>, 3, <<"reply">>, #{<<"text">> => <<"Try dividing both by 12.">>}),
    {200, #{mastery := #{status := <<"completed">>}}} = M(<<"stud">>, 3, <<"event">>, #{<<"event">> => <<"completed">>}),
    %% verification only when the teacher asks for it, and only what they asked
    ?assertMatch({400, #{code := <<"not_asked">>}}, M(<<"stud">>, 3, <<"explain">>, #{<<"to">> => <<"lo">>, <<"text">> => <<"common factor">>})),
    ?assertMatch({403, _}, M(<<"stud">>, 3, <<"verify">>, #{<<"lo">> => true})),
    {200, #{mastery := #{asks := #{lo := true, paper := false, teacher := true}}}} = M(<<"teacher">>, 3, <<"verify">>, #{<<"lo">> => true, <<"teacher">> => true}),
    {200, #{mastery := StudentView}} = M(<<"stud">>, 3, <<"explain">>, #{<<"to">> => <<"lo">>, <<"text">> => <<"You divide top and bottom by a common factor, digits are not numbers.">>}),
    ?assertEqual([lo], maps:get(explained, StudentView)),
    ?assertNot(maps:is_key(lo_next, StudentView)),                         %% understood: Lo asks nothing more
    ?assertNot(maps:is_key(explain, StudentView)),                         %% the verdict is the teacher's to read
    [{judged, 3, _}] = [E || E = {judged, _, _} <- events()],
    {200, _} = M(<<"stud">>, 3, <<"explain">>, #{<<"to">> => <<"teacher">>, <<"text">> => <<"I know now.">>}),
    %% a fresh question on paper, watched again: only once the teacher set one; its marking comes back onto question 3
    Clip = #{<<"mime">> => <<"video/mp4">>, <<"size">> => 10},
    ?assertMatch({400, #{code := <<"not_asked">>}}, M(<<"stud">>, 3, <<"fresh">>, Clip)),
    {200, #{mastery := #{asks := #{paper := true, fresh := <<"Simplify 12/48">>}}}} =
        M(<<"teacher">>, 3, <<"verify">>, #{<<"lo">> => true, <<"teacher">> => true, <<"paper">> => true, <<"fresh">> => <<"Simplify 12/48">>}),
    ?assertMatch({403, _}, M(<<"teacher">>, 3, <<"fresh">>, Clip)),
    ?assertMatch({400, #{code := <<"bad_type">>}}, M(<<"stud">>, 3, <<"fresh">>, Clip#{<<"mime">> => <<"image/png">>})),
    {200, #{fresh := #{id := F, put := _}, mastery := #{fresh := #{status := <<"uploading">>}}}} = M(<<"stud">>, 3, <<"fresh">>, Clip),
    {202, _} = r(<<"POST">>, [<<"sitting">>, F, <<"mark">>], #{}, <<"stud">>),
    {200, #{result := #{questions := [_, QF]}}} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{mastery := #{fresh := #{sitting := F, status := <<"marked">>, question := #{n := _}}}}, QF),
    {200, #{result := #{questions := [_, Q3]}}} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{mastery := #{explain := #{lo := #{verdict := #{understood := true}}, teacher := #{text := <<"I know now.">>}}}}, Q3),
    ?assertMatch(#{mastery := #{check := #{passes := false, problems := [<<"lesson 2: the checks are all lucky cancels">>]}}}, Q3),
    %% the badge is the teacher's alone, and only for a question that was to master
    ?assertMatch({403, _}, M(<<"stud">>, 3, <<"badge">>, #{<<"issue">> => true})),
    ?assertMatch({400, #{code := <<"not_to_master">>}}, M(<<"teacher">>, 1, <<"badge">>, #{<<"issue">> => true})),
    {200, #{mastery := #{status := <<"badge">>, badge := #{issued := true, note := <<"Turned around">>}}}} = M(<<"teacher">>, 3, <<"badge">>, #{<<"issue">> => true, <<"note">> => <<"Turned around">>}),
    %% the student's own list shows the badge and the thread, not the verdict
    {200, #{papers := [#{result := #{questions := [_, Mine3]}}]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>),
    ?assertMatch(#{mastery := #{status := <<"badge">>, badge := #{issued := true}, thread := [_, _]}}, Mine3),
    ?assertNot(maps:is_key(explain, maps:get(mastery, Mine3))),
    ?assertEqual(#{status => <<"marked">>}, maps:get(fresh, maps:get(mastery, Mine3))).   %% the fresh marks are the teacher's

%% The examiner's two questions, answered out loud or in writing; the stills; the drawn step; the spoken comment;
%% the Proof of Thinking record; the measured numbers.
examiner_proof_draw_voice_measure_test() ->
    setup(),
    [persistent_term:put({witness_api_on, K}, true) || K <- [stills, examiner]],
    persistent_term:put(witness_api_result, #{questions => [
        #{n => 1, result => <<"mastered">>, confidence => 0.95, marks => 2, out_of => 2, steps => [#{t => 9, wrote => <<"3/2">>, crossed_out => false}]},
        #{n => 3, result => <<"right_answer_wrong_thinking">>, confidence => 0.9, marks => 0, out_of => 2, moment_s => 35,
          diagnosis => <<"Cancelled the 6s.">>, steps => [#{t => 34, wrote => <<"16/64 = 1/4">>, crossed_out => false}]}],
        pauses => [], lines => [], cost_usd => 0.08}),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>, <<"level">> => <<"Year 7">>,
        <<"questions">> => [#{<<"n">> => 1, <<"text">> => <<"3/4 ÷ 1/2"/utf8>>}, #{<<"n">> => 3, <<"text">> => <<"Simplify 16/64">>}]}, <<"teacher">>),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amara">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    %% a still at each moment: where the thinking went wrong (35 s), else the question's last step (9 s)
    ?assertEqual([9, 35], lists:sort([T || {still, _, T} <- events()])),
    [{examiner, <<"Year 7">>, [1, 3]}] = [E || E = {examiner, _, _} <- events()],
    ?assert(lists:member({spend, <<"teacher">>, <<"witness_examiner">>, 0.02}, events())),
    %% before release the student sees no marks, only the two questions about their own steps
    {200, #{papers := [Before]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>),
    ?assertMatch(#{status := <<"with_teacher">>, title := <<"Fractions">>, examiner := #{asks := [#{k := 1, answered := false}, #{k := 2}]}}, Before),
    ?assertNot(maps:is_key(result, Before)),
    %% answered out loud (heard) and in writing; once each; never by anyone else
    {200, #{examiner := #{asks := [#{answered := true}, #{answered := false}]}}} =
        r(<<"POST">>, [<<"sitting">>, S, <<"answer">>], #{<<"k">> => 1, <<"audio">> => base64:encode(<<"audio-bytes">>), <<"mime">> => <<"audio/mp4">>}, <<"stud">>),
    ?assert(lists:member({spend, <<"teacher">>, <<"witness_transcribe">>, witness_meta:cost(transcribe, 4.0)}, events())),
    ?assertMatch({409, #{code := <<"answered">>}}, r(<<"POST">>, [<<"sitting">>, S, <<"answer">>], #{<<"k">> => 1, <<"text">> => <<"again">>}, <<"stud">>)),
    ?assertMatch({400, #{code := <<"not_heard">>}}, r(<<"POST">>, [<<"sitting">>, S, <<"answer">>], #{<<"k">> => 2, <<"audio">> => base64:encode(<<"noise">>)}, <<"stud">>)),
    %% Meta busy is not the student's microphone
    ?assertMatch({503, #{code := <<"busy">>, error := <<"Listening is busy right now", _/binary>>}},
                 r(<<"POST">>, [<<"sitting">>, S, <<"answer">>], #{<<"k">> => 2, <<"audio">> => base64:encode(<<"busy">>)}, <<"stud">>)),
    ?assertMatch({404, _}, r(<<"POST">>, [<<"sitting">>, S, <<"answer">>], #{<<"k">> => 2, <<"text">> => <<"x">>}, <<"other">>)),
    {200, _} = r(<<"POST">>, [<<"sitting">>, S, <<"answer">>], #{<<"k">> => 2, <<"text">> => <<"I multiplied by the reciprocal.">>}, <<"stud">>),
    {200, TV} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{examiner := #{asks := [#{answer := #{spoken := true, text := <<"Because I divided by the common factor 16.">>, verdict := #{own_work := true, understood := true}}},
                                          #{answer := #{spoken := false, verdict := #{understood := false}}}]}}, TV),
    ?assertMatch(#{result := #{stills := [#{n := 1, asset := <<"still-1.jpg">>}, #{n := 3, t := 35}]}}, TV),
    %% the teacher draws the corrected step and speaks a comment; the review keeps the written comment and desk time
    {202, #{drawn := #{status := <<"drawing">>}}} = r(<<"POST">>, [<<"sitting">>, S, <<"draw">>], #{<<"n">> => 3}, <<"teacher">>),
    [{drawn, 3, [1, 3]}] = [E || E = {drawn, _, _} <- events()],
    ?assertMatch({404, _}, r(<<"POST">>, [<<"sitting">>, S, <<"draw">>], #{<<"n">> => 3}, <<"stud">>)),
    {200, #{text := <<"Because I divided by the common factor 16.">>}} = r(<<"POST">>, [<<"sitting">>, S, <<"voice">>], #{<<"n">> => 3, <<"audio">> => base64:encode(<<"audio-bytes">>)}, <<"teacher">>),
    {200, _} = r(<<"POST">>, [<<"sitting">>, S, <<"review">>], #{<<"n">> => 3, <<"comment">> => <<"Divide by 16, not the 6s.">>, <<"desk_s">> => 40}, <<"teacher">>),
    {200, _} = r(<<"POST">>, [<<"sitting">>, S, <<"review">>], #{<<"n">> => 1, <<"result">> => <<"part_way">>, <<"desk_s">> => 20}, <<"teacher">>),
    {200, #{result := #{questions := [_, Q3]}}} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{drawn := #{status := <<"done">>, asset := <<"drawn-3.webp">>, changed := 2}, comment := #{text := <<"Divide by 16, not the 6s.">>, spoken := true}}, Q3),
    %% pictures: the teacher at once; the student only once the paper is released; never a path outside the paper
    {200, #{url := <<"https://store.example.com/a/", S:16/binary, "/drawn-3.webp">>}} = r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"drawn-3.webp">>], #{}, <<"teacher">>),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"still-3.jpg">>], #{}, <<"stud">>)),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"../x">>], #{}, <<"teacher">>)),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"sitting">>, S, <<"proof">>], #{}, <<"stud">>)),
    {200, _} = r(<<"POST">>, [<<"pile">>, P, <<"release">>], #{}, <<"teacher">>),
    {200, #{url := _}} = r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"still-3.jpg">>], #{}, <<"stud">>),
    %% the Proof of Thinking record: the teacher reads the verdicts, the student their own answers
    {200, Proof} = r(<<"GET">>, [<<"sitting">>, S, <<"proof">>], #{}, <<"teacher">>),
    ?assertMatch(#{record := <<"proof_of_thinking">>, exam := <<"Fractions">>, student := <<"Amara">>, video := <<"deleted once the paper was marked">>,
                   questions := [#{n := 1, question := <<"3/4 ÷ 1/2"/utf8>>, still := <<"still-1.jpg">>, teacher_result := <<"part_way">>},
                                 #{n := 3, steps := [#{t := 34, wrote := <<"16/64 = 1/4">>}], still := <<"still-3.jpg">>, comment := <<"Divide by 16, not the 6s.">>,
                                   drawn := #{lines := [_, _]}}],
                   examiner := [#{k := 1, answer := #{verdict := _}}, _]}, Proof),
    {200, Mine} = r(<<"GET">>, [<<"sitting">>, S, <<"proof">>], #{}, <<"stud">>),
    ?assertMatch(#{examiner := [#{k := 1, answered := true, answer := #{text := _}}, _]}, Mine),
    ?assertNot(maps:is_key(verdict, maps:get(answer, hd(maps:get(examiner, Mine))))),
    %% the measured numbers
    {200, M} = r(<<"GET">>, [<<"pile">>, P, <<"measure">>], #{}, <<"teacher">>),
    ?assertMatch(#{papers := 1, marked := 1, questions := 2, reviewed := 2, teacher_agreed := 1, agreement := 0.5,
                   changed_by_teacher := [#{n := 1, witness := <<"mastered">>, teacher := <<"part_way">>}],
                   wrong_thinking_caught := 1, wrong_thinking_kept_by_teacher := 1,
                   teacher_seconds_per_paper := #{n := 1, mean := 60.0}, examiner_asks := 2, examiner_answered := 2, examiner_own_work := 2}, M),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"pile">>, P, <<"measure">>], #{}, <<"stud">>)).

practical_mode_marks_the_procedure_test() ->
    setup(),
    {201, #{id := P}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Heating water">>, <<"kind">> => <<"practical">>, <<"level">> => <<"Grade 8 science">>,
        <<"questions">> => [#{<<"n">> => 1, <<"text">> => <<"Measure 100 ml of water">>, <<"marks">> => 2}, #{<<"n">> => 2, <<"text">> => <<"Read the thermometer at eye level">>}]}, <<"teacher">>),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"pile">> => P}, <<"teacher">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"teacher">>),
    [{marked, _, _, Sitting}] = [E || E = {marked, _, _, _} <- events()],
    ?assertMatch(#{kind := <<"practical">>, questions := [#{n := 1, text := <<"Measure 100 ml of water">>}, _]}, Sitting),
    Prompt = witness_mark:prompt(Sitting),
    ?assertNotEqual(nomatch, binary:match(Prompt, <<"practical task">>)),
    ?assertNotEqual(nomatch, binary:match(Prompt, <<"Read the thermometer at eye level">>)),
    ?assertEqual(nomatch, binary:match(witness_mark:prompt(Sitting#{kind => <<"paper">>}), <<"practical task">>)).

open_weights_engine_test() ->
    setup(),
    {201, #{id := P}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Open">>, <<"engine">> => <<"open">>}, <<"teacher">>),
    %% no open endpoint on this host: Muse Spark marks it, and the result says so
    {201, #{id := S1}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"pile">> => P}, <<"teacher">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S1, <<"mark">>], #{}, <<"teacher">>),
    ?assertMatch({200, #{result := #{engine := <<"muse-spark-1.3">>}}}, r(<<"GET">>, [<<"sitting">>, S1], #{}, <<"teacher">>)),
    %% with one, Spark Open marks it from the same signed link
    persistent_term:put({witness_api_on, open}, true),
    {201, #{id := S2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"pile">> => P}, <<"teacher">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S2, <<"mark">>], #{}, <<"teacher">>),
    [{open_marked, <<"muse-spark-open">>, Url, <<"open">>}] = [E || E = {open_marked, _, _, _} <- events()],
    ?assertEqual(<<"https://store.example.com/", S2/binary, "?signed">>, Url),
    ?assertMatch({200, #{result := #{engine := <<"muse-spark-open">>}}}, r(<<"GET">>, [<<"sitting">>, S2], #{}, <<"teacher">>)),
    ?assertMatch({200, #{engine := <<"muse-spark-open">>}}, r(<<"GET">>, [<<"sitting">>, S2, <<"proof">>], #{}, <<"teacher">>)).

%% 27 Oct, emulator: a dropped upload stayed on the teacher's desk as "Uploading" for good, and counted as a paper
an_upload_whose_link_ran_out_leaves_the_exam_test() ->
    setup(),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions check">>}, <<"teacher">>),
    {201, #{id := Lost}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Tom">>}, <<"stud">>),
    {201, #{id := Sent}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Tom">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Sent, <<"mark">>], #{}, <<"stud">>),
    %% a fresh upload still shows: its link is good for fifteen minutes
    {200, #{sittings := [_, _]}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    {ok, Row} = load(<<"teacher">>, {sitting, Lost}),
    ok = save(<<"teacher">>, {sitting, Lost}, Row#{created_ms => erlang:system_time(millisecond) - 21 * 60000}),
    ?assertMatch({200, #{sittings := [#{id := Sent}]}}, r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>)),
    ?assertMatch({200, #{piles := [#{papers := 1}]}}, r(<<"GET">>, [<<"piles">>], #{}, <<"teacher">>)),
    ?assertMatch({200, #{papers := [#{id := Sent}]}}, r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>)),
    %% the row itself is kept
    ?assertMatch({ok, #{status := <<"uploading">>}}, load(<<"teacher">>, {sitting, Lost})).

%% 27 Oct, emulator: a video of no paper was marked "to master" on every question at 20% sure
a_video_without_the_paper_is_not_marked_test() ->
    setup(), persistent_term:put(witness_api_fail, {unreadable, <<"A picture of a house; no paper.">>}),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions check">>}, <<"teacher">>),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amina">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    ?assertMatch({200, #{status := <<"failed">>, unreadable := <<"A picture of a house; no paper.">>, error := <<"Witness couldn't see the paper", _/binary>>}},
                 r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>)),
    {200, #{sittings := [Row], queue := Queue}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    ?assertMatch(#{status := <<"failed">>, unreadable := _, to_master := 0}, Row),
    ?assertEqual([], Queue),
    ?assertMatch({200, #{papers := [#{status := <<"failed">>, unseen := true} = Mine]}} when not is_map_key(unreadable, Mine), r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>)),
    ?assertNot(lists:keymember(spend, 1, events())),
    persistent_term:put(witness_api_fail, false).

%% 28 Oct, Meta tooling through the judges' eyes: a moment's outage at Meta failed the sitting and deleted the clip,
%% so the student had to sit the exam again
a_moment_of_meta_busy_is_tried_again_test() ->
    setup(), persistent_term:put(witness_api_fail, {busy, 2}),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>),
    ?assertMatch({200, #{status := <<"marked">>}}, r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>)),
    ?assertEqual(3, length([1 || {marked, _, _, _} <- events()])),
    ?assertEqual([{drop, <<"u1">>, Id}], [E || E = {drop, _, _} <- events()]),
    persistent_term:put(witness_api_fail, false).

meta_busy_every_time_keeps_the_clip_to_mark_again_test() ->
    setup(), persistent_term:put(witness_api_fail, {busy, always}),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions check">>}, <<"teacher">>),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amina">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    ?assertEqual(3, length([1 || {marked, _, _, _} <- events()])),
    ?assertEqual([], [E || E = {drop, _, _} <- events()]),
    {200, V} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{status := <<"failed">>, kept := true, error := <<"Witness couldn't reach the marking service", _/binary>>}, V),
    ?assertMatch({200, #{sittings := [#{status := <<"failed">>, kept := true}]}}, r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>)),
    %% the student is not told to film it again: the paper is with the teacher
    ?assertMatch({200, #{papers := [#{status := <<"with_teacher">>}]}}, r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>)),
    ?assertNot(lists:keymember(spend, 1, events())),
    %% Meta is back: the teacher marks it again from the kept clip, and only then is the clip dropped
    persistent_term:put(witness_api_fail, false),
    ?assertMatch({202, #{status := <<"marking">>}}, r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"teacher">>)),
    {200, V2} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{status := <<"marked">>}, V2),
    ?assertMatch({200, #{sittings := [#{status := <<"marked">>} = Row]}} when not is_map_key(kept, Row), r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>)),
    ?assertEqual(1, length([E || E = {drop, _, _} <- events()])).

a_kept_clip_is_not_kept_past_a_day_test() ->
    setup(), persistent_term:put(witness_api_fail, {busy, always}),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"T">>}, <<"teacher">>),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    {ok, Row} = load(<<"teacher">>, {sitting, S}),
    save(<<"teacher">>, {sitting, S}, Row#{marked_ms => maps:get(marked_ms, Row) - 86400001}),
    {200, #{sittings := [Sum]}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    ?assertNot(is_map_key(kept, Sum)),
    ?assertEqual([{drop, <<"teacher">>, S}], [E || E = {drop, _, _} <- events()]),
    persistent_term:put(witness_api_fail, false),
    ?assertMatch({410, #{code := <<"too_old">>}}, r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"teacher">>)),
    ?assertMatch({200, #{error := <<"This sitting couldn't be marked. Record it again.">>}}, r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>)).

a_marking_that_never_came_back_can_be_marked_again_test() ->
    setup(),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {ok, Row} = load(<<"u1">>, {sitting, Id}),
    save(<<"u1">>, {sitting, Id}, Row#{status => <<"marking">>, started_ms => erlang:system_time(millisecond) - 60000}),
    %% still inside its time: left alone
    ?assertMatch({200, #{status := <<"marking">>}}, r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>)),
    save(<<"u1">>, {sitting, Id}, Row#{status => <<"marking">>, started_ms => erlang:system_time(millisecond) - 2700001}),
    ?assertMatch({202, _}, r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>)),
    ?assertMatch({200, #{status := <<"marked">>}}, r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>)).

a_failure_that_is_not_meta_busy_is_not_tried_again_test() ->
    setup(), persistent_term:put(witness_api_fail, true),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>),
    ?assertEqual(1, length([1 || {marked, _, _, _} <- events()])),
    ?assertMatch({200, #{status := <<"failed">>} = V} when not is_map_key(kept, V), r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>)),
    persistent_term:put(witness_api_fail, false).

%% the examiner (Muse Wonder) is written off the request: Meta busy once is tried again, not left without questions
the_examiner_is_tried_again_when_meta_is_busy_test() ->
    setup(), persistent_term:put({witness_api_on, examiner}, true), persistent_term:put(witness_api_exbusy, 1),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>),
    ?assertEqual(1, length([1 || examiner_busy <- events()])),
    ?assertMatch({200, #{examiner := #{status := <<"ready">>, asks := [_, _]}}}, r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>)),
    persistent_term:put(witness_api_exbusy, 5),
    {201, #{id := Id2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id2, <<"mark">>], #{}, <<"u1">>),
    %% busy every time: the marking stands, the examiner says it failed (three tries, not five)
    ?assertEqual(4, length([1 || examiner_busy <- events()])),
    ?assertMatch({200, #{status := <<"marked">>, examiner := #{status := <<"failed">>}}}, r(<<"GET">>, [<<"sitting">>, Id2], #{}, <<"u1">>)),
    persistent_term:erase({witness_api_on, examiner}).

