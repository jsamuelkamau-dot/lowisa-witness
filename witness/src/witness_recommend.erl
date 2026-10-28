%%%-------------------------------------------------------------------
%%% witness_recommend — Muse Spark's recommendation for the teacher's badge decision (hackathon, 2026-10-28).
%%%
%%% The plan's badge review shows the teacher "the AI's recommendation" beside the evidence: the original slip, the
%%% focus note, the level's activity, the explanations, the fresh question and the thread. Spark reads all of it and
%%% recommends issuing "Turned around" or "not yet", with the reason and what is still missing. It only recommends:
%%% the badge is the teacher's, always (owner, 27 Oct).
%%%
%%%   prompt(Q) -> binary           Q = the question with its mastery (witness_mastery)
%%%   parse(ModelText) -> {ok, #{recommend => <<"issue">> | <<"not_yet">>, why, missing}} | {error, no_recommendation}
%%%   run(Key, Q) -> {ok, Rec, CostUsd} | {error, Why}
%%%-------------------------------------------------------------------
-module(witness_recommend).
-export([prompt/1, parse/1, run/2]).

-define(MODEL, <<"muse-spark-1.3">>).

prompt(Q) ->
    M = maps:get(mastery, Q, #{}),
    Ex = maps:get(explain, M, #{}),
    Asks = maps:get(asks, M, #{}),
    Activity = [io_lib:format("- ~ts: ~ts~n", [maps:get(title, A, <<>>), case {maps:get(right, A, null), maps:get(asked, A, null)} of
                                                                          {R, N} when is_integer(R), is_integer(N) -> io_lib:format("~b of ~b right first time", [R, N]);
                                                                          _ -> "finished" end])
                || A <- maps:get(activity, M, [])],
    Fresh = case maps:get(fresh, M, #{}) of
        #{status := <<"marked">>, question := FQ} -> ["marked ", str(maps:get(result, FQ, <<>>)), ", ", num(maps:get(marks, FQ, 0)), " of ",
                                                      num(maps:get(out_of, FQ, 0)), case str(maps:get(diagnosis, FQ, <<>>)) of <<>> -> ""; D -> [": ", D] end];
        #{status := S} -> ["not marked (", str(S), ")"];
        _ -> case maps:get(paper, Asks, false) of true -> "asked for, not done yet"; false -> "not asked for" end
    end,
    unicode:characters_to_binary([
        "You help a teacher decide whether a student has turned around one exam question they did not master. The teacher ",
        "decides; you recommend, from the evidence only.\n\n",
        "THE QUESTION: ", str(maps:get(question, Q, maps:get(text, Q, <<>>))), "\n",
        "WHAT WENT WRONG IN THE EXAM: ", str(maps:get(diagnosis, Q, <<>>)), "\n",
        case str(maps:get(focus, Q, <<>>)) of <<>> -> ""; F -> ["THE TEACHER'S FOCUS NOTE: ", F, "\n"] end,
        "THE MASTERY LEVEL: ", str(maps:get(status, M, <<"not_started">>)), "\n",
        case Activity of [] -> "LESSONS FINISHED: none recorded\n"; _ -> ["LESSONS FINISHED:\n", Activity] end,
        "EXPLAINED BACK TO LO: ", explained(maps:get(lo, Ex, undefined), maps:get(lo, Asks, false), true), "\n",
        "EXPLAINED BACK TO THE TEACHER: ", explained(maps:get(teacher, Ex, undefined), maps:get(teacher, Asks, false), false), "\n",
        "THE FRESH QUESTION ON PAPER: ", Fresh, "\n",
        "QUESTIONS THE STUDENT ASKED: ", integer_to_list(length([T || T = #{from := student} <- maps:get(thread, M, [])])), "\n\n",
        "Recommend \"issue\" only when the evidence shows the right idea now (a correct fresh question, or an explanation ",
        "that names why the first way was wrong). A finished level alone is not proof. Name what is missing when you say ",
        "\"not_yet\". Return JSON only: {\"recommend\":\"issue\",\"why\":\"one or two sentences\",\"missing\":\"what would settle it, or empty\"}"]).

explained(undefined, true, _) -> "asked for, not done yet";
explained(undefined, _, _) -> "not asked for";
explained(#{text := T} = E, _, Lo) ->
    [$", T, $", case {Lo, maps:get(verdict, E, undefined)} of
                    {true, #{understood := U, why := W}} -> [" (Lo judged it ", case U of true -> "understood"; false -> "not yet understood" end, ": ", str(W), ")"];
                    _ -> ""
                end].

parse(Text) ->
    case decode(Text) of
        #{<<"recommend">> := R} = J when R =:= <<"issue">>; R =:= <<"not_yet">> ->
            {ok, #{recommend => R, why => str(maps:get(<<"why">>, J, <<>>)), missing => str(maps:get(<<"missing">>, J, <<>>))}};
        _ -> {error, no_recommendation}
    end.

run(Key, Q) ->
    Req = #{model => ?MODEL, reasoning => #{effort => <<"medium">>}, max_output_tokens => 4000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(Q)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
            case parse(witness_meta:text_of(R)) of {ok, Rec} -> {ok, Rec, Cost}; E -> E end;
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

str(B) when is_binary(B) -> B;
str(L) when is_list(L) -> unicode:characters_to_binary(L);
str(_) -> <<>>.
num(N) when is_integer(N) -> integer_to_list(N);
num(N) when is_float(N) -> float_to_list(N, [{decimals, 1}, compact]);
num(_) -> "0".
