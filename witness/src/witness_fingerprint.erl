%%%-------------------------------------------------------------------
%%% witness_fingerprint — Lo's diagnostic question, when the paper alone is not enough (owner, 30 Oct).
%%%
%%% The marking (witness_mark:fingerprint/2) names a misconception only when the student's own ink holds enough
%%% evidence for it. When it does not ("Half up, half down. Same price."), the fingerprint carries `ask`: one
%%% diagnostic question Lo puts to the student in their Mastery Plan before the level is built. Their answer (written,
%%% or spoken and written down) is evidence too: Muse Spark reads it with the ink and completes the fingerprint
%%% (the misconception, the reasoning, the evidence, the intervention), or asks once more. After ?MAX_ASKS answers the
%%% level is built from the reasoning as it stands; the student is never held up.
%%%
%%%   fingerprint => #{reasoning, evidence, misconception, intervention, ask, said => [#{ask, text, at, spoken?}]}
%%%
%%%   answer(Q, Text, Read, At) (pure) / prompt(Q, Text) / parse(ModelText) / run(Key, Q, Text) -> {ok, F, Cost}
%%%-------------------------------------------------------------------
-module(witness_fingerprint).
-export([answer/4, prompt/2, parse/1, run/3, pending/1]).

-define(MODEL, <<"muse-spark-1.3">>).
-define(MAX_ASKS, 2).
-define(MAX_TEXT, 1500).

%% Whether Lo still has a question for this paper's question.
pending(#{fingerprint := #{ask := A} = F}) when A =/= <<>> -> length(maps:get(said, F, [])) < ?MAX_ASKS;
pending(_) -> false.

%% The student's answer, kept with the question it answered; Read is Spark's reading (a fingerprint map) or undefined.
answer(Q, Text0, Read, At) ->
    Text = case Text0 of B when is_binary(B) -> string:slice(string:trim(B), 0, ?MAX_TEXT); _ -> <<>> end,
    case {pending(Q), Text} of
        {false, _} -> {error, not_asked};
        {_, <<>>} -> {error, empty};
        {true, _} ->
            F = maps:get(fingerprint, Q),
            Said = maps:get(said, F, []) ++ [#{ask => maps:get(ask, F), text => Text, at => At}],
            F1 = case Read of
                #{} -> maps:merge(F, maps:with([reasoning, evidence, misconception, intervention, ask], Read));
                _ -> F
            end,
            %% after the last answer Lo asks no more: the level is built from what is known
            F2 = case length(Said) >= ?MAX_ASKS of true -> F1#{ask => <<>>}; false -> F1 end,
            Q#{fingerprint => F2#{said => Said}}
    end.

prompt(Q, Text) ->
    F = maps:get(fingerprint, Q, #{}),
    Said = [["  Lo asked: ", str(maps:get(ask, S, <<>>)), "\n  They said: ", str(maps:get(text, S, <<>>)), "\n"] || S <- maps:get(said, F, [])],
    unicode:characters_to_binary([
        "A student's exam answer was marked; the marking could not tell from the paper alone which wrong idea produced it,\n"
        "so Lo asked them one diagnostic question. Complete the Misconception Fingerprint from ALL the evidence.\n\n",
        "THE QUESTION: ", str(maps:get(question, Q, maps:get(text, Q, <<>>))), "\n",
        "THEIR ANSWER ON THE PAPER: ", str(maps:get(final_answer, Q, <<>>)), "\n",
        "THEIR WORKING, AS WRITTEN:\n", [["  ", str(maps:get(wrote, S, <<>>)), "\n"] || S <- maps:get(steps, Q, []), is_map(S)],
        "WHAT THE MARKING SAW: ", str(maps:get(diagnosis, Q, <<>>)), "\n",
        "THE REASONING IT READ: ", str(maps:get(reasoning, F, <<>>)), "\n",
        Said,
        "  Lo asked: ", str(maps:get(ask, F, <<>>)), "\n  They said now: ", Text, "\n\n",
        "Name the misconception only when the paper and what they said together are enough evidence; quote that evidence\n"
        "(their ink exactly, and their words as \"said: ...\"). The intervention is what would repair THAT idea, in one or\n"
        "two sentences a tutor can act on. If it is still not clear, leave misconception empty and give ONE more short\n"
        "question in \"ask\" that would settle it, without giving the right answer away; otherwise \"ask\" is empty.\n"
        "Return JSON only: {\"reasoning\":\"...\",\"evidence\":[\"...\"],\"misconception\":\"...\",\"intervention\":\"...\",\"ask\":\"\"}"]).

parse(Text) ->
    case decode(Text) of
        #{} = J when map_size(J) > 0 ->
            case witness_mark_fp(J) of
                #{} = F -> {ok, F};
                _ -> {error, no_fingerprint}
            end;
        _ -> {error, no_fingerprint}
    end.

%% the same rule as the marking's: a named misconception needs evidence, and with neither there is a question
witness_mark_fp(J) ->
    Evidence = [E || E <- [str(X) || X <- listy(maps:get(<<"evidence">>, J, []))], E =/= <<>>],
    Named = str(maps:get(<<"misconception">>, J, <<>>)),
    Ask = str(maps:get(<<"ask">>, J, <<>>)),
    M = case Named =/= <<>> andalso Evidence =/= [] of true -> Named; false -> <<>> end,
    A = Ask,
    #{reasoning => str(maps:get(<<"reasoning">>, J, <<>>)), evidence => lists:sublist(Evidence, 5), misconception => M,
      intervention => str(maps:get(<<"intervention">>, J, <<>>)), ask => A}.

run(Key, Q, Text) ->
    Req = #{model => ?MODEL, reasoning => #{effort => <<"medium">>}, max_output_tokens => 4000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(Q, Text)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
            case parse(witness_meta:text_of(R)) of {ok, F} -> {ok, F, Cost}; E -> E end;
        E -> E
    end.

decode(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

listy(L) when is_list(L) -> L;
listy(_) -> [].
str(B) when is_binary(B) -> B;
str(L) when is_list(L) -> unicode:characters_to_binary(L);
str(_) -> <<>>.
