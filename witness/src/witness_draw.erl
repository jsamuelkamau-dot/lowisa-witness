%%%-------------------------------------------------------------------
%%% witness_draw — Muse Image draws the corrected step (hackathon, 2026-10-27).
%%%
%%% A picture model can draw handwriting well but should not do the arithmetic, so Muse Spark first writes the
%%% corrected working as exact lines (from the student's own steps, so it starts where they started), and Muse Image
%%% draws those lines in ink on lined paper with the changed step marked. The lines are kept beside the picture, so
%%% the teacher reads what was drawn and a screen reader can say it.
%%%
%%%   lines_prompt(Q, Sitting) / parse_lines(Text) -> {ok, #{lines, changed}}
%%%   picture_prompt(Lines, Changed) -> binary()
%%%   run(Key, Q, Sitting) -> {ok, #{bytes, format, lines, changed}, Cost}
%%%-------------------------------------------------------------------
-module(witness_draw).
-export([lines_prompt/2, parse_lines/1, picture_prompt/2, run/3]).

-define(SPARK, <<"muse-spark-1.3">>).

lines_prompt(Q, Sitting) ->
    Text = case [X || X = #{n := N} <- maps:get(questions, Sitting, []), N =:= maps:get(n, Q, 0)] of [#{text := T} | _] -> T; _ -> <<>> end,
    unicode:characters_to_binary([
        "Write the corrected working for one question a student got wrong, for them to see drawn on paper.\n",
        "THE QUESTION: ", str(Text), "\n",
        "WHAT THEY WROTE:\n", [["  ", str(maps:get(wrote, S, <<>>)), "\n"] || S <- maps:get(steps, Q, []), is_map(S)],
        "WHERE IT WENT WRONG: ", str(maps:get(diagnosis, Q, <<>>)), "\n\n",
        "Start from their own first step where it was right and change only what was wrong. At most 6 short lines of\n"
        "working, in the paper's language and notation, every number checked, ending in the answer. Return JSON only:\n"
        "{\"lines\":[\"...\"],\"changed\":2}   (changed = the number of the first line that differs from their work)"]).

parse_lines(Text) ->
    case json_in(Text) of
        #{<<"lines">> := L} = J when is_list(L) ->
            Lines = [string:slice(string:trim(X), 0, 120) || X <- lists:sublist(L, 6), is_binary(X), string:trim(X) =/= <<>>],
            case Lines of
                [] -> {error, no_lines};
                _ -> {ok, #{lines => Lines, changed => case maps:get(<<"changed">>, J, 1) of C when is_integer(C), C >= 1 -> min(C, length(Lines)); _ -> 1 end}}
            end;
        _ -> {error, no_lines}
    end.

picture_prompt(Lines, Changed) ->
    Numbered = [[integer_to_binary(I), ". ", L, "\n"] || {I, L} <- lists:zip(lists:seq(1, length(Lines)), Lines)],
    unicode:characters_to_binary([
        "A photo-real top-down view of one sheet of lined school paper with neat handwriting in dark blue ink. Write\n"
        "EXACTLY these lines, one per ruled line, nothing else on the page (no title, no labels, no extra numbers):\n",
        Numbered,
        "Line ", integer_to_binary(Changed), " is the corrected step: underline it in green and put a small green tick\n"
        "beside it. Plain paper, soft daylight, no hands, no people, no logos."]).

run(Key, Q, Sitting) ->
    Req = #{model => ?SPARK, reasoning => #{effort => <<"medium">>}, max_output_tokens => 4000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => lines_prompt(Q, Sitting)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            SparkCost = witness_meta:cost({tokens, ?SPARK}, maps:get(<<"usage">>, R, #{})),
            case parse_lines(witness_meta:text_of(R)) of
                {ok, #{lines := Lines, changed := Ch}} ->
                    case witness_meta:image(Key, picture_prompt(Lines, Ch)) of
                        {ok, Bytes, Fmt} -> {ok, #{bytes => Bytes, format => Fmt, lines => Lines, changed => Ch}, SparkCost + witness_meta:cost(image, 1)};
                        E -> E
                    end;
                E -> E
            end;
        E -> E
    end.

json_in(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

str(B) when is_binary(B) -> B;
str(_) -> <<>>.
