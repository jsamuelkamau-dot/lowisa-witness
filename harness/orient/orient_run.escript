#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% orient_run.escript <private photo dir> <runs> <out.json>
%%
%% Does Muse Spark know which way up a photographed exam page is? Two ways of asking, on the same small images:
%%   edge:    witness_photo:orient/3 as shipped: "which edge of the photo is the top of the printed page"
%%   degrees: the first version: "how many degrees clockwise must the photo be turned to read normally"
%% Each set of truth.json is asked <runs> times each way. A page is right when the turn matches its label.
%% The key comes from MODEL_API_KEY and is never printed.
main([Dir, RunsS, Out]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    Runs = list_to_integer(RunsS),
    Files = #{<<"maths">> => ["blurred/57.jpg", "blurred/58.jpg", "blurred/59.jpg", "noink/43.jpg"],
              <<"science">> => ["blurred/44.jpg", "blurred/45.jpg", "blurred/46.jpg", "noink/47.jpg"],
              <<"english">> => ["blurred/53.jpg", "blurred/54.jpg", "blurred/55.jpg", "noink/56.jpg"],
              <<"made_harder">> => ["upright/57_topleft.jpg", "upright/53_upsidedown.jpg", "blurred/44.jpg"]},
    {ok, TJ} = file:read_file(filename:join(filename:dirname(escript:script_name()), "truth.json")),
    #{<<"sets">> := Truth} = json:decode(TJ),
    Small = fun(Path) -> witness_media:small(Path, 640) end,
    Rows = [begin
                Pages = [#{n => N, url => list_to_binary(filename:join(Dir, F))} || {N, F} <- lists:zip(lists:seq(1, length(Fs)), Fs)],
                Want = [maps:get(<<"turn">>, T) || T <- maps:get(Set, Truth)],
                [ask(Way, Key, Pages, Small, Want, Set, R) || R <- lists:seq(1, Runs), Way <- [edge, degrees]]
            end || {Set, Fs} <- lists:sort(maps:to_list(Files))],
    All = lists:append(Rows),
    Sum = fun(Way) -> Ws = [X || #{way := W} = X <- All, W =:= Way],
                      #{pages_right => lists:sum([maps:get(right, X) || X <- Ws]), pages => lists:sum([maps:get(pages, X) || X <- Ws]),
                        sideways_right => lists:sum([maps:get(sideways_right, X) || X <- Ws]), sideways => lists:sum([maps:get(sideways, X) || X <- Ws])} end,
    R = #{run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second))), runs_per_set => Runs,
          engine => <<"muse-spark-1.3">>, effort => <<"low">>, edge => Sum(edge), degrees => Sum(degrees), asks => All},
    ok = file:write_file(Out, json:encode(R)),
    io:format("edge ~p~ndegrees ~p~n", [Sum(edge), Sum(degrees)]).

ask(Way, Key, Pages, Small, Want, Set, Run) ->
    T0 = erlang:monotonic_time(millisecond),
    Got = case Way of
        edge -> case witness_photo:orient(Key, Pages, #{small => Small}) of
                    {ok, Turns, C0, N0} -> {[maps:get(N, Turns, 0) || #{n := N} <- Pages], C0, N0};
                    E -> {error, E}
                end;
        degrees -> degrees(Key, Pages, Small)
    end,
    Ms = erlang:monotonic_time(millisecond) - T0,
    case Got of
        {error, Why} -> #{way => Way, set => Set, run => Run, error => iolist_to_binary(io_lib:format("~0p", [Why])), right => 0, pages => length(Want), sideways_right => 0, sideways => length([W || W <- Want, W =/= 0])};
        {Turned, Cost, Count} ->
            Pairs = lists:zip(Want, Turned),
            #{way => Way, set => Set, run => Run, want => Want, got => Turned, ms => Ms, cost_usd => Cost, questions_counted => Count,
              right => length([1 || {W, G} <- Pairs, W =:= G]), pages => length(Pairs),
              sideways_right => length([1 || {W, G} <- Pairs, W =/= 0, W =:= G]), sideways => length([1 || {W, _} <- Pairs, W =/= 0])}
    end.

%% the first version's question, kept here only to measure it
degrees(Key, Pages, Small) ->
    Images = lists:append([[#{type => input_text, text => iolist_to_binary(["Page ", integer_to_list(N), ":"])},
                            #{type => input_image, image_url => <<"data:image/jpeg;base64,", (base64:encode(element(2, {ok, _} = Small(Url))))/binary>>}]
                           || #{n := N, url := Url} <- Pages]),
    Ask = <<"Each photo below is one page of a student's exam paper, labelled with its page number. A page may have been "
            "photographed sideways or upside down. For each page, say how many degrees the photo must be turned clockwise so "
            "the printed text reads normally: 0, 90, 180 or 270. Answer with JSON only: {\"pages\": [{\"n\": 1, \"turn\": 0}]}">>,
    case witness_meta:read_content(Key, <<"muse-spark-1.3">>, [#{type => input_text, text => Ask} | Images], #{effort => <<"low">>}) of
        {ok, Text, Usage} ->
            Found = case re:run(Text, <<"\{.*\}">>, [dotall, {capture, first, binary}]) of
                {match, [J]} -> try json:decode(J) of #{<<"pages">> := L} when is_list(L) -> L; _ -> [] catch _:_ -> [] end;
                nomatch -> []
            end,
            ByN = maps:from_list([{N, D} || #{<<"n">> := N, <<"turn">> := D} <- Found, lists:member(D, [0, 90, 180, 270])]),
            {[maps:get(N, ByN, 0) || #{n := N} <- Pages], witness_meta:cost({tokens, <<"muse-spark-1.3">>}, Usage), null};
        E -> {error, E}
    end.
