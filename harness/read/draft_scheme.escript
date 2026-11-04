#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% draft_scheme.escript <out.json> <runs> <file>: the desk's "Start from your own paper" on a paper with no mark scheme,
%% live through the server's own reader (witness_read:run/3, 5 Nov): what Muse Spark drafts for the teacher to check.
%% Key from $MODEL_API_KEY, never printed. Each run's drafted scheme is written to <out.json>, to compare by hand with
%% the paper's real scheme.
main([Out, RunsS, File]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = list_to_binary(os:getenv("MODEL_API_KEY")),
    {ok, Bytes} = file:read_file(File),
    Mime = case filename:extension(File) of ".pdf" -> <<"application/pdf">>; ".png" -> <<"image/png">>; _ -> <<"image/jpeg">> end,
    Me = self(),
    Pids = [spawn(fun() -> T0 = erlang:monotonic_time(millisecond), R = witness_read:run(Key, Mime, Bytes),
                           Me ! {self(), N, R, erlang:monotonic_time(millisecond) - T0} end) || N <- lists:seq(1, list_to_integer(RunsS))],
    Rs = [receive {P, N, R, Ms} -> row(N, R, Ms) after 600000 -> #{run => 0, error => <<"timeout">>} end || P <- Pids],
    [io:format("run ~w: ~s, ~w questions, drafted ~p, $~.4f, ~ws~n",
               [maps:get(run, R), maps:get(status, R, <<"error">>), maps:get(questions, R, 0), maps:get(drafted, R, false),
                maps:get(cost_usd, R, 0.0), maps:get(ms, R, 0) div 1000]) || R <- Rs],
    ok = file:write_file(Out, json:encode(#{file => list_to_binary(filename:basename(File)), runs => Rs})).

row(N, {ok, #{questions := Qs, scheme := S, drafted := D}, Cost}, Ms) ->
    #{run => N, status => <<"ok">>, questions => length(Qs), drafted => D, scheme => S, cost_usd => Cost, ms => Ms};
row(N, E, Ms) -> #{run => N, status => <<"error">>, error => iolist_to_binary(io_lib:format("~0p", [E])), ms => Ms}.
