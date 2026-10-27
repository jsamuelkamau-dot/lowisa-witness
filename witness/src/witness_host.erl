%%%-------------------------------------------------------------------
%%% witness_host — what a host gives Witness (hackathon, 2026-10-27).
%%%
%%% Witness owns the marking; the host owns accounts, storage, money and keys. A host is one module that
%%% implements these callbacks (LoWisa's edge has its own; harness/demo_host.erl is an in-memory one).
%%% The clip goes straight from the phone to the host's storage and Meta reads it from a signed link,
%%% so the host never handles a video's bytes and drops the clip as soon as the sitting is marked.
%%%-------------------------------------------------------------------
-module(witness_host).

%% Meta Model API key, or undefined when Witness is not configured.
-callback meta_key() -> binary() | string() | undefined.
%% A signed upload for the phone: the URL and the headers it must send.
-callback put_url(Uid :: binary(), Id :: binary(), Mime :: binary(), Size :: pos_integer()) ->
    {ok, Url :: binary(), Headers :: map()} | {error, term()}.
%% A short-lived signed link Meta reads the clip from.
-callback get_url(Uid :: binary(), Id :: binary()) -> {ok, Url :: binary()} | {error, term()}.
%% The clip is gone once the sitting is marked (or failed).
-callback drop_clip(Uid :: binary(), Id :: binary()) -> ok.
%% One sitting's row, the caller's own.
-callback save(Uid :: binary(), Id :: binary(), Row :: map()) -> ok.
-callback load(Uid :: binary(), Id :: binary()) -> {ok, map()} | none.
%% What a sitting cost, in US dollars, for the host to charge or log.
-callback spend(Uid :: binary(), Feature :: binary(), Usd :: float()) -> ok.
%% Run the marking off the request (the host chooses how it is supervised).
-callback run(fun(() -> any())) -> ok.
