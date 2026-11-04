#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% face_look.escript <out.json> <clip.mp4>...: SAM 3.1 asked for "face" on each clip (the server's own face look,
%% 4 Nov, after the final audit). Prints every clip's face objects and their best confidence. Key from $MODEL_API_KEY,
%% never printed. A clip named p*/face* must show a face; every other clip must not.
main([Out | Clips]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = list_to_binary(os:getenv("MODEL_API_KEY")),
    Prompt = list_to_binary(os:getenv("PROMPT", "face")),
    Me = self(),
    Pids = [spawn(fun() -> Me ! {self(), look(Key, Prompt, C)} end) || C <- Clips],
    Rs = [receive {P, R} -> R after 600000 -> #{clip => <<"timeout">>} end || P <- Pids],
    [io:format("~-28s faces ~3w best ~.2f frames ~4w ~s~n", [maps:get(clip, R), maps:get(objects, R, -1), maps:get(best, R, 0.0),
                maps:get(frames, R, 0), maps:get(error, R, <<>>)]) || R <- Rs],
    ok = file:write_file(Out, json:encode(Rs)).

look(Key, Prompt, Clip) ->
    Name = list_to_binary(filename:basename(Clip)),
    {ok, Bin} = file:read_file(Clip),
    T0 = erlang:monotonic_time(millisecond),
    R = case witness_meta:upload(Key, Name, <<"video/mp4">>, Bin) of
        {ok, Fid} ->
            case witness_meta:sam_video(Key, Fid, Prompt) of
                {ok, Text, Frames} ->
                    Recs = witness_sam:records(Text),
                    Cs = [maps:get(c, B, 1.0) || {_, _, B} <- Recs],
                    Ids = lists:usort([I || {_, I, _} <- Recs]),
                    #{objects => length(Ids), boxes => length(Recs), best => lists:max([0.0 | Cs]), frames => Frames,
                      seen_frames => length(lists:usort([F || {F, _, _} <- Recs]))};
                E -> #{error => iolist_to_binary(io_lib:format("~0p", [E]))}
            end;
        E -> #{error => iolist_to_binary(io_lib:format("~0p", [E]))}
    end,
    R#{clip => Name, ms => erlang:monotonic_time(millisecond) - T0}.
