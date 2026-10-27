#!/usr/bin/env escript
%%! -pa _build/t
%% Live check of witness_meta and witness_sam against the Meta Model API (spends a few cents).
%%   MODEL_API_KEY=... escript harness/live_check.escript clip.mp4
main([Clip]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = os:getenv("MODEL_API_KEY"),
    {ok, Bytes} = file:read_file(Clip),
    {ok, Fid} = witness_meta:upload(Key, filename:basename(Clip), <<"video/mp4">>, Bytes),
    io:format("uploaded ~s~n", [Fid]),
    {ok, Text, Frames} = witness_meta:sam_video(Key, Fid, <<"number">>),
    Order = witness_sam:appeared(witness_sam:tracks(witness_sam:records(Text))),
    io:format("SAM: ~p frames, ~p objects; first five to appear (frame, id, x1, y1):~n", [Frames, length(Order)]),
    [io:format("  ~p ~p ~p ~p~n", [F, Id, X, Y]) || {F, Id, #{x1 := X, y1 := Y}} <- lists:sublist(Order, 5)],
    {ok, Marked, Usage} = witness_meta:read_video(Key, <<"muse-spark-1.3">>, Fid,
        <<"List each answer on this paper in the order it was written, one line each: question, what was written, "
          "and whether the thinking is right. Plain text.">>, #{effort => <<"low">>}),
    io:format("Spark:~n~s~n", [Marked]),
    Cost = witness_meta:cost(sam_video, Frames) + witness_meta:cost({tokens, <<"muse-spark-1.3">>}, Usage),
    io:format("cost about $~.3f~n", [Cost]);
main(_) ->
    io:format("usage: escript harness/live_check.escript clip.mp4~n"), halt(1).
