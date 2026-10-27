%%%-------------------------------------------------------------------
%%% witness_sam — reading SAM 3.1's answer (hackathon, 2026-10-27).
%%%
%%% A video answer is one line per frame: "<Nf>" then comma-separated records "id<|box;...|><|mask;...|>".
%%% Box corners are source pixels; w and h repeat the frame size; c is the confidence when asked for.
%%% Frame numbers start at 0, may skip and are not always ascending; ids are stable for one object
%%% while it stays in view (dev.meta.ai/docs/sam/reading-segmentation).
%%%
%%%   records(Text) -> [{Frame, Id, Box}]          Box = #{x1, y1, x2, y2, w, h, c}
%%%   tracks(Records) -> #{Id => Track}            Track = #{first, last, seen, box}
%%%                                                box = where the object was when first seen
%%%   appeared(Tracks) -> [{Frame, Id, Box}]       in the order the objects came into view
%%%-------------------------------------------------------------------
-module(witness_sam).
-export([records/1, tracks/1, appeared/1]).

records(Text) ->
    lists:append([frame_records(L) || L <- binary:split(Text, <<"\n">>, [global]), L =/= <<>>]).

frame_records(<<"<", Rest/binary>>) ->
    case binary:split(Rest, <<"f>">>) of
        [N, Body] ->
            case string:to_integer(N) of
                {F, <<>>} -> [{F, Id, Box} || {Id, Box} <- objects(Body)];
                _ -> []
            end;
        _ -> []
    end;
frame_records(_) -> [].

%% Each object starts with its id and is followed by its box token, then its mask token.
objects(Body) ->
    {match, Ms} = case re:run(Body, <<"(?:^|,)(\\d+)<\\|box;([^|]*)\\|>">>, [global, {capture, all_but_first, binary}]) of
        nomatch -> {match, []};
        M -> M
    end,
    [{binary_to_integer(Id), B} || [Id, Fields] <- Ms, B <- [box(Fields)], corners(B)].

%% A box is only used with all four corners as numbers: a short or garbled one is left out, not trusted.
corners(B) -> lists:all(fun(K) -> is_number(maps:get(K, B, x)) end, [x1, y1, x2, y2]).

%% Only the box's own fields, as fixed atoms: a field name from the model never becomes a new atom (27 Oct, live: a
%% row holding atoms one node had never made could not be read back on that node).
box(Fields) ->
    maps:from_list([{A, number(V)} || F <- binary:split(Fields, <<";">>, [global]),
                                      [K, V] <- [binary:split(F, <<"=">>)], A <- field(K)]).

field(<<"x1">>) -> [x1];
field(<<"y1">>) -> [y1];
field(<<"x2">>) -> [x2];
field(<<"y2">>) -> [y2];
field(<<"w">>) -> [w];
field(<<"h">>) -> [h];
field(<<"c">>) -> [c];
field(_) -> [].

number(V) ->
    case string:to_integer(V) of
        {I, <<>>} -> I;
        _ -> case string:to_float(V) of {Fl, <<>>} -> Fl; _ -> V end
    end.

tracks(Records) ->
    lists:foldl(fun({F, Id, Box}, Acc) ->
        case Acc of
            #{Id := T = #{first := First, last := Last, seen := N}} ->
                T1 = T#{last => max(Last, F), seen => N + 1},
                Acc#{Id => case F < First of true -> T1#{first => F, box => Box}; false -> T1 end};
            _ -> Acc#{Id => #{first => F, last => F, seen => 1, box => Box}}
        end
    end, #{}, Records).

appeared(Tracks) ->
    lists:sort([{F, Id, B} || {Id, #{first := F, box := B}} <- maps:to_list(Tracks)]).
