%%%-------------------------------------------------------------------
%%% witness_face — the server's own face look on a desk video (4 Nov, after the final audit: "the server still relies
%%% on the client's declaration"; a modified app can send faces: "checked" without looking).
%%%
%%%   look(Key, Url) -> {clear, CostUsd} | {face, CostUsd, Boxes} | {error, face_unsure} | {error, Why}
%%%
%%% SAM 3.1 is asked for "face" on the video before anything else reads it. The video is first cut to five frames a
%%% second, 480 pixels wide (ffmpeg reads the signed link and stops at the first decoding error), and that copy is
%%% deleted from Meta's file store after the look. Any face SAM reports, at any confidence, is a face: the look fails
%%% safe. Measured live (harness/face/): every clip with a face caught (a full face, a face crossing for one second, a
%%% small face in a corner, half a face at the edge, the lower half of a face, the 28 Oct phone output that left a face
%%% uncovered); no face reported on 25 face-free desk clips, a writing hand and the phone's covered output.
%%%
%%% 5 Nov (owner, after the last review: "a face shown briefly can fall between sampled frames; refuse uncertain
%%% results"): five frames a second, not two, so a face in view for a fifth of a second or more is on a sampled frame;
%%% and the look must cover the whole video or the video is refused (face_unsure: deleted unmarked, the paper is
%%% photographed). Unsure is: ffmpeg cannot read the whole video, the copy cannot be made or its frames counted, or SAM
%%% looked at fewer frames than the copy holds. SAM no longer reads the original link itself when the copy fails: that
%%% look could not be counted. A Meta outage while sending the copy is still tried again (busy), never refused.
%%%-------------------------------------------------------------------
-module(witness_face).
-export([look/2, verdict/2, covered/2, fps/0]).

-define(FPS, 5).
-define(WIDTH, 480).

fps() -> ?FPS.

look(Key, Url) ->
    case witness_media:available() andalso witness_media:sample(Url, ?FPS, ?WIDTH) of
        {ok, Mp4} ->
            case witness_mp4:frame_times(Mp4) of
                {ok, Times} when Times =/= [] ->
                    case witness_meta:upload(Key, <<"face-look.mp4">>, <<"video/mp4">>, Mp4) of
                        {ok, F} ->
                            try witness_meta:sam_video(Key, F, <<"face">>) of
                                {ok, Text, Frames} ->
                                    Cost = witness_meta:cost(sam_video, Frames),
                                    case covered(Frames, length(Times)) of
                                        true -> verdict(witness_sam:records(Text), Cost);
                                        %% a face SAM did report still counts as a face; otherwise unsure
                                        false -> case verdict(witness_sam:records(Text), Cost) of
                                                     {face, _, _} = Face -> Face;
                                                     _ -> {error, face_unsure}
                                                 end
                                    end;
                                E -> E
                            after
                                %% the sampled copy is deleted from Meta's file store once looked at, a face or not
                                _ = witness_meta:forget(Key, F)
                            end;
                        E -> E
                    end;
                _ -> {error, face_unsure}
            end;
        _ -> {error, face_unsure}
    end.

%% covered(FramesSamLookedAt, FramesInTheCopy) -> the look saw every sampled frame
covered(Frames, Have) when is_integer(Frames), is_integer(Have), Have > 0 -> Frames >= Have;
covered(_, _) -> false.

%% Every box SAM gave is a face it saw; none means none was seen.
verdict([], Cost) -> {clear, Cost};
verdict(Records, Cost) -> {face, Cost, length(Records)}.
