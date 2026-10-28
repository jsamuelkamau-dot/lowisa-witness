%%%-------------------------------------------------------------------
%%% witness_read — an exam's questions and mark scheme read from the teacher's own file (hackathon, 2026-10-28).
%%%
%%% The submission: Spark marks "against a mark scheme built from the teacher's own material". The teacher gives a photo
%%% or a PDF of the paper or of its scheme; Muse Spark reads it (28 Oct, live: a phone photo as an image data URL, a PDF
%%% through the Files API as input_file) and fills the new exam: its name, level, questions with their marks, and the
%%% scheme in the teacher's own words. The teacher checks it before the exam is made.
%%%
%%%   prompt() -> binary
%%%   parse(ModelText) -> {ok, #{title, level, questions => [#{n, text, marks}], scheme}} | {error, unreadable | no_reading}
%%%   run(Key, Mime, Bytes) -> {ok, Read, CostUsd} | {error, Why}
%%%-------------------------------------------------------------------
-module(witness_read).
-export([prompt/0, parse/1, run/3, mimes/0]).

-define(MODEL, <<"muse-spark-1.3">>).

mimes() -> [<<"image/jpeg">>, <<"image/png">>, <<"image/webp">>, <<"application/pdf">>].

prompt() ->
    <<"A teacher is setting up an exam from their own material: a photo or a PDF of the exam paper, of its mark scheme, "
      "or of both. Read it as printed or written.\n"
      "- Every numbered question, with what it asks, word for word where it is printed, and the marks it is worth (the "
      "number in brackets, or the scheme's total for it; 1 when nothing says).\n"
      "- The mark scheme, question by question, in the teacher's own words, method marks included; empty when the "
      "material has none.\n"
      "- The exam's name and level when the page says them; else empty.\n"
      "Keep the material's own language. Never invent a question or a mark that is not there.\n"
      "Return JSON only: {\"title\":\"...\",\"level\":\"...\",\"questions\":[{\"n\":1,\"text\":\"...\",\"marks\":2}],"
      "\"scheme\":\"Q1: ...\"}. When it is not an exam or a mark scheme: {\"readable\":false}">>.

parse(Text) ->
    case decode(Text) of
        #{<<"readable">> := false} -> {error, unreadable};
        #{<<"questions">> := Qs} = J when is_list(Qs) ->
            Questions = [#{n => N, text => str(maps:get(<<"text">>, Q, <<>>)), marks => marks(maps:get(<<"marks">>, Q, 1))}
                         || Q <- lists:sublist(Qs, 60), is_map(Q), N <- [maps:get(<<"n">>, Q, null)], is_integer(N)],
            case {Questions, str(maps:get(<<"scheme">>, J, <<>>))} of
                {[], <<>>} -> {error, unreadable};
                {_, Scheme} -> {ok, #{title => str(maps:get(<<"title">>, J, <<>>)), level => str(maps:get(<<"level">>, J, <<>>)),
                                      questions => Questions, scheme => Scheme}}
            end;
        _ -> {error, no_reading}
    end.

run(Key, Mime, Bytes) ->
    Part = case Mime of
        <<"application/pdf">> ->
            case witness_meta:upload(Key, "material.pdf", "application/pdf", Bytes) of
                {ok, F} -> {ok, #{type => input_file, file_id => F}};
                Failed -> Failed
            end;
        _ -> {ok, #{type => input_image, image_url => <<"data:", Mime/binary, ";base64,", (base64:encode(Bytes))/binary>>}}
    end,
    case Part of
        {ok, P} ->
            Req = #{model => ?MODEL, reasoning => #{effort => <<"low">>}, max_output_tokens => 8000,
                    input => [#{type => message, role => user, content => [#{type => input_text, text => prompt()}, P]}]},
            case witness_meta:responses(Key, Req) of
                {ok, R} ->
                    Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
                    case parse(witness_meta:text_of(R)) of {ok, Read} -> {ok, Read, Cost}; NoRead -> NoRead end;
                CallFailed -> CallFailed
            end;
        NoPart -> NoPart
    end.

marks(N) when is_integer(N), N > 0, N =< 100 -> N;
marks(_) -> 1.

decode(Text) ->
    T = iolist_to_binary(Text),
    case binary:match(T, <<"{">>) of
        nomatch -> undefined;
        {S, _} ->
            E = lists:max([P || {P, _} <- binary:matches(T, <<"}">>)] ++ [S]),
            try json:decode(binary:part(T, S, E - S + 1)) catch _:_ -> undefined end
    end.

str(B) when is_binary(B) -> B;
str(_) -> <<>>.
