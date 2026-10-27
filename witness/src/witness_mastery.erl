%%%-------------------------------------------------------------------
%%% witness_mastery — what happens to a question after the paper is released (hackathon, 2026-10-27).
%%%
%%% Owner (27 Oct):
%%%   - one mastery level per question not mastered, generated as Master any topic generates a level;
%%%   - "the student has access to teacher, they can still ask the teacher in case they get stuck";
%%%   - verification is the TEACHER'S choice, never automatic and never required: explain back to Lo, a fresh question on
%%%     paper, explain back to the teacher; the student sees only what the teacher asked for;
%%%   - "the badge is issued by the teacher after review" of all the activity and the answers.
%%%
%%% Each question of a released paper may carry `mastery`:
%%%   #{status => building | ready | completed | badge | not_yet,
%%%     path, built_ms, completed_ms,
%%%     asks => #{lo, paper, teacher} (booleans, the teacher's),
%%%     explain => #{lo => #{text, verdict, at}, teacher => #{text, at}},
%%%     thread => [#{from => student | teacher, text, at}],
%%%     badge => #{issued, note, at}}
%%%
%%% Every function here is pure: a question in, the question changed (or a refusal) out. witness_api does the reading,
%%% saving and checking who may do what.
%%%-------------------------------------------------------------------
-module(witness_mastery).
-export([event/3, verify/2, explain/4, ask/3, reply/3, badge/3, view/2, needs/1, judge_prompt/2, judge/1]).

-define(MAX_TEXT, 2000).
-define(MAX_THREAD, 60).

needs(Q) -> witness_mark:needs_level(Q#{result => maps:get(teacher_result, Q, maps:get(result, Q))}).

m(Q) -> maps:get(mastery, Q, #{status => <<"not_started">>}).
put_m(Q, M) -> Q#{mastery => M}.

%% The student's phone: the level was built (with its path on that phone) or played to the end.
event(Q, <<"built">>, #{path := Path, at := At}) -> put_m(Q, (m(Q))#{status => keep(m(Q), <<"ready">>), path => Path, built_ms => At});
event(Q, <<"completed">>, #{at := At}) ->
    M = m(Q),
    case maps:get(status, M) of
        S when S =:= <<"badge">> -> Q;
        _ -> put_m(Q, M#{status => <<"completed">>, completed_ms => At})
    end;
event(_, _, _) -> {error, bad_event}.

%% a level built again never takes back a badge or a completion
keep(#{status := S}, _) when S =:= <<"completed">>; S =:= <<"badge">>; S =:= <<"not_yet">> -> S;
keep(_, New) -> New.

%% The teacher: which checks they want, if any.
verify(Q, Asks) ->
    A = #{lo => maps:get(<<"lo">>, Asks, false) =:= true, paper => maps:get(<<"paper">>, Asks, false) =:= true,
          teacher => maps:get(<<"teacher">>, Asks, false) =:= true},
    put_m(Q, (m(Q))#{asks => A}).

%% The student: explain back, only to whom the teacher asked. Explaining to Lo carries Spark's verdict (judge/1).
explain(Q, To, Text0, #{at := At} = Ctx) ->
    Text = clean(Text0),
    M = m(Q),
    Asked = maps:get(asks, M, #{}),
    Key = case To of <<"lo">> -> lo; <<"teacher">> -> teacher; _ -> none end,
    case {Key, Text} of
        {none, _} -> {error, bad_to};
        {_, <<>>} -> {error, empty};
        _ ->
            case maps:get(Key, Asked, false) of
                false -> {error, not_asked};
                true ->
                    Entry0 = #{text => Text, at => At},
                    Entry = case {Key, maps:get(verdict, Ctx, undefined)} of {lo, V} when is_map(V) -> Entry0#{verdict => V}; _ -> Entry0 end,
                    put_m(Q, M#{explain => (maps:get(explain, M, #{}))#{Key => Entry}})
            end
    end.

%% Ask my teacher, from any step; the teacher answers in the same thread.
ask(Q, Text, At) -> say(Q, student, Text, At).
reply(Q, Text, At) -> say(Q, teacher, Text, At).

say(Q, Who, Text0, At) ->
    case clean(Text0) of
        <<>> -> {error, empty};
        Text ->
            M = m(Q),
            Thread = lists:sublist(maps:get(thread, M, []) ++ [#{from => Who, text => Text, at => At}], ?MAX_THREAD),
            put_m(Q, M#{thread => Thread})
    end.

%% The teacher issues the badge (or not yet, with a note): only for a question that was to master.
badge(Q, Issue, #{note := Note0, at := At}) ->
    case needs(Q) of
        false -> {error, not_to_master};
        true ->
            Note = clean(Note0),
            M = m(Q),
            put_m(Q, M#{status => case Issue of true -> <<"badge">>; false -> <<"not_yet">> end,
                        badge => #{issued => Issue =:= true, note => Note, at => At}})
    end.

%% What each side sees: the teacher everything; the student their own level's state, the checks asked of them,
%% the thread and the badge, never the verdict text the teacher reads before deciding.
view(Q, teacher) -> m(Q);
view(Q, student) ->
    M = m(Q),
    Explain = maps:map(fun(_, E) -> maps:without([verdict], E) end, maps:get(explain, M, #{})),
    (maps:with([status, path, asks, thread, badge], M))#{explained => maps:keys(Explain)}.

%% Spark judges an explanation back to Lo against the diagnosis: the idea in the student's own words, not the lesson's.
judge_prompt(Q, Text) ->
    unicode:characters_to_binary([
        "A student explains, in their own words, the idea they got wrong on an exam question, after a lesson on it.\n",
        "THE MISCONCEPTION THEY HAD: ", str(maps:get(diagnosis, Q, <<>>)), "\n",
        "THEIR EXPLANATION: ", Text, "\n\n",
        "Does the explanation show they now understand the right idea and why their first way was wrong? Repeating words ",
        "without the reason is not enough. Return JSON only: {\"understood\":true,\"why\":\"one sentence\",",
        "\"next\":\"one question Lo should ask next if not understood, else empty\"}"]).

judge(Text) ->
    case witness_mark_json(Text) of
        #{<<"understood">> := U} = J -> {ok, #{understood => U =:= true, why => str(maps:get(<<"why">>, J, <<>>)), next => str(maps:get(<<"next">>, J, <<>>))}};
        _ -> {error, no_verdict}
    end.

witness_mark_json(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

clean(B) when is_binary(B) -> string:slice(string:trim(B), 0, ?MAX_TEXT);
clean(_) -> <<>>.
str(B) when is_binary(B) -> B;
str(_) -> <<>>.
