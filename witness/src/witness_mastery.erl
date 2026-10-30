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
%%%     check => #{passes, problems} (the kept level's own self-check; the teacher sees it, the student does not),
%%%     asks => #{lo, paper, teacher} (booleans, the teacher's), and fresh => the fresh question's text when paper,
%%%     fresh => #{sitting, status => uploading | marked | failed, at, question} (the paper watched again),
%%%     explain => #{lo => #{text, verdict, at, audio?}, teacher => #{text, at, audio?}} (audio: the recording, kept for the teacher),
%%%     thread => [#{from => student | teacher, text, at}],
%%%     activity => [#{title, right, asked, at}] (each lesson of the level the student finished),
%%%     recommendation => #{recommend => issue | not_yet, why, at} (Muse Spark's, for the teacher only),
%%%     badge => #{issued, note, at},
%%%     challenge, past (the teacher's new challenge: witness_challenge)}
%%%
%%% Every function here is pure: a question in, the question changed (or a refusal) out. witness_api does the reading,
%%% saving and checking who may do what.
%%%-------------------------------------------------------------------
-module(witness_mastery).
-export([event/3, approve/2, ask/4, verify/2, explain/4, ask/3, reply/3, badge/3, view/2, needs/1, judge_prompt/2, judge/1, fresh_started/3, fresh_marked/3,
         recommended/3]).

-define(MAX_TEXT, 2000).
-define(MAX_THREAD, 60).
-define(MAX_ACTIVITY, 24).

needs(Q) -> witness_mark:needs_level(Q#{result => maps:get(teacher_result, Q, maps:get(result, Q))}).

m(Q) -> maps:get(mastery, Q, #{status => <<"not_started">>}).
put_m(Q, M) -> Q#{mastery => M}.

%% The student's phone: the level was built (with its path on that phone) or played to the end.
event(Q, <<"built">>, #{path := Path, at := At} = Ctx) ->
    M = maps:remove(check, m(Q)),
    Check = case check(maps:get(check, Ctx, null)) of none -> #{}; C -> #{check => C} end,
    %% 28 Oct audit (the plan's step 4): the exam's teacher may look at each level first; then it waits, held.
    %% 30 Oct (judges' panel: a level that failed its self-check still reached the student): a level Muse Wonder did
    %% not pass, or never checked, waits for the teacher whatever the exam's setting; the teacher sees what it found.
    Passed = case Check of #{check := #{passes := true}} -> true; _ -> false end,
    Status = case maps:get(preview, Ctx, false) orelse not Passed of true -> keep(M, <<"held">>); false -> keep(M, <<"ready">>) end,
    Level = case outline(maps:get(level, Ctx, null)) of none -> #{}; L -> #{level => L} end,
    put_m(Q, maps:merge(maps:merge(M#{status => Status, path => Path, built_ms => At}, Check), Level));
%% 30 Oct (judges' panel: "completed" was the phone's word alone): a level counts as completed only once the server
%% has seen each of its lessons finished (the `lesson` events), when it knows the level's lessons.
event(Q, <<"completed">>, #{at := At}) ->
    M = m(Q),
    Lessons = case maps:get(level, M, none) of #{lessons := Ls} -> length(Ls); _ -> 0 end,
    Seen = length(lists:usort([T || #{title := T} <- maps:get(activity, M, [])])),
    case maps:get(status, M) of
        S when S =:= <<"badge">> -> Q;
        _ when Seen < Lessons -> {error, lessons_left};
        _ -> put_m(Q, M#{status => <<"completed">>, completed_ms => At})
    end;
%% 28 Oct re-audit (the plan's badge review: "the level activity and answers"): each lesson the student finishes in
%% the level, with how many of its questions they had right first time. It never changes the level's state.
event(Q, <<"lesson">>, #{at := At, lesson := #{} = L}) ->
    case clean(maps:get(<<"title">>, L, <<>>)) of
        <<>> -> {error, bad_event};
        Title ->
            M = m(Q),
            Entry = #{title => Title, right => count(maps:get(<<"right">>, L, null)), asked => count(maps:get(<<"asked">>, L, null)), at => At},
            put_m(Q, M#{activity => lists:sublist(maps:get(activity, M, []) ++ [Entry], ?MAX_ACTIVITY)})
    end;
event(_, _, _) -> {error, bad_event}.

count(N) when is_integer(N), N >= 0, N < 1000 -> N;
count(_) -> null.

%% The teacher lets a held level reach the student.
approve(Q, At) ->
    M = m(Q),
    case maps:get(status, M) of
        <<"held">> -> put_m(Q, M#{status => <<"ready">>, approved_ms => At});
        _ -> {error, not_held}
    end.

%% What the teacher reads of a level: its title and each lesson with its steps (short, capped).
outline(#{<<"title">> := T, <<"lessons">> := Ls}) when is_binary(T), is_list(Ls) ->
    #{title => clean(T), lessons => [#{title => clean(maps:get(<<"title">>, L, <<>>)),
                                       beats => [clean(B) || B <- lists:sublist(listy(maps:get(<<"beats">>, L, [])), 8), is_binary(B)]}
                                     || L <- lists:sublist(Ls, 5), is_map(L)]};
outline(_) -> none.

%% the phone's verdict on the level it kept: passes, and what Wonder still found (a few short lines)
check(#{<<"passes">> := P} = C) when is_boolean(P) ->
    Problems = [clean(X) || X <- lists:sublist(listy(maps:get(<<"problems">>, C, [])), 6), is_binary(X)],
    #{passes => P, problems => [X || X <- Problems, X =/= <<>>]};
check(_) -> none.
listy(L) when is_list(L) -> L;
listy(_) -> [].

%% a level built again never takes back a badge or a completion
keep(#{status := S}, _) when S =:= <<"completed">>; S =:= <<"badge">>; S =:= <<"not_yet">> -> S;
keep(_, New) -> New.

%% The teacher: which checks they want, if any.
verify(Q, Asks) ->
    Paper = maps:get(<<"paper">>, Asks, false) =:= true,
    A0 = #{lo => maps:get(<<"lo">>, Asks, false) =:= true, paper => Paper, teacher => maps:get(<<"teacher">>, Asks, false) =:= true},
    A = case {Paper, clean(maps:get(<<"fresh">>, Asks, <<>>))} of {true, F} when F =/= <<>> -> A0#{fresh => F}; _ -> A0 end,
    put_m(Q, (m(Q))#{asks => A}).

%% The student films the fresh question the teacher set (only when the teacher asked for one and wrote it).
fresh_started(Q, Sitting, At) ->
    M = m(Q),
    case maps:get(asks, M, #{}) of
        #{paper := true, fresh := F} when F =/= <<>> -> put_m(Q, M#{fresh => #{sitting => Sitting, status => <<"uploading">>, at => At}});
        _ -> {error, not_asked}
    end.

%% Its marking comes back onto the question it checks: the status, and the marked question for the teacher.
fresh_marked(Q, Status, Marked) ->
    M = m(Q),
    F = maps:get(fresh, M, #{}),
    put_m(Q, M#{fresh => case Marked of #{} = X when map_size(X) > 0 -> F#{status => Status, question => X}; _ -> F#{status => Status} end}).

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
                    %% 28 Oct re-audit (the plan: "by voice or in writing"; owner: keep the recording for the teacher)
                    Entry0 = case maps:get(audio, Ctx, undefined) of A when is_binary(A) -> #{text => Text, at => At, audio => A, spoken => true}; _ -> #{text => Text, at => At} end,
                    Entry = case {Key, maps:get(verdict, Ctx, undefined)} of {lo, V} when is_map(V) -> Entry0#{verdict => V}; _ -> Entry0 end,
                    put_m(Q, M#{explain => (maps:get(explain, M, #{}))#{Key => Entry}})
            end
    end.

%% Ask my teacher, from any step; the teacher answers in the same thread.
ask(Q, Text, At) -> say(Q, student, Text, At).
%% 28 Oct audit (the plan: "a button on every step, with the exact moment attached"): asked from inside the level, the
%% question carries where (the lesson, the step and what the student answered there).
ask(Q, Text, At, Where) ->
    case {ask(Q, Text, At), clean(Where)} of
        {{error, _} = E, _} -> E;
        {Q1, <<>>} -> Q1;
        {Q1, W} -> M = m(Q1), [Last | Rest] = lists:reverse(maps:get(thread, M)), put_m(Q1, M#{thread => lists:reverse([Last#{where => W} | Rest])})
    end.
reply(Q, Text, At) -> say(Q, teacher, Text, At).

say(Q, Who, Text0, At) ->
    case clean(Text0) of
        <<>> -> {error, empty};
        Text ->
            M = m(Q),
            Thread = lists:sublist(maps:get(thread, M, []) ++ [#{from => Who, text => Text, at => At}], ?MAX_THREAD),
            put_m(Q, M#{thread => Thread})
    end.

%% The teacher issues the badge (or not yet, with a note): only for a question that was to master. 29 Oct (owner): the
%% badge replaces a level's certificate, so it is issued only once the student completed the level (every lesson's
%% questions and its flashcards, the checkpoint the app holds before a level counts as done); the game is optional.
badge(Q, Issue, #{note := Note0, at := At}) ->
    case {needs(Q), Issue =:= true andalso not is_map_key(completed_ms, m(Q))} of
        {false, _} -> {error, not_to_master};
        {_, true} -> {error, not_completed};
        {true, false} ->
            Note = clean(Note0),
            M = m(Q),
            put_m(Q, M#{status => case Issue of true -> <<"badge">>; false -> <<"not_yet">> end,
                        badge => #{issued => Issue =:= true, note => Note, at => At}})
    end.

%% Muse Spark's recommendation for the teacher's decision (witness_recommend), kept with when it was made.
recommended(Q, Rec, At) -> put_m(Q, (m(Q))#{recommendation => Rec#{at => At}}).

%% What each side sees: the teacher everything; the student their own level's state, the checks asked of them,
%% the thread and the badge, never the verdict text the teacher reads before deciding.
view(Q, teacher) -> m(Q);
view(Q, student) ->
    M = m(Q),
    Explain = maps:map(fun(_, E) -> maps:without([verdict, audio], E) end, maps:get(explain, M, #{})),
    LoNext = case maps:get(explain, M, #{}) of
        #{lo := #{verdict := #{understood := false, next := Next}}} when Next =/= <<>> -> #{lo_next => Next};
        _ -> #{}
    end,
    Fresh = case M of #{fresh := #{status := FS}} -> #{fresh => #{status => FS}}; _ -> #{} end,     %% the marks are the teacher's to give
    maps:merge(maps:merge(maps:merge((maps:with([status, path, asks, thread, badge, world], M))#{explained => maps:keys(Explain)}, LoNext), Fresh),
               witness_challenge:view(M)).

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
