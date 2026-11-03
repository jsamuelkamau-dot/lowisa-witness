-module(witness_photo_tests).
-include_lib("eunit/include/eunit.hrl").
%% From Exam to Mastery (29 Oct): a paper photographed after the exam by one phone, its name matched to the class list.
%% This module is also the test host.
-export([meta_key/0, put_url/4, get_url/2, drop_clip/2, save/3, load/2, list/2, spend/3, run/1, design/2, put_asset/4, asset_url/2,
         retry_waits/0, photo_marker/0, cropper/0, regioner/0, examiner/0, orienter/0, turner/0]).

meta_key() -> <<"test-key">>.
put_url(_, Id, _, _) -> {ok, <<"https://store.example.com/", Id/binary>>, #{}}.
get_url(_, Id) -> {ok, <<"https://store.example.com/", Id/binary>>}.
drop_clip(U, Id) -> ev({drop, U, Id}), ok.
save(Uid, Key, Row) -> ets:insert(witness_photo_t, {{row, Uid, Key}, Row}), ok.
load(Uid, Key) -> case ets:lookup(witness_photo_t, {row, Uid, Key}) of [{_, R}] -> {ok, R}; [] -> none end.
list(Uid, Kind) -> [{Id, R} || {{row, U, {K, Id}}, R} <- ets:tab2list(witness_photo_t), U =:= Uid, K =:= Kind].
spend(U, F, Usd) -> ev({spend, U, F, Usd}), ok.
run(F) -> F(), ok.
design(_, _) -> {error, none}.
put_asset(Uid, Name, Bytes, Mime) -> ets:insert(witness_photo_t, {{asset, Uid, Name}, {Bytes, Mime}}), ok.
asset_url(Uid, Name) -> case ets:lookup(witness_photo_t, {asset, Uid, Name}) of [_] -> {ok, <<"https://store.example.com/a/", Name/binary>>}; [] -> {error, none} end.
retry_waits() -> [0, 0].
%% which way up each page is: upright unless a test says otherwise (3 Nov)
orienter() -> fun(_, Pages) -> ev({oriented, length(Pages)}), persistent_term:get(witness_photo_turns, {ok, #{}, 0.0}) end.
turner() -> fun(Url, Deg, Ext) -> ev({turned, Url, Deg, Ext}), {ok, <<255, 216, "upright">>} end.
examiner() -> fun(_, _, _) -> {error, off} end.
cropper() -> fun(Url, T, Box) -> ev({cropped, Url, T, Box}), {ok, <<255, 216, "step">>} end.
regioner() -> fun(Url, Box) -> ev({region, Url, Box}), {ok, <<255, 216, "still">>} end.
%% the marking: the name on the paper, Q1 wrong, Q2 mastered, Q3 right answer by wrong thinking (its slip on step 1)
photo_marker() ->
    fun(<<"test-key">>, Pages, _Sitting) ->
        ev({photo_marked, [maps:get(url, P) || P <- Pages]}),
        Name = persistent_term:get(witness_photo_name, <<"Amani Wanjiru">>),
        Box = fun(Y) -> #{x1 => 150, y1 => Y, x2 => 400, y2 => Y + 25, w => 1000, h => 1000} end,
        {ok, #{student => #{name => Name, class => <<"8B">>}, pages => length(Pages), cost_usd => 0.018,
               questions => [#{n => 1, result => <<"not_yet">>, marks => 0, out_of => 2, confidence => 0.95, diagnosis => <<"Multiplied straight across.">>,
                               capabilities => [<<"Pattern Recognition">>], slip => 1, printed => #{page => 1, box => [90, 170, 600, 185], place => Box(165)},
                               steps => [#{t => null, wrote => <<"3/4 ÷ 1/2 = 3/8"/utf8>>, crossed_out => false, page => 1, box => Box(218)}]},
                             #{n => 2, result => <<"mastered">>, marks => 2, out_of => 2, confidence => 0.99, diagnosis => <<>>, capabilities => [], slip => null,
                               printed => null, steps => [#{t => null, wrote => <<"x = 4">>, crossed_out => false, page => 1, box => Box(465)}]},
                             #{n => 3, result => <<"right_answer_wrong_thinking">>, marks => 0, out_of => 2, confidence => 0.95,
                               diagnosis => <<"Cancelled the 6s.">>, capabilities => [<<"Root Cause Analysis">>], slip => 1, printed => null,
                               steps => [#{t => null, wrote => <<"16/64 with both 6s struck =">>, crossed_out => false, page => 2, box => Box(120)},
                                         #{t => null, wrote => <<"= 1/4">>, crossed_out => false, page => 2, box => Box(160)}]}]}}
    end.

ev(E) -> ets:insert(witness_photo_t, {erlang:unique_integer([monotonic]), E}).
events() -> [E || {K, E} <- lists:sort(ets:tab2list(witness_photo_t)), is_integer(K)].
setup() ->
    case ets:whereis(witness_photo_t) of undefined -> ok; _ -> ets:delete(witness_photo_t) end,
    ets:new(witness_photo_t, [named_table, public]), persistent_term:erase(witness_photo_name), persistent_term:erase(witness_photo_turns).
r(M, P, B, Uid) -> witness_api:route(M, P, B, Uid, ?MODULE).
jpeg() -> base64:encode(<<255, 216, 255, "page">>).

%% 31 Oct: a phone photographs with the exam's photographing code (the desk shows it), never the students' join code
photo(Join) ->
    {ok, #{owner := O, pile := P}} = load(<<"witness-codes">>, {code, Join}),
    {ok, #{photo_code := C}} = load(O, {pile, P}),
    C.

exam() ->
    {201, #{id := Pile, code := Code}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Maths Term Test">>,
        <<"questions">> => [#{<<"n">> => 1, <<"text">> => <<"3/4 ÷ 1/2"/utf8>>, <<"marks">> => 2}]}, <<"teacher">>),
    {Pile, Code}.

%% the whole road: students join with their names; after the exam one phone photographs a paper; the name read from it
%% finds the student, whose paper (and Mastery Plan) is theirs; the phone that took it does not own it
photographed_paper_reaches_the_student_by_name_test() ->
    setup(),
    {Pile, Code} = exam(),
    {200, _} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Amani Wanjiru">>}, <<"amani">>),
    {200, _} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Liam Chen">>}, <<"liam">>),
    {ok, #{roster := Roster}} = load(<<"teacher">>, {pile, Pile}),
    ?assertEqual([<<"Amani Wanjiru">>, <<"Liam Chen">>], [maps:get(name, E) || E <- Roster]),
    %% the class phone (not the teacher's account) photographs a two-page paper
    {201, #{id := Id, pages := 2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 2, <<"code">> => photo(Code)}, <<"school-phone">>),
    {409, #{code := <<"pages_missing">>, missing := [1, 2]}} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"school-phone">>),
    {200, #{got := [1]}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"mime">> => <<"image/jpeg">>, <<"file">> => jpeg()}, <<"school-phone">>),
    {409, #{missing := [2]}} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"school-phone">>),
    {200, #{got := [1, 2]}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 2, <<"mime">> => <<"image/jpeg">>, <<"file">> => jpeg()}, <<"school-phone">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"school-phone">>),
    %% Spark read both pages in order
    ?assert(lists:member({photo_marked, [<<"https://store.example.com/a/", Id/binary, "/page-1.jpg">>,
                                         <<"https://store.example.com/a/", Id/binary, "/page-2.jpg">>]}, events())),
    {ok, Row} = load(<<"teacher">>, {sitting, Id}),
    ?assertMatch(#{status := <<"marked">>, student := <<"Amani Wanjiru">>, student_uid := <<"amani">>, name_match := <<"read">>}, Row),
    %% the student's own step and the question's answer are cut from the right page, for every question in the plan
    ?assert(lists:member({region, <<"https://store.example.com/a/", Id/binary, "/page-1.jpg">>,
                          #{x1 => 135, y1 => 213, x2 => 425, y2 => 254, w => 1000, h => 1000}}, events())),
    ?assert(lists:member({region, <<"https://store.example.com/a/", Id/binary, "/page-2.jpg">>,
                          #{x1 => 135, y1 => 115, x2 => 425, y2 => 156, w => 1000, h => 1000}}, events())),
    %% a mastered question keeps its answer, with no step cut for a Mastery Plan it is not in
    ?assertMatch([#{n := 2, asset := <<"still-2.jpg">>}], [X || X = #{n := 2} <- maps:get(stills, maps:get(result, element(2, load(<<"teacher">>, {sitting, Id}))))]),
    ?assertNot(lists:any(fun(#{n := 2} = X) -> maps:is_key(step, X); (_) -> false end, maps:get(stills, maps:get(result, element(2, load(<<"teacher">>, {sitting, Id})))))),
    ?assert(lists:member({region, <<"https://store.example.com/a/", Id/binary, "/page-1.jpg">>,
                          #{x1 => 30, y1 => 150, x2 => 970, y2 => 263, w => 1000, h => 1000}}, events())),
    Stills = maps:get(stills, maps:get(result, Row)),
    ?assertEqual([1, 3, 2], [maps:get(n, S) || S <- Stills]),             %% the Mastery Plan's questions first
    ?assertMatch([#{asset := <<"still-1.jpg">>, step := <<"step-1.jpg">>, page := 1, t := null} | _], Stills),
    %% the teacher's desk: whose it is, read and matched; every question not mastered is in the Mastery Plan
    {200, #{sittings := [S]}} = r(<<"GET">>, [<<"pile">>, Pile], #{}, <<"teacher">>),
    ?assertMatch(#{kind := <<"photo">>, student := <<"Amani Wanjiru">>, linked := true, name_match := <<"read">>,
                   read := #{name := <<"Amani Wanjiru">>, class := <<"8B">>}, to_master := 2}, S),
    %% the phone that took it sees the name come back, but the paper is not its own
    {200, #{papers := [T]}} = r(<<"GET">>, [<<"taken">>], #{}, <<"school-phone">>),
    ?assertMatch(#{id := Id, status := <<"marked">>, student := <<"Amani Wanjiru">>, title := <<"Maths Term Test">>, name_match := <<"read">>}, T),
    %% and which exam it belongs to by its code, not its title (two exams can share one)
    ?assertEqual(Code, maps:get(code, T)),
    ?assertEqual(photo(Code), maps:get(photo_code, T)),
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"school-phone">>),
    %% the student has it (marks once released), Liam does not
    {200, #{papers := [#{id := Id, status := <<"with_teacher">>}]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amani">>),
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"liam">>),
    {200, #{released := 1}} = r(<<"POST">>, [<<"pile">>, Pile, <<"release">>], #{}, <<"teacher">>),
    {200, #{papers := [Mine]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amani">>),
    ?assertMatch(#{status := <<"released">>, result := #{questions := [_, _, _]}}, Mine),
    %% the pages are the paper: they stay (no clip is dropped) and the student may see their own pages once released
    ?assertEqual([], [E || {drop, _, _} = E <- events()]),
    ?assertMatch({200, #{url := _}}, r(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, <<"page-1.jpg">>], #{}, <<"amani">>)),
    %% the Proof of Thinking record (printed for a student with no phone): the pages kept, each question's capabilities
    %% and the student's own step, and no video
    {200, Proof} = r(<<"GET">>, [<<"sitting">>, Id, <<"proof">>], #{}, <<"teacher">>),
    ?assertMatch(#{source := <<"photo">>, pages := 2, student := <<"Amani Wanjiru">>}, Proof),
    ?assertNot(maps:is_key(video, Proof)),
    [P1 | _] = maps:get(questions, Proof),
    ?assertMatch(#{n := 1, capabilities := [<<"Pattern Recognition">>], slip := 1, still := <<"still-1.jpg">>, step := <<"step-1.jpg">>}, P1).

%% 3 Nov (a real student's papers: sideways pages misread): a page photographed sideways is turned upright and kept so
%% before it is marked; the upright page is the one marked, and the look's cost is on the paper
a_sideways_page_is_turned_upright_before_it_is_marked_test() ->
    setup(),
    persistent_term:put(witness_photo_turns, {ok, #{2 => 90}, 0.002}),
    {_Pile, Code} = exam(),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 2, <<"code">> => photo(Code)}, <<"school-phone">>),
    [{200, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => N, <<"mime">> => <<"image/jpeg">>, <<"file">> => jpeg()}, <<"school-phone">>) || N <- [1, 2]],
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, <<"school-phone">>),
    Page2 = <<"https://store.example.com/a/", Id/binary, "/page-2.jpg">>,
    ?assert(lists:member({oriented, 2}, events())),
    ?assertEqual([{turned, Page2, 90, ".jpg"}], [E || {turned, _, _, _} = E <- events()]),
    ?assertMatch([{_, {<<255, 216, "upright">>, <<"image/jpeg">>}}], ets:lookup(witness_photo_t, {asset, <<"teacher">>, <<Id/binary, "/page-2.jpg">>})),
    ?assertMatch([{_, {<<255, 216, 255, "page">>, _}}], ets:lookup(witness_photo_t, {asset, <<"teacher">>, <<Id/binary, "/page-1.jpg">>})),
    {ok, #{result := Res}} = load(<<"teacher">>, {sitting, Id}),
    ?assertMatch(#{turned := [2]}, Res),
    ?assert(abs(maps:get(cost_usd, Res) - 0.020) < 1.0e-9),
    %% a look that fails leaves the pages as they were, and the paper is still marked
    setup(),
    persistent_term:put(witness_photo_turns, {error, timeout}),
    {_, Code2} = exam(),
    {201, #{id := Id2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => photo(Code2)}, <<"school-phone">>),
    {200, _} = r(<<"POST">>, [<<"sitting">>, Id2, <<"page">>], #{<<"n">> => 1, <<"mime">> => <<"image/jpeg">>, <<"file">> => jpeg()}, <<"school-phone">>),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id2, <<"mark">>], #{}, <<"school-phone">>),
    ?assertEqual([], [E || {turned, _, _, _} = E <- events()]),
    {ok, #{status := <<"marked">>, result := Res2}} = load(<<"teacher">>, {sitting, Id2}),
    ?assertNot(maps:is_key(turned, Res2)).

%% the answer to "which way up": only the pages asked about, only real turns
orientation_answer_test() ->
    Read = fun(Text) -> fun(_, _) -> {ok, Text, #{}} end end,
    Pages = [#{n => 1, url => <<"u1">>}, #{n => 2, url => <<"u2">>}],
    Small = fun(_) -> {ok, <<255, 216>>} end,
    ?assertMatch({ok, #{2 := 90}, _, 30}, witness_photo:orient(k, Pages, #{small => Small, read => Read(<<"Sure: {\"pages\": [{\"n\": 1, \"top\": \"top\"}, {\"n\": 2, \"top\": \"left\"}], \"questions\": 30}">>)})),
    {ok, T, _, 0} = witness_photo:orient(k, Pages, #{small => Small, read => Read(<<"{\"pages\": [{\"n\": 7, \"top\": \"left\"}, {\"n\": 1, \"top\": \"diagonal\"}], \"questions\": \"many\"}">>)}),
    ?assertEqual(#{}, T),
    ?assertMatch({ok, #{}, _, 0}, witness_photo:orient(k, Pages, #{small => Small, read => Read(<<"no idea">>)})).

%% 4 Nov (a real 30-question paper took 4.5 minutes live): a long paper is read in parts at once, each part only its own
%% questions with every page; the parts come back in order, an unsure question is read again only in its own part, and a
%% short paper is still one reading
a_long_paper_is_marked_in_parts_at_once_test() ->
    Q = fun(N, C) -> #{<<"n">> => N, <<"result">> => <<"mastered">>, <<"marks">> => 1, <<"out_of">> => 1, <<"confidence">> => C, <<"steps">> => []} end,
    Self = self(),
    Read = fun(_K, [#{text := Prompt} | Images], Effort) ->
        {From, To} = case re:run(Prompt, <<"questions? ([0-9]+) to (the last|[0-9]+)">>, [{capture, all_but_first, binary}]) of
            {match, [F, <<"the last">>]} -> {binary_to_integer(F), 30};
            {match, [F, T]} -> {binary_to_integer(F), binary_to_integer(T)};
            nomatch -> {1, 30}
        end,
        Self ! {read, From, Effort, length(Images)},
        timer:sleep(200),
        %% the part from 11 is unsure of question 12 at medium effort; every part also returns its neighbours' questions
        Qs = [Q(N, case {N, Effort} of {12, <<"medium">>} -> 0.5; _ -> 0.95 end) || N <- lists:seq(From, To)] ++
             [Q(N, 0.1) || N <- [From - 1, To + 1], N >= 1, N =< 30],
        {ok, iolist_to_binary(json:encode(#{<<"student">> => #{<<"name">> => <<"Amani">>}, <<"questions">> => Qs})), #{}}
    end,
    Pages = [#{n => 1, url => <<"u1">>}, #{n => 2, url => <<"u2">>}],
    Opts = #{fetch => fun(_) -> {ok, <<255, 216>>} end, read => Read, gray => fun(_) -> {error, none} end, tint => fun(_) -> none end,
             price => {price, {0.0, 0.0}}},
    T0 = erlang:monotonic_time(millisecond),
    {ok, M} = witness_photo:mark(k, Pages, #{question_count => 30}, Opts),
    Ms = erlang:monotonic_time(millisecond) - T0,
    ?assertEqual(lists:seq(1, 30), [maps:get(n, X) || X <- maps:get(questions, M)]),
    ?assertMatch(#{parts := 3, read_twice := true, student := #{name := <<"Amani">>}}, M),
    Reads = lists:sort(fun(A, B) -> A =< B end, [R || R <- flush_reads()]),
    %% the parts with no unsure question are checked by a reading of their answers alone (3 Nov: two readings must agree)
    ?assertEqual([{1, <<"low">>}, {1, <<"medium">>}, {11, <<"high">>}, {11, <<"medium">>}, {21, <<"low">>}, {21, <<"medium">>}],
                 [{F, E} || {read, F, E, _} <- Reads]),
    %% every part sees both pages; the answers-only check adds its own instruction after them
    ?assert(lists:all(fun({read, _, E, Imgs}) -> Imgs =:= 4 + case E of <<"low">> -> 1; _ -> 0 end end, Reads)),
    ?assert(Ms < 900),                                                                % the parts ran at once (3 x 200 ms read + one reread)
    %% a one-page paper is one reading, however many questions it has (the physics page: no faster in parts)
    {ok, M1} = witness_photo:mark(k, [hd(Pages)], #{question_count => 30}, Opts),
    ?assertNot(maps:is_key(parts, M1)),
    ?assertEqual([{1, <<"high">>}, {1, <<"medium">>}], lists:sort([{F, E} || {read, F, E, _} <- flush_reads()])),
    %% a short paper is one reading, as before
    {ok, M2} = witness_photo:mark(k, Pages, #{question_count => 8}, Opts),
    ?assertNot(maps:is_key(parts, M2)),
    %% (one reading of the whole paper, and its unsure question 12 read again)
    ?assertEqual([{1, <<"high">>}, {1, <<"medium">>}], lists:sort([{F, E} || {read, F, E, _} <- flush_reads()])).

flush_reads() -> receive {read, _, _, _} = R -> [R | flush_reads()] after 0 -> [] end.

%% a name the paper cannot settle waits for the teacher, who links it; the student who joins later finds their paper
an_unclear_name_waits_for_the_teacher_test() ->
    setup(),
    {Pile, Code} = exam(),
    {200, _} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Amani Wanjiru">>}, <<"amani">>),
    {200, _} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Amina Wanjiku">>}, <<"amina">>),
    persistent_term:put(witness_photo_name, <<"Amani Wanjku">>),
    Id = photographed(Code, <<"teacher">>),
    {ok, Row} = load(<<"teacher">>, {sitting, Id}),
    ?assertMatch(#{name_match := <<"unsure">>, student := <<"Amani Wanjku">>}, Row),
    ?assertNot(maps:is_key(student_uid, Row)),
    ?assertEqual([<<"amani">>, <<"amina">>], lists:sort(maps:get(candidates, Row))),
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amani">>),
    %% the teacher says whose it is
    {200, #{paper := #{student := <<"Amina Wanjiku">>, linked := true}}} =
        r(<<"POST">>, [<<"sitting">>, Id, <<"student">>], #{<<"uid">> => <<"amina">>}, <<"teacher">>),
    {200, #{papers := [_]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amina">>),
    %% and changes their mind: the first student loses it, the second has it
    {200, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"student">>], #{<<"uid">> => <<"amani">>}, <<"teacher">>),
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amina">>),
    {404, _} = r(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, <<"page-1.jpg">>], #{}, <<"amina">>),
    {200, #{papers := [_]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amani">>),
    {404, #{code := <<"not_on_list">>}} = r(<<"POST">>, [<<"sitting">>, Id, <<"student">>], #{<<"uid">> => <<"stranger">>}, <<"teacher">>),
    %% a student with no phone: the teacher types the name (their Mastery Plan is printed from the desk)
    {200, #{paper := #{student := <<"Baraka Otieno">>, linked := false}}} =
        r(<<"POST">>, [<<"sitting">>, Id, <<"student">>], #{<<"name">> => <<"Baraka Otieno">>}, <<"teacher">>),
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amani">>),
    %% a paper photographed before its student joined is found when they join
    persistent_term:put(witness_photo_name, <<"Liam Chen">>),
    Id2 = photographed(Code, <<"teacher">>),
    {ok, #{name_match := <<"none">>}} = load(<<"teacher">>, {sitting, Id2}),
    {200, _} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Liam Chen">>}, <<"liam">>),
    %% 31 Oct (judges' panel): someone who joins AFTER the paper was photographed is not linked on their own: the
    %% teacher confirms (an impostor joining under a classmate's name gets nothing)
    {ok, #{name_match := <<"confirm">>, candidates := [<<"liam">>]} = Waiting} = load(<<"teacher">>, {sitting, Id2}),
    ?assertNot(maps:is_key(student_uid, Waiting)),
    {200, _} = r(<<"POST">>, [<<"sitting">>, Id2, <<"student">>], #{<<"uid">> => <<"liam">>}, <<"teacher">>),
    {ok, #{student_uid := <<"liam">>, name_match := <<"teacher">>}} = load(<<"teacher">>, {sitting, Id2}),
    _ = Pile.

%% 31 Oct (judges' panel, confirmed by probes): an impostor who joins under a classmate's name after the photos gets
%% nothing; the join code cannot photograph; the phone that photographed cannot read the student's recordings
the_class_code_and_the_photographing_phone_open_nothing_else_test() ->
    setup(),
    {Pile, Code} = exam(),
    {403, #{code := <<"photo_code">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => Code}, <<"stud">>),
    %% the photographing code typed in the phone's code box opens the exam for photographing only: no name is listed
    {200, #{photo := true, pile := #{title := <<"Maths Term Test">>}}} = r(<<"POST">>, [<<"join">>], #{<<"code">> => photo(Code), <<"name">> => <<"X">>}, <<"stud">>),
    {ok, #{} = P0} = load(<<"teacher">>, {pile, Pile}),
    ?assertEqual([], maps:get(roster, P0, [])),
    {404, #{code := <<"no_code">>}} = r(<<"POST">>, [<<"join">>], #{<<"code">> => <<"ZZZZZZ">>}, <<"stud">>),
    {200, _} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Amani Wanjiru">>}, <<"amani">>),
    Id = photographed(Code, <<"school-phone">>),
    {ok, #{student_uid := <<"amani">>}} = load(<<"teacher">>, {sitting, Id}),
    %% a classmate joining as Amani afterwards changes nothing
    {200, _} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Amani Wanjiru">>}, <<"impostor">>),
    {ok, #{student_uid := <<"amani">>}} = load(<<"teacher">>, {sitting, Id}),
    {200, _} = r(<<"POST">>, [<<"pile">>, Pile, <<"release">>], #{}, <<"teacher">>),
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"impostor">>),
    %% the photographing phone: no page, recording or record of a released paper
    ok = put_asset(<<"teacher">>, <<Id/binary, "/answer-1.m4a">>, <<"a">>, <<"audio/mp4">>),
    {404, _} = r(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, <<"answer-1.m4a">>], #{}, <<"school-phone">>),
    {404, _} = r(<<"GET">>, [<<"sitting">>, Id, <<"proof">>], #{}, <<"school-phone">>),
    {200, #{url := _}} = r(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, <<"answer-1.m4a">>], #{}, <<"amani">>),
    {200, #{url := _}} = r(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, <<"answer-1.m4a">>], #{}, <<"teacher">>),
    %% the teacher hears the answer to Lo too (31 Oct: "diagnose-" was refused)
    ok = put_asset(<<"teacher">>, <<Id/binary, "/diagnose-1-1.m4a">>, <<"a">>, <<"audio/mp4">>),
    {200, #{url := _}} = r(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, <<"diagnose-1-1.m4a">>], #{}, <<"teacher">>),
    %% the teacher takes a name off the list: its paper waits for its name again
    {200, _} = r(<<"POST">>, [<<"pile">>, Pile, <<"roster">>, <<"remove">>], #{<<"uid">> => <<"amani">>}, <<"teacher">>),
    {ok, Row} = load(<<"teacher">>, {sitting, Id}),
    ?assertNot(maps:is_key(student_uid, Row)),
    %% and closes joining
    {200, #{joining := <<"closed">>}} = r(<<"POST">>, [<<"pile">>, Pile, <<"joining">>], #{<<"open">> => false}, <<"teacher">>),
    {409, #{code := <<"closed">>}} = r(<<"POST">>, [<<"join">>], #{<<"code">> => Code, <<"name">> => <<"Late">>}, <<"late">>).

photographed(Code, By) ->
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => photo(Code)}, By),
    {200, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"mime">> => <<"image/jpeg">>, <<"file">> => jpeg()}, By),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, By),
    Id.

photo_refusals_test() ->
    setup(),
    {_, Code} = exam(),
    {400, #{code := <<"bad_pages">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 0, <<"code">> => photo(Code)}, <<"p">>),
    {400, #{code := <<"bad_pages">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 21, <<"code">> => photo(Code)}, <<"p">>),
    {404, #{code := <<"no_pile">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => <<"NOPE00">>}, <<"p">>),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => photo(Code)}, <<"p">>),
    {400, #{code := <<"bad_page">>}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 2, <<"file">> => jpeg()}, <<"p">>),
    {400, #{code := <<"bad_type">>}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"mime">> => <<"application/pdf">>, <<"file">> => jpeg()}, <<"p">>),
    {400, #{code := <<"empty">>}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"file">> => <<>>}, <<"p">>),
    %% someone else's account can't add pages to it
    {404, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"file">> => jpeg()}, <<"stranger">>),
    %% a practical is filmed, never photographed
    {201, #{code := PCode}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Titration">>, <<"kind">> => <<"practical">>}, <<"teacher">>),
    {400, #{code := <<"practical">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => photo(PCode)}, <<"p">>).

%% ---------------------------------------------------------------- names
names_test() ->
    Roster = [#{uid => <<"a">>, name => <<"Amani Wanjiru">>}, #{uid => <<"s">>, name => <<"Sofia Ramírez"/utf8>>},
              #{uid => <<"l">>, name => <<"Liam Chen">>}],
    ?assertMatch({match, #{uid := <<"a">>}}, witness_names:match(<<"Amani Wanjiru">>, Roster)),
    ?assertMatch({match, #{uid := <<"a">>}}, witness_names:match(<<"  AMANI   wanjiru ">>, Roster)),
    ?assertMatch({match, #{uid := <<"a">>}}, witness_names:match(<<"Wanjiru Amani">>, Roster)),
    ?assertMatch({match, #{uid := <<"a">>}}, witness_names:match(<<"Amani W.">>, Roster)),
    ?assertMatch({match, #{uid := <<"s">>}}, witness_names:match(<<"Sofia Ramirez">>, Roster)),       %% the accent left off
    ?assertMatch({match, #{uid := <<"a">>}}, witness_names:match(<<"Amani Wanjru">>, Roster)),        %% one misread letter
    ?assertMatch({close, [#{uid := <<"a">>} | _]}, witness_names:match(<<"Amari Wanjro">>, Roster)),  %% two: the teacher says
    ?assertEqual(none, witness_names:match(<<"Baraka Otieno">>, Roster)),
    ?assertEqual(none, witness_names:match(<<>>, Roster)),
    ?assertEqual(none, witness_names:match(<<"Amani">>, [])),
    %% two students the same name: never linked by itself
    Twins = Roster ++ [#{uid => <<"a2">>, name => <<"Amani Wanjiru">>}],
    ?assertMatch({close, [_, _]}, witness_names:match(<<"Amani Wanjiru">>, Twins)),
    ?assertEqual([<<"sofia">>, <<"ramirez">>], witness_names:key(<<"Sofía  RAMÍREZ!"/utf8>>)).

%% ---------------------------------------------------------------- the page
%% a page 100 x 200: a printed line at rows 20-29, the student's two lines at 50-59 and 80-89, a ruled line across row 120
page() ->
    W = 100, H = 200,
    Px = fun(X, Y) ->
        Ink = (Y >= 20 andalso Y < 30 andalso X >= 10 andalso X < 80 andalso X rem 4 =:= 0)
              orelse (Y >= 50 andalso Y < 60 andalso X >= 20 andalso X < 50 andalso X rem 2 =:= 0)
              orelse (Y >= 80 andalso Y < 90 andalso X >= 20 andalso X < 40 andalso X rem 2 =:= 0),
        Ruled = Y =:= 120,
        case Ink orelse Ruled of true -> 40; false -> 235 end
    end,
    {W, H, << <<(Px(X, Y))>> || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1) >>}.

page_places_each_line_on_its_own_ink_in_reading_order_test() ->
    {W, H, G} = page(),
    %% Spark's boxes (thousandths) are off by most of a line: the step's box sits between the printed line and its own
    Items = [[100, 95, 800, 140], [200, 210, 500, 255], [200, 380, 420, 420]],
    [Q, S1, S2] = witness_page:place(G, W, H, Items),
    ?assertMatch(#{y1 := 100, y2 := 150}, Q),
    ?assertMatch(#{y1 := 250, y2 := 300, x1 := 200}, S1),
    ?assertMatch(#{y1 := 400, y2 := 450}, S2),
    %% a line with no ink near it is not forced onto another
    [_, _, _, Lost] = witness_page:place(G, W, H, Items ++ [[200, 900, 400, 930]]),
    ?assertEqual(none, Lost),
    ?assertMatch(#{y1 := 885, y2 := 945}, witness_page:loose([200, 900, 400, 930])),
    %% a page that isn't one leaves every line to Spark's box
    ?assertEqual([none, none], witness_page:place(<<1, 2, 3>>, W, H, [[1, 2, 3, 4], [1, 2, 3, 4]])).

%% 29 Oct (film take): a picture printed on the paper, an answer line written right under the printed question, and
%% Spark's boxes a line low all down the page
picture_page() ->
    W = 200, H = 400,
    Line = fun(Y, Y0, X, X0, X1) -> Y >= Y0 andalso Y < Y0 + 10 andalso X >= X0 andalso X < X1 andalso X rem 3 =:= 0 end,
    Px = fun(X, Y) ->
        Ink = Line(Y, 20, X, 10, 150)                                                     %% printed question 1
              orelse (Y >= 40 andalso Y < 140 andalso X >= 20 andalso X < 90 andalso (X + Y) rem 3 =:= 0)  %% the picture
              orelse Line(Y, 150, X, 20, 60)                                              %% "Fake."
              orelse Line(Y, 170, X, 20, 120)                                             %% "So many people shared it"
              orelse Line(Y, 230, X, 10, 150)                                             %% printed question 2
              orelse Line(Y, 242, X, 20, 110)                                             %% its answer, touching it
              orelse Line(Y, 262, X, 20, 70),
        case Ink of true -> 40; false -> 235 end
    end,
    {W, H, << <<(Px(X, Y))>> || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1) >>}.

page_keeps_a_picture_out_and_splits_touching_lines_test() ->
    {W, H, G} = picture_page(),
    %% thousandths of the 400-row page, each a line (25 thousandths) low
    Items = [[50, 75, 750, 100], [100, 400, 300, 425], [100, 450, 600, 475], [50, 600, 750, 625], [100, 630, 550, 655], [100, 680, 350, 705]],
    [Q1, Fake, SoMany, Q2, A1, A2] = witness_page:place(G, W, H, Items),
    ?assertMatch(#{y1 := 50, y2 := 75}, Q1),
    ?assertMatch(#{y1 := 375, y2 := 400}, Fake),          %% not the picture above it
    ?assertMatch(#{y1 := 425, y2 := 450}, SoMany),
    ?assertMatch(#{y1 := 575, y2 := 600}, Q2),
    #{y1 := A1y1, y2 := A1y2} = A1,                        %% its own line, apart from the question it touches
    ?assert(A1y1 >= 600 andalso A1y2 =< 632),
    ?assertMatch(#{y1 := 655, y2 := 680}, A2).

%% 30 Oct (film take): Spark's boxes drift by more than a line, differently each marking; on a page in two inks the
%% student's pen and the printed question are told apart by their colour, so the first answer line keeps its own line
tint_page() ->
    W = 200, H = 300,
    Line = fun(Y, Y0, X, X0, X1) -> Y >= Y0 andalso Y < Y0 + 10 andalso X >= X0 andalso X < X1 andalso X rem 3 =:= 0 end,
    Printed = fun(X, Y) -> Line(Y, 20, X, 10, 160) orelse Line(Y, 110, X, 10, 160) end,
    Pen = fun(X, Y) -> Line(Y, 40, X, 20, 120) orelse Line(Y, 60, X, 20, 90) orelse Line(Y, 130, X, 20, 110) end,
    G = << <<(case Printed(X, Y) orelse Pen(X, Y) of true -> 40; false -> 235 end)>> || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1) >>,
    T = << <<(case Pen(X, Y) of true -> 160; false -> 126 end)>> || Y <- lists:seq(0, H - 1), X <- lists:seq(0, W - 1) >>,
    {W, H, G, T}.

page_tells_pen_from_print_test() ->
    {W, H, G, T} = tint_page(),
    %% every box well over a line high (Spark's drift), in reading order: question 1, two lines, question 2, a line
    Items = [[50, 30, 800, 60], [100, 85, 600, 115], [100, 160, 450, 190], [50, 330, 800, 360], [100, 395, 550, 425]],
    Kinds = [printed, hand, hand, printed, hand],
    [Q1, L1, L2, Q2, L3] = witness_page:place(G, T, W, H, Items, Kinds),
    ?assertMatch(#{y1 := 67, y2 := 100}, Q1),
    ?assertMatch(#{y1 := 133, y2 := 167}, L1),
    ?assertMatch(#{y1 := 200, y2 := 233}, L2),
    ?assertMatch(#{y1 := 367, y2 := 400}, Q2),
    ?assertMatch(#{y1 := 433, y2 := 467}, L3),
    %% the same page with no tint places by the boxes alone, as before
    ?assertEqual(length(Items), length(witness_page:place(G, none, W, H, Items, none))).

%% ---------------------------------------------------------------- the marking
photo_marking_reads_details_places_lines_and_names_capabilities_test() ->
    Text = <<"{\"student\":{\"name\":\"Sofia Ramírez\",\"class\":\"8B\",\"number\":\"\",\"date\":\"\",\"name_note\":\"\"},"/utf8,
             "\"questions\":[{\"n\":1,\"printed\":{\"page\":1,\"box\":[100,95,800,140]},\"final_answer\":\"x = 10\","
             "\"steps\":[{\"wrote\":\"2x = 20\",\"crossed_out\":false,\"page\":1,\"box\":[200,210,500,255]},"
             "{\"wrote\":\"x = 10\",\"crossed_out\":false,\"page\":1,\"box\":[200,380,420,420]}],"
             "\"result\":\"not_yet\",\"marks\":0,\"out_of\":2,\"diagnosis\":\"Added 6 instead of subtracting it.\",\"slip\":1,"
             "\"capabilities\":[\"Decision-Making\",\"Telepathy\"],\"confidence\":0.93},"
             "{\"n\":2,\"printed\":null,\"final_answer\":\"1/4\",\"steps\":[{\"wrote\":\"16/64 = 1/4\",\"page\":2,\"box\":[1,2,3]}],"
             "\"result\":\"mastered\",\"marks\":2,\"out_of\":2,\"diagnosis\":\"\",\"slip\":2,\"capabilities\":[\"Optimization\"],\"confidence\":0.97}]}">>,
    {W, H, G} = page(),
    Opts = #{fetch => fun(<<"u1">>) -> {ok, <<"one">>}; (<<"u2">>) -> {ok, <<"two">>} end,
             gray => fun(<<"u1">>) -> {ok, W, H, G}; (_) -> {error, no} end,
             read => fun(<<"k">>, Content, <<"medium">>) ->
                         self() ! {content, Content},
                         {ok, Text, #{<<"input_tokens">> => 1000, <<"output_tokens">> => 500}} end},
    Sitting = #{questions => [#{n => 1, text => <<"Solve 2x + 6 = 14">>, marks => 2}, #{n => 2, text => <<"Simplify 16/64">>, marks => 2}], level => <<"Year 8">>},
    {ok, R} = witness_photo:mark(<<"k">>, [#{n => 1, url => <<"u1">>, mime => <<"image/jpeg">>}, #{n => 2, url => <<"u2">>, mime => <<"image/png">>}], Sitting, Opts),
    receive {content, [#{type := input_text, text := Prompt}, #{text := <<"Page 1:">>}, #{image_url := <<"data:image/jpeg;base64,b25l">>},
                       #{text := <<"Page 2:">>}, #{image_url := <<"data:image/png;base64,dHdv">>}]} ->
        ?assertNotEqual(nomatch, binary:match(Prompt, <<"Solve 2x + 6 = 14">>)),
        ?assertNotEqual(nomatch, binary:match(Prompt, <<"Root Cause Analysis">>))
    after 0 -> ?assert(false)
    end,
    ?assertEqual(#{name => <<"Sofia Ramírez"/utf8>>, class => <<"8B">>}, maps:get(student, R)),
    [Q1, Q2] = maps:get(questions, R),
    ?assertMatch(#{result := <<"not_yet">>, slip := 1, capabilities := [<<"Decision-Making">>]}, Q1),
    ?assertMatch(#{printed := #{page := 1, place := #{y1 := 100}}}, Q1),
    ?assertMatch([#{box := #{y1 := 250}, page := 1}, #{box := #{y1 := 400}}], maps:get(steps, Q1)),
    %% mastered: no capabilities, no slip; a box that isn't four numbers is no place
    ?assertMatch(#{result := <<"mastered">>, slip := null, capabilities := []}, Q2),
    ?assertEqual([#{t => null, wrote => <<"16/64 = 1/4">>, crossed_out => false}], maps:get(steps, Q2)),
    ?assert(maps:get(cost_usd, R) > 0).

%% every question not mastered is in the Mastery Plan: no verdict ends a question
no_question_ends_in_a_verdict_test() ->
    ?assert(witness_mark:needs_level(#{result => <<"not_yet">>})),
    ?assert(witness_mark:needs_level(#{result => <<"right_answer_wrong_thinking">>})),
    ?assert(witness_mark:needs_level(#{result => <<"part_way">>})),
    ?assertNot(witness_mark:needs_level(#{result => <<"mastered">>})),
    ?assertEqual(7, length(witness_mark:capabilities())).

%% 31 Oct, photo bench on the committed code: with no mark scheme the prompt said "give 1 mark" beside questions
%% listed as 2 marks, and right work came back 1 of 2, part way. A fully correct question earns all of its worth.
%% 4 Nov: full marks are a mastered question's only; half a mark on a one-mark question no longer rounds up to full
full_marks_only_when_mastered_test() ->
    Sitting = #{questions => [#{n => 1, text => <<"a">>, marks => 1}, #{n => 2, text => <<"b">>, marks => 2}, #{n => 3, text => <<"c">>, marks => 1}]},
    [Q1, Q2, Q3, Q4] = witness_mark:fit([#{n => 1, result => <<"part_way">>, marks => 0.5, out_of => 1},
                                         #{n => 2, result => <<"part_way">>, marks => 2, out_of => 2},
                                         #{n => 3, result => <<"mastered">>, marks => 1, out_of => 1},
                                         #{n => 4, result => <<"right_answer_wrong_thinking">>, marks => 3, out_of => 3}], Sitting),
    ?assertMatch(#{marks := 0, out_of := 1}, Q1),
    ?assertMatch(#{marks := 1, out_of := 2}, Q2),
    ?assertMatch(#{marks := 1, out_of := 1}, Q3),
    ?assertMatch(#{marks := 2, out_of := 3}, Q4).

no_scheme_gives_a_right_question_all_its_marks_test() ->
    S = #{level => <<"Year 8">>, questions => [#{n => 1, text => <<"Solve 2x + 3 = 11">>, marks => 2}]},
    [begin
         P = Prompt(S),
         ?assertEqual(nomatch, binary:match(P, <<"give 1 mark">>)),
         ?assertNotEqual(nomatch, binary:match(P, <<"earns every mark it is worth">>))
     end || Prompt <- [fun witness_photo:prompt/1, fun witness_mark:prompt/1]],
    %% and the scheme, when given, is still what is followed
    ?assertNotEqual(nomatch, binary:match(witness_photo:prompt(S#{scheme => <<"Q1: x = 4 (2)">>}), <<"follow it exactly">>)).

%% 3 Nov (judges' panel; the real student's science Q33, his D read as C at 90%): on a paper with no unsure question the
%% answers-only check reads the letter again; read differently, the paper is read in full again and the third reading
%% decides, so the misread letter is never accepted as mastered
a_letter_read_differently_is_read_again_before_it_is_accepted_test() ->
    Self = self(),
    Q = fun(Final, Result, C) -> #{<<"n">> => 33, <<"final_answer">> => Final, <<"result">> => Result, <<"marks">> => 0,
                                   <<"out_of">> => 1, <<"confidence">> => C, <<"steps">> => [#{<<"wrote">> => Final}]} end,
    Read = fun(_K, _Content, Effort) ->
        Self ! {effort, Effort},
        Qs = case Effort of
            <<"medium">> -> [(Q(<<"C">>, <<"mastered">>, 0.95))#{<<"marks">> => 1}];
            <<"low">> -> [#{<<"n">> => 33, <<"final_answer">> => <<"D">>}];
            <<"high">> -> [Q(<<"D">>, <<"not_yet">>, 0.9)]
        end,
        {ok, iolist_to_binary(json:encode(#{<<"questions">> => Qs})), #{}}
    end,
    Opts = #{fetch => fun(_) -> {ok, <<255, 216>>} end, read => Read, gray => fun(_) -> {error, none} end, tint => fun(_) -> none end,
             price => {price, {0.0, 0.0}}},
    {ok, #{questions := [Q33]} = M} = witness_photo:mark(k, [#{n => 1, url => <<"u1">>}], #{}, Opts),
    ?assertMatch(#{result := <<"not_yet">>, read_thrice := true}, Q33),
    ?assertMatch(#{checked := true, read_twice := true}, M),
    Efforts = (fun F() -> receive {effort, E} -> [E | F()] after 0 -> [] end end)(),
    ?assertEqual([<<"medium">>, <<"low">>, <<"high">>, <<"high">>], Efforts).
