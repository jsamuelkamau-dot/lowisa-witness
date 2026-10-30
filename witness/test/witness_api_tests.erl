-module(witness_api_tests).
-include_lib("eunit/include/eunit.hrl").
-behaviour(witness_host).
-export([meta_key/0, put_url/4, get_url/2, drop_clip/2, save/3, load/2, list/2, spend/3, run/1, marker/0, checker/0, design/2, judger/0,
         put_asset/4, asset_url/2, stiller/0, examiner/0, answer_judge/0, drawer/0, hearer/0, open_engine/0, open_marker/0, retry_waits/0, cropper/0, painter/0, parts_start/3, part_url/4, parts_done/3, parts_finish/4,
         reader/0, patterner/0, recommender/0, clipper/0, clip_tag/2, suggester/0, challenge_judger/0, fingerprinter/0,
         delete/2, drop_asset/2, update/3, guard/0, rechecker/0, recheck_judger/0]).
-export([events/0, setup/0]).


%% An in-memory host: rows and events in an ets table, marking run at once, a canned marker.
meta_key() -> <<"test-key">>.
put_url(Uid, Id, Mime, Size) -> ev({put, Uid, Id, Mime, Size}), {ok, <<"https://store.example.com/", Id/binary>>, #{<<"content-type">> => Mime}}.
get_url(_Uid, Id) -> {ok, <<"https://store.example.com/", Id/binary, "?signed">>}.
drop_clip(Uid, Id) -> ev({drop, Uid, Id}), ok.
save(Uid, Key, Row) -> ets:insert(witness_api_t, {{row, Uid, Key}, Row}), ok.
%% the conditional write: one change to a row at a time (two at once both land)
update(Uid, Key, F) ->
    global:trans({{witness_api_t_lock, Uid, Key}, self()}, fun() -> case F(load(Uid, Key)) of stop -> stop; Row -> save(Uid, Key, Row), {ok, Row} end end).
guard() -> fun(<<"test-key">>, Text) -> ev({guarded, Text}), case binary:match(Text, <<"UNSAFE">>) of nomatch -> {ok, 0.0001}; _ -> {unsafe, <<"not a lesson">>, 0.0001} end end.
load(Uid, Key) -> case ets:lookup(witness_api_t, {row, Uid, Key}) of [{_, R}] -> {ok, R}; [] -> none end.
list(Uid, Kind) -> [{Id, R} || {{row, U, {K, Id}}, R} <- ets:tab2list(witness_api_t), U =:= Uid, K =:= Kind].
spend(Uid, F, Usd) -> ev({spend, Uid, F, Usd}), ok.
run(Fun) -> Fun(), ok.
retry_waits() -> [0, 0].
%% a video in parts: which parts arrived is kept in the table; parts_arrived(Id, [N]) is the test's phone
parts_start(_Uid, Id, _Mime) -> ev({parts_start, Id}), {ok, <<"up-", Id/binary>>}.
part_url(_Uid, Id, U, N) -> {ok, <<"https://store.example.com/", Id/binary, "?partNumber=", (integer_to_binary(N))/binary, "&uploadId=", U/binary>>}.
parts_done(_Uid, Id, _U) -> {ok, [{N, <<"etag", (integer_to_binary(N))/binary>>, 8388608} || {{arrived, I, N}} <- ets:tab2list(witness_api_t), I =:= Id]}.
parts_finish(_Uid, Id, U, Ps) -> ev({parts_finish, Id, U, [N || {N, _, _} <- Ps]}), ok.
parts_arrived(Id, Ns) -> [ets:insert(witness_api_t, {{arrived, Id, N}}) || N <- Ns], ok.
marker() ->
    fun(<<"test-key">>, #{url := Url, fps := Fps}, Sitting) ->
        ev({marked, Url, Fps, Sitting}),
        %% a test may act while the marking is under way (31 Oct: the teacher deletes the paper meanwhile)
        case persistent_term:get(witness_api_during, none) of none -> ok; During -> During() end,
        case persistent_term:get(witness_api_fail, false) of
            true -> {error, boom};
            {unreadable, _} = U -> {error, U};
            %% Meta busy for the next N marking calls (forever when N is always)
            {busy, always} -> {error, {503, <<"busy">>}};
            {busy, N} when N > 0 -> persistent_term:put(witness_api_fail, {busy, N - 1}), {error, {503, <<"busy">>}};
            {busy, 0} -> {ok, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], cost_usd => 0.08}};
            %% a reply that ran out before its JSON, the next N calls
            {nomark, N} when N > 0 -> persistent_term:put(witness_api_fail, {nomark, N - 1}), {error, no_marking};
            {nomark, 0} -> {ok, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], cost_usd => 0.08}};
            false -> {ok, persistent_term:get(witness_api_result, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], cost_usd => 0.08})}
        end
    end.

design(<<"broke">>, _) -> {gate, 402, #{success => false, code => <<"credits_exhausted">>}};
design(Uid, Req) -> ev({design, Uid, Req}), {ok, persistent_term:get(witness_api_design_text, <<"{\"title\":\"Common factors\"}">>)}.

judger() ->
    fun(<<"test-key">>, #{n := N}, Text) -> ev({judged, N, Text}), {ok, #{understood => binary:match(Text, <<"factor">>) =/= nomatch, why => <<"w">>, next => <<"n">>}} end.

rechecker() -> fun(<<"test-key">>, Q) -> ev({recheck_written, maps:get(question, Q, none)}),
                   {ok, #{q => <<"After a 20% rise a jacket costs $60. What did it cost before?">>, answer => 50, unit => <<"$">>, working => <<"60 / 1.2">>}, 0.003} end.
recheck_judger() -> fun(<<"test-key">>, _Q, {V, W}) -> ev({recheck_judged, V, W}), {ok, #{understood => binary:match(W, <<"1.2">>) =/= nomatch, why => <<"w">>}, 0.001} end.
checker() ->
    fun(<<"test-key">>, In) ->
        ev({checked, In}),
        Passes = persistent_term:get(witness_api_check_passes, false),
        {ok, #{passes => Passes, caught => Passes, cleared => true, on_idea => true, why => <<"the checks let digit-cancelling pass">>,
               plays => #{holds => [#{lesson => 2, check => <<"Simplify 19/95">>, answered => <<"1/5">>, right => false}], knows => []},
               false_claims => [],
               problems => case Passes of true -> []; false -> [#{lesson => 3, fix => <<"use 19/95, where cancelling the 9s gives 1/5, not 1/5... make it fail">>}] end}, 0.04}
    end.

%% 31 Oct: a level is built as the phone builds it now: its self-check through the route, for the student's own
%% question, then the built event naming that check (the server uses its own verdict and outline).
build_level(S, N, Who, Passes, Lessons) ->
    persistent_term:put(witness_api_check_passes, Passes),
    Level = #{<<"title">> => <<"Common factors">>, <<"lessons">> => [#{<<"title">> => T, <<"beats">> => [<<"b">>]} || T <- Lessons]},
    {202, #{id := C}} = r(<<"POST">>, [<<"check">>], #{<<"question">> => <<"q">>, <<"working">> => <<"w">>, <<"diagnosis">> => <<"d">>,
                                                      <<"level">> => Level, <<"for">> => #{<<"sitting">> => S, <<"n">> => N}}, Who),
    r(<<"POST">>, [<<"mastery">>, S, integer_to_binary(N), <<"event">>], #{<<"event">> => <<"built">>, <<"path">> => <<"custom-topic-x">>, <<"check_id">> => C}, Who).

put_asset(Uid, Name, Bytes, Mime) -> ets:insert(witness_api_t, {{asset, Uid, Name}, {Bytes, Mime}}), ok.
delete(Uid, Key) -> ets:delete(witness_api_t, {row, Uid, Key}), ok.
drop_asset(Uid, Name) -> ets:delete(witness_api_t, {asset, Uid, Name}), ok.
asset_url(Uid, Name) -> case ets:lookup(witness_api_t, {asset, Uid, Name}) of [_] -> {ok, <<"https://store.example.com/a/", Name/binary>>}; [] -> {error, none} end.

%% The new seams stay off unless a test turns them on, so the older tests' event lists are unchanged.
on(K) -> persistent_term:get({witness_api_on, K}, false).
painter() -> fun(<<"test-key">>, Prompt) -> case on(world) of true -> ev({painted, Prompt}), {ok, <<"RIFFworld">>, <<"webp">>}; false -> {error, off} end end.
cropper() -> fun(Url, T, Box) -> case on(stills) of true -> ev({cropped, Url, T, Box}), {ok, <<255, 216, "step">>}; false -> {error, off} end end.
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

%% 28 Oct re-audit seams: each off unless its test turns it on
reader() -> fun(<<"test-key">>, Mime, Bytes) -> ev({read, Mime, Bytes}),
    {ok, #{title => <<"Algebra quiz">>, level => <<"Year 8">>, questions => [#{n => 1, text => <<"Expand 3(x + 4)">>, marks => 2}], scheme => <<"Q1: 1 mark each term">>}, 0.003} end.
patterner() -> fun(<<"test-key">>, Exam, Items) -> ev({patterns, Exam, Items}),
    {ok, #{patterns => [#{idea => <<"Cancels digits">>, students => [<<"Amara">>], questions => [3], turned_around => 0, reteach => <<"r">>}],
           tomorrow => <<"t">>, next_exam => [#{text => <<"Simplify 18/48">>, marks => 2}]}, 0.05} end.
recommender() -> fun(<<"test-key">>, Q) -> ev({recommend, maps:get(question, Q, none)}), {ok, #{recommend => <<"issue">>, why => <<"The fresh question was right.">>, missing => <<>>}, 0.004} end.
suggester() -> fun(<<"test-key">>, Q, Note) -> ev({suggest, maps:get(question, Q, none), Note}),
                   {ok, #{q => <<"Simplify 18/72">>, options => [<<"1/4">>, <<"1/2">>, <<"8/7">>], answer => 0, checks => <<"Divides by a common factor.">>}, 0.003} end.
challenge_judger() -> fun(<<"test-key">>, _Q, {Pick, Why}) -> ev({judge_challenge, Pick, Why}), {ok, #{understood => true, why => <<"Divides by 18.">>}, 0.001} end.
fingerprinter() -> fun(<<"test-key">>, Q, Text) -> ev({fingerprint, maps:get(question, Q, none), Text}),
                       {ok, #{reasoning => <<"Halves $100 both times.">>, evidence => [<<"said: half of 100 both times">>],
                              misconception => <<"takes the second percentage of the original amount">>, intervention => <<"Find the base.">>, ask => <<>>}, 0.002} end.
clipper() -> fun(Url, From, Secs) -> case on(clips) of true -> ev({clip, Url, From, Secs}), {ok, <<"mp4clip">>}; false -> {error, off} end end.
clip_tag(_Uid, _Id) -> case on(cache) of true -> {ok, <<"etag-same-video">>}; false -> {error, off} end.

open_engine() -> case on(open) of true -> #{url => <<"https://open.example.com/v1">>, key => <<"k">>, model => <<"muse-spark-open">>}; false -> undefined end.
open_marker() -> fun(#{model := M}, #{url := Url}, Sitting) -> ev({open_marked, M, Url, maps:get(engine, Sitting)}), {ok, #{questions => [#{n => 1, result => <<"mastered">>}], pauses => [], lines => [], engine => M, cost_usd => 0.07}} end.

ev(E) -> ets:insert(witness_api_t, {erlang:unique_integer([monotonic]), E}).
events() -> [E || {K, E} <- lists:sort(ets:tab2list(witness_api_t)), is_integer(K)].

setup() -> case ets:whereis(witness_api_t) of undefined -> ok; _ -> ets:delete(witness_api_t) end, ets:new(witness_api_t, [named_table, public]), persistent_term:put(witness_api_fail, false), persistent_term:erase(witness_api_result),
           [persistent_term:erase({witness_api_on, K}) || K <- [stills, examiner, open, world, clips, cache]], persistent_term:erase(witness_api_exbusy),
           persistent_term:erase(witness_api_check_passes), persistent_term:erase(witness_api_design_text),
           persistent_term:erase(witness_api_during).

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
                  #{id := SB, student := <<"Ben">>, to_master := 2}], Ss),   %% part way is in the Mastery Plan too
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
    {200, #{sittings := [_, #{id := SB, marks := 1, to_master := 2}], queue := Q2}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"t1">>),
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
    {_P, S} = released_paper(#{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    For = #{<<"sitting">> => S, <<"n">> => 3},
    ?assertMatch({400, #{code := <<"no_level">>}}, r(<<"POST">>, [<<"check">>], #{<<"for">> => For}, <<"stud">>)),
    Body = #{<<"question">> => <<"Simplify 16/64">>, <<"working">> => <<"16/64 = 1/4">>, <<"diagnosis">> => <<"Cancelled the 6s.">>,
             <<"focus">> => <<"football">>, <<"for">> => For,
             <<"level">> => #{<<"title">> => <<"Common factors">>, <<"lessons">> => [#{<<"title">> => <<"Your step, at the stadium">>, <<"beats">> => [<<"a">>, 7, <<"b">>]}]}},
    %% 31 Oct: only for the caller's own level (not another account's paper, not without one)
    ?assertMatch({403, #{code := <<"not_a_level">>}}, r(<<"POST">>, [<<"check">>], maps:remove(<<"for">>, Body), <<"stud">>)),
    ?assertMatch({403, #{code := <<"not_a_level">>}}, r(<<"POST">>, [<<"check">>], Body, <<"other">>)),
    {202, #{id := Id, status := <<"checking">>}} = r(<<"POST">>, [<<"check">>], Body, <<"stud">>),
    [{checked, In}] = [E || E = {checked, _} <- events()],
    ?assertMatch(#{diagnosis := <<"Cancelled the 6s.">>, focus := <<"football">>, level := #{lessons := [#{beats := [<<"a">>, <<"b">>]}]}}, In),
    ?assertMatch({200, #{status := <<"done">>, verdict := #{passes := false, problems := [#{lesson := 3}], plays := #{holds := [#{right := false}]}}}},
                 r(<<"GET">>, [<<"check">>, Id], #{}, <<"stud">>)),
    ?assert(lists:member({spend, <<"stud">>, <<"witness_check">>, 0.04}, events())),
    ?assertMatch({404, _}, r(<<"GET">>, [<<"check">>, Id], #{}, <<"other">>)).

%% ---------------------------------------------------------------- 28 Oct re-audit
released_paper(Result) ->
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>,
        <<"questions">> => [#{<<"n">> => 3, <<"text">> => <<"Simplify 16/64">>, <<"marks">> => 2}]}, <<"teacher">>),
    persistent_term:put(witness_api_result, Result),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amara">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    {200, _} = r(<<"POST">>, [<<"pile">>, P, <<"release">>], #{}, <<"teacher">>),
    {P, S}.

%% the submission: "a mark scheme built from the teacher's own material"
the_exam_is_read_from_the_teachers_own_file_test() ->
    setup(),
    {200, R} = r(<<"POST">>, [<<"pile">>, <<"read">>], #{<<"mime">> => <<"image/jpeg">>, <<"file">> => base64:encode(<<"jpegbytes">>)}, <<"teacher">>),
    ?assertMatch(#{title := <<"Algebra quiz">>, questions := [#{n := 1, marks := 2}], scheme := <<"Q1: 1 mark each term">>}, R),
    ?assert(lists:member({read, <<"image/jpeg">>, <<"jpegbytes">>}, events())),
    ?assert(lists:member({spend, <<"teacher">>, <<"witness_read">>, 0.003}, events())),
    ?assertMatch({400, #{code := <<"bad_type">>}}, r(<<"POST">>, [<<"pile">>, <<"read">>], #{<<"mime">> => <<"text/html">>, <<"file">> => base64:encode(<<"x">>)}, <<"teacher">>)),
    ?assertMatch({400, #{code := <<"empty">>}}, r(<<"POST">>, [<<"pile">>, <<"read">>], #{<<"mime">> => <<"application/pdf">>}, <<"teacher">>)).

%% the submission's class report and the plan's class patterns, with the turned-around count read off the papers
the_class_patterns_come_back_on_the_exam_test() ->
    setup(),
    {P, S} = released_paper(#{questions => [q(1, <<"mastered">>, 0.9), q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {202, #{patterns := #{status := <<"making">>}}} = r(<<"POST">>, [<<"pile">>, P, <<"patterns">>], #{}, <<"teacher">>),
    [{patterns, #{title := <<"Fractions">>}, [Item]}] = [E || E = {patterns, _, _} <- events()],
    ?assertMatch(#{student := <<"Amara">>, n := 3, question := <<"Simplify 16/64">>, turned_around := false}, Item),
    {200, #{pile := #{patterns := Pat}}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    ?assertMatch(#{status := <<"ready">>, papers := 1, patterns := [#{idea := <<"Cancels digits">>}], next_exam := [_]}, Pat),
    %% nothing to master, nothing to group; and the exam is the teacher's only
    ?assertMatch({404, _}, r(<<"POST">>, [<<"pile">>, P, <<"patterns">>], #{}, <<"stud">>)),
    _ = S.

%% the plan's badge review: the level's activity, the explanations (spoken ones kept for the teacher), the AI's
%% recommendation; a turned-around question then counts as mastered
the_badge_review_has_the_activity_the_recording_and_a_recommendation_test() ->
    setup(),
    {P, S} = released_paper(#{questions => [q(1, <<"mastered">>, 0.9), q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    M = fun(Who, Action, Body) -> r(<<"POST">>, [<<"mastery">>, S, <<"3">>, Action], Body, Who) end,
    {200, _} = build_level(S, 3, <<"stud">>, true, [<<"Price the boots sale">>]),
    {200, _} = M(<<"stud">>, <<"event">>, #{<<"event">> => <<"lesson">>, <<"lesson">> => #{<<"title">> => <<"Price the boots sale">>, <<"right">> => 5, <<"asked">> => 6}}),
    ?assertMatch({400, _}, M(<<"stud">>, <<"event">>, #{<<"event">> => <<"lesson">>, <<"lesson">> => #{}})),
    %% 31 Oct: only a lesson of the level the self-check played counts
    ?assertMatch({400, #{code := <<"not_in_level">>}}, M(<<"stud">>, <<"event">>, #{<<"event">> => <<"lesson">>, <<"lesson">> => #{<<"title">> => <<"Something else">>}})),
    {200, _} = M(<<"teacher">>, <<"verify">>, #{<<"lo">> => true, <<"teacher">> => true}),
    %% out loud to Lo: Voice Transcribe writes it, Spark judges it, the recording is kept for the teacher
    {200, #{mastery := StudentView}} = M(<<"stud">>, <<"explain">>, #{<<"to">> => <<"lo">>, <<"audio">> => base64:encode(<<"audio-bytes">>), <<"mime">> => <<"audio/mp4">>}),
    ?assertEqual([lo], maps:get(explained, StudentView)),
    {200, _} = M(<<"stud">>, <<"explain">>, #{<<"to">> => <<"teacher">>, <<"text">> => <<"Divide both by the same factor.">>}),
    {ok, Row} = load(<<"teacher">>, {sitting, S}),
    [Q3] = [Q || Q = #{n := 3} <- maps:get(questions, maps:get(result, Row))],
    #{explain := #{lo := Lo, teacher := Te}, activity := [Act]} = maps:get(mastery, Q3),
    ?assertMatch(#{text := <<"Because I divided by the common factor 16.">>, spoken := true, audio := <<"explain-lo-3.m4a">>, verdict := #{understood := true}}, Lo),
    ?assertNot(maps:is_key(audio, Te)),
    ?assertMatch(#{title := <<"Price the boots sale">>, right := 5, asked := 6}, Act),
    ?assertMatch([_], ets:lookup(witness_api_t, {asset, <<"teacher">>, <<S/binary, "/explain-lo-3.m4a">>})),
    %% the recommendation: the teacher's only, never the student's
    ?assertMatch({403, _}, M(<<"stud">>, <<"recommend">>, #{})),
    {200, #{mastery := #{recommendation := #{recommend := <<"issue">>, why := <<"The fresh question was right.">>}}}} = M(<<"teacher">>, <<"recommend">>, #{}),
    ?assert(lists:member({recommend, <<"Simplify 16/64">>}, events())),
    {200, #{mastery := SV}} = M(<<"stud">>, <<"ask">>, #{<<"text">> => <<"hi">>}),
    ?assertNot(maps:is_key(recommendation, SV)),
    ?assertNot(maps:is_key(activity, SV)),
    %% before the badge it is to master; after it, turned around and no longer to master
    {200, #{sittings := [#{to_master := 1, turned_around := 0}]}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    %% 29 Oct (owner): the badge replaces the level's certificate, so it waits for the level to be finished (its lessons'
    %% questions and the flashcards); the teacher's "keep going" with a note does not
    ?assertMatch({400, #{code := <<"not_completed">>}}, M(<<"teacher">>, <<"badge">>, #{<<"issue">> => true})),
    {200, _} = M(<<"stud">>, <<"event">>, #{<<"event">> => <<"completed">>}),
    {200, _} = M(<<"teacher">>, <<"badge">>, #{<<"issue">> => true, <<"note">> => <<"Proved it on paper.">>}),
    {200, #{sittings := [#{to_master := 0, turned_around := 1}]}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    {200, Rec} = r(<<"GET">>, [<<"sitting">>, S, <<"proof">>], #{}, <<"stud">>),
    ?assertMatch(#{mastered := 2, turned_around := 1}, Rec),
    [_, RQ3] = maps:get(questions, Rec),
    ?assertMatch(#{turned_around := #{note := <<"Proved it on paper.">>}}, RQ3).

%% the examiner's spoken answer is kept for the teacher; the record names it for the teacher only
the_examiners_spoken_answer_is_kept_for_the_teacher_test() ->
    setup(), persistent_term:put({witness_api_on, examiner}, true),
    {_P, S} = released_paper(#{questions => [q(1, <<"mastered">>, 0.9), q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {200, _} = r(<<"POST">>, [<<"sitting">>, S, <<"answer">>], #{<<"k">> => 1, <<"audio">> => base64:encode(<<"audio-bytes">>), <<"mime">> => <<"audio/mp4">>}, <<"stud">>),
    ?assertMatch([_], ets:lookup(witness_api_t, {asset, <<"teacher">>, <<S/binary, "/answer-1.m4a">>})),
    {200, #{examiner := [A1 | _]}} = r(<<"GET">>, [<<"sitting">>, S, <<"proof">>], #{}, <<"teacher">>),
    ?assertMatch(#{answer := #{spoken := true, audio := <<"answer-1.m4a">>}}, A1),
    {200, #{examiner := [B1 | _]}} = r(<<"GET">>, [<<"sitting">>, S, <<"proof">>], #{}, <<"stud">>),
    ?assertNot(maps:is_key(audio, maps:get(answer, B1))),
    ?assertMatch({200, #{url := _}}, r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"answer-1.m4a">>], #{}, <<"teacher">>)).

%% the research's Proof of Thinking: a six-second clip at each moment, beside its still
a_short_clip_is_kept_at_each_moment_test() ->
    setup(), persistent_term:put({witness_api_on, stills}, true), persistent_term:put({witness_api_on, clips}, true),
    {_P, S} = released_paper(#{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    ?assert(lists:member({clip, <<"https://store.example.com/", S/binary, "?signed">>, 0, 6}, events())),
    {200, #{result := #{stills := [St]}}} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{n := 3, clip := <<"clip-3.mp4">>}, St),
    {200, #{questions := [RQ]}} = r(<<"GET">>, [<<"sitting">>, S, <<"proof">>], #{}, <<"stud">>),
    ?assertMatch(#{clip := <<"clip-3.mp4">>, still := <<"still-3.jpg">>}, RQ),
    ?assertMatch({200, #{url := _}}, r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"clip-3.mp4">>], #{}, <<"stud">>)).

%% the submission's caching: the same video for the same exam is marked once
the_same_video_is_marked_once_test() ->
    setup(), persistent_term:put({witness_api_on, cache}, true),
    {201, #{id := P}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>}, <<"teacher">>),
    Mark = fun(Who) ->
        {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"pile">> => P, <<"student">> => Who}, <<"teacher">>),
        {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"teacher">>), S end,
    S1 = Mark(<<"A">>), S2 = Mark(<<"B">>),
    ?assertEqual(1, length([E || E = {marked, _, _, _} <- events()])),
    {200, #{status := <<"marked">>, result := #{questions := [_]}}} = r(<<"GET">>, [<<"sitting">>, S2], #{}, <<"teacher">>),
    ?assertEqual([0.08, 0.0], [U || {spend, _, <<"witness_sitting">>, U} <- events()]),
    _ = S1.

%% the plan: a mastery level is charged to the school's wallet (the exam's teacher), not the student
a_levels_design_calls_are_paid_by_the_exams_teacher_test() ->
    setup(),
    {_P, S} = released_paper(#{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    B = #{<<"requestId">> => <<"mob-1">>, <<"messages">> => [#{<<"role">> => <<"user">>, <<"content">> => <<"One level">>}]},
    {200, _} = r(<<"POST">>, [<<"design">>], B#{<<"for">> => #{<<"sitting">> => S, <<"n">> => 3}}, <<"stud">>),
    %% 31 Oct (judges' panel): never for someone else's paper, a question mastered already, or with no paper named
    ?assertMatch({403, #{code := <<"not_a_level">>}}, r(<<"POST">>, [<<"design">>], B#{<<"for">> => #{<<"sitting">> => S, <<"n">> => 3}}, <<"other">>)),
    ?assertMatch({403, #{code := <<"not_a_level">>}}, r(<<"POST">>, [<<"design">>], B#{<<"for">> => #{<<"sitting">> => S, <<"n">> => 1}}, <<"stud">>)),
    ?assertMatch({403, #{code := <<"not_a_level">>}}, r(<<"POST">>, [<<"design">>], B, <<"stud">>)),
    ?assertEqual([<<"teacher">>], [U || {design, U, _} <- events()]),
    %% the server's own first instruction keeps the call on this level's idea
    [{design, _, #{messages := [#{role := <<"system">>, content := Scope} | _]}}] = [E || E = {design, _, _} <- events()],
    ?assertNotEqual(nomatch, binary:match(Scope, <<"THE IDEA TO REPAIR: d">>)),
    %% a teacher out of credits: the student is told it is the teacher's, not shown their own credit wall
    {201, #{code := Code2}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Broke class">>}, <<"broke">>),
    persistent_term:put(witness_api_result, #{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {201, #{id := S2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code2, <<"student">> => <<"Amara">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S2, <<"mark">>], #{}, <<"stud">>),
    {200, _} = r(<<"POST">>, [<<"pile">>, maps:get(pile, element(2, load(<<"broke">>, {sitting, S2}))), <<"release">>], #{}, <<"broke">>),
    ?assertMatch({409, #{code := <<"teacher_credits">>}}, r(<<"POST">>, [<<"design">>], B#{<<"for">> => #{<<"sitting">> => S2, <<"n">> => 3}}, <<"stud">>)).

%% 28 Oct, live: a teacher sitting their own exam on one account was refused every student step ("That isn't yours")
a_teacher_sitting_their_own_exam_plays_both_sides_test() ->
    setup(),
    {201, #{code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>, <<"preview">> => false}, <<"teacher">>),
    persistent_term:put(witness_api_result, #{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Me">>}, <<"teacher">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"teacher">>),
    {200, _} = r(<<"POST">>, [<<"pile">>, maps:get(pile, element(2, load(<<"teacher">>, {sitting, S}))), <<"release">>], #{}, <<"teacher">>),
    M = fun(Action, Body) -> r(<<"POST">>, [<<"mastery">>, S, <<"3">>, Action], Body, <<"teacher">>) end,
    {200, #{mastery := #{status := <<"ready">>}}} = build_level(S, 3, <<"teacher">>, true, [<<"L1">>]),
    %% 31 Oct (judges' panel, confirmed): the phone's own "passes" is not the verdict; a level built naming no check waits
    {200, #{mastery := #{status := <<"held">>}}} = M(<<"event">>, #{<<"event">> => <<"built">>, <<"path">> => <<"p">>, <<"check">> => #{<<"passes">> => true}}),
    {200, #{mastery := #{status := <<"ready">>}}} = M(<<"approve">>, #{}),
    {200, #{mastery := #{thread := [#{from := student}]}}} = M(<<"ask">>, #{<<"text">> => <<"Why?">>, <<"where">> => <<"Lesson 1">>}),
    %% the teacher's own steps stay the teacher's
    {200, #{mastery := #{thread := [_, #{from := teacher}]}}} = M(<<"reply">>, #{<<"text">> => <<"Because.">>}),
    {200, _} = M(<<"verify">>, #{<<"lo">> => true}),
    %% and someone else's paper is still not theirs to act on as its student
    ?assertMatch({404, _}, r(<<"POST">>, [<<"mastery">>, S, <<"3">>, <<"ask">>], #{<<"text">> => <<"hi">>}, <<"other">>)).

design_door_passes_one_call_and_the_wall_test() ->
    setup(),
    {_P, S} = released_paper(#{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    B = #{<<"requestId">> => <<"mob-course-1-s">>, <<"reasoningEffort">> => <<"medium">>, <<"maxOutputTokens">> => 12000,
          <<"for">> => #{<<"sitting">> => S, <<"n">> => 3},
          <<"messages">> => [#{<<"role">> => <<"system">>, <<"content">> => <<"Design.">>}, #{<<"role">> => <<"user">>, <<"content">> => <<"One level">>},
                             #{<<"role">> => <<"assistant">>, <<"content">> => <<"dropped">>}]},
    ?assertMatch({200, #{success := true, text := <<"{\"title\":\"Common factors\"}">>}}, r(<<"POST">>, [<<"design">>], B, <<"stud">>)),
    [{design, <<"teacher">>, Req}] = [E || E = {design, _, _} <- events()],
    %% the server's scope first, then the level's own system and user messages (an assistant turn is dropped)
    ?assertMatch(#{request_id := <<"mob-course-1-s">>, effort := <<"medium">>, max_tokens := 12000,
                   messages := [#{role := <<"system">>}, #{role := <<"system">>, content := <<"Design.">>}, #{role := <<"user">>}]}, Req),
    ?assertMatch({400, _}, r(<<"POST">>, [<<"design">>], #{}, <<"stud">>)),
    %% an unknown effort or size falls back to the safe ones
    {200, _} = r(<<"POST">>, [<<"design">>], B#{<<"reasoningEffort">> => <<"max">>, <<"maxOutputTokens">> => 999999}, <<"stud">>),
    ?assertMatch([_, {design, _, #{effort := <<"low">>, max_tokens := 8000, reply := json}}], [E || E = {design, _, _} <- events()]),
    %% Lo's live teaching turn asks for words, not JSON, and is read for safety before it reaches the student
    {200, #{text := <<"{\"title\":\"Common factors\"}">>}} = r(<<"POST">>, [<<"design">>], B#{<<"reply">> => <<"text">>}, <<"stud">>),
    ?assertMatch(#{reply := text}, lists:last([R || {design, _, R} <- events()])),
    ?assertMatch([{guarded, _}], [E || E = {guarded, _} <- events()]),
    %% a teacher who sits their own exam pays from their own wallet, and meets the host's own wall
    {201, #{code := C2}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Own">>}, <<"broke">>),
    {201, #{id := S2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => C2, <<"student">> => <<"Me">>}, <<"broke">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S2, <<"mark">>], #{}, <<"broke">>),
    {200, _} = r(<<"POST">>, [<<"pile">>, maps:get(pile, element(2, load(<<"broke">>, {sitting, S2}))), <<"release">>], #{}, <<"broke">>),
    ?assertMatch({402, #{code := <<"credits_exhausted">>}}, r(<<"POST">>, [<<"design">>], B#{<<"for">> => #{<<"sitting">> => S2, <<"n">> => 3}}, <<"broke">>)).

%% 31 Oct (judges' panel): a turn the guard finds unsafe never reaches the student
an_unsafe_turn_is_replaced_before_it_reaches_the_student_test() ->
    setup(),
    {_P, S} = released_paper(#{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    persistent_term:put(witness_api_design_text, <<"UNSAFE words">>),
    B = #{<<"requestId">> => <<"t">>, <<"reply">> => <<"text">>, <<"for">> => #{<<"sitting">> => S, <<"n">> => 3},
          <<"messages">> => [#{<<"role">> => <<"user">>, <<"content">> => <<"say something">>}]},
    ?assertMatch({200, #{text := <<"Let's keep to your level.", _/binary>>, guarded := true}}, r(<<"POST">>, [<<"design">>], B, <<"stud">>)),
    persistent_term:erase(witness_api_design_text).

after_release_the_teacher_chooses_and_issues_the_badge_test() ->
    setup(),
    {201, #{code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>, <<"preview">> => false}, <<"teacher">>),
    persistent_term:put(witness_api_result, #{questions => [q(1, <<"mastered">>, 0.9), q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amara">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    M = fun(Who, N, Action, Body) -> r(<<"POST">>, [<<"mastery">>, S, integer_to_binary(N), Action], Body, Who) end,
    %% nothing before release; nobody else at all
    ?assertMatch({409, #{code := <<"not_released">>}}, M(<<"stud">>, 3, <<"event">>, #{<<"event">> => <<"built">>})),
    ?assertMatch({404, _}, M(<<"other">>, 3, <<"ask">>, #{<<"text">> => <<"hi">>})),
    {200, _} = r(<<"POST">>, [<<"pile">>, maps:get(pile, element(2, load(<<"teacher">>, {sitting, S}))), <<"release">>], #{}, <<"teacher">>),
    %% the student builds and plays the level; asks the teacher from a step; the teacher answers
    {200, #{mastery := Built}} = build_level(S, 3, <<"stud">>, false, [<<"Lesson A">>]),
    %% a level its self-check did not pass waits for the teacher, who sees why and lets it start
    ?assertMatch(#{status := <<"held">>, path := <<"custom-topic-x">>}, Built),
    {200, #{mastery := #{status := <<"ready">>}}} = M(<<"teacher">>, 3, <<"approve">>, #{}),
    ?assertNot(maps:is_key(check, Built)),                                 %% the self-check is the teacher's to read
    {200, #{mastery := #{thread := [#{where := <<"Lesson 2, step 3: I typed 1/2">>}]}}} =
        M(<<"stud">>, 3, <<"ask">>, #{<<"text">> => <<"Why does 12/24 not work?">>, <<"where">> => <<"Lesson 2, step 3: I typed 1/2">>}),
    {200, #{mastery := #{thread := [_, #{from := teacher}]}}} = M(<<"teacher">>, 3, <<"reply">>, #{<<"text">> => <<"Try dividing both by 12.">>}),
    ?assertMatch({400, #{code := <<"lessons_left">>}}, M(<<"stud">>, 3, <<"event">>, #{<<"event">> => <<"completed">>})),
    {200, _} = M(<<"stud">>, 3, <<"event">>, #{<<"event">> => <<"lesson">>, <<"lesson">> => #{<<"title">> => <<"Lesson A">>}}),
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
    ?assertMatch(#{mastery := #{check := #{passes := false, problems := [<<"lesson 3: use 19/95", _/binary>>], plays := #{holds := [_]}}}}, Q3),
    %% the badge is the teacher's alone, and only for a question that was to master
    ?assertMatch({403, _}, M(<<"stud">>, 3, <<"badge">>, #{<<"issue">> => true})),
    ?assertMatch({400, #{code := <<"not_to_master">>}}, M(<<"teacher">>, 1, <<"badge">>, #{<<"issue">> => true})),
    {200, #{mastery := #{status := <<"badge">>, badge := #{issued := true, note := <<"Turned around">>}}}} = M(<<"teacher">>, 3, <<"badge">>, #{<<"issue">> => true, <<"note">> => <<"Turned around">>}),
    %% the student's own list shows the badge and the thread, not the verdict
    {200, #{papers := [#{result := #{questions := [_, Mine3]}}]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>),
    ?assertMatch(#{mastery := #{status := <<"badge">>, badge := #{issued := true}, thread := [_, _]}}, Mine3),
    ?assertNot(maps:is_key(explain, maps:get(mastery, Mine3))),
    ?assertEqual(#{status => <<"marked">>}, maps:get(fresh, maps:get(mastery, Mine3))),   %% the fresh marks are the teacher's
    %% 28 Oct audit: the badge is on the student's profile too, naming the question and what was turned around
    {200, #{badges := [Bd]}} = r(<<"GET">>, [<<"badges">>], #{}, <<"stud">>),
    ?assertMatch(#{exam := <<"Fractions">>, note := <<"Turned around">>, fixed := _, turned_at := _, wrong_at := _}, Bd),
    ?assert(maps:get(turned_at, Bd) >= maps:get(wrong_at, Bd)),
    ?assertMatch({200, #{badges := []}}, r(<<"GET">>, [<<"badges">>], #{}, <<"other">>)).

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
    ?assertMatch({200, #{status := <<"failed">>, unreadable := <<"A picture of a house; no paper.">>, error := <<"The paper couldn't be seen", _/binary>>}},
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
    ?assertMatch(#{status := <<"failed">>, kept := true, error := <<"The marking service couldn't be reached", _/binary>>}, V),
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

%% 28 Oct re-audit, live: 1 in 12 benchmark papers came back with no JSON (Spark's thinking used the whole budget); it
%% failed the sitting and deleted the video. It is read again now.
a_reply_without_its_marking_is_read_again_test() ->
    setup(), persistent_term:put(witness_api_fail, {nomark, 1}),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>),
    ?assertEqual(2, length([1 || {marked, _, _, _} <- events()])),
    ?assertMatch({200, #{status := <<"marked">>}}, r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>)),
    persistent_term:put(witness_api_fail, false).

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

%% 28 Oct, the demo record named Muse Voice Transcribe on a paper where nothing was said out loud
the_record_names_only_the_models_that_read_this_paper_test() ->
    Pile = #{title => <<"T">>, questions => []},
    Plain = #{result => #{questions => [#{n => 1, result => <<"mastered">>}], lines => []}},
    ?assertEqual([<<"Muse Spark (the marking)">>], maps:get(read_by, witness_proof:record(<<"s">>, Plain, Pile, teacher))),
    Full = #{result => #{questions => [#{n => 1, result => <<"not_yet">>, drawn => #{status => <<"done">>, asset => <<"a">>, lines => [], changed => 1}}],
                         lines => [#{id => 1}]},
             examiner => #{asks => [#{k => 1, n => 1, ask => <<"Why?">>, answer => #{text => <<"Because">>, spoken => true}}]}},
    ?assertEqual([<<"SAM 3.1 (the ink, line by line)">>, <<"Muse Spark (the marking)">>, <<"Muse Wonder (the examiner)">>,
                  <<"Muse Voice Transcribe (spoken answers)">>, <<"Muse Image (the corrected step)">>],
                 maps:get(read_by, witness_proof:record(<<"s">>, Full, Pile, teacher))),
    Open = #{result => #{questions => [], lines => [], engine => <<"muse-spark-open">>}},
    ?assertEqual([<<"Muse Spark Open on open weights (the marking)">>], maps:get(read_by, witness_proof:record(<<"s">>, Open, Pile, student))).

%% 28 Oct audit (the plan's step 4): the teacher may look at each level before it reaches the student
the_teacher_can_look_at_each_level_first_test() ->
    setup(),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>, <<"preview">> => true}, <<"teacher">>),
    ?assertMatch({200, #{pile := #{preview := true}}}, r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>)),
    persistent_term:put(witness_api_result, #{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => <<"Amara">>}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    {200, _} = r(<<"POST">>, [<<"pile">>, P, <<"release">>], #{}, <<"teacher">>),
    M = fun(Who, Action, Body) -> r(<<"POST">>, [<<"mastery">>, S, <<"3">>, Action], Body, Who) end,
    Level = #{<<"title">> => <<"Cancel Factors Right">>, <<"lessons">> => [#{<<"title">> => <<"Price the boots sale">>, <<"beats">> => [<<"Half price: 32/64">>]}]},
    _ = Level,
    {200, #{mastery := #{status := <<"held">>}}} = build_level(S, 3, <<"stud">>, true, [<<"Price the boots sale">>]),
    %% the teacher reads it (the outline the self-check played); the student cannot approve it; the teacher lets them start
    {200, #{result := #{questions := [#{mastery := #{level := #{title := <<"Common factors">>, lessons := [#{title := <<"Price the boots sale">>}]}}}]}}} =
        r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch({403, _}, M(<<"stud">>, <<"approve">>, #{})),
    {200, #{mastery := #{status := <<"ready">>}}} = M(<<"teacher">>, <<"approve">>, #{}),
    ?assertMatch({400, #{code := <<"not_held">>}}, M(<<"teacher">>, <<"approve">>, #{})),
    %% 30 Oct (judges' panel): the default is that the teacher looks first; turned off, a level that passed its
    %% self-check reaches the student at once, and one that failed it (or was never checked) still waits
    {201, #{id := Pdef}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Default">>}, <<"teacher">>),
    ?assertMatch({200, #{pile := #{preview := true}}}, r(<<"GET">>, [<<"pile">>, Pdef], #{}, <<"teacher">>)),
    {201, #{code := Code2}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Other">>, <<"preview">> => false}, <<"teacher">>),
    {201, #{id := S2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code2}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S2, <<"mark">>], #{}, <<"stud">>),
    {200, _} = r(<<"POST">>, [<<"pile">>, maps:get(pile, element(2, load(<<"teacher">>, {sitting, S2}))), <<"release">>], #{}, <<"teacher">>),
    ?assertMatch({200, #{mastery := #{status := <<"held">>}}},
                 r(<<"POST">>, [<<"mastery">>, S2, <<"3">>, <<"event">>], #{<<"event">> => <<"built">>, <<"path">> => <<"p2">>}, <<"stud">>)),
    ?assertMatch({200, #{mastery := #{status := <<"held">>}}},
                 r(<<"POST">>, [<<"mastery">>, S2, <<"3">>, <<"event">>], #{<<"event">> => <<"built">>, <<"path">> => <<"p2">>,
                                                                         <<"check">> => #{<<"passes">> => false, <<"problems">> => [<<"lesson 2 never shows the base">>]}}, <<"stud">>)),
    %% the phone's own word that it passed is not enough (31 Oct): the server's verdict is
    ?assertMatch({200, #{mastery := #{status := <<"held">>}}},
                 r(<<"POST">>, [<<"mastery">>, S2, <<"3">>, <<"event">>], #{<<"event">> => <<"built">>, <<"path">> => <<"p2">>,
                                                                         <<"check">> => #{<<"passes">> => true}}, <<"stud">>)),
    ?assertMatch({200, #{mastery := #{status := <<"held">>}}}, build_level(S2, 3, <<"stud">>, false, [<<"A">>])),
    ?assertMatch({200, #{mastery := #{status := <<"ready">>}}}, build_level(S2, 3, <<"stud">>, true, [<<"A">>])),
    %% a check for another question, or another student's, is not this level's
    {202, #{id := Other}} = r(<<"POST">>, [<<"check">>], #{<<"level">> => #{<<"title">> => <<"x">>, <<"lessons">> => [#{<<"title">> => <<"y">>}]},
                                                           <<"for">> => #{<<"sitting">> => S, <<"n">> => 3}}, <<"stud">>),
    ?assertMatch({200, #{mastery := #{status := <<"held">>}}},
                 r(<<"POST">>, [<<"mastery">>, S2, <<"3">>, <<"event">>], #{<<"event">> => <<"built">>, <<"path">> => <<"p2">>, <<"check_id">> => Other}, <<"stud">>)).

%% 30 Oct (judges' panel: "completed" was the phone's word alone): the level counts as completed only once each of its
%% lessons was seen finished
a_level_is_completed_only_after_its_lessons_test() ->
    setup(),
    {_P, S} = released_paper(#{questions => [q(3, <<"not_yet">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    M = fun(Body) -> r(<<"POST">>, [<<"mastery">>, S, <<"3">>, <<"event">>], Body, <<"stud">>) end,
    {200, _} = build_level(S, 3, <<"stud">>, true, [<<"One">>, <<"Two">>]),
    {200, _} = M(#{<<"event">> => <<"lesson">>, <<"lesson">> => #{<<"title">> => <<"One">>, <<"right">> => 6, <<"asked">> => 6}}),
    ?assertMatch({400, #{code := <<"lessons_left">>}}, M(#{<<"event">> => <<"completed">>})),
    {200, _} = M(#{<<"event">> => <<"lesson">>, <<"lesson">> => #{<<"title">> => <<"Two">>, <<"right">> => 5, <<"asked">> => 6}}),
    ?assertMatch({200, #{mastery := #{status := <<"completed">>}}}, M(#{<<"event">> => <<"completed">>})).

%% 28 Oct audit: the plan's first look opens on the student's own handwriting; it is cut from the frame by SAM's box
the_students_own_step_is_cut_from_the_page_test() ->
    setup(), persistent_term:put({witness_api_on, stills}, true),
    Box = #{x1 => 100, y1 => 200, x2 => 400, y2 => 240, w => 720, h => 1280},
    persistent_term:put(witness_api_result, #{questions => [#{n => 3, result => <<"right_answer_wrong_thinking">>, moment_s => 35, confidence => 0.9,
        marks => 0, out_of => 2, steps => [#{t => 33, wrote => <<"16/64">>, box => Box, line => 7}, #{t => 38, wrote => <<"= 1/4">>}]}], pauses => [],
        lines => [#{id => 7, start_s => 36.0, end_s => 41.0, box => Box}], cost_usd => 0.0}),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10}, <<"u1">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"u1">>),
    %% cut once SAM saw the line stop growing (41 s), not at Spark's step time: the ink is there
    ?assertMatch([{cropped, _, 42.0, Box}], [E || E = {cropped, _, _, _} <- events()]),
    {200, #{result := #{stills := [#{n := 3, asset := <<"still-3.jpg">>, step := <<"step-3.jpg">>}]}}} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"u1">>),
    ?assertMatch({200, #{url := _}}, r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"step-3.jpg">>], #{}, <<"u1">>)),
    persistent_term:erase({witness_api_on, stills}).

%% 28 Oct audit (the plan: Muse Image art for the world): a built level gets one picture of its real-world place
a_built_level_gets_a_picture_of_its_world_test() ->
    setup(), persistent_term:put({witness_api_on, world}, true),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Fractions">>}, <<"teacher">>),
    persistent_term:put(witness_api_result, #{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code}, <<"stud">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"stud">>),
    {200, _} = r(<<"POST">>, [<<"pile">>, P, <<"release">>], #{}, <<"teacher">>),
    Level = #{<<"title">> => <<"Cancel Factors Right">>, <<"lessons">> => [#{<<"title">> => <<"The sports shop sale">>, <<"beats">> => [<<"Boots at 16/64 off">>]}]},
    _ = Level,
    {200, _} = build_level(S, 3, <<"stud">>, true, [<<"The sports shop sale">>]),
    [{painted, Prompt}] = [E || E = {painted, _} <- events()],
    [?assertNotEqual(nomatch, binary:match(Prompt, W)) || W <- [<<"The sports shop sale">>, <<"No words, letters or numbers">>]],
    {200, #{papers := [#{result := #{questions := [#{mastery := #{world := <<"world-3.webp">>}}]}}]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>),
    ?assert(lists:member({spend, <<"teacher">>, <<"witness_world">>, 0.01}, events())),
    %% built again: drawn once only
    {200, _} = build_level(S, 3, <<"stud">>, true, [<<"The sports shop sale">>]),
    ?assertEqual(1, length([E || E = {painted, _} <- events()])),
    ?assertMatch({200, #{url := _}}, r(<<"GET">>, [<<"sitting">>, S, <<"asset">>, <<"world-3.webp">>], #{}, <<"stud">>)).

%% 28 Oct audit (the plan: upload in parts, resumable, so a bad connection loses nothing)
a_long_video_goes_up_in_parts_and_resumes_test() ->
    setup(),
    Size = 3 * 8388608 + 1000,
    %% an old phone (no parts asked) still gets one link
    ?assertMatch({201, #{put := _}}, r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => Size}, <<"u1">>)),
    %% one part's worth goes up whole
    ?assertMatch({201, #{put := _}}, r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 1000, <<"parts">> => true}, <<"u1">>)),
    {201, #{id := Id, parts := #{size := 8388608, count := 4, urls := Urls}} = Started} =
        r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => Size, <<"parts">> => true}, <<"u1">>),
    ?assertNot(maps:is_key(put, Started)),
    ?assertEqual([1, 2, 3, 4], [N || #{n := N} <- Urls]),
    %% the connection drops after two parts: nothing is marked, and the phone learns what is missing
    ok = parts_arrived(Id, [1, 2]),
    ?assertMatch({409, #{code := <<"parts_missing">>, missing := [3, 4]}}, r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>)),
    {200, #{done := [1, 2], urls := Rest}} = r(<<"GET">>, [<<"sitting">>, Id, <<"parts">>], #{}, <<"u1">>),
    ?assertEqual([3, 4], [N || #{n := N} <- Rest]),
    %% the rest arrive: joined, then marked
    ok = parts_arrived(Id, [3, 4]),
    ?assertMatch({202, _}, r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"u1">>)),
    ?assert(lists:member({parts_finish, Id, <<"up-", Id/binary>>, [1, 2, 3, 4]}, events())),
    ?assertMatch({200, #{status := <<"marked">>}}, r(<<"GET">>, [<<"sitting">>, Id], #{}, <<"u1">>)),
    %% a video in parts is not dropped as a lapsed upload after 20 minutes
    {201, #{id := Id2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => Size, <<"parts">> => true}, <<"u1">>),
    {ok, Row} = load(<<"u1">>, {sitting, Id2}),
    save(<<"u1">>, {sitting, Id2}, Row#{created_ms => maps:get(created_ms, Row) - 1300000}),
    ?assertMatch({200, #{status := <<"uploading">>}}, r(<<"GET">>, [<<"sitting">>, Id2], #{}, <<"u1">>)).


%% 30 Oct (owner): after the level, the teacher sends a new challenge (the same idea, a new situation) and the student
%% answers it on the phone with a reason; Spark drafts it for the teacher and reads the reason, for the teacher only
the_teacher_sends_a_new_challenge_and_the_student_answers_it_test() ->
    setup(),
    {_P, S} = released_paper(#{questions => [q(1, <<"mastered">>, 0.9), q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    M = fun(Who, Action, Body) -> r(<<"POST">>, [<<"mastery">>, S, <<"3">>, Action], Body, Who) end,
    %% nothing set yet: the student cannot answer
    ?assertMatch({400, #{code := <<"not_asked">>}}, M(<<"stud">>, <<"challenge_answer">>, #{<<"pick">> => 0, <<"why">> => <<"x">>})),
    %% Spark drafts one for the teacher; nothing is kept until the teacher sends it
    {200, #{suggestion := #{q := <<"Simplify 18/72">>, answer := 0}, mastery := TV0}} = M(<<"teacher">>, <<"challenge_suggest">>, #{<<"note">> => <<"bigger numbers">>}),
    ?assertNot(maps:is_key(challenge, TV0)),
    ?assert(lists:member({suggest, <<"Simplify 16/64">>, <<"bigger numbers">>}, events())),
    ?assert(lists:member({spend, <<"teacher">>, <<"witness_challenge">>, 0.003}, events())),
    ?assertMatch({403, _}, M(<<"stud">>, <<"challenge_suggest">>, #{})),
    ?assertMatch({403, _}, M(<<"stud">>, <<"challenge">>, #{<<"q">> => <<"x">>, <<"options">> => [<<"a">>, <<"b">>], <<"answer">> => 0})),
    %% a challenge needs a question, 2 to 5 different options and the right one
    ?assertMatch({400, #{code := <<"bad_challenge">>}}, M(<<"teacher">>, <<"challenge">>, #{<<"q">> => <<"x">>, <<"options">> => [<<"a">>], <<"answer">> => 0})),
    ?assertMatch({400, #{code := <<"bad_challenge">>}}, M(<<"teacher">>, <<"challenge">>, #{<<"q">> => <<"x">>, <<"options">> => [<<"a">>, <<"A">>], <<"answer">> => 0})),
    ?assertMatch({400, #{code := <<"bad_challenge">>}}, M(<<"teacher">>, <<"challenge">>, #{<<"q">> => <<"x">>, <<"options">> => [<<"a">>, <<"b">>], <<"answer">> => 2})),
    ?assertMatch({400, #{code := <<"empty">>}}, M(<<"teacher">>, <<"challenge">>, #{<<"q">> => <<" ">>, <<"options">> => [<<"a">>, <<"b">>], <<"answer">> => 0})),
    Water = #{<<"q">> => <<"A town starts with 1,000 litres of stored water. The supply falls by 30%, then rises by 30%. How much water is there?">>,
              <<"options">> => [<<"910 litres">>, <<"1,000 litres">>, <<"1,090 litres">>], <<"answer">> => 0},
    {200, _} = M(<<"teacher">>, <<"challenge">>, Water),
    %% the student sees the question and the options, never which is right before answering
    {200, #{mastery := #{challenge := SC}}} = M(<<"stud">>, <<"ask">>, #{<<"text">> => <<"hi">>}),
    ?assertMatch(#{options := [<<"910 litres">>, _, _]}, SC),
    ?assertNot(maps:is_key(answer, SC)),
    ?assertMatch({400, #{code := <<"bad_pick">>}}, M(<<"stud">>, <<"challenge_answer">>, #{<<"pick">> => 3, <<"why">> => <<"x">>})),
    ?assertMatch({400, #{code := <<"empty">>}}, M(<<"stud">>, <<"challenge_answer">>, #{<<"pick">> => 0, <<"why">> => <<"">>})),
    ?assertNot(lists:keymember(judge_challenge, 1, events())),                  %% a refused answer never reaches a model
    Why = <<"30% of 1,000 is 300, so 700. Then 30% of 700 is only 210, so 910.">>,
    {200, #{mastery := #{challenge := #{reply := Rp}} = SV}} = M(<<"stud">>, <<"challenge_answer">>, #{<<"pick">> => 0, <<"why">> => Why}),
    ?assertEqual(#{pick => 0, right => true, answer => 0}, Rp),
    ?assertNot(maps:is_key(recommendation, SV)),
    ?assert(lists:member({judge_challenge, 0, Why}, events())),
    ?assertMatch({400, #{code := <<"answered">>}}, M(<<"stud">>, <<"challenge_answer">>, #{<<"pick">> => 1, <<"why">> => <<"again">>})),
    %% the teacher reads the answer, the reason and Spark's reading of it
    {ok, Row} = load(<<"teacher">>, {sitting, S}),
    [Q3] = [Q || Q = #{n := 3} <- maps:get(questions, maps:get(result, Row))],
    ?assertMatch(#{challenge := #{reply := #{pick := 0, right := true, why := Why, verdict := #{understood := true}}}}, maps:get(mastery, Q3)),
    %% and Spark's badge recommendation is given it
    ?assertNotEqual(nomatch, binary:match(witness_recommend:prompt(Q3), <<"answered right, saying">>)),
    %% a new challenge replaces the last; the last is kept
    {200, _} = M(<<"teacher">>, <<"challenge">>, Water#{<<"q">> => <<"A shop raises a price by 20%, then cuts it by 20%. What happens?">>}),
    {ok, Row2} = load(<<"teacher">>, {sitting, S}),
    [Q3b] = [Q || Q = #{n := 3} <- maps:get(questions, maps:get(result, Row2))],
    ?assertMatch(#{challenge := #{q := <<"A shop raises", _/binary>>}, past := [#{reply := _}]}, maps:get(mastery, Q3b)),
    %% a mastered question has nothing to challenge
    ?assertMatch({400, #{code := <<"not_to_master">>}}, r(<<"POST">>, [<<"mastery">>, S, <<"1">>, <<"challenge">>], Water, <<"teacher">>)).

%% 30 Oct (owner): the Misconception Fingerprint. When the paper was not enough evidence, Lo asks one diagnostic
%% question in the Mastery Plan; the answer is read by Spark with the ink and completes the fingerprint
lo_asks_when_the_paper_is_not_enough_evidence_test() ->
    setup(),
    Fp = #{reasoning => <<"An intuition with no numbers.">>, evidence => [<<"Half up, half down. Same price.">>], misconception => <<>>,
           intervention => <<>>, ask => <<"You wrote half up, half down. Half of what, each time?">>},
    {_P, S} = released_paper(#{questions => [(q(3, <<"not_yet">>, 0.9))#{fingerprint => Fp}], pauses => [], lines => [], cost_usd => 0.0}),
    M = fun(Who, Body) -> r(<<"POST">>, [<<"mastery">>, S, <<"3">>, <<"diagnose">>], Body, Who) end,
    ?assertMatch({400, #{code := <<"empty">>}}, M(<<"stud">>, #{<<"text">> => <<" ">>})),
    ?assertNot(lists:keymember(fingerprint, 1, events())),
    ?assertMatch({403, _}, M(<<"teacher">>, #{<<"text">> => <<"x">>})),
    {200, #{fingerprint := F}} = M(<<"stud">>, #{<<"text">> => <<"Half of 100, both times.">>}),
    ?assertMatch(#{misconception := <<"takes the second percentage of the original amount">>, ask := <<>>,
                   said := [#{ask := <<"You wrote half up, half down. Half of what, each time?">>, text := <<"Half of 100, both times.">>}]}, F),
    ?assert(lists:member({fingerprint, <<"Simplify 16/64">>, <<"Half of 100, both times.">>}, events())),
    ?assert(lists:member({spend, <<"teacher">>, <<"witness_fingerprint">>, 0.002}, events())),
    %% the teacher's paper carries it; Lo asks no more
    {ok, Row} = load(<<"teacher">>, {sitting, S}),
    [Q3] = [Q || Q = #{n := 3} <- maps:get(questions, maps:get(result, Row))],
    ?assertMatch(#{fingerprint := #{misconception := <<"takes the second percentage", _/binary>>}}, Q3),
    ?assertMatch({400, #{code := <<"not_asked">>}}, M(<<"stud">>, #{<<"text">> => <<"again">>})).

%% the answer to Lo out loud: Voice Transcribe writes it down, and the recording is kept beside the paper for the
%% teacher, as the phone tells the student it is
a_spoken_answer_to_lo_is_kept_for_the_teacher_test() ->
    setup(),
    Fp = #{reasoning => <<"r">>, evidence => [<<"Half up, half down.">>], misconception => <<>>, intervention => <<>>, ask => <<"Half of what?">>},
    {_P, S} = released_paper(#{questions => [(q(3, <<"not_yet">>, 0.9))#{fingerprint => Fp}], pauses => [], lines => [], cost_usd => 0.0}),
    {200, #{fingerprint := #{said := [Said]}}} =
        r(<<"POST">>, [<<"mastery">>, S, <<"3">>, <<"diagnose">>], #{<<"audio">> => base64:encode(<<"audio-bytes">>), <<"mime">> => <<"audio/mp4">>}, <<"stud">>),
    ?assertMatch(#{text := <<"Because I divided by the common factor 16.">>, audio := <<"diagnose-3-1.m4a">>}, Said),
    ?assertMatch([_], ets:lookup(witness_api_t, {asset, <<"teacher">>, <<S/binary, "/diagnose-3-1.m4a">>})).

%% 30 Oct (judges' panel): the teacher deletes a paper, then a whole exam; nothing of it is left: its row, its pages and
%% recordings, the student's pointer, the join code
the_teacher_deletes_a_paper_and_an_exam_test() ->
    setup(),
    Fp = #{reasoning => <<"r">>, evidence => [<<"Half up, half down.">>], misconception => <<>>, intervention => <<>>, ask => <<"Half of what?">>},
    {P, S} = released_paper(#{questions => [(q(3, <<"not_yet">>, 0.9))#{fingerprint => Fp}], pauses => [], lines => [], cost_usd => 0.0}),
    {200, _} = r(<<"POST">>, [<<"mastery">>, S, <<"3">>, <<"diagnose">>], #{<<"audio">> => base64:encode(<<"audio-bytes">>), <<"mime">> => <<"audio/mp4">>}, <<"stud">>),
    ?assertMatch([_], ets:lookup(witness_api_t, {asset, <<"teacher">>, <<S/binary, "/diagnose-3-1.m4a">>})),
    ?assertMatch({ok, _}, load(<<"stud">>, {mine, S})),
    ?assertMatch({404, _}, r(<<"POST">>, [<<"sitting">>, S, <<"delete">>], #{}, <<"stud">>)),
    {200, #{deleted := 1}} = r(<<"POST">>, [<<"sitting">>, S, <<"delete">>], #{}, <<"teacher">>),
    ?assertEqual(none, load(<<"teacher">>, {sitting, S})),
    ?assertEqual(none, load(<<"stud">>, {mine, S})),
    ?assertEqual([], ets:lookup(witness_api_t, {asset, <<"teacher">>, <<S/binary, "/diagnose-3-1.m4a">>})),
    ?assertMatch({200, #{sittings := []}}, r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>)),
    {ok, #{code := Code}} = load(<<"teacher">>, {pile, P}),
    {200, _} = r(<<"POST">>, [<<"pile">>, P, <<"delete">>], #{}, <<"teacher">>),
    ?assertEqual(none, load(<<"teacher">>, {pile, P})),
    ?assertEqual(none, load(<<"witness-codes">>, {code, Code})).

%% the names of a paper's kept files come from its row
a_papers_files_are_named_in_its_row_test() ->
    Row = #{files => [#{n => 1, file => <<"page-1.jpg">>}], result => #{stills => [#{asset => <<"still-4.jpg">>}],
            questions => [#{drawn => #{asset => <<"drawn-3.webp">>}, fingerprint => #{said => [#{audio => <<"diagnose-3-1.m4a">>, text => <<"I halved it.">>}]}}]}},
    ?assertEqual([<<"diagnose-3-1.m4a">>, <<"drawn-3.webp">>, <<"page-1.jpg">>, <<"still-4.jpg">>], witness_api:files_of(Row)).

%% a level the teacher pays for has a ceiling on its design calls; the student's own calls have none here
a_teacher_paid_level_has_a_ceiling_on_its_calls_test() ->
    setup(),
    {_P, S} = released_paper(#{questions => [q(3, <<"not_yet">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    Key = {mark_cache, <<"calls:", S/binary, ":3:stud">>},
    ok = save(<<"teacher">>, Key, #{calls => 150, sitting => S}),
    Body = #{<<"messages">> => [#{<<"role">> => <<"user">>, <<"content">> => <<"write lesson 1">>}], <<"for">> => #{<<"sitting">> => S, <<"n">> => 3}},
    ?assertMatch({429, #{code := <<"level_budget">>}}, r(<<"POST">>, [<<"design">>], Body, <<"stud">>)),
    ok = save(<<"teacher">>, Key, #{calls => 3, sitting => S}),
    ?assertMatch({200, #{success := true}}, r(<<"POST">>, [<<"design">>], Body, <<"stud">>)),
    ?assertMatch({ok, #{calls := 4}}, load(<<"teacher">>, Key)),
    %% two calls at once are both counted (31 Oct: the count was read, then written)
    Me = self(),
    [spawn(fun() -> Me ! {done, r(<<"POST">>, [<<"design">>], Body, <<"stud">>)} end) || _ <- lists:seq(1, 10)],
    [receive {done, _} -> ok end || _ <- lists:seq(1, 10)],
    ?assertMatch({ok, #{calls := 14}}, load(<<"teacher">>, Key)).

%% a teacher who sat their own exam (one account, both sides): deleting the paper takes their own pointer too
deleting_a_paper_one_account_sat_takes_its_pointer_test() ->
    setup(),
    {201, #{code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Self">>}, <<"teacher">>),
    persistent_term:put(witness_api_result, #{questions => [q(3, <<"not_yet">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code}, <<"teacher">>),
    {ok, Row} = load(<<"teacher">>, {sitting, S}),
    ok = save(<<"teacher">>, {sitting, S}, Row#{student_uid => <<"teacher">>}),
    ok = save(<<"teacher">>, {mine, S}, #{owner => <<"teacher">>}),
    {200, _} = r(<<"POST">>, [<<"sitting">>, S, <<"delete">>], #{}, <<"teacher">>),
    ?assertEqual(none, load(<<"teacher">>, {mine, S})).

%% ---------------------------------------------------------------- 31 Oct, the 12-judge panel

%% the re-check: "Turned around" starts a clock; once due (or sent now by the teacher) Muse Spark writes a problem of a
%% different structure, answered with the student's own number and working; the number is checked by code
the_badge_starts_a_recheck_a_week_later_test() ->
    setup(),
    {P, S} = released_paper(#{questions => [q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    M = fun(Who, Action, Body) -> r(<<"POST">>, [<<"mastery">>, S, <<"3">>, Action], Body, Who) end,
    {200, _} = build_level(S, 3, <<"stud">>, true, [<<"L1">>]),
    {200, _} = M(<<"stud">>, <<"event">>, #{<<"event">> => <<"lesson">>, <<"lesson">> => #{<<"title">> => <<"L1">>}}),
    {200, _} = M(<<"stud">>, <<"event">>, #{<<"event">> => <<"completed">>}),
    {200, #{mastery := #{recheck := #{status := <<"scheduled">>, due_ms := Due}}}} = M(<<"teacher">>, <<"badge">>, #{<<"issue">> => true}),
    ?assert(Due > erlang:system_time(millisecond) + 6 * 86400000),
    %% not due yet: nothing is written
    ?assertMatch({400, #{code := <<"not_due">>}}, M(<<"stud">>, <<"recheck_open">>, #{})),
    ?assertMatch({403, _}, M(<<"stud">>, <<"recheck_now">>, #{})),
    {200, _} = M(<<"teacher">>, <<"recheck_now">>, #{}),
    {200, #{mastery := #{recheck := Open}}} = M(<<"stud">>, <<"recheck_open">>, #{}),
    ?assertMatch(#{status := <<"open">>, q := <<"After a 20% rise", _/binary>>, unit := <<"$">>}, Open),
    ?assertNot(maps:is_key(answer, Open)),                                   %% the answer is never sent before they answer
    ?assertMatch({400, #{code := <<"bad_value">>}}, M(<<"stud">>, <<"recheck_answer">>, #{<<"value">> => <<"fifty">>, <<"working">> => <<"w">>})),
    ?assertMatch({400, #{code := <<"empty">>}}, M(<<"stud">>, <<"recheck_answer">>, #{<<"value">> => <<"$50">>})),
    {200, #{mastery := #{recheck := #{status := <<"passed">>, reply := #{right := true, answer := 50}, days := 0}}}} =
        M(<<"stud">>, <<"recheck_answer">>, #{<<"value">> => <<"$50.00">>, <<"working">> => <<"60 / 1.2 = 50">>}),
    ?assert(lists:member({recheck_judged, 50.0, <<"60 / 1.2 = 50">>}, events())),
    ?assertMatch({400, #{code := <<"answered">>}}, M(<<"stud">>, <<"recheck_answer">>, #{<<"value">> => 50, <<"working">> => <<"again">>})),
    {200, Measured} = r(<<"GET">>, [<<"pile">>, P, <<"measure">>], #{}, <<"teacher">>),
    ?assertMatch(#{rechecks := #{passed := 1}}, Measured).

%% one teacher action on many questions: a challenge to a group, the badge after one review, accepting confident marks
the_teacher_acts_on_a_whole_group_at_once_test() ->
    setup(),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Class">>, <<"preview">> => false}, <<"teacher">>),
    persistent_term:put(witness_api_result, #{questions => [q(1, <<"mastered">>, 0.95), q(3, <<"right_answer_wrong_thinking">>, 0.9)], pauses => [], lines => [], cost_usd => 0.0}),
    Ss = [begin {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"code">> => Code, <<"student">> => W}, W),
                {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, W), S end || W <- [<<"s1">>, <<"s2">>, <<"s3">>]],
    {200, #{done := 3}} = r(<<"POST">>, [<<"pile">>, P, <<"bulk">>], #{<<"action">> => <<"accept">>, <<"items">> => [#{<<"sitting">> => S, <<"n">> => 1} || S <- Ss]}, <<"teacher">>),
    {200, #{queue := Q}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    ?assertEqual([3, 3, 3], [maps:get(n, I) || I <- Q]),
    {200, _} = r(<<"POST">>, [<<"pile">>, P, <<"release">>], #{}, <<"teacher">>),
    Ch = #{<<"q">> => <<"Simplify 18/72">>, <<"options">> => [<<"1/4">>, <<"1/2">>, <<"8/7">>, <<"1/8">>], <<"answer">> => 0},
    {200, #{done := 3}} = r(<<"POST">>, [<<"pile">>, P, <<"bulk">>], #{<<"action">> => <<"challenge">>, <<"challenge">> => Ch,
                                                                     <<"items">> => [#{<<"sitting">> => S, <<"n">> => 3} || S <- Ss]}, <<"teacher">>),
    %% the badge only where the level was finished; the reply says which
    [S1 | _] = Ss,
    {200, _} = build_level(S1, 3, <<"s1">>, true, [<<"L1">>]),
    {200, _} = r(<<"POST">>, [<<"mastery">>, S1, <<"3">>, <<"event">>], #{<<"event">> => <<"lesson">>, <<"lesson">> => #{<<"title">> => <<"L1">>}}, <<"s1">>),
    {200, _} = r(<<"POST">>, [<<"mastery">>, S1, <<"3">>, <<"event">>], #{<<"event">> => <<"completed">>}, <<"s1">>),
    %% the exam lists what is ready for one review: the level finished and the challenge answered right
    {200, _} = r(<<"POST">>, [<<"mastery">>, S1, <<"3">>, <<"challenge_answer">>], #{<<"pick">> => 0, <<"why">> => <<"Divide both by 18.">>}, <<"s1">>),
    {200, #{ready := [#{sitting := S1, n := 3, student := <<"s1">>}]}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    {200, #{done := 1, results := Rs}} = r(<<"POST">>, [<<"pile">>, P, <<"bulk">>], #{<<"action">> => <<"badge">>, <<"items">> => [#{<<"sitting">> => S, <<"n">> => 3} || S <- Ss]}, <<"teacher">>),
    {200, #{ready := []}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>),
    ?assertEqual([<<"ok">>, <<"not_completed">>, <<"not_completed">>], [maps:get(result, R) || R <- Rs]),
    %% another teacher's exam: nothing
    ?assertMatch({404, _}, r(<<"POST">>, [<<"pile">>, P, <<"bulk">>], #{<<"action">> => <<"accept">>}, <<"other">>)).

%% a paper deleted while it is being marked stays deleted (31 Oct: the marking wrote it back)
a_paper_deleted_while_marking_stays_deleted_test() ->
    setup(),
    {201, #{id := P}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Q">>}, <<"teacher">>),
    {201, #{id := S}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"size">> => 10, <<"pile">> => P}, <<"teacher">>),
    persistent_term:put(witness_api_during, fun() -> {200, _} = r(<<"POST">>, [<<"sitting">>, S, <<"delete">>], #{}, <<"teacher">>) end),
    {202, _} = r(<<"POST">>, [<<"sitting">>, S, <<"mark">>], #{}, <<"teacher">>),
    persistent_term:erase(witness_api_during),
    ?assertEqual(none, load(<<"teacher">>, {sitting, S})),
    {200, #{sittings := []}} = r(<<"GET">>, [<<"pile">>, P], #{}, <<"teacher">>).

%% forty students joining at once all reach the class list (31 Oct: the list was read, then written)
students_joining_at_once_all_reach_the_list_test() ->
    setup(),
    {201, #{id := P, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Q">>}, <<"teacher">>),
    Me = self(),
    [spawn(fun() -> Me ! {joined, r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Student ", (integer_to_binary(I))/binary>>},
                                       <<"s", (integer_to_binary(I))/binary>>)} end) || I <- lists:seq(1, 40)],
    [receive {joined, {200, _}} -> ok end || _ <- lists:seq(1, 40)],
    {ok, #{roster := Roster}} = load(<<"teacher">>, {pile, P}),
    ?assertEqual(40, length(Roster)).

%% the student's own payload never carries the model's guess (31 Oct, confirmed: `possible` reached the phone)
the_students_phone_never_gets_the_models_guess_test() ->
    setup(),
    Fp = #{reasoning => <<"Could cancel, could keep the base.">>, evidence => [], misconception => <<>>, intervention => <<>>,
           ask => <<"Write or say what you had after each step.">>, possible => <<"percentage changes cancel">>, rivals => [<<"base">>]},
    {_P, S} = released_paper(#{questions => [(q(3, <<"not_yet">>, 0.9))#{fingerprint => Fp, diagnosis_draft => <<"cancels">>}], pauses => [], lines => [], cost_usd => 0.0}),
    {200, #{papers := [#{result := #{questions := [Q]}}]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"stud">>),
    #{fingerprint := F} = Q,
    [?assertNot(maps:is_key(K, F)) || K <- [possible, rivals, reasoning]],
    [?assertNot(maps:is_key(K, Q)) || K <- [confidence, diagnosis_draft]],
    ?assertMatch(#{ask := <<"Write or say", _/binary>>}, F),
    %% the teacher still sees all of it
    {200, #{result := #{questions := [TQ]}}} = r(<<"GET">>, [<<"sitting">>, S], #{}, <<"teacher">>),
    ?assertMatch(#{fingerprint := #{possible := <<"percentage changes cancel">>}}, TQ).

%% each door that calls a model has a daily ceiling for one account
a_model_door_has_a_daily_ceiling_test() ->
    setup(),
    Slot = integer_to_binary(erlang:system_time(millisecond) div 86400000),
    ok = save(<<"teacher">>, {mark_cache, <<"rate:read:teacher">>}, #{minute => Slot, n => 40, sitting => <<>>}),
    ?assertMatch({429, #{code := <<"daily_limit">>}},
                 r(<<"POST">>, [<<"pile">>, <<"read">>], #{<<"mime">> => <<"image/jpeg">>, <<"file">> => base64:encode(<<"jpegbytes">>)}, <<"teacher">>)),
    ?assertMatch({200, _}, r(<<"POST">>, [<<"pile">>, <<"read">>], #{<<"mime">> => <<"image/jpeg">>, <<"file">> => base64:encode(<<"jpegbytes">>)}, <<"other">>)).
