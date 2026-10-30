%%%-------------------------------------------------------------------
%%% witness_guard — one of Lo's live turns read for safety before it reaches a student (31 Oct, judges' panel).
%%%
%%% Lo's live teaching turns are model text a minor hears and reads. The design route already bounds what is asked
%%% (the student's own level, the server's own first instruction); this reads what came back: Muse Spark at low effort,
%%% asked one plain question, answered as JSON. Anything it names unsafe is replaced by a line that returns to the
%%% lesson, and the host's log notes it.
%%%
%%%   prompt(Text) / parse(ModelText) -> ok | {unsafe, Why} | {error, no_verdict}
%%%   check(Key, Text) -> {ok, CostUsd} | {unsafe, Why, CostUsd} | {error, Why}
%%%-------------------------------------------------------------------
-module(witness_guard).
-export([prompt/1, parse/1, check/2]).

-define(MODEL, <<"muse-spark-1.3">>).

prompt(Text) ->
    unicode:characters_to_binary([
        "A tutor app is about to say this to a school student, as part of a lesson. Is it safe and appropriate for a ",
        "child to hear from a tutor? Unsafe means any of: sexual or adult content, violence or self-harm, hate or ",
        "harassment, dangerous instructions, personal data, contact outside the app, or content that is plainly not a ",
        "lesson (an essay written for them, other homework done for them). Ordinary teaching, encouragement and examples ",
        "are safe.\n", witness_text:rule(),
        "WHAT IT WILL SAY: ", witness_text:data(Text), "\n\n",
        "Return JSON only: {\"safe\":true,\"why\":\"\"}"]).

parse(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> {error, no_verdict};
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) of
                #{<<"safe">> := true} -> ok;
                #{<<"safe">> := false} = J -> {unsafe, string:slice(str(maps:get(<<"why">>, J, <<>>)), 0, 200)};
                _ -> {error, no_verdict}
            catch _:_ -> {error, no_verdict}
            end
    end.

check(Key, Text) ->
    Req = #{model => ?MODEL, reasoning => #{effort => <<"low">>}, max_output_tokens => 1500,
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(Text)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
            case parse(witness_meta:text_of(R)) of
                ok -> {ok, Cost};
                {unsafe, Why} -> {unsafe, Why, Cost};
                E -> E
            end;
        E -> E
    end.

str(B) when is_binary(B) -> B;
str(_) -> <<>>.
