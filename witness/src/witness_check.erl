%%%-------------------------------------------------------------------
%%% witness_check — a mastery level checks itself before it reaches the student (hackathon, 2026-10-27).
%%%
%%% Owner (27 Oct): "Before the level reaches the student, an agent plays it once as a student who still has the
%%% misconception and once as one who doesn't, and repairs it if the results come out wrong."
%%%
%%% Muse Wonder plays the level twice: as the student who holds the misconception named in the diagnosis (the level's
%%% checks must catch them: at least one check answered their way comes out wrong, and the lessons show why), and as a
%%% student who has the idea right (every check passes). A level passes only when both come out as they should; when
%%% not, it names what to change, lesson by lesson, for the builder's next writing.
%%%
%%%   prompt(Input) -> binary        Input = #{question, working, diagnosis, focus, level => #{title, lessons}}
%%%   parse(ModelText) -> {ok, Verdict} | {error, no_verdict}
%%%       Verdict = #{passes, caught, cleared, problems => [#{lesson, fix}], why}
%%%   run(Key, Input) -> {ok, Verdict, CostUsd} | {error, Why}
%%%-------------------------------------------------------------------
-module(witness_check).
-export([prompt/1, parse/1, run/2]).

-define(MODEL, <<"muse-wonder-1.0">>).

prompt(In) ->
    Level = maps:get(level, In, #{}),
    Lessons = [unicode:characters_to_binary(io_lib:format("LESSON ~p: ~ts~n~ts~n", [I, maps:get(title, L, <<>>),
                 lists:join(<<"\n">>, [<<"- ", (str(B))/binary>> || B <- maps:get(beats, L, [])])]))
               || {I, L} <- lists:zip(lists:seq(1, length(maps:get(lessons, Level, []))), maps:get(lessons, Level, []))],
    unicode:characters_to_binary([
        "You check a mastery level before a student sees it. It was written for ONE student who did not master one exam ",
        "question. Play the level twice, honestly, the way each student would really answer every question and check in it.\n\n",
        "THE QUESTION: ", str(maps:get(question, In, <<>>)), "\n",
        "HOW THE STUDENT WORKED IT:\n", str(maps:get(working, In, <<>>)), "\n",
        "THE MISCONCEPTION: ", str(maps:get(diagnosis, In, <<>>)), "\n",
        case str(maps:get(focus, In, <<>>)) of <<>> -> ""; F -> ["THE TEACHER'S FOCUS NOTE: ", F, "\n"] end,
        "\nTHE LEVEL: ", str(maps:get(title, Level, <<>>)), "\n", Lessons, "\n",
        "1. As the student who STILL HOLDS the misconception: answer every check their way. Does the level catch them ",
        "(at least one of their answers comes out wrong, and a lesson shows them why)? That is \"caught\".\n",
        "2. As a student who HAS THE IDEA RIGHT: answer every check. Do they pass all of them? That is \"cleared\".\n",
        "3. Does lesson 1 run the student's own step in a real-world setting, does the level end with a REAL TASK done at work ",
        "with this idea (so the student leaves able to do it, not only answer it), and does it stay on this one idea? ",
        "Does it follow the teacher's note?\n",
        "4. Is LESSON 3 a real task someone does at work with this idea (pricing a sale, fixing a stock order, sizing a part, ",
        "checking a report), done in the lesson, with a title that names that task? An exercise, a worked example, a ",
        "counterexample, a quiz or a review is not a work task. That is \"work_task\".\n",
        "The level passes only when caught, cleared and work_task are all true and 3 holds. When it does not pass, name ",
        "what to change, lesson by lesson, so a writer can fix it in one pass.\n",
        "Return JSON only: {\"caught\":true,\"cleared\":true,\"on_idea\":true,\"work_task\":true,\"why\":\"one sentence\",",
        "\"problems\":[{\"lesson\":1,\"fix\":\"what to change\"}]}"]).

parse(Text) ->
    case decode(Text) of
        #{} = M when is_map_key(<<"caught">>, M); is_map_key(<<"cleared">>, M) ->
            Caught = maps:get(<<"caught">>, M, false) =:= true,
            Cleared = maps:get(<<"cleared">>, M, false) =:= true,
            OnIdea = maps:get(<<"on_idea">>, M, true) =/= false,
            %% 28 Oct audit: a fractions level passed with lesson 3 "Digit Cancel Counterexample"; the work task is its
            %% own answer now, and a verdict that does not give it does not pass
            WorkTask = maps:get(<<"work_task">>, M, false) =:= true,
            Problems = [#{lesson => case maps:get(<<"lesson">>, P, null) of N when is_integer(N) -> N; _ -> null end,
                          fix => str(maps:get(<<"fix">>, P, <<>>))}
                        || P <- list(maps:get(<<"problems">>, M, [])), is_map(P), str(maps:get(<<"fix">>, P, <<>>)) =/= <<>>],
            Passes = Caught andalso Cleared andalso OnIdea andalso WorkTask,
            {ok, #{passes => Passes, caught => Caught, cleared => Cleared, on_idea => OnIdea, work_task => WorkTask, why => str(maps:get(<<"why">>, M, <<>>)),
                   %% a level that fails with nothing named to change still gets one thing to change
                   problems => case {Passes, Problems} of
                                   {false, []} -> [#{lesson => null, fix => <<"Make the level's checks catch the misconception and let the right idea pass.">>}];
                                   _ -> Problems
                               end}};
        _ -> {error, no_verdict}
    end.

run(Key, In) ->
    %% 27 Oct, live: at 4,000 tokens Wonder thought for 3,998 of them and wrote no verdict (status incomplete); it reasons
    %% at medium effort with room to answer.
    Req = #{model => ?MODEL, max_output_tokens => 16000, reasoning => #{effort => <<"medium">>},
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(In)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, #{<<"status">> := <<"incomplete">>}} -> {error, incomplete};
        {ok, R} ->
            Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
            case parse(witness_meta:text_of(R)) of
                {ok, V} -> {ok, V, Cost};
                E -> E
            end;
        E -> E
    end.

decode(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

str(B) when is_binary(B) -> B;
str(L) when is_list(L) -> unicode:characters_to_binary(L);
str(_) -> <<>>.
list(L) when is_list(L) -> L;
list(_) -> [].
