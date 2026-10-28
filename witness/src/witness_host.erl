%%%-------------------------------------------------------------------
%%% witness_host — what a host gives Witness (hackathon, 2026-10-27).
%%%
%%% Witness owns the marking; the host owns accounts, storage, money and keys. A host is one module that
%%% implements these callbacks (LoWisa's edge has its own; the tests keep one in memory).
%%% The clip goes straight from the phone to the host's storage and Meta reads it from a signed link,
%%% so the host never handles a video's bytes and drops the clip as soon as the sitting is marked.
%%%
%%% Rows are keyed {Kind, Id} under an owner: {pile, Id} one exam, {sitting, Id} one paper, {mine, Id} a student's
%%% pointer to a paper they sat in a teacher's exam, {code, Code} (under the owner <<"witness-codes">>) a join code,
%%% and {check, Id} one mastery level's self-check.
%%%-------------------------------------------------------------------
-module(witness_host).

-type key() :: {pile | sitting | mine | code | check, binary()}.
-export_type([key/0]).

%% Meta Model API key, or undefined when Witness is not configured.
-callback meta_key() -> binary() | string() | undefined.
%% A signed upload for the phone: the URL and the headers it must send.
-callback put_url(Uid :: binary(), Id :: binary(), Mime :: binary(), Size :: pos_integer()) ->
    {ok, Url :: binary(), Headers :: map()} | {error, term()}.
%% A short-lived signed link Meta reads the clip from.
-callback get_url(Uid :: binary(), Id :: binary()) -> {ok, Url :: binary()} | {error, term()}.
%% The clip is gone once the sitting is marked (or failed).
-callback drop_clip(Uid :: binary(), Id :: binary()) -> ok.
%% The caller's rows.
-callback save(Uid :: binary(), Key :: key(), Row :: map()) -> ok.
-callback load(Uid :: binary(), Key :: key()) -> {ok, map()} | none.
-callback list(Uid :: binary(), Kind :: pile | sitting | mine) -> [{Id :: binary(), Row :: map()}].
%% What a sitting cost, in US dollars, for the host to charge or log.
-callback spend(Uid :: binary(), Feature :: binary(), Usd :: float()) -> ok.
%% One design call of a mastery level (Muse Spark), paid by the learner the host's own way; {gate, ...} is its wall.
-callback design(Uid :: binary(), Req :: #{request_id := binary(), messages := [map()], effort := binary(), max_tokens := pos_integer()}) ->
    {ok, Text :: binary()} | {gate, Status :: pos_integer(), Body :: map()} | {error, term()}.
%% Run the marking off the request (the host chooses how it is supervised).
-callback run(fun(() -> any())) -> ok.
%% A small file kept with a paper (a still of the desk at a moment, a drawn corrected step), and a short-lived link
%% to it. Name is <<SittingId/binary, "/", File/binary>>; they go when the paper's rows go.
-callback put_asset(Uid :: binary(), Name :: binary(), Bytes :: binary(), Mime :: binary()) -> ok | {error, term()}.
-callback asset_url(Uid :: binary(), Name :: binary()) -> {ok, Url :: binary()} | {error, term()}.
%% Optional: an OpenAI-compatible endpoint serving Muse Spark Open (Baseten, Modal, a school's own server), for exams
%% marked on open weights; undefined when there is none.
-callback open_engine() -> #{url := string() | binary(), key := string() | binary(), model := binary()} | undefined.
%% Optional: a line for the host's own log when something off the request failed (a drawing, the examiner).
-callback report(Event :: binary(), Why :: term()) -> any().
%% 2026-10-28: a long video in parts (S3 multipart), so a dropped connection resends only what did not arrive.
-callback parts_start(Uid :: binary(), Id :: binary(), Mime :: binary()) -> {ok, UploadId :: binary()} | {error, term()}.
-callback part_url(Uid :: binary(), Id :: binary(), UploadId :: binary(), N :: pos_integer()) -> {ok, Url :: binary()} | {error, term()}.
-callback parts_done(Uid :: binary(), Id :: binary(), UploadId :: binary()) -> {ok, [{pos_integer(), binary(), non_neg_integer()}]} | {error, term()}.
-callback parts_finish(Uid :: binary(), Id :: binary(), UploadId :: binary(), Parts :: list()) -> ok | {error, term()}.
%% The store's fingerprint of a clip (its ETag): the same video marked again for the same exam reuses its marking.
-callback clip_tag(Uid :: binary(), Id :: binary()) -> {ok, binary()} | {error, term()}.
-optional_callbacks([open_engine/0, report/2, parts_start/3, part_url/4, parts_done/3, parts_finish/4, clip_tag/2]).
