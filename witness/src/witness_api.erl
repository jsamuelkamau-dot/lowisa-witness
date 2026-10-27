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
                    Sitting = case maps:get(pile, Row, undefined) of
                        undefined -> sitting_of(B);
                        PileId -> case Host:load(Uid, {pile, PileId}) of {ok, P} -> maps:with([questions, scheme, level], P); none -> sitting_of(B) end
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
                    ok = Host:save(Uid, {sitting, Id}, Row#{result => R#{questions => [case X of #{n := N} -> Q1; _ -> X end || X <- Qs]}}),
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
route(_, _, _, _, _) -> refuse(404, <<"not_found">>, <<"No such Witness route.">>).

%% A student's paper in a teacher's exam is the teacher's row; the student reaches it through their pointer.
owner_of(Uid, Id, Host) ->
    case Host:load(Uid, {sitting, Id}) of
        {ok, _} -> Uid;
        none -> case Host:load(Uid, {mine, Id}) of {ok, #{owner := O}} -> O; _ -> Uid end
    end.

%% What a student sees of their own paper: its status, and the marks only once the teacher released them.
mine_view(Id, #{owner := O}, Host) ->
    case Host:load(O, {sitting, Id}) of
        {ok, #{status := <<"released">>} = R} ->
            Title = case Host:load(O, {pile, maps:get(pile, R, <<>>)}) of {ok, P} -> maps:get(title, P); none -> <<>> end,
            (view(Id, R))#{title => Title};
        {ok, R} -> #{id => Id, status => case maps:get(status, R) of <<"failed">> -> <<"failed">>; <<"uploading">> -> <<"uploading">>; _ -> <<"with_teacher">> end};
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
    Q3#{reviewed => true}.

mark(Uid, Id, Key, Fps, Sitting, Host) ->
    {ok, Row} = Host:load(Uid, {sitting, Id}),
    Outcome = try
        case Host:get_url(Uid, Id) of
            {ok, Url} -> (marker(Host))(Key, #{url => Url, fps => Fps}, Sitting);
            E -> E
        end
    catch C:R -> {error, {C, R}}
    end,
    ok = Host:drop_clip(Uid, Id),
    case Outcome of
        {ok, Result} ->
            ok = Host:save(Uid, {sitting, Id}, Row#{status => <<"marked">>, result => Result, marked_ms => now_ms()}),
            Host:spend(Uid, <<"witness_sitting">>, maps:get(cost_usd, Result, 0.0));
        {error, Why} ->
            ok = Host:save(Uid, {sitting, Id}, Row#{status => <<"failed">>, reason => iolist_to_binary(io_lib:format("~0p", [Why])), marked_ms => now_ms()})
    end.

marker(Host) ->
    _ = code:ensure_loaded(Host),
    case erlang:function_exported(Host, marker, 0) of
        true -> Host:marker();
        false -> fun witness_sitting:mark/3
    end.

%% What the phone and the desk see of a sitting (never the reason a model call failed).
view(Id, #{status := S, result := R} = Row) when S =:= <<"marked">>; S =:= <<"released">> ->
    #{ok => true, id => Id, status => S, student => maps:get(student, Row, <<>>),
      result => #{questions => maps:get(questions, R, []), pauses => maps:get(pauses, R, []), lines => maps:get(lines, R, [])}};
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

%% queue(Sittings): every question not yet reviewed, the ones that most need a teacher first: the result the model
%% is least sure of, and among equals wrong thinking, then "not yet", then part way, then mastered.
queue(Ss) ->
    Items = [#{sitting => Id, student => maps:get(student, R, <<>>), n => maps:get(n, Q), result => maps:get(result, Q),
               confidence => maps:get(confidence, Q, 0.0), diagnosis => maps:get(diagnosis, Q, <<>>), moment_s => maps:get(moment_s, Q, null)}
             || {Id, R = #{result := #{questions := Qs}}} <- Ss, Q <- Qs, not maps:get(reviewed, Q, false)],
    lists:sort(fun(A, B) -> rank(A) =< rank(B) end, Items).

rank(#{confidence := C, result := R}) -> {round(num(C) * 20), order(R)}.
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
      level => case clean(maps:get(<<"level">>, B, <<>>), 60) of <<>> -> <<"any level">>; L -> L end}.

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
