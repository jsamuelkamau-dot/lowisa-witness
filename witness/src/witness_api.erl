%%%-------------------------------------------------------------------
%%% witness_api — the Witness endpoints (hackathon, 2026-10-27).
%%%
%%% A teacher's exam is a PILE: its questions, the teacher's mark scheme and level, and one SITTING per paper.
%%%
%%%   POST pile                     {title, level?, questions?, scheme?}  -> 201 {id}
%%%   GET  piles                                                            -> 200 {piles: [summary]}
%%%   GET  pile/<id>                -> 200 {pile, sittings: [summary], queue: [{sitting, n, ...}]}
%%%        the queue is every question still to look at: least certain first, wrong thinking and "not yet" first
%%%   POST pile/<id>/release        -> 200 {released}  marks go to the students; failed questions become mastery work
%%%   POST join                     {code}  -> 200 {pile: {title, level}}   a student checks the teacher's join code
%%%   GET  mine                     -> 200 {papers: [...]}   a student's own papers in teachers' exams (marks once released)
%%%   POST sitting/start            {mime, size, pile? | code?, student?}  -> 201 {id, put, headers, expiresIn}
%%%        with `code` the paper is the teacher's (in their pile) and the student keeps a pointer to it
%%%        the phone uploads the clip straight to the signed URL
%%%   POST sitting/<id>/mark        {fps?, questions?, scheme?, level?}  -> 202 {status: "marking"}
%%%        a sitting in a pile is marked with the pile's questions and scheme
%%%   POST sitting/<id>/review      {n, result?, marks?, focus?}  -> 200 {question}   the teacher's word, kept beside
%%%        the model's (never over it), and the focus note for that question's mastery level
%%%   GET  sitting/<id>             -> 200 {id, status, result?}
%%%   POST check                    {question, working, diagnosis, focus?, level: {title, lessons: [{title, beats}]}}
%%%                                 -> 202 {id}   Muse Wonder plays a mastery level as both students (witness_check)
%%%   GET  check/<id>               -> 200 {status: "checking" | "done" | "failed", verdict?}
%%%   POST mastery/<sitting>/<n>/<action>   one question's life after release (witness_mastery):
%%%        student: event {event: built|completed, path?, check?: {passes, problems}}, explain {to: lo|teacher, text}, ask {text},
%%%                 fresh {mime, size} -> {fresh: {id, put, headers}}: the teacher's fresh question on paper, watched again
%%%                 (a one-question sitting the teacher owns; marked with sitting/<id>/mark, it comes back onto the question)
%%%        teacher: verify {lo, paper, teacher, fresh?}, reply {text}, badge {issue, note}
%%%   POST sitting/<id>/answer      {k, audio? (base64), mime?, text?}  the student answers the examiner's question k,
%%%                                 out loud (Voice Transcribe) or in writing; Spark judges it against their own step
%%%   POST sitting/<id>/draw        {n} -> 202   Muse Image draws question n's corrected step (the teacher's)
%%%   POST sitting/<id>/voice       {n, audio, mime} -> {text}   the teacher's spoken comment, written down as feedback
%%%   GET  sitting/<id>/asset/<f>   -> {url}   a still of the desk or a drawn step (the teacher; the student once released)
%%%   GET  sitting/<id>/proof       -> the Proof of Thinking record (witness_proof)
%%%   GET  pile/<id>/measure        -> the exam's measured numbers (witness_measure)
%%%   A pile with kind "practical" marks a practical task: its questions are the procedure's steps.
%%%   A pile with engine "open" is marked by Muse Spark Open on open weights (witness_open) when the host has an
%%%   endpoint for it (Host:open_engine/0), else by Muse Spark; the result names the engine that marked it.
%%%   When a paper is marked Witness also keeps a still at each moment that matters and Muse Wonder writes the
%%%   examiner's two questions about the student's own steps (witness_examiner).
%%%   POST design                   {requestId, messages: [system, user], reasoningEffort?, maxOutputTokens?}
%%%                                 -> 200 {success, text}   one design call of a mastery level, on Muse Spark, paid by
%%%                                 the learner through the host (a credit wall answers as the host's wall)
%%%
%%% route(Method, PathParts, Body, Uid, Host) -> {Status, Map}. Host implements witness_host; the caller has
%%% already checked the account may use Witness. An optional Host:marker/0 replaces the model calls in tests.
%%%-------------------------------------------------------------------
-module(witness_api).
-export([route/5, view/2, sitting_of/1, queue/1, summary/2]).

-define(MAX_BYTES, 500 * 1024 * 1024).
-define(MIMES, [<<"video/mp4">>, <<"video/quicktime">>]).
-define(MAX_PILE, 200).
-define(CODES, <<"witness-codes">>).

%% ---------------------------------------------------------------- piles
route(<<"POST">>, [<<"pile">>], B, Uid, Host) ->
    case clean(maps:get(<<"title">>, B, <<>>), 120) of
        <<>> -> refuse(400, <<"no_title">>, <<"Give the exam a name.">>);
        Title ->
            Id = new_id(),
            Code = new_code(Host),
            ok = Host:save(?CODES, {code, Code}, #{owner => Uid, pile => Id}),
            ok = Host:save(Uid, {pile, Id}, (sitting_of(B))#{title => Title, sittings => [], created_ms => now_ms(), code => Code}),
            {201, #{ok => true, id => Id, code => Code}}
    end;
route(<<"GET">>, [<<"piles">>], _B, Uid, Host) ->
    Ps = lists:sort(fun({_, A}, {_, B}) -> maps:get(created_ms, A, 0) >= maps:get(created_ms, B, 0) end, Host:list(Uid, pile)),
    {200, #{ok => true, piles => [#{id => Id, title => maps:get(title, P), papers => length(maps:get(sittings, P, [])), code => maps:get(code, P, <<>>),
                                    released => maps:is_key(released_ms, P)} || {Id, P} <- Ps]}};
route(<<"GET">>, [<<"pile">>, Id], _B, Uid, Host) ->
    case Host:load(Uid, {pile, Id}) of
        none -> refuse(404, <<"no_pile">>, <<"That exam isn't here.">>);
        {ok, P} ->
            Ss = [{S, R} || S <- maps:get(sittings, P, []), {ok, R} <- [Host:load(Uid, {sitting, S})]],
            {200, #{ok => true, pile => maps:without([sittings], P#{id => Id}),
                    sittings => [summary(S, R) || {S, R} <- Ss], queue => queue(Ss)}}
    end;
route(<<"POST">>, [<<"pile">>, Id, <<"release">>], _B, Uid, Host) ->
    case Host:load(Uid, {pile, Id}) of
        none -> refuse(404, <<"no_pile">>, <<"That exam isn't here.">>);
        {ok, P} ->
            Now = now_ms(),
            N = length([ok || S <- maps:get(sittings, P, []), {ok, R = #{status := <<"marked">>}} <- [Host:load(Uid, {sitting, S})],
                              ok =:= Host:save(Uid, {sitting, S}, R#{status => <<"released">>, released_ms => Now})]),
            ok = Host:save(Uid, {pile, Id}, P#{released_ms => Now}),
            {200, #{ok => true, released => N}}
    end;

%% ---------------------------------------------------------------- students
route(<<"POST">>, [<<"join">>], B, _Uid, Host) ->
    case by_code(maps:get(<<"code">>, B, null), Host) of
        {ok, _Owner, _PileId, P} -> {200, #{ok => true, pile => #{title => maps:get(title, P), level => maps:get(level, P, <<>>)}}};
        none -> refuse(404, <<"no_code">>, <<"That code doesn't match an exam. Check it with your teacher.">>)
    end;
route(<<"GET">>, [<<"mine">>], _B, Uid, Host) ->
    Papers = [mine_view(Id, M, Host) || {Id, M} <- Host:list(Uid, mine)],
    {200, #{ok => true, papers => [P || P <- Papers, P =/= none]}};

%% ---------------------------------------------------------------- sittings
route(<<"POST">>, [<<"sitting">>, <<"start">>], B, Uid0, Host) ->
    Mime = maps:get(<<"mime">>, B, <<"video/mp4">>),
    Size = maps:get(<<"size">>, B, 0),
    %% a join code puts the paper in the teacher's pile: the teacher owns the row, the student keeps a pointer
    {Uid, Pile, Student} = case maps:get(<<"code">>, B, null) of
        C when is_binary(C) ->
            case by_code(C, Host) of
                {ok, Owner, PileId0, PR0} -> {Owner, {ok, PR0}, {Uid0, PileId0}};
                none -> {Uid0, none, none}
            end;
        _ -> {Uid0, case maps:get(<<"pile">>, B, null) of P when is_binary(P) -> Host:load(Uid0, {pile, P}); _ -> no_pile end, none}
    end,
    case {lists:member(Mime, ?MIMES), is_integer(Size) andalso Size > 0 andalso Size =< ?MAX_BYTES, Pile} of
        {false, _, _} -> refuse(400, <<"bad_type">>, <<"Record the sitting as an MP4 or MOV video.">>);
        {_, false, _} -> refuse(400, <<"bad_size">>, <<"That recording is too long to send. Keep a sitting under an hour.">>);
        {_, _, none} -> refuse(404, <<"no_pile">>, <<"That exam isn't here.">>);
        {_, _, {ok, #{sittings := Have}}} when length(Have) >= ?MAX_PILE ->
            refuse(400, <<"pile_full">>, <<"This exam already holds 200 papers. Start another one.">>);
        _ ->
            Id = new_id(),
            case Host:put_url(Uid, Id, Mime, Size) of
                {ok, Url, Headers} ->
                    Row0 = #{status => <<"uploading">>, mime => Mime, size => Size, created_ms => now_ms(),
                             student => clean(maps:get(<<"student">>, B, <<>>), 80)},
                    PileId = case Student of {_, PI} -> PI; none -> maps:get(<<"pile">>, B, undefined) end,
                    Row1 = case Pile of
                        {ok, PR} ->
                            ok = Host:save(Uid, {pile, PileId}, PR#{sittings => maps:get(sittings, PR, []) ++ [Id]}),
                            Row0#{pile => PileId};
                        no_pile -> Row0
                    end,
                    Row = case Student of
                        {Sid, _} -> ok = Host:save(Sid, {mine, Id}, #{owner => Uid, pile => PileId, created_ms => now_ms()}), Row1#{student_uid => Sid};
                        none -> Row1
                    end,
                    ok = Host:save(Uid, {sitting, Id}, Row),
                    {201, #{ok => true, id => Id, put => Url, headers => Headers, expiresIn => 900}};
                {error, _} -> refuse(503, <<"storage">>, <<"Couldn't get the upload ready. Try again in a moment.">>)
            end
    end;
route(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], B, Uid0, Host) ->
    Uid = owner_of(Uid0, Id, Host),
    case Host:load(Uid, {sitting, Id}) of
        none -> refuse(404, <<"no_sitting">>, <<"That sitting isn't here.">>);
        {ok, #{status := <<"uploading">>} = Row} ->
            case Host:meta_key() of
                undefined -> refuse(503, <<"not_configured">>, <<"Marking isn't available right now.">>);
                Key ->
                    Sitting = case {maps:get(sitting_in, Row, undefined), maps:get(pile, Row, undefined)} of
                        {#{} = In, _} -> In;                                   %% a fresh question carries its own
                        {_, undefined} -> sitting_of(B);
                        {_, PileId} -> case Host:load(Uid, {pile, PileId}) of {ok, P} -> maps:with([questions, scheme, level, kind, engine], P); none -> sitting_of(B) end
                    end,
                    Fps = case maps:get(<<"fps">>, B, 30) of F when is_number(F), F > 0, F =< 240 -> F; _ -> 30 end,
                    ok = Host:save(Uid, {sitting, Id}, Row#{status => <<"marking">>, started_ms => now_ms()}),
                    ok = Host:run(fun() -> mark(Uid, Id, Key, Fps, Sitting, Host) end),
                    {202, #{ok => true, id => Id, status => <<"marking">>}}
            end;
        {ok, #{status := S}} -> {200, #{ok => true, id => Id, status => S}}
    end;
route(<<"POST">>, [<<"sitting">>, Id, <<"review">>], B, Uid, Host) ->
    case Host:load(Uid, {sitting, Id}) of
        {ok, #{result := #{questions := Qs} = R} = Row} ->
            N = maps:get(<<"n">>, B, null),
            case [Q || Q = #{n := Qn} <- Qs, Qn =:= N] of
                [] -> refuse(404, <<"no_question">>, <<"That question isn't on this paper.">>);
                [Q | _] ->
                    Q1 = review(Q, B),
                    %% the seconds the paper was open at the desk since the last save: the pilot's time per paper
                    Desk = case maps:get(<<"desk_s">>, B, null) of D when is_number(D), D >= 0, D < 7200 -> #{desk_s => maps:get(desk_s, Row, 0) + D}; _ -> #{} end,
                    ok = Host:save(Uid, {sitting, Id}, maps:merge(Row#{result => R#{questions => [case X of #{n := N} -> Q1; _ -> X end || X <- Qs]}}, Desk)),
                    {200, #{ok => true, question => Q1}}
            end;
        {ok, _} -> refuse(409, <<"not_marked">>, <<"This paper isn't marked yet.">>);
        none -> refuse(404, <<"no_sitting">>, <<"That sitting isn't here.">>)
    end;
route(<<"GET">>, [<<"sitting">>, Id], _B, Uid, Host) ->
    case Host:load(Uid, {sitting, Id}) of
        none -> refuse(404, <<"no_sitting">>, <<"That sitting isn't here.">>);
        {ok, Row} -> {200, view(Id, Row)}
    end;
%% ---------------------------------------------------------------- the examiner, the drawn step, the spoken comment
route(<<"POST">>, [<<"sitting">>, Id, <<"answer">>], B, Uid, Host) ->
    Owner = owner_of(Uid, Id, Host),
    case Host:load(Owner, {sitting, Id}) of
        {ok, #{examiner := #{asks := Asks} = Ex, result := #{questions := Qs}} = Row} ->
            Mine = maps:get(student_uid, Row, Owner) =:= Uid,
            K = maps:get(<<"k">>, B, null),
            case {Mine, [A || A = #{k := Ak} <- Asks, Ak =:= K]} of
                {false, _} -> refuse(404, <<"no_sitting">>, <<"That paper isn't here.">>);
                {_, []} -> refuse(404, <<"no_ask">>, <<"That question isn't on this paper.">>);
                {_, [#{answer := _} | _]} -> refuse(409, <<"answered">>, <<"You answered that one already.">>);
                {_, [Ask | _]} ->
                    case heard(Owner, B, Host) of
                        {error, Code} -> refuse(case Code of not_configured -> 503; _ -> 400 end, atom_to_binary(Code), answer_words(Code));
                        {Text, Spoken} ->
                            Q = case [X || X = #{n := N} <- Qs, N =:= maps:get(n, Ask)] of [X | _] -> X; [] -> #{} end,
                            Verdict = case (answer_judge(Host))(Host:meta_key(), Ask, Q, Text) of
                                {ok, V, Cost} -> Host:spend(Owner, <<"witness_examiner">>, Cost), V;
                                _ -> undefined
                            end,
                            Answer0 = #{text => Text, spoken => Spoken, at => now_ms()},
                            Answer = case Verdict of undefined -> Answer0; _ -> Answer0#{verdict => Verdict} end,
                            {ok, Fresh} = Host:load(Owner, {sitting, Id}),
                            FEx = maps:get(examiner, Fresh, Ex),
                            Asks1 = [case A of #{k := K} -> A#{answer => Answer}; _ -> A end || A <- maps:get(asks, FEx, Asks)],
                            ok = Host:save(Owner, {sitting, Id}, Fresh#{examiner => FEx#{asks => Asks1}}),
                            {200, #{ok => true, examiner => examiner_view(FEx#{asks => Asks1}, student)}}
                    end
            end;
        {ok, _} -> refuse(409, <<"no_examiner">>, <<"There are no questions about this paper yet.">>);
        none -> refuse(404, <<"no_sitting">>, <<"That paper isn't here.">>)
    end;
route(<<"POST">>, [<<"sitting">>, Id, <<"draw">>], B, Uid, Host) ->
    N = maps:get(<<"n">>, B, null),
    case {Host:load(Uid, {sitting, Id}), Host:meta_key()} of
        {none, _} -> refuse(404, <<"no_sitting">>, <<"That sitting isn't here.">>);
        {_, undefined} -> refuse(503, <<"not_configured">>, <<"Drawing isn't available right now.">>);
        {{ok, #{result := #{questions := Qs}} = Row}, Key} ->
            case [Q || Q = #{n := Qn} <- Qs, Qn =:= N] of
                [] -> refuse(404, <<"no_question">>, <<"That question isn't on this paper.">>);
                [Q | _] ->
                    ok = put_q(Uid, Id, N, fun(X) -> X#{drawn => #{status => <<"drawing">>}} end, Host),
                    Sitting = case Host:load(Uid, {pile, maps:get(pile, Row, <<>>)}) of {ok, P} -> maps:with([questions, level], P); none -> #{questions => []} end,
                    ok = Host:run(fun() ->
                        Name = <<Id/binary, "/drawn-", (integer_to_binary(N))/binary, ".webp">>,
                        Drawn = case catch (drawer(Host))(Key, Q, Sitting) of
                            {ok, #{bytes := Bytes, lines := Lines, changed := Ch}, Cost} ->
                                Host:spend(Uid, <<"witness_draw">>, Cost),
                                case Host:put_asset(Uid, Name, Bytes, <<"image/webp">>) of
                                    ok -> #{status => <<"done">>, asset => <<"drawn-", (integer_to_binary(N))/binary, ".webp">>, lines => Lines, changed => Ch, at => now_ms()};
                                    _ -> #{status => <<"failed">>}
                                end;
                            Why -> report(Host, <<"witness.draw_failed">>, Why), #{status => <<"failed">>}
                        end,
                        put_q(Uid, Id, N, fun(X) -> X#{drawn => Drawn} end, Host)
                    end),
                    {202, #{ok => true, n => N, drawn => #{status => <<"drawing">>}}}
            end;
        {{ok, _}, _} -> refuse(409, <<"not_marked">>, <<"This paper isn't marked yet.">>)
    end;
route(<<"POST">>, [<<"sitting">>, Id, <<"voice">>], B, Uid, Host) ->
    N = maps:get(<<"n">>, B, null),
    case Host:load(Uid, {sitting, Id}) of
        {ok, #{result := #{questions := Qs}}} ->
            case {[Q || Q = #{n := Qn} <- Qs, Qn =:= N], heard(Uid, B, Host)} of
                {[], _} -> refuse(404, <<"no_question">>, <<"That question isn't on this paper.">>);
                {_, {error, Code}} -> refuse(case Code of not_configured -> 503; _ -> 400 end, atom_to_binary(Code), answer_words(Code));
                {_, {Text, _}} ->
                    ok = put_q(Uid, Id, N, fun(X) -> X#{comment => #{text => Text, spoken => true, at => now_ms()}} end, Host),
                    {200, #{ok => true, n => N, text => Text}}
            end;
        {ok, _} -> refuse(409, <<"not_marked">>, <<"This paper isn't marked yet.">>);
        none -> refuse(404, <<"no_sitting">>, <<"That sitting isn't here.">>)
    end;
route(<<"GET">>, [<<"sitting">>, Id, <<"asset">>, File], _B, Uid, Host) ->
    Owner = owner_of(Uid, Id, Host),
    Safe = binary:match(File, [<<"/">>, <<"\\">>, <<"..">>]) =:= nomatch andalso
           (binary:longest_common_prefix([File, <<"still-">>]) =:= 6 orelse binary:longest_common_prefix([File, <<"drawn-">>]) =:= 6),
    case {Safe, Host:load(Owner, {sitting, Id})} of
        {true, {ok, Row}} when Owner =:= Uid; map_get(status, Row) =:= <<"released">> ->
            case Host:asset_url(Owner, <<Id/binary, "/", File/binary>>) of
                {ok, Url} -> {200, #{ok => true, url => Url}};
                _ -> refuse(404, <<"no_asset">>, <<"That picture isn't here.">>)
            end;
        _ -> refuse(404, <<"no_asset">>, <<"That picture isn't here.">>)
    end;
route(<<"GET">>, [<<"sitting">>, Id, <<"proof">>], _B, Uid, Host) ->
    Owner = owner_of(Uid, Id, Host),
    case Host:load(Owner, {sitting, Id}) of
        {ok, #{result := _} = Row} when Owner =:= Uid; map_get(status, Row) =:= <<"released">> ->
            Pile = case Host:load(Owner, {pile, maps:get(pile, Row, <<>>)}) of {ok, P} -> P; none -> #{} end,
            Viewer = case Owner =:= Uid of true -> teacher; false -> student end,
            {200, maps:merge(#{ok => true}, witness_proof:record(Id, Row, Pile, Viewer))};
        _ -> refuse(404, <<"no_sitting">>, <<"That paper isn't here.">>)
    end;
route(<<"GET">>, [<<"pile">>, Id, <<"measure">>], _B, Uid, Host) ->
    case Host:load(Uid, {pile, Id}) of
        none -> refuse(404, <<"no_pile">>, <<"That exam isn't here.">>);
        {ok, P} ->
            Ss = [{S, R} || S <- maps:get(sittings, P, []), {ok, R} <- [Host:load(Uid, {sitting, S})]],
            {200, maps:merge(#{ok => true, title => maps:get(title, P)}, witness_measure:exam(Ss))}
    end;

%% ---------------------------------------------------------------- a question after release
route(<<"POST">>, [<<"mastery">>, Sid, NBin, Action], B, Uid, Host) ->
    N = try binary_to_integer(NBin) catch _:_ -> -1 end,
    Owner = owner_of(Uid, Sid, Host),
    case Host:load(Owner, {sitting, Sid}) of
        none -> refuse(404, <<"no_sitting">>, <<"That paper isn't here.">>);
        {ok, Row} ->
            Role = if Owner =:= Uid -> teacher; true -> case maps:get(student_uid, Row, undefined) of Uid -> student; _ -> none end end,
            Released = maps:get(status, Row) =:= <<"released">>,
            Qs = case Row of #{result := #{questions := L}} -> L; _ -> [] end,
            case {Role, Released, [Q || Q = #{n := Qn} <- Qs, Qn =:= N]} of
                {none, _, _} -> refuse(404, <<"no_sitting">>, <<"That paper isn't here.">>);
                {student, false, _} -> refuse(409, <<"not_released">>, <<"Your teacher hasn't released this paper yet.">>);
                {_, _, []} -> refuse(404, <<"no_question">>, <<"That question isn't on this paper.">>);
                {_, _, [Q | _]} ->
                    Step = case {Role, Action} of
                        {student, <<"fresh">>} -> fresh_start(Q, B, #{owner => Owner, sid => Sid, n => N, uid => Uid, row => Row}, Host);
                        _ -> mastery_step(Role, Action, Q, B, Host)
                    end,
                    case Step of
                        {error, Code} -> refuse(case Code of forbidden -> 403; storage -> 503; _ -> 400 end, atom_to_binary(Code), mastery_words(Code));
                        _ ->
                            {Q1, Extra} = case Step of {#{} = Qx, #{} = E} -> {Qx, E}; Qx -> {Qx, #{}} end,
                            R = maps:get(result, Row),
                            ok = Host:save(Owner, {sitting, Sid}, Row#{result => R#{questions => [case X of #{n := N} -> Q1; _ -> X end || X <- Qs]}}),
                            {200, maps:merge(#{ok => true, n => N, mastery => witness_mastery:view(Q1, Role)}, Extra)}
                    end
            end
    end;

%% ---------------------------------------------------------------- a mastery level's design calls
route(<<"POST">>, [<<"design">>], B, Uid, Host) ->
    Msgs = [#{role => R, content => C} || #{<<"role">> := R, <<"content">> := C} <- list(maps:get(<<"messages">>, B, [])),
                                         lists:member(R, [<<"system">>, <<"user">>]), is_binary(C)],
    Size = lists:sum([byte_size(C) || #{content := C} <- Msgs]),
    case {Msgs, Size =< 200000} of
        {[], _} -> {400, #{success => false, error => <<"Nothing to design.">>}};
        {_, false} -> {413, #{success => false, error => <<"That is too much to send at once.">>}};
        _ ->
            Req = #{request_id => clean(maps:get(<<"requestId">>, B, <<>>), 120), messages => Msgs,
                    effort => case maps:get(<<"reasoningEffort">>, B, null) of E when E =:= <<"low">>; E =:= <<"medium">>; E =:= <<"high">> -> E; _ -> <<"low">> end,
                    max_tokens => case maps:get(<<"maxOutputTokens">>, B, null) of N when is_integer(N), N >= 1024, N =< 16000 -> N; _ -> 8000 end},
            case Host:design(Uid, Req) of
                {ok, Text} -> {200, #{success => true, text => Text}};
                {gate, Status, Body} -> {Status, Body};
                {error, _} -> {502, #{success => false, error => <<"The design call did not come back. Try again in a moment.">>}}
            end
    end;

%% ---------------------------------------------------------------- the level's self-check
route(<<"POST">>, [<<"check">>], B, Uid, Host) ->
    Level = maps:get(<<"level">>, B, null),
    Lessons = case Level of #{<<"lessons">> := Ls} when is_list(Ls) -> Ls; _ -> [] end,
    case {Lessons, Host:meta_key()} of
        {[], _} -> refuse(400, <<"no_level">>, <<"There is no level to check.">>);
        {_, undefined} -> refuse(503, <<"not_configured">>, <<"Checking isn't available right now.">>);
        {_, Key} ->
            In = #{question => clean(maps:get(<<"question">>, B, <<>>), 1000), working => clean(maps:get(<<"working">>, B, <<>>), 3000),
                   diagnosis => clean(maps:get(<<"diagnosis">>, B, <<>>), 600), focus => clean(maps:get(<<"focus">>, B, <<>>), 600),
                   level => #{title => clean(maps:get(<<"title">>, Level, <<>>), 160),
                              lessons => [#{title => clean(maps:get(<<"title">>, L, <<>>), 160),
                                            beats => [clean(Bt, 1500) || Bt <- lists:sublist(list(maps:get(<<"beats">>, L, [])), 12), is_binary(Bt)]}
                                          || L <- lists:sublist(Lessons, 6), is_map(L)]}},
            Id = new_id(),
            ok = Host:save(Uid, {check, Id}, #{status => <<"checking">>, created_ms => now_ms()}),
            ok = Host:run(fun() ->
                Out = try (checker(Host))(Key, In) catch C:R -> {error, {C, R}} end,
                case Out of
                    {ok, V, Cost} -> ok = Host:save(Uid, {check, Id}, #{status => <<"done">>, verdict => V}), Host:spend(Uid, <<"witness_check">>, Cost);
                    {error, Why} -> ok = Host:save(Uid, {check, Id}, #{status => <<"failed">>, reason => iolist_to_binary(io_lib:format("~0p", [Why]))})
                end
            end),
            {202, #{ok => true, id => Id, status => <<"checking">>}}
    end;
route(<<"GET">>, [<<"check">>, Id], _B, Uid, Host) ->
    case Host:load(Uid, {check, Id}) of
        none -> refuse(404, <<"no_check">>, <<"That check isn't here.">>);
        {ok, #{status := <<"done">>, verdict := V}} -> {200, #{ok => true, id => Id, status => <<"done">>, verdict => V}};
        {ok, #{status := S}} -> {200, #{ok => true, id => Id, status => S}}
    end;
route(_, _, _, _, _) -> refuse(404, <<"not_found">>, <<"No such Witness route.">>).

checker(Host) ->
    _ = code:ensure_loaded(Host),
    case erlang:function_exported(Host, checker, 0) of
        true -> Host:checker();
        false -> fun witness_check:run/2
    end.

mastery_step(student, <<"event">>, Q, B, _Host) ->
    witness_mastery:event(Q, maps:get(<<"event">>, B, <<>>), #{path => clean(maps:get(<<"path">>, B, <<>>), 200), at => now_ms(),
                                                             check => maps:get(<<"check">>, B, null)});
mastery_step(student, <<"explain">>, Q, B, Host) ->
    To = maps:get(<<"to">>, B, <<>>),
    Text = clean(maps:get(<<"text">>, B, <<>>), 2000),
    %% explaining back to Lo is judged at once against the diagnosis (Muse Spark); to the teacher it waits for them
    %% (only when the teacher asked for it: an explanation that is refused is never sent to a model)
    AskedLo = maps:get(lo, maps:get(asks, maps:get(mastery, Q, #{}), #{}), false) =:= true,
    Verdict = case {To, Text, AskedLo andalso Host:meta_key()} of
        {<<"lo">>, T, K} when T =/= <<>>, is_binary(K) orelse is_list(K) -> case (judger(Host))(K, Q, T) of {ok, V} -> V; _ -> undefined end;
        _ -> undefined
    end,
    witness_mastery:explain(Q, To, Text, #{at => now_ms(), verdict => Verdict});
mastery_step(student, <<"ask">>, Q, B, _Host) -> witness_mastery:ask(Q, maps:get(<<"text">>, B, <<>>), now_ms());
mastery_step(teacher, <<"verify">>, Q, B, _Host) -> witness_mastery:verify(Q, B);
mastery_step(teacher, <<"reply">>, Q, B, _Host) -> witness_mastery:reply(Q, maps:get(<<"text">>, B, <<>>), now_ms());
mastery_step(teacher, <<"badge">>, Q, B, _Host) ->
    witness_mastery:badge(Q, maps:get(<<"issue">>, B, false) =:= true, #{note => maps:get(<<"note">>, B, <<>>), at => now_ms()});
mastery_step(_, _, _, _, _) -> {error, forbidden}.

mastery_words(forbidden) -> <<"That isn't yours to do on this paper.">>;
mastery_words(bad_type) -> <<"Record it as an MP4 or MOV video, under an hour.">>;
mastery_words(storage) -> <<"Couldn't get the upload ready. Try again in a moment.">>;
mastery_words(not_asked) -> <<"Your teacher hasn't asked for that.">>;
mastery_words(empty) -> <<"Write something first.">>;
mastery_words(not_to_master) -> <<"This question was mastered already.">>;
mastery_words(_) -> <<"That can't be done here.">>.

%% The fresh question on paper: a sitting of one question in the teacher's store, pointing back at the question it
%% checks; the student's pointer to it is marked fresh so it never shows as a paper of its own.
fresh_start(Q, B, #{owner := O, sid := Sid, n := N, uid := U, row := Row}, Host) ->
    Mime = maps:get(<<"mime">>, B, <<"video/mp4">>),
    Size = maps:get(<<"size">>, B, 0),
    Id = new_id(),
    case {lists:member(Mime, ?MIMES) andalso is_integer(Size) andalso Size > 0 andalso Size =< ?MAX_BYTES,
          witness_mastery:fresh_started(Q, Id, now_ms())} of
        {_, {error, _} = E} -> E;
        {false, _} -> {error, bad_type};
        {true, Q1} ->
            case Host:put_url(O, Id, Mime, Size) of
                {ok, Url, Headers} ->
                    Level = case Host:load(O, {pile, maps:get(pile, Row, <<>>)}) of {ok, P} -> maps:get(level, P, <<"any level">>); none -> <<"any level">> end,
                    Text = maps:get(fresh, maps:get(asks, maps:get(mastery, Q1))),
                    ok = Host:save(O, {sitting, Id}, #{status => <<"uploading">>, mime => Mime, size => Size, created_ms => now_ms(),
                        student => maps:get(student, Row, <<>>), student_uid => U, for => #{sitting => Sid, n => N},
                        sitting_in => #{questions => [#{n => 1, text => Text, marks => marks(maps:get(out_of, Q, 2))}], level => Level,
                                        scheme => iolist_to_binary([<<"A fresh question the teacher set to check one idea the student had wrong: ">>,
                                                                    maps:get(diagnosis, Q, <<>>), <<" Judge the method as well as the answer.">>])}}),
                    ok = Host:save(U, {mine, Id}, #{owner => O, fresh => true, created_ms => now_ms()}),
                    {Q1, #{fresh => #{id => Id, put => Url, headers => Headers, expiresIn => 900}}};
                {error, _} -> {error, storage}
            end
    end.

%% A still of the desk at each moment that matters: where the thinking went wrong, else the question's last step.
stills(Uid, Id, Url, Result, Host) ->
    Moments = lists:sublist([{maps:get(n, Q), T} || Q <- maps:get(questions, Result, []), T <- [moment(Q)], is_number(T)], 8),
    Still = stiller(Host),
    lists:append([case catch Still(Url, T) of
                      {ok, Jpeg} ->
                          File = <<"still-", (integer_to_binary(N))/binary, ".jpg">>,
                          case Host:put_asset(Uid, <<Id/binary, "/", File/binary>>, Jpeg, <<"image/jpeg">>) of
                              ok -> [#{n => N, t => T, asset => File}];
                              _ -> []
                          end;
                      _ -> []
                  end || {N, T} <- Moments]).

moment(#{moment_s := M}) when is_number(M) -> M;
moment(Q) -> case [T || #{t := T} <- maps:get(steps, Q, []), is_number(T)] of [] -> null; Ts -> lists:max(Ts) end.

%% Muse Wonder writes the examiner's questions as soon as the paper is marked, while the student is still there.
examine(Uid, Id, Key, Sitting, Qs, Host) ->
    Ex = case catch (examiner(Host))(Key, Sitting, Qs) of
        {ok, Asks, Cost} -> Host:spend(Uid, <<"witness_examiner">>, Cost), #{status => <<"ready">>, asks => Asks, at => now_ms()};
        Why -> report(Host, <<"witness.examiner_failed">>, Why), #{status => <<"failed">>, asks => []}
    end,
    case Host:load(Uid, {sitting, Id}) of
        {ok, Row} -> Host:save(Uid, {sitting, Id}, Row#{examiner => Ex});
        none -> ok
    end.

examiner_view(Ex, teacher) -> Ex;
examiner_view(Ex, student) ->
    #{status => maps:get(status, Ex, <<"ready">>),
      asks => [(maps:with([k, n, ask, wrote], A))#{answered => maps:is_key(answer, A)} || A <- maps:get(asks, Ex, [])]}.

%% An answer is heard (audio, through Voice Transcribe) or read (text).
heard(Owner, B, Host) ->
    case {maps:get(<<"audio">>, B, null), clean(maps:get(<<"text">>, B, <<>>), 2000)} of
        {A, _} when is_binary(A), A =/= <<>> ->
            case {Host:meta_key(), try base64:decode(A) catch _:_ -> bad end} of
                {undefined, _} -> {error, not_configured};
                {_, bad} -> {error, bad_audio};
                {Key, Bytes} ->
                    case catch (hearer(Host))(Key, Bytes) of
                        {ok, T, Secs} ->
                            Host:spend(Owner, <<"witness_transcribe">>, witness_meta:cost(transcribe, Secs)),
                            case clean(T, 2000) of <<>> -> {error, not_heard}; Text -> {Text, true} end;
                        _ -> {error, not_heard}
                    end
            end;
        {_, <<>>} -> {error, empty};
        {_, Text} -> {Text, false}
    end.

answer_words(empty) -> <<"Say or write your answer first.">>;
answer_words(bad_audio) -> <<"That recording couldn't be read. Try again.">>;
answer_words(not_heard) -> <<"Nothing was heard. Speak a little closer, or write it.">>;
answer_words(not_configured) -> <<"Listening isn't available right now. Write your answer instead.">>;
answer_words(_) -> <<"That can't be done here.">>.

%% One question of a sitting changed in place (the row read again first, so a change made meanwhile is kept).
put_q(Uid, Id, N, F, Host) ->
    case Host:load(Uid, {sitting, Id}) of
        {ok, #{result := #{questions := Qs} = R} = Row} ->
            Host:save(Uid, {sitting, Id}, Row#{result => R#{questions => [case X of #{n := N} -> F(X); _ -> X end || X <- Qs]}});
        _ -> ok
    end.

%% Why something off the request failed, for the host's log (never shown to anyone): optional Host:report/2.
report(Host, Event, Why) ->
    _ = code:ensure_loaded(Host),
    case erlang:function_exported(Host, report, 2) of true -> catch Host:report(Event, Why), ok; false -> ok end.

seam(Host, Name, Default) ->
    _ = code:ensure_loaded(Host),
    case erlang:function_exported(Host, Name, 0) of true -> Host:Name(); false -> Default end.

open_engine(Host) -> _ = code:ensure_loaded(Host), case erlang:function_exported(Host, open_engine, 0) of true -> Host:open_engine(); false -> undefined end.
open_marker(Host) -> seam(Host, open_marker, fun witness_open:mark/3).
stiller(Host) -> seam(Host, stiller, case witness_media:available() of true -> fun witness_media:still/2; false -> fun(_, _) -> {error, no_ffmpeg} end end).
examiner(Host) -> seam(Host, examiner, fun witness_examiner:run/3).
answer_judge(Host) -> seam(Host, answer_judge, fun witness_examiner:judge_run/4).
drawer(Host) -> seam(Host, drawer, fun witness_draw:run/3).
hearer(Host) -> seam(Host, hearer, fun(Key, Bytes) -> case witness_media:wav(Bytes) of {ok, Wav} -> witness_meta:transcribe(Key, Wav); E -> E end end).

%% A fresh question's marking goes back onto the question it checks.
link_fresh(Uid, #{for := #{sitting := Sid, n := N}}, Status, Result, Host) ->
    case Host:load(Uid, {sitting, Sid}) of
        {ok, #{result := #{questions := Qs} = R} = Row} ->
            Marked = case Result of #{questions := [F | _]} -> F; _ -> #{} end,
            Qs1 = [case X of #{n := N} -> witness_mastery:fresh_marked(X, Status, Marked); _ -> X end || X <- Qs],
            ok = Host:save(Uid, {sitting, Sid}, Row#{result => R#{questions => Qs1}});
        _ -> ok
    end;
link_fresh(_, _, _, _, _) -> ok.

judger(Host) ->
    _ = code:ensure_loaded(Host),
    case erlang:function_exported(Host, judger, 0) of
        true -> Host:judger();
        false -> fun spark_judge/3
    end.

spark_judge(Key, Q, Text) ->
    Req = #{model => <<"muse-spark-1.3">>, reasoning => #{effort => <<"low">>}, max_output_tokens => 3000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => witness_mastery:judge_prompt(Q, Text)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} -> witness_mastery:judge(witness_meta:text_of(R));
        E -> E
    end.

%% A student's paper in a teacher's exam is the teacher's row; the student reaches it through their pointer.
owner_of(Uid, Id, Host) ->
    case Host:load(Uid, {sitting, Id}) of
        {ok, _} -> Uid;
        none -> case Host:load(Uid, {mine, Id}) of {ok, #{owner := O}} -> O; _ -> Uid end
    end.

%% What a student sees of their own paper: its status, and the marks only once the teacher released them.
mine_view(_, #{fresh := true}, _) -> none;     %% a fresh question shows on the question it checks, not as a paper
mine_view(Id, #{owner := O}, Host) ->
    case Host:load(O, {sitting, Id}) of
        {ok, #{status := <<"released">>} = R} ->
            Title = case Host:load(O, {pile, maps:get(pile, R, <<>>)}) of {ok, P} -> maps:get(title, P); none -> <<>> end,
            V = view(Id, R),
            Qs = [case Q of #{mastery := _} -> Q#{mastery => witness_mastery:view(Q, student)}; _ -> Q end
                  || Q <- maps:get(questions, maps:get(result, V))],
            V1 = V#{title => Title, result => (maps:get(result, V))#{questions => Qs}},
            case maps:get(examiner, R, undefined) of undefined -> V1; Ex -> V1#{examiner => examiner_view(Ex, student)} end;
        {ok, R} ->
            %% before release the student sees no marks, only the examiner's questions about their own steps
            Title = case Host:load(O, {pile, maps:get(pile, R, <<>>)}) of {ok, P} -> maps:get(title, P); none -> <<>> end,
            V = #{id => Id, title => Title, status => case maps:get(status, R) of <<"failed">> -> <<"failed">>; <<"uploading">> -> <<"uploading">>; _ -> <<"with_teacher">> end},
            case maps:get(examiner, R, undefined) of undefined -> V; Ex -> V#{examiner => examiner_view(Ex, student)} end;
        none -> none
    end;
mine_view(_, _, _) -> none.

by_code(C, Host) when is_binary(C) ->
    case Host:load(?CODES, {code, string:uppercase(string:trim(C))}) of
        {ok, #{owner := O, pile := P}} -> case Host:load(O, {pile, P}) of {ok, PR} -> {ok, O, P, PR}; none -> none end;
        none -> none
    end;
by_code(_, _) -> none.

%% Six letters and digits a teacher can read out loud (no 0 or O, no 1, I or L).
new_code(Host) ->
    A = <<"ABCDEFGHJKMNPQRSTUVWXYZ23456789">>,
    C = << <<(binary:at(A, X rem byte_size(A)))>> || <<X>> <= crypto:strong_rand_bytes(6) >>,
    case Host:load(?CODES, {code, C}) of none -> C; _ -> new_code(Host) end.

%% The teacher's word sits beside the model's: teacher_result / teacher_marks, and a focus note for the level.
review(Q, B) ->
    Res = maps:get(<<"result">>, B, null),
    Marks = maps:get(<<"marks">>, B, null),
    Q1 = case lists:member(Res, witness_mark:results()) of true -> Q#{teacher_result => Res}; false -> Q end,
    Q2 = case is_number(Marks) andalso Marks >= 0 andalso Marks =< maps:get(out_of, Q, 100) of true -> Q1#{teacher_marks => Marks}; false -> Q1 end,
    Q3 = case maps:get(<<"focus">>, B, null) of F when is_binary(F) -> Q2#{focus => clean(F, 600)}; _ -> Q2 end,
    Q4 = case maps:get(<<"comment">>, B, null) of
        Cm when is_binary(Cm) -> Q3#{comment => (maps:get(comment, Q3, #{}))#{text => clean(Cm, 2000), at => now_ms()}};
        _ -> Q3
    end,
    Q4#{reviewed => true}.

mark(Uid, Id, Key, Fps, Sitting, Host) ->
    {ok, Row} = Host:load(Uid, {sitting, Id}),
    UrlR = Host:get_url(Uid, Id),
    Outcome = try
        case UrlR of
            {ok, Url} ->
                case {maps:get(engine, Sitting, <<"meta">>), open_engine(Host)} of
                    {<<"open">>, #{} = Cfg} -> (open_marker(Host))(Cfg, #{url => Url}, Sitting);
                    _ -> case (marker(Host))(Key, #{url => Url, fps => Fps}, Sitting) of
                             {ok, R0} -> {ok, maps:merge(#{engine => <<"muse-spark-1.3">>}, R0)};
                             E0 -> E0
                         end
                end;
            E -> E
        end
    catch C:R -> {error, {C, R}}
    end,
    %% the stills are taken while the clip is still there: the record keeps the moments, never the video
    Stills = case {Outcome, UrlR} of {{ok, Res}, {ok, U}} -> stills(Uid, Id, U, Res, Host); _ -> [] end,
    ok = Host:drop_clip(Uid, Id),
    case Outcome of
        {ok, Result} ->
            ok = Host:save(Uid, {sitting, Id}, Row#{status => <<"marked">>, result => Result#{stills => Stills}, marked_ms => now_ms()}),
            link_fresh(Uid, Row, <<"marked">>, Result, Host),
            Host:spend(Uid, <<"witness_sitting">>, maps:get(cost_usd, Result, 0.0)),
            case maps:is_key(for, Row) of
                true -> ok;                                         %% a fresh question is checked by the teacher
                false -> examine(Uid, Id, Key, Sitting, maps:get(questions, Result, []), Host)
            end;
        {error, Why} ->
            ok = Host:save(Uid, {sitting, Id}, Row#{status => <<"failed">>, reason => iolist_to_binary(io_lib:format("~0p", [Why])), marked_ms => now_ms()}),
            link_fresh(Uid, Row, <<"failed">>, #{}, Host)
    end.

marker(Host) ->
    _ = code:ensure_loaded(Host),
    case erlang:function_exported(Host, marker, 0) of
        true -> Host:marker();
        false -> fun witness_sitting:mark/3
    end.

%% What the phone and the desk see of a sitting (never the reason a model call failed).
view(Id, #{status := S, result := R} = Row) when S =:= <<"marked">>; S =:= <<"released">> ->
    V = #{ok => true, id => Id, status => S, student => maps:get(student, Row, <<>>),
          result => #{questions => maps:get(questions, R, []), pauses => maps:get(pauses, R, []), lines => maps:get(lines, R, []),
                      stills => maps:get(stills, R, []), engine => maps:get(engine, R, <<"muse-spark-1.3">>)}},
    case maps:get(examiner, Row, undefined) of undefined -> V; Ex -> V#{examiner => examiner_view(Ex, teacher)} end;
view(Id, #{status := <<"failed">>}) ->
    #{ok => true, id => Id, status => <<"failed">>, error => <<"This sitting couldn't be marked. Record it again.">>};
view(Id, #{status := S}) -> #{ok => true, id => Id, status => S}.

%% summary(Id, Row): one paper's line on the desk.
summary(Id, Row) ->
    Qs = case Row of #{result := #{questions := L}} -> L; _ -> [] end,
    Marks = lists:sum([num(maps:get(teacher_marks, Q, maps:get(marks, Q, 0))) || Q <- Qs]),
    OutOf = lists:sum([num(maps:get(out_of, Q, 0)) || Q <- Qs]),
    #{id => Id, student => maps:get(student, Row, <<>>), status => maps:get(status, Row),
      marks => Marks, out_of => OutOf, to_master => length([Q || Q <- Qs, needs_level(Q)]),
      to_review => length([Q || Q <- Qs, not maps:get(reviewed, Q, false)])}.

%% queue(Sittings): every question not yet reviewed, the ones that most need a teacher first: anything not mastered
%% above anything mastered (27 Oct, the live desk: a "mastered, 90% sure" sat above a right answer reached by wrong
%% thinking at 95%), then the result the model is least sure of, then wrong thinking, "not yet", part way.
queue(Ss) ->
    Items = [#{sitting => Id, student => maps:get(student, R, <<>>), n => maps:get(n, Q), result => maps:get(result, Q),
               confidence => maps:get(confidence, Q, 0.0), diagnosis => maps:get(diagnosis, Q, <<>>), moment_s => maps:get(moment_s, Q, null)}
             || {Id, R = #{result := #{questions := Qs}}} <- Ss, Q <- Qs, not maps:get(reviewed, Q, false)],
    lists:sort(fun(A, B) -> rank(A) =< rank(B) end, Items).

rank(#{confidence := C, result := R}) -> {case R of <<"mastered">> -> 1; _ -> 0 end, round(num(C) * 20), order(R)}.
order(<<"right_answer_wrong_thinking">>) -> 0;
order(<<"not_yet">>) -> 1;
order(<<"part_way">>) -> 2;
order(_) -> 3.

needs_level(Q) -> witness_mark:needs_level(Q#{result => maps:get(teacher_result, Q, maps:get(result, Q))}).

%% sitting_of(Body) -> the marking's input, cleaned (pure).
sitting_of(B) ->
    Qs = [#{n => N, text => clean(maps:get(<<"text">>, Q, <<>>), 600), marks => marks(maps:get(<<"marks">>, Q, 1))}
          || Q <- lists:sublist(list(maps:get(<<"questions">>, B, [])), 60), is_map(Q),
             N <- [maps:get(<<"n">>, Q, 0)], is_integer(N)],
    #{questions => Qs, scheme => clean(maps:get(<<"scheme">>, B, <<>>), 8000),
      level => case clean(maps:get(<<"level">>, B, <<>>), 60) of <<>> -> <<"any level">>; L -> L end,
      kind => case maps:get(<<"kind">>, B, <<"paper">>) of <<"practical">> -> <<"practical">>; _ -> <<"paper">> end,
      engine => case maps:get(<<"engine">>, B, <<"meta">>) of <<"open">> -> <<"open">>; _ -> <<"meta">> end}.

marks(N) when is_integer(N), N >= 0, N =< 100 -> N;
marks(_) -> 1.

clean(B, Max) when is_binary(B) -> string:slice(string:trim(B), 0, Max);
clean(_, _) -> <<>>.

list(L) when is_list(L) -> L;
list(_) -> [].

num(N) when is_number(N) -> N;
num(_) -> 0.

refuse(Code, Kind, Msg) -> {Code, #{ok => false, code => Kind, error => Msg}}.

new_id() -> binary:encode_hex(crypto:strong_rand_bytes(8), lowercase).

now_ms() -> erlang:system_time(millisecond).
