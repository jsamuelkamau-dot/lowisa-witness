#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% face_look_e2e.escript <out.json> <clip>...: the server's own face look (witness_face:look/2, the code the edge runs:
%% ffmpeg's two-frames-a-second copy, sent to Meta, SAM 3.1 "face", the copy deleted after) on each clip. ffmpeg must be
%% on the PATH. Key from $MODEL_API_KEY, never printed. Also checks that Meta deletes an uploaded file when asked.
main([Out | Clips]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = list_to_binary(os:getenv("MODEL_API_KEY")),
    true = witness_media:available(),
    {ok, Fid} = witness_meta:upload(Key, <<"forget-check.mp4">>, <<"video/mp4">>, element(2, file:read_file(hd(Clips)))),
    Forget = witness_meta:forget(Key, Fid),
    io:format("an uploaded file deleted when asked: ~p~n", [Forget]),
    Me = self(),
    Pids = [spawn(fun() -> T0 = erlang:monotonic_time(millisecond), R = witness_face:look(Key, C),
                           Me ! {self(), C, R, erlang:monotonic_time(millisecond) - T0} end) || C <- Clips],
    Rs = [receive {P, C, R, Ms} -> row(C, R, Ms) after 600000 -> #{clip => <<"timeout">>} end || P <- Pids],
    [io:format("~-28s ~-6s cost $~.4f boxes ~w ~ws~n", [maps:get(clip, R), maps:get(look, R), maps:get(cost_usd, R, 0.0),
                maps:get(boxes, R, 0), maps:get(ms, R, 0) div 1000]) || R <- Rs],
    ok = file:write_file(Out, json:encode(#{forget => Forget =:= ok, clips => Rs})).

row(C, {clear, Cost}, Ms) -> #{clip => list_to_binary(filename:basename(C)), look => clear, cost_usd => Cost, ms => Ms};
row(C, {face, Cost, N}, Ms) -> #{clip => list_to_binary(filename:basename(C)), look => face, cost_usd => Cost, boxes => N, ms => Ms};
row(C, E, Ms) -> #{clip => list_to_binary(filename:basename(C)), look => error, error => iolist_to_binary(io_lib:format("~0p", [E])), ms => Ms}.
