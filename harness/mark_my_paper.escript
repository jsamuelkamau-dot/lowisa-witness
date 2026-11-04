#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% mark_my_paper.escript <the exam: photo or PDF> <a finished page.jpg> [more pages.jpg ...]
%%
%% 4 Nov (independent audit: "a recorded result is not a live model demonstration; give judges a route to test a
%% genuinely new examination with current Meta models"). Any exam, any finished paper, marked live by Muse Spark through
%% the code the edge runs, with no LoWisa account: witness_read reads the questions and their marks from the exam, then
%% witness_photo:mark/4 marks the photographed pages and reads each wrong answer's Misconception Fingerprint. It prints
%% what the teacher's desk would show: each question's result, how sure it is, whether it goes to "Accept all" or is
%% checked one by one, and for each question not mastered either the idea named (with the student's own lines as
%% evidence) or the question Lo asks first because the ink cannot tell. The whole result is written beside the first page.
%%
%%   sh scripts/test.sh                       # builds the library into _build (no key needed)
%%   MODEL_API_KEY=... escript harness/mark_my_paper.escript evidence/unseen-physics/paper.jpg evidence/unseen-physics/paper.jpg
%%
%% Needs Erlang/OTP 27+, ffmpeg on the PATH (the ink colour and line placing), and a Meta Model API key, which is read
%% from MODEL_API_KEY and never printed. A 30-question page costs about $0.05-0.45 and takes about a minute.
main([Exam | Pages]) when Pages =/= [] ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    {ok, ExamBytes} = file:read_file(Exam),
    Mime = case string:lowercase(filename:extension(Exam)) of ".pdf" -> <<"application/pdf">>; ".png" -> <<"image/png">>; _ -> <<"image/jpeg">> end,
    io:format("Reading the exam's questions from ~s ...~n", [Exam]),
    {ok, Read, ReadCost} = case witness_read:run(Key, Mime, ExamBytes) of
        {ok, _, _} = Ok -> Ok;
        E1 -> io:format("The exam could not be read: ~p~n", [E1]), halt(1)
    end,
    Qs = maps:get(questions, Read),
    io:format("~ts: ~p questions~n", [maps:get(title, Read, <<"Exam">>), length(Qs)]),
    Sitting = #{level => maps:get(level, Read, <<>>), scheme => maps:get(scheme, Read, <<>>), questions => Qs},
    io:format("Marking ~p page(s) with Muse Spark ...~n", [length(Pages)]),
    T0 = erlang:monotonic_time(millisecond),
    Paper = [#{n => N, url => list_to_binary(P)} || {N, P} <- lists:zip(lists:seq(1, length(Pages)), Pages)],
    M = case witness_photo:mark(Key, Paper, Sitting, #{fetch => fun(F) -> file:read_file(F) end}) of
        {ok, M0} -> M0;
        E2 -> io:format("The paper could not be marked: ~p~n", [E2]), halt(1)
    end,
    Secs = (erlang:monotonic_time(millisecond) - T0) / 1000,
    Marked = maps:get(questions, M),
    io:format("~nName on the paper: ~ts~n~n", [maps:get(name, maps:get(student, M, #{}), <<"(none read)">>)]),
    [line(Q) || Q <- Marked],
    Sure = [Q || Q <- Marked, maps:get(confidence, Q, 0) >= 0.9],
    io:format("~n\"Accept all\" (0.9 or more): ~p; checked one by one: ~p. Nothing reaches a student until the teacher releases it.~n",
              [length(Sure), length(Marked) - length(Sure)]),
    Cost = ReadCost + maps:get(cost_usd, M, 0),
    io:format("Marked in ~.1f s, about $~.3f.~n", [Secs, Cost]),
    Out = filename:rootname(hd(Pages)) ++ "-marked.json",
    ok = file:write_file(Out, json:encode(#{exam => Read, result => M, marking_seconds => Secs, cost_usd => Cost})),
    io:format("Everything it returned: ~s~n", [Out]);
main(_) ->
    io:format("usage: escript harness/mark_my_paper.escript <exam photo or PDF> <finished page.jpg> [more pages]~n"), halt(1).

line(Q) ->
    Res = maps:get(result, Q, <<"?">>),
    io:format("Q~p  ~ts  ~p/~p  sure ~.2f~n", [maps:get(n, Q, 0), Res, maps:get(marks, Q, 0), maps:get(out_of, Q, 0), float(maps:get(confidence, Q, 0))]),
    case maps:get(fingerprint, Q, null) of
        #{misconception := Mc, evidence := Ev} when Mc =/= <<>>, Ev =/= [] ->
            io:format("    idea named: ~ts~n    from the student's own lines: ~ts~n", [Mc, lists:join(<<" | ">>, Ev)]);
        #{ask := Ask} when Ask =/= <<>> ->
            io:format("    no idea named: the ink cannot tell. Lo asks first: ~ts~n", [Ask]);
        _ when Res =/= <<"mastered">> ->
            case maps:get(diagnosis, Q, <<>>) of <<>> -> ok; D -> io:format("    ~ts~n", [D]) end;
        _ -> ok
    end.
