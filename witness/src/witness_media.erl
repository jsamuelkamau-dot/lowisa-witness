%%%-------------------------------------------------------------------
%%% witness_media — the two things Witness asks of ffmpeg (hackathon, 2026-10-27).
%%%
%%%   wav(Bytes) -> {ok, Wav}               a phone recording (AAC in .m4a, or anything ffmpeg reads) as 16 kHz mono
%%%                                         16-bit WAV: Muse Voice Transcribe's file door takes WAV only (27 Oct, live:
%%%                                         AAC, MP3 and Opus were refused)
%%%   still(Url, Seconds) -> {ok, Jpeg}     one frame of the clip at a moment, read from its signed link (ffmpeg
%%%                                         seeks over HTTP, so the host never downloads the video)
%%%
%%% ffmpeg runs as a program with its arguments (no shell); it must be on the PATH. available/0 says whether it is.
%%%-------------------------------------------------------------------
-module(witness_media).
-export([step/3, wav/1, still/2, clip/3, last/1, frames/3, gray/4, gray_image/2, region/2, available/0]).

-define(TIMEOUT_MS, 60000).
-define(MAX_AUDIO, 25 * 1024 * 1024).

available() -> os:find_executable("ffmpeg") =/= false.

wav(Bytes) when is_binary(Bytes), byte_size(Bytes) > 0, byte_size(Bytes) =< ?MAX_AUDIO ->
    In = tmp(".in"), Out = tmp(".wav"),
    try
        ok = file:write_file(In, Bytes),
        case run(["-v", "error", "-y", "-i", In, "-ac", "1", "-ar", "16000", "-sample_fmt", "s16", "-f", "wav", Out]) of
            ok -> file:read_file(Out);
            E -> E
        end
    after
        _ = file:delete(In), _ = file:delete(Out)
    end;
wav(_) -> {error, bad_audio}.

still(Url, Seconds) when is_number(Seconds), Seconds >= 0 ->
    Out = tmp(".jpg"),
    try
        At = float_to_list(float(Seconds), [{decimals, 2}]),
        case run(["-v", "error", "-y", "-ss", At, "-i", str(Url), "-frames:v", "1", "-vf", "scale=720:-2", "-q:v", "4", Out]) of
            ok -> file:read_file(Out);
            E -> E
        end
    after
        _ = file:delete(Out)
    end;
still(_, _) -> {error, bad_time}.

%% clip(Url, From, Secs) -> {ok, Mp4}: a few seconds of the desk around a moment that matters, small and silent (28 Oct
%% re-audit: the research's Proof of Thinking keeps "short clips at the moments that matter" once the video is deleted).
%% H.264 so a browser and the phone's web view play it; read from the signed link as the stills are.
clip(Url, From, Secs) when is_number(From), From >= 0, is_number(Secs), Secs > 0, Secs =< 12 ->
    Out = tmp(".mp4"),
    try
        At = float_to_list(float(From), [{decimals, 2}]), For = float_to_list(float(Secs), [{decimals, 2}]),
        case run(["-v", "error", "-y", "-ss", At, "-i", str(Url), "-t", For, "-an", "-vf", "scale=480:-2,fps=10",
                  "-c:v", "libx264", "-preset", "veryfast", "-crf", "30", "-pix_fmt", "yuv420p", "-movflags", "+faststart", Out]) of
            ok -> file:read_file(Out);
            E -> E
        end
    after
        _ = file:delete(Out)
    end;
clip(_, _, _) -> {error, bad_time}.

%% step(Url, Seconds, Box) -> {ok, Jpeg}: the student's own written step, cut from the frame by SAM's box for its line
%% (source pixels; w and h the frame), with room around it (28 Oct audit: the plan's first look opens on the student's
%% own handwriting).
step(Url, Seconds, #{x1 := X1, y1 := Y1, x2 := X2, y2 := Y2, w := W, h := H}) when is_number(Seconds), X2 > X1, Y2 > Y1 ->
    PadX = (X2 - X1) * 0.08 + 12, PadY = (Y2 - Y1) * 0.6 + 12,
    L = max(0, round(X1 - PadX)), T = max(0, round(Y1 - PadY)),
    R = min(W, round(X2 + PadX)), B = min(H, round(Y2 + PadY)),
    %% the box is in SAM's frame (W x H); scaled to the video's own size, so a frame of another size cuts the same place
    Crop = io_lib:format("crop=iw*~b/~b:ih*~b/~b:iw*~b/~b:ih*~b/~b,scale='min(900,iw)':-2", [R - L, W, B - T, H, L, W, T, H]),
    Out = tmp(".jpg"),
    try
        At = float_to_list(float(Seconds), [{decimals, 2}]),
        case run(["-v", "error", "-y", "-ss", At, "-i", str(Url), "-frames:v", "1", "-vf", lists:flatten(Crop), "-q:v", "3", Out]) of
            ok -> file:read_file(Out);
            E -> E
        end
    after
        _ = file:delete(Out)
    end;
step(_, _, _) -> {error, no_box}.

%% region(Url, Box) -> {ok, Jpeg}: a part of a photographed page as it is (a question's answer, from its printed line to
%% its last written one), the box in the page's own fractions (w and h its scale), at most 1000 pixels wide.
region(Url, #{x1 := X1, y1 := Y1, x2 := X2, y2 := Y2, w := W, h := H}) when X2 > X1, Y2 > Y1 ->
    Crop = io_lib:format("crop=iw*~b/~b:ih*~b/~b:iw*~b/~b:ih*~b/~b,scale='min(1000,iw)':-2", [X2 - X1, W, Y2 - Y1, H, X1, W, Y1, H]),
    Out = tmp(".jpg"),
    try
        case run(["-v", "error", "-y", "-i", str(Url), "-frames:v", "1", "-vf", lists:flatten(Crop), "-q:v", "3", Out]) of
            ok -> file:read_file(Out);
            E -> E
        end
    after
        _ = file:delete(Out)
    end;
region(_, _) -> {error, no_box}.

%% gray(Url, first | last, W, H) -> {ok, Pixels}: the clip's first or last frame as W x H grey bytes, one a pixel, row
%% by row (W x H = SAM's frame, so SAM's boxes index it directly). witness_timeline:printed/4 reads which of SAM's lines
%% already held ink before anything was written.
gray(Url, Which, W, H) when is_integer(W), is_integer(H), W > 0, H > 0 ->
    Out = tmp(".gray"),
    Seek = case Which of first -> ["-ss", "0"]; last -> ["-sseof", "-0.4"] end,
    try
        Size = integer_to_list(W) ++ ":" ++ integer_to_list(H),
        case run(["-v", "error", "-y"] ++ Seek ++ ["-i", str(Url), "-frames:v", "1", "-vf", "scale=" ++ Size ++ ",format=gray",
                                                    "-f", "rawvideo", Out]) of
            ok -> case file:read_file(Out) of {ok, B} when byte_size(B) =:= W * H -> {ok, B}; {ok, _} -> {error, short_frame}; E -> E end;
            E -> E
        end
    after
        _ = file:delete(Out)
    end;
gray(_, _, _, _) -> {error, bad_size}.

%% gray_image(Url, W) -> {ok, W, H, Pixels}: a photographed page W pixels wide (its own shape kept), grey bytes row by
%% row, for witness_page to find the ink lines (29 Oct, From Exam to Mastery).
gray_image(Url, W) when is_integer(W), W > 0 ->
    Out = tmp(".gray"),
    try
        case run(["-v", "error", "-y", "-i", str(Url), "-frames:v", "1", "-vf", "scale=" ++ integer_to_list(W) ++ ":-2,format=gray",
                  "-f", "rawvideo", Out]) of
            ok -> case file:read_file(Out) of
                      {ok, B} when byte_size(B) > 0, byte_size(B) rem W =:= 0 -> {ok, W, byte_size(B) div W, B};
                      {ok, _} -> {error, short_frame};
                      E -> E
                  end;
            E -> E
        end
    after
        _ = file:delete(Out)
    end.


%% last(Url) -> {ok, Jpeg}: the clip's final frame (the finished page, whatever the frame rate).
last(Url) ->
    Out = tmp(".jpg"),
    try
        case run(["-v", "error", "-y", "-sseof", "-0.4", "-i", str(Url), "-frames:v", "1", "-vf", "scale=640:-2", "-q:v", "6", Out]) of
            ok -> file:read_file(Out);
            E -> E
        end
    after
        _ = file:delete(Out)
    end.

%% frames(Url, Fps, Max) -> {ok, [Jpeg]}: the clip as stills, Fps a second, at most Max (the open-weight marking reads
%% these; frame I is at I / Fps seconds).
frames(Url, Fps, Max) when is_number(Fps), Fps > 0, is_integer(Max), Max > 0 ->
    Dir = tmp(".frames"),
    ok = file:make_dir(Dir),
    try
        Pattern = filename:join(Dir, "f%04d.jpg"),
        case run(["-v", "error", "-y", "-i", str(Url), "-vf", "fps=" ++ float_to_list(float(Fps), [{decimals, 3}]) ++ ",scale=640:-2",
                  "-frames:v", integer_to_list(Max), "-q:v", "6", Pattern]) of
            ok -> {ok, [B || F <- lists:sort(filelib:wildcard(filename:join(Dir, "f*.jpg"))), {ok, B} <- [file:read_file(F)]]};
            E -> E
        end
    after
        [file:delete(F) || F <- filelib:wildcard(filename:join(Dir, "*"))], file:del_dir(Dir)
    end.

run(Args) ->
    case os:find_executable("ffmpeg") of
        false -> {error, no_ffmpeg};
        Exe ->
            Port = open_port({spawn_executable, Exe}, [{args, Args}, exit_status, stderr_to_stdout, binary, hide]),
            wait(Port, <<>>)
    end.

wait(Port, Said) ->
    receive
        {Port, {data, D}} -> wait(Port, <<Said/binary, D/binary>>);
        {Port, {exit_status, 0}} -> ok;
        {Port, {exit_status, S}} -> {error, {ffmpeg, S, binary:part(Said, 0, min(300, byte_size(Said)))}}
    after ?TIMEOUT_MS ->
        try port_close(Port) catch _:_ -> ok end,
        {error, ffmpeg_timeout}
    end.

tmp(Ext) ->
    Dir = case os:getenv("TMPDIR") of false -> case os:type() of {win32, _} -> os:getenv("TEMP", "."); _ -> "/tmp" end; D -> D end,
    filename:join(Dir, "witness-" ++ integer_to_list(erlang:unique_integer([positive])) ++ Ext).

str(B) when is_binary(B) -> binary_to_list(B);
str(L) when is_list(L) -> L.
