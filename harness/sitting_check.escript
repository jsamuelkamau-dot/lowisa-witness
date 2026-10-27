#!/usr/bin/env escript
%%! -pa _build/t
%% One sitting end to end against the Meta Model API (spends a few cents).
%%   MODEL_API_KEY=... escript harness/sitting_check.escript clip.mp4
main([Clip]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    {ok, Bytes} = file:read_file(Clip),
    T0 = erlang:monotonic_time(millisecond),
    {ok, R} = witness_sitting:mark(os:getenv("MODEL_API_KEY"), #{name => filename:basename(Clip), bytes => Bytes}, #{}),
    io:format("~p lines on the page, ~p SAM frames, $~.3f, ~p s~n",
              [length(maps:get(lines, R)), maps:get(frames, R), maps:get(cost_usd, R), (erlang:monotonic_time(millisecond) - T0) div 1000]),
    [begin
         io:format("Q~p ~ts  ~ts  (confidence ~p)~n", [maps:get(n, Q), maps:get(result, Q), maps:get(final_answer, Q), maps:get(confidence, Q)]),
         [io:format("    ~5ts s  line ~p  ~ts~ts~n", [fmt(maps:get(t, S)), maps:get(line, S, none), maps:get(wrote, S),
                                                     case maps:get(crossed_out, S) of true -> "  (crossed out)"; false -> "" end]) || S <- maps:get(steps, Q)],
         case maps:get(diagnosis, Q) of <<>> -> ok; D -> io:format("    diagnosis at ~ts s: ~ts~n", [fmt(maps:get(moment_s, Q)), D]) end
     end || Q <- maps:get(questions, R)],
    io:format("pauses: ~p~n", [maps:get(pauses, R)]).
fmt(null) -> "-";
fmt(N) -> io_lib:format("~p", [N]).
