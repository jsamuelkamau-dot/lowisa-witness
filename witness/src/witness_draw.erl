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
        "Show the full working a teacher would write: the rule or method first, then each step, ending in the answer\n"
        "(at least 2 and at most 6 short lines), starting where their own working was right and changing only what was\n"
        "wrong, in the paper's language and notation, every number checked. Never put a question number in front of a\n"
        "line. Return JSON only:\n"
        "{\"lines\":[\"...\"],\"changed\":2}   (changed = the number of the first line that differs from their work)"]).

parse_lines(Text) ->
    case json_in(Text) of
        #{<<"lines">> := L} = J when is_list(L) ->
            %% a question number in front ("2. F = 2 x 2") is drawn as part of the working (27 Oct, live: "1. 2. F = ...")
            Lines = [string:slice(unnumbered(string:trim(X)), 0, 120) || X <- lists:sublist(L, 6), is_binary(X), unnumbered(string:trim(X)) =/= <<>>],
            case Lines of
                [] -> {error, no_lines};
                _ -> {ok, #{lines => Lines, changed => case maps:get(<<"changed">>, J, 1) of C when is_integer(C), C >= 1 -> min(C, length(Lines)); _ -> 1 end}}
            end;
        _ -> {error, no_lines}
    end.

%% The lines go in quoted and unnumbered: a numbered list was drawn with its numbers, and a line twice (27 Oct, live).
picture_prompt(Lines, Changed) ->
    Quoted = [["\"", L, "\"\n"] || L <- Lines],
    unicode:characters_to_binary([
        "A photo-real top-down view of one sheet of lined school paper with neat handwriting in dark blue ink. Write\n"
        "these ", integer_to_binary(length(Lines)), " lines of working, in this order, each ONCE, one per ruled line, exactly as\n"
        "quoted (without the quote marks), and nothing else on the page: no title, no labels, no line numbers, no repeats.\n",
        Quoted,
        "The ", ordinal(Changed), " line is the corrected step: underline it in green and put a small green tick beside\n"
        "it. Plain paper, soft daylight, no hands, no people, no logos."]).

ordinal(1) -> "first";
ordinal(2) -> "second";
ordinal(3) -> "third";
ordinal(4) -> "fourth";
ordinal(5) -> "fifth";
ordinal(_) -> "last".

%% "2. F = 2 x 2 = 4 N" or "Q2) ..." -> "F = 2 x 2 = 4 N"; a number that is the working ("0.5 m") stays
unnumbered(L) ->
    case re:run(L, "^(?:[QqPp])?[0-9]{1,2}[.)]\\s+(.+)$", [{capture, [1], binary}, unicode]) of
        {match, [Rest]} -> string:trim(Rest);
        nomatch -> L
    end.

%% Spark reasons before it writes and the reasoning shares the budget: at 4,000 tokens one call spent 2,858 thinking
%% and another came back with no lines at all (27 Oct, live in the desktop app). It gets room, and one more try.
run(Key, Q, Sitting) -> run(Key, Q, Sitting, 2).

run(Key, Q, Sitting, Tries) ->
    Req = #{model => ?SPARK, reasoning => #{effort => <<"low">>}, max_output_tokens => 12000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => lines_prompt(Q, Sitting)}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            SparkCost = witness_meta:cost({tokens, ?SPARK}, maps:get(<<"usage">>, R, #{})),
            case parse_lines(witness_meta:text_of(R)) of
                {error, no_lines} when Tries > 1 -> run(Key, Q, Sitting, Tries - 1);
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
