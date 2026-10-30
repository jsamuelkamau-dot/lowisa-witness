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
%%%   fingerprint => #{reasoning, evidence, misconception, intervention, ask, possible?, said => [#{ask, text, at, audio?}]}
%%%   (`possible`: the model's guess while Lo is still asking, for the teacher only; nothing is named until the answer)
%%%
%%%   answer(Q, Text, Read, At) (pure) / prompt(Q, Text) / parse(ModelText) / run(Key, Q, Text) -> {ok, F, Cost}
%%%-------------------------------------------------------------------
-module(witness_fingerprint).
-export([answer/4, answer/5, prompt/2, parse/1, run/3, pending/1, settled/1]).

-define(MODEL, <<"muse-spark-1.3">>).
-define(MAX_ASKS, 2).
-define(MAX_TEXT, 1500).

%% Whether Lo still has a question for this paper's question.
pending(#{fingerprint := #{ask := A} = F}) when A =/= <<>> -> length(maps:get(said, F, [])) < ?MAX_ASKS;
pending(_) -> false.

%% The student's answer, kept with the question it answered; Read is Spark's reading (a fingerprint map) or undefined.
answer(Q, Text0, Read, At) -> answer(Q, Text0, Read, At, #{}).

%% Kept: what was kept of a spoken answer (#{audio => File}), noted with the answer.
answer(Q, Text0, Read, At, Kept) ->
    Text = case Text0 of B when is_binary(B) -> string:slice(string:trim(B), 0, ?MAX_TEXT); _ -> <<>> end,
    case {pending(Q), Text} of
        {false, _} -> {error, not_asked};
        {_, <<>>} -> {error, empty};
        {true, _} ->
            F = maps:get(fingerprint, Q),
            Said = maps:get(said, F, []) ++ [maps:merge(#{ask => maps:get(ask, F), text => Text, at => At}, maps:with([audio], Kept))],
            F1 = case Read of
                #{} -> maps:merge(maps:remove(possible, F), maps:with([reasoning, evidence, misconception, intervention, ask, possible], vet(Read, Q, Said)));
                _ -> F
            end,
            %% after the last answer Lo asks no more: the level is built from what is known
            F2 = case length(Said) >= ?MAX_ASKS of true -> F1#{ask => <<>>}; false -> F1 end,
            settled(Q#{fingerprint => F2#{said => Said}})
    end.

%% 31 Oct (judges' panel: after Lo asked, any evidence the model wrote let it name the idea, the film's own path). The
%% marking's rule again, with the student's answer as a second source: an evidence line is kept only when it is in the
%% lines read from their page (never the final answer alone) or, written "said: ...", in what they told Lo. A name left
%% with no evidence is a guess again, kept for the teacher, and Lo may ask once more.
vet(#{misconception := Named} = Read, Q, Said) ->
    Lines = [witness_mark:norm(W) || #{wrote := W} <- maps:get(steps, Q, []), is_binary(W)],
    Final = maps:get(final_answer, Q, <<>>),
    Words = witness_mark:norm(iolist_to_binary(lists:join(<<" ">>, [T || #{text := T} <- Said]))),
    Kept = [E || E <- maps:get(evidence, Read, []), own(E, Lines, Final, Words)],
    case {Named, Kept} of
        {<<_, _/binary>>, []} ->
            Ask = case length(Said) < ?MAX_ASKS of true -> <<"Write or say what you had after each step, and how you got it.">>; false -> <<>> end,
            Read#{evidence => [], misconception => <<>>, possible => Named, ask => Ask};
        _ -> Read#{evidence => Kept}
    end;
vet(Read, _, _) -> Read.

own(E, Lines, Final, Words) ->
    case string:prefix(string:lowercase(E), <<"said:">>) of
        nomatch -> witness_mark:quote_in_ink(E, Lines, Final);
        Rest -> W = witness_mark:norm(Rest), byte_size(W) >= 4 andalso binary:match(Words, W) =/= nomatch
    end.

%% 30 Oct (judges' panel: the corrected reading reached nothing after it). Once Lo has no more questions, what the
%% answer showed becomes the question's diagnosis, so everything that reads the diagnosis next (the level's brief,
%% Muse Wonder's self-check and class patterns, the challenge drafter and judge, the recommendation) works from it.
%% The marking's first reading is kept as `diagnosis_first`.
settled(#{fingerprint := #{ask := <<>>} = F} = Q) ->
    New = case {maps:get(misconception, F, <<>>), maps:get(reasoning, F, <<>>)} of
        {<<>>, <<>>} -> <<>>;
        {<<>>, R} -> R;
        %% the named idea alone: the reasoning is how the evidence led there, and the desk shows it on its own line
        %% (30 Oct rehearsal: "where the thinking went wrong" read "...: Paper alone with A $100 could be ...")
        {M, _} -> M
    end,
    case New of
        <<>> -> Q;
        _ -> (maps:merge(#{diagnosis_first => maps:get(diagnosis, Q, <<>>)}, Q))#{diagnosis => New}
    end;
settled(Q) -> Q.

prompt(Q, Text) ->
    F = maps:get(fingerprint, Q, #{}),
    Said = [["  Lo asked: ", str(maps:get(ask, S, <<>>)), "\n  They said: ", witness_text:data(maps:get(text, S, <<>>)), "\n"] || S <- maps:get(said, F, [])],
    unicode:characters_to_binary([
        "A student's exam answer was marked; the marking could not tell from the paper alone which wrong idea produced it,\n"
        "so Lo asked them one diagnostic question. Complete the Misconception Fingerprint from ALL the evidence.\n",
        witness_text:rule(), "\n",
        "THE QUESTION: ", str(maps:get(question, Q, maps:get(text, Q, <<>>))), "\n",
        "THEIR ANSWER ON THE PAPER: ", str(maps:get(final_answer, Q, <<>>)), "\n",
        "THEIR WORKING, AS WRITTEN:\n", [["  ", witness_text:data(maps:get(wrote, S, <<>>)), "\n"] || S <- maps:get(steps, Q, []), is_map(S)],
        "WHAT THE MARKING SAW: ", str(maps:get(diagnosis, Q, <<>>)), "\n",
        "THE REASONING IT READ: ", str(maps:get(reasoning, F, <<>>)), "\n",
        Said,
        "  Lo asked: ", str(maps:get(ask, F, <<>>)), "\n  They said now: ", witness_text:data(Text), "\n\n",
        "Name the misconception only when the paper and what they said together are enough evidence; quote that evidence\n"
        "(their ink exactly, and their words as \"said: ...\"). The intervention is what would repair THAT idea, in one or\n"
        "two sentences a tutor can act on. If it is still not clear, leave misconception empty, say in \"reasoning\" which\n"
        "ideas it could still be, and give ONE more short question in \"ask\" that would settle it: it asks them to show or\n"
        "say their own calculation, never names the idea you suspect, and never gives the right answer away. When the\n"
        "misconception is named, \"ask\" is empty.\n"
        "\"rivals\" lists any other wrong idea that what they wrote and said still fits; name one only when none is left.\n"
        "Return JSON only: {\"reasoning\":\"...\",\"evidence\":[\"...\"],\"rivals\":[],\"misconception\":\"...\",\"intervention\":\"...\",\"ask\":\"\"}"]).

parse(Text) ->
    case decode(Text) of
        #{} = J when map_size(J) > 0 ->
            case witness_mark_fp(J) of
                #{} = F -> {ok, F};
                _ -> {error, no_fingerprint}
            end;
        _ -> {error, no_fingerprint}
    end.

%% The same rule as the marking's (witness_mark:fingerprint/4): a named misconception needs evidence, and while there is
%% still a question nothing is named; the guess waits as `possible`. Evidence here may also be the student's words.
witness_mark_fp(J) ->
    Evidence = [E || E <- [str(X) || X <- listy(maps:get(<<"evidence">>, J, []))], E =/= <<>>],
    Named = str(maps:get(<<"misconception">>, J, <<>>)),
    Rivals = [R || R <- [str(X) || X <- lists:sublist(listy(maps:get(<<"rivals">>, J, [])), 4)], R =/= <<>>],
    Ask = case {str(maps:get(<<"ask">>, J, <<>>)), Rivals} of
        {<<>>, [_ | _]} -> <<"Write or say what you had after each step, and how you got it.">>;
        {A0, _} -> A0
    end,
    {M, Possible} = case {Ask, Evidence} of
        {<<>>, [_ | _]} -> {Named, <<>>};
        _ -> {<<>>, Named}
    end,
    maps:merge(#{reasoning => str(maps:get(<<"reasoning">>, J, <<>>)), evidence => lists:sublist(Evidence, 5), misconception => M,
                 intervention => str(maps:get(<<"intervention">>, J, <<>>)), ask => Ask},
               case Possible of <<>> -> #{}; _ -> #{possible => Possible} end).

run(Key, Q, Text) ->
    Req = #{model => ?MODEL, reasoning => #{effort => <<"medium">>}, max_output_tokens => 4000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(Q, Text)}]}]},
    case witness_meta:structured(Key, Req, <<"fingerprint">>, schema()) of
        {ok, R} ->
            Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
            case parse(witness_meta:text_of(R)) of {ok, F} -> {ok, F, Cost}; E -> E end;
        E -> E
    end.

schema() ->
    witness_meta:object(#{reasoning => #{type => string}, evidence => #{type => array, items => #{type => string}}, rivals => #{type => array, items => #{type => string}}, misconception => #{type => string}, intervention => #{type => string}, ask => #{type => string}}).

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
