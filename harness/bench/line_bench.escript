#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% line_bench.escript <dir from make_items.py ... truth> <out.json>
%%
%% Where is each handwritten line on the photo? (31 Oct 2026, after the 12-judge panel: "the main photo flow uses no
%% SAM; 288 lines of hand-written dynamic programming place the lines; bench SAM against it".) For every paper of the
%% development set, three answers are compared with where each line really is (<id>.truth.json, from the same random
%% draws that made the photo):
%%   spark  Muse Spark's own box for the line, from the marking (witness_photo, `spot`)
%%   page   that box placed on the ink by witness_page (`box`), what the product cuts the student's step with
%%   sam    SAM 3.1 on the photo, prompt "word" (the one short phrase it answered on a page: harness/probes/results-31oct),
%%          its word boxes joined into lines by height
%% Score per line: intersection over union with the truth; a line is "found" at 0.5 or more. MODEL_API_KEY is read,
%% never printed; ffmpeg (FFMPEG, else on the path) reads the pages for witness_page.
main([Dir, Out]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Specs = lists:sort(filelib:wildcard(filename:join(Dir, "*.truth.json"))),
    Me = self(),
    Pids = [spawn(fun() -> Me ! {self(), try one(Key, Dir, T) catch C:E -> #{error => unicode:characters_to_binary(io_lib:format("~0p", [{C, E}]))} end} end) || T <- Specs],
    Results = [receive {P, R} -> R after 900000 -> #{error => timeout} end || P <- Pids],
    Ok = [R || R = #{lines := _} <- Results],
    Lines = lists:append([maps:get(lines, R) || R <- Ok]),
    Score = fun(M) -> Ious = [maps:get(M, L) || L <- Lines, is_number(maps:get(M, L))],
                      #{lines => length(Lines), placed => length(Ious), found => length([x || I <- Ious, I >= 0.5]),
                        mean_iou => case Ious of [] -> null; _ -> round(lists:sum(Ious) / length(Ious) * 1000) / 1000 end} end,
    Summary = #{papers => length(Ok), errors => length(Results) - length(Ok), spark => Score(spark), page => Score(page), sam => Score(sam),
                sam_cost_usd => witness_meta:cost(sam_image, length(Ok))},
    Meta = #{commit => list_to_binary(string:trim(os:cmd("git rev-parse HEAD"))),
             run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second)))},
    ok = file:write_file(Out, json:encode(#{meta => Meta, summary => Summary, results => Results})),
    io:format("~ts~n", [json:encode(Summary)]).

one(Key, Dir, TruthFile) ->
    {ok, TJ} = file:read_file(TruthFile),
    #{<<"id">> := Id, <<"boxes">> := Truth} = json:decode(TJ),
    Base = filename:join(Dir, binary_to_list(Id)),
    {ok, SJ} = file:read_file(Base ++ ".json"),
    Spec = json:decode(SJ),
    Jpg = Base ++ ".jpg",
    Sitting = #{level => maps:get(<<"level">>, Spec), scheme => maps:get(<<"scheme">>, Spec),
                questions => [#{n => maps:get(<<"n">>, Q), text => maps:get(<<"text">>, Q), marks => maps:get(<<"marks">>, Q)} || Q <- maps:get(<<"questions">>, Spec)]},
    {ok, #{questions := Qs}} = witness_photo:mark(Key, [#{n => 1, url => list_to_binary(Jpg)}], Sitting, #{fetch => fun(F) -> file:read_file(F) end}),
    Steps = case Qs of [#{steps := St} | _] -> St; _ -> [] end,
    {ok, Img} = file:read_file(Jpg),
    SamLines = sam_lines(Key, Img),
    %% each true line against the step read for it (in order) and against the SAM line that overlaps it most
    Lines = [begin
                 S = case length(Steps) >= K of true -> lists:nth(K, Steps); false -> #{} end,
                 #{k => K, truth => T,
                   spark => iou(spot(maps:get(spot, S, none)), T),
                   page => iou(placed(maps:get(box, S, none)), T),
                   sam => best(SamLines, T)}
             end || {K, T} <- lists:enumerate(Truth), is_list(T)],
    #{id => Id, steps_read => length(Steps), sam_lines => length(SamLines), lines => Lines}.

%% SAM 3.1 on the page: its word boxes ("<|box;x1=..;y1=..;x2=..;y2=..;w=..;h=..;c=..|>") in thousandths, joined into
%% lines: words whose vertical middles fall inside a line's band belong to it
sam_lines(Key, Jpg) ->
    Req = #{model => <<"sam-3.1">>, metadata => #{include_confidence => <<"true">>},
            input => [#{type => message, role => user, content => [#{type => input_text, text => <<"word">>},
                                                                   #{type => input_image, image_url => <<"data:image/jpeg;base64,", (base64:encode(Jpg))/binary>>}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            T = witness_meta:text_of(R),
            Words = [[X1 / W * 1000, Y1 / H * 1000, X2 / W * 1000, Y2 / H * 1000]
                     || [X1, Y1, X2, Y2, W, H] <- [[binary_to_integer(V) || V <- Vs]
                                                   || Vs <- case re:run(T, <<"box;x1=(\\d+);y1=(\\d+);x2=(\\d+);y2=(\\d+);w=(\\d+);h=(\\d+)">>, [global, {capture, all_but_first, binary}]) of
                                                                {match, M} -> M; nomatch -> [] end], W > 0, H > 0],
            join(lists:sort(fun([_, A1, _, A2], [_, B1, _, B2]) -> A1 + A2 =< B1 + B2 end, Words), []);
        _ -> []
    end.

join([], Lines) -> lists:reverse(Lines);
join([[X1, Y1, X2, Y2] | Rest], [[L1, T1, R1, B1] | Done]) when (Y1 + Y2) / 2 >= T1, (Y1 + Y2) / 2 =< B1 ->
    join(Rest, [[min(X1, L1), min(Y1, T1), max(X2, R1), max(Y2, B1)] | Done]);
join([W | Rest], Lines) -> join(Rest, [W | Lines]).

spot([L, T, R, B]) when is_number(L) -> [L, T, R, B];
spot(_) -> none.
placed(#{x1 := L, y1 := T, x2 := R, y2 := B}) -> [L, T, R, B];
placed(_) -> none.

best([], _) -> null;
best(Lines, T) -> lists:max([iou(L, T) || L <- Lines]).

iou(none, _) -> null;
iou([A1, B1, A2, B2], [C1, D1, C2, D2]) ->
    W = max(0, min(A2, C2) - max(A1, C1)), H = max(0, min(B2, D2) - max(B1, D1)),
    I = W * H, U = (A2 - A1) * (B2 - B1) + (C2 - C1) * (D2 - D1) - I,
    case U > 0 of true -> round(I / U * 1000) / 1000; false -> 0.0 end.
