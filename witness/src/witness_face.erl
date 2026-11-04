%%%-------------------------------------------------------------------
%%% witness_face — the server's own face look on a desk video (4 Nov, after the final audit: "the server still relies
%%% on the client's declaration"; a modified app can send faces: "checked" without looking).
%%%
%%%   look(Key, Url) -> {clear, CostUsd} | {face, CostUsd, Boxes} | {error, Why}
%%%
%%% SAM 3.1 is asked for "face" on the video before anything else reads it. The video is first cut to two frames a
%%% second, 480 pixels wide (ffmpeg reads the signed link; a few MB for the look, a fifth of the frames to pay for),
%%% and that copy is deleted from Meta's file store after the look; without ffmpeg, or when the copy cannot be made,
%%% SAM reads the signed link itself. Any face SAM reports, at any confidence, is a face: the look fails
%%% safe. Measured live (harness/face/): every clip with a face caught, also cut to two frames a second (a full face, a
%%% face crossing for one second, a small face in a corner, half a face at the edge, the lower half of a face, the
%%% 28 Oct phone output that left a face uncovered); no face reported on 25 face-free desk clips, a writing hand and the
%%% phone's covered output. A face shown for less than half a second can fall between two sampled frames.
%%%-------------------------------------------------------------------
-module(witness_face).
-export([look/2, verdict/2]).

-define(FPS, 2).
-define(WIDTH, 480).

look(Key, Url) ->
    Video = case witness_media:available() of
        true ->
            %% a sample that cannot be made or sent: SAM reads the signed link itself (every frame, dearer, same look)
            case witness_media:sample(Url, ?FPS, ?WIDTH) of
                {ok, Mp4} -> case witness_meta:upload(Key, <<"face-look.mp4">>, <<"video/mp4">>, Mp4) of {ok, F} -> {ok, F}; _ -> {ok, {url, Url}} end;
                _ -> {ok, {url, Url}}
            end;
        false -> {ok, {url, Url}}
    end,
    case Video of
        {ok, V} ->
            try witness_meta:sam_video(Key, V, <<"face">>) of
                {ok, Text, Frames} -> verdict(witness_sam:records(Text), witness_meta:cost(sam_video, Frames));
                E -> E
            after
                %% the sampled copy is deleted from Meta's file store once looked at, a face or not
                case V of {url, _} -> ok; Fid -> _ = witness_meta:forget(Key, Fid), ok end
            end;
        E -> E
    end.

%% Every box SAM gave is a face it saw; none means none was seen.
verdict([], Cost) -> {clear, Cost};
verdict(Records, Cost) -> {face, Cost, length(Records)}.
