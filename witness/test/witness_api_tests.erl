-module(witness_api_tests).
-include_lib("eunit/include/eunit.hrl").
-behaviour(witness_host).
-export([meta_key/0, put_url/4, get_url/2, drop_clip/2, save/3, load/2, list/2, spend/3, run/1, marker/0, checker/0, design/2, judger/0]).

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
marker() ->
    fun(<<"test-key">>, #{url := Url, fps := Fps}, Sitting) ->
        ev({marked, Url, Fps, Sitting}),
        case persistent_term:get(witness_api_fail, false) of
            true -> {error, boom};
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

ev(E) -> ets:insert(witness_api_t, {erlang:unique_integer([monotonic]), E}).
events() -> [E || {K, E} <- lists:sort(ets:tab2list(witness_api_t)), is_integer(K)].

setup() -> case ets:whereis(witness_api_t) of undefined -> ok; _ -> ets:delete(witness_api_t) end, ets:new(witness_api_t, [named_table, public]), persistent_term:put(witness_api_fail, false), persistent_term:erase(witness_api_result).

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
    ?assertNot(maps:is_key(explain, maps:get(mastery, Mine3))).
