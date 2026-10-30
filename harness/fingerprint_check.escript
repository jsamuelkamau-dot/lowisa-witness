#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% fingerprint_check.escript <paper_p1.jpg> <paper_p2.jpg> <spec.json> [n]
%%
%% Marks a photographed two-page paper with Muse Spark through the same code the product uses (witness_photo:mark/4)
%% and prints question n's result and its Misconception Fingerprint as JSON. This is how the three learners in
%% evidence/misconceptions/ were recorded. The Meta key comes from MODEL_API_KEY and is never printed.
%%
%%   erlc -o _build/default/lib/witness/ebin witness/src/*.erl
%%   MODEL_API_KEY=... escript harness/fingerprint_check.escript p1.jpg p2.jpg spec.json 4
%%
%% spec.json: {"level": "Year 9", "scheme": "Q1: ...", "questions": [{"n": 1, "text": "...", "marks": 1}, ...]}
main([P1, P2, SpecFile]) -> main([P1, P2, SpecFile, "4"]);
main([P1, P2, SpecFile, NStr]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    N = list_to_integer(NStr),
    {ok, SpecJ} = file:read_file(SpecFile),
    Spec = json:decode(SpecJ),
    Sitting = #{level => maps:get(<<"level">>, Spec), scheme => maps:get(<<"scheme">>, Spec),
                questions => [#{n => maps:get(<<"n">>, Q), text => maps:get(<<"text">>, Q), marks => maps:get(<<"marks">>, Q)}
                              || Q <- maps:get(<<"questions">>, Spec)]},
    Pages = [#{n => 1, url => list_to_binary(P1)}, #{n => 2, url => list_to_binary(P2)}],
    case witness_photo:mark(Key, Pages, Sitting, #{fetch => fun(F) -> file:read_file(F) end}) of
        {ok, #{questions := Qs} = M} ->
            [Q] = [X || #{n := Xn} = X <- Qs, Xn =:= N],
            Out = #{name_read_from_paper => maps:get(name, maps:get(student, M, #{}), <<>>),
                    result => maps:get(result, Q), marks => maps:get(marks, Q), final_answer => maps:get(final_answer, Q),
                    steps_as_read => [maps:get(wrote, S) || S <- maps:get(steps, Q, [])],
                    fingerprint => maps:get(fingerprint, Q, null)},
            io:format("~ts~n", [json:encode(Out)]);
        E -> io:format("could not mark: ~p~n", [E]), halt(1)
    end;
main(_) -> io:format("usage: fingerprint_check.escript p1.jpg p2.jpg spec.json [question]~n"), halt(2).
