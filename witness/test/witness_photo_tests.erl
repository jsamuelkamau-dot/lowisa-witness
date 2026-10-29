-module(witness_photo_tests).
-include_lib("eunit/include/eunit.hrl").
%% From Exam to Mastery (29 Oct): a paper photographed after the exam by one phone, its name matched to the class list.
%% This module is also the test host.
-export([meta_key/0, put_url/4, get_url/2, drop_clip/2, save/3, load/2, list/2, spend/3, run/1, design/2, put_asset/4, asset_url/2,
         retry_waits/0, photo_marker/0, cropper/0, regioner/0, examiner/0]).

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
    ets:new(witness_photo_t, [named_table, public]), persistent_term:erase(witness_photo_name).
r(M, P, B, Uid) -> witness_api:route(M, P, B, Uid, ?MODULE).
jpeg() -> base64:encode(<<255, 216, 255, "page">>).

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
    {201, #{id := Id, pages := 2}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 2, <<"code">> => Code}, <<"school-phone">>),
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
    ?assert(lists:member({cropped, <<"https://store.example.com/a/", Id/binary, "/page-1.jpg">>, 0.0,
                          #{x1 => 150, y1 => 218, x2 => 400, y2 => 243, w => 1000, h => 1000}}, events())),
    ?assert(lists:member({cropped, <<"https://store.example.com/a/", Id/binary, "/page-2.jpg">>, 0.0,
                          #{x1 => 150, y1 => 120, x2 => 400, y2 => 145, w => 1000, h => 1000}}, events())),
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
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"school-phone">>),
    %% the student has it (marks once released), Liam does not
    {200, #{papers := [#{id := Id, status := <<"with_teacher">>}]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amani">>),
    {200, #{papers := []}} = r(<<"GET">>, [<<"mine">>], #{}, <<"liam">>),
    {200, #{released := 1}} = r(<<"POST">>, [<<"pile">>, Pile, <<"release">>], #{}, <<"teacher">>),
    {200, #{papers := [Mine]}} = r(<<"GET">>, [<<"mine">>], #{}, <<"amani">>),
    ?assertMatch(#{status := <<"released">>, result := #{questions := [_, _, _]}}, Mine),
    %% the pages are the paper: they stay (no clip is dropped) and the student may see their own pages once released
    ?assertEqual([], [E || {drop, _, _} = E <- events()]),
    ?assertMatch({200, #{url := _}}, r(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, <<"page-1.jpg">>], #{}, <<"amani">>)).

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
    {ok, #{student_uid := <<"liam">>, name_match := <<"read">>}} = load(<<"teacher">>, {sitting, Id2}),
    _ = Pile.

photographed(Code, By) ->
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => Code}, By),
    {200, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"mime">> => <<"image/jpeg">>, <<"file">> => jpeg()}, By),
    {202, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], #{}, By),
    Id.

photo_refusals_test() ->
    setup(),
    {_, Code} = exam(),
    {400, #{code := <<"bad_pages">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 0, <<"code">> => Code}, <<"p">>),
    {400, #{code := <<"bad_pages">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 21, <<"code">> => Code}, <<"p">>),
    {404, #{code := <<"no_pile">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => <<"NOPE00">>}, <<"p">>),
    {201, #{id := Id}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => Code}, <<"p">>),
    {400, #{code := <<"bad_page">>}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 2, <<"file">> => jpeg()}, <<"p">>),
    {400, #{code := <<"bad_type">>}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"mime">> => <<"application/pdf">>, <<"file">> => jpeg()}, <<"p">>),
    {400, #{code := <<"empty">>}} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"file">> => <<>>}, <<"p">>),
    %% someone else's account can't add pages to it
    {404, _} = r(<<"POST">>, [<<"sitting">>, Id, <<"page">>], #{<<"n">> => 1, <<"file">> => jpeg()}, <<"stranger">>),
    %% a practical is filmed, never photographed
    {201, #{code := PCode}} = r(<<"POST">>, [<<"pile">>], #{<<"title">> => <<"Titration">>, <<"kind">> => <<"practical">>}, <<"teacher">>),
    {400, #{code := <<"practical">>}} = r(<<"POST">>, [<<"sitting">>, <<"start">>], #{<<"kind">> => <<"photo">>, <<"pages">> => 1, <<"code">> => PCode}, <<"p">>).

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
    ?assertMatch(#{y1 := 870, y2 := 960}, witness_page:loose([200, 900, 400, 930])),
    %% a page that isn't one leaves every line to Spark's box
    ?assertEqual([none, none], witness_page:place(<<1, 2, 3>>, W, H, [[1, 2, 3, 4], [1, 2, 3, 4]])).

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
