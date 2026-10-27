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
-export([wav/1, still/2, last/1, frames/3, available/0]).

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
