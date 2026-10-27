%%%-------------------------------------------------------------------
%%% witness_api — the sitting endpoints (hackathon, 2026-10-27).
%%%
%%%   POST sitting/start      {mime, size}                     -> 201 {id, put, headers, expiresIn}
%%%        the phone uploads the clip straight to the signed URL
%%%   POST sitting/<id>/mark  {fps?, questions?, scheme?, level?} -> 202 {id, status: "marking"}
%%%        SAM 3.1 and Muse Spark read the clip from a signed link; the clip is dropped afterwards
%%%   GET  sitting/<id>                                         -> 200 {id, status, result?}
%%%
%%% route(Method, PathParts, Body, Uid, Host) -> {Status, Map}. Host implements witness_host; the caller has
%%% already checked the account may use Witness. An optional Host:marker/0 replaces the model calls in tests.
%%%-------------------------------------------------------------------
-module(witness_api).
-export([route/5, view/2, sitting_of/1]).

-define(MAX_BYTES, 500 * 1024 * 1024).
-define(MIMES, [<<"video/mp4">>, <<"video/quicktime">>]).

route(<<"POST">>, [<<"sitting">>, <<"start">>], B, Uid, Host) ->
    Mime = maps:get(<<"mime">>, B, <<"video/mp4">>),
    Size = maps:get(<<"size">>, B, 0),
    case {lists:member(Mime, ?MIMES), is_integer(Size) andalso Size > 0 andalso Size =< ?MAX_BYTES} of
        {false, _} -> refuse(400, <<"bad_type">>, <<"Record the sitting as an MP4 or MOV video.">>);
        {_, false} -> refuse(400, <<"bad_size">>, <<"That recording is too long to send. Keep a sitting under an hour.">>);
        _ ->
            Id = binary:encode_hex(crypto:strong_rand_bytes(8), lowercase),
            case Host:put_url(Uid, Id, Mime, Size) of
                {ok, Url, Headers} ->
                    ok = Host:save(Uid, Id, #{status => <<"uploading">>, mime => Mime, size => Size, created_ms => now_ms()}),
                    {201, #{ok => true, id => Id, put => Url, headers => Headers, expiresIn => 900}};
                {error, _} -> refuse(503, <<"storage">>, <<"Couldn't get the upload ready. Try again in a moment.">>)
            end
    end;
route(<<"POST">>, [<<"sitting">>, Id, <<"mark">>], B, Uid, Host) ->
    case Host:load(Uid, Id) of
        none -> refuse(404, <<"no_sitting">>, <<"That sitting isn't here.">>);
        {ok, #{status := <<"uploading">>} = Row} ->
            case Host:meta_key() of
                undefined -> refuse(503, <<"not_configured">>, <<"Marking isn't available right now.">>);
                Key ->
                    Sitting = sitting_of(B),
                    Fps = case maps:get(<<"fps">>, B, 30) of F when is_number(F), F > 0, F =< 240 -> F; _ -> 30 end,
                    ok = Host:save(Uid, Id, Row#{status => <<"marking">>, started_ms => now_ms()}),
                    ok = Host:run(fun() -> mark(Uid, Id, Key, Fps, Sitting, Host) end),
                    {202, #{ok => true, id => Id, status => <<"marking">>}}
            end;
        {ok, #{status := S}} -> {200, #{ok => true, id => Id, status => S}}
    end;
route(<<"GET">>, [<<"sitting">>, Id], _B, Uid, Host) ->
    case Host:load(Uid, Id) of
        none -> refuse(404, <<"no_sitting">>, <<"That sitting isn't here.">>);
        {ok, Row} -> {200, view(Id, Row)}
    end;
route(_, _, _, _, _) -> refuse(404, <<"not_found">>, <<"No such Witness route.">>).

mark(Uid, Id, Key, Fps, Sitting, Host) ->
    {ok, Row} = Host:load(Uid, Id),
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
            ok = Host:save(Uid, Id, Row#{status => <<"marked">>, result => Result, marked_ms => now_ms()}),
            Host:spend(Uid, <<"witness_sitting">>, maps:get(cost_usd, Result, 0.0));
        {error, Why} ->
            ok = Host:save(Uid, Id, Row#{status => <<"failed">>, reason => iolist_to_binary(io_lib:format("~0p", [Why])), marked_ms => now_ms()})
    end.

marker(Host) ->
    _ = code:ensure_loaded(Host),
    case erlang:function_exported(Host, marker, 0) of
        true -> Host:marker();
        false -> fun witness_sitting:mark/3
    end.

%% What the phone and the desk see of a sitting (never the reason a model call failed).
view(Id, #{status := <<"marked">>, result := R}) ->
    #{ok => true, id => Id, status => <<"marked">>,
      result => #{questions => maps:get(questions, R, []),
                  pauses => maps:get(pauses, R, []), lines => maps:get(lines, R, [])}};
view(Id, #{status := <<"failed">>}) ->
    #{ok => true, id => Id, status => <<"failed">>, error => <<"This sitting couldn't be marked. Record it again.">>};
view(Id, #{status := S}) -> #{ok => true, id => Id, status => S}.

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

refuse(Code, Kind, Msg) -> {Code, #{ok => false, code => Kind, error => Msg}}.

now_ms() -> erlang:system_time(millisecond).
