%%%-------------------------------------------------------------------
%%% witness_photo — a finished paper marked from photos of its pages (2026-10-29, From Exam to Mastery).
%%%
%%% After the exam one phone (a teacher's, or one the school owns) photographs every page of each student's paper. Muse
%%% Spark reads the paper's own details (the name as the student wrote it, the class, a number, the date), marks every
%%% question's thinking as well as its answer against the teacher's scheme, and names which of the seven thinking
%%% capabilities each question to master should build. witness_page puts every line on its own ink on the page, so the
%%% student's own step can be cut from their paper for their Mastery Plan.
%%%
%%% Witness (the desk filmed while the student writes) is the other way in; both give the same result, so the desk,
%%% the queue, the release and the Mastery Plan are the same for both.
%%%
%%%   prompt(Sitting) -> binary
%%%   mark(Key, Pages, Sitting) -> {ok, Result} | {error, Why}
%%%       Pages = [#{n, url, mime}]  signed links to the photographed pages, in page order
%%%       Result = #{questions, student => #{name, class, number, date, note}, pages, cost_usd}
%%%   orient(Key, Pages) -> {ok, #{N => Degrees}, CostUsd} | {error, Why}
%%%       how far each page must be turned clockwise to read upright (0, 90, 180 or 270)
%%%-------------------------------------------------------------------
-module(witness_photo).
-export([prompt/1, mark/3, mark/4, place/3, place/4]).
%% 3 Nov: which way up each photographed page is
-export([orient/2, orient/3]).

-define(SPARK, <<"muse-spark-1.3">>).

prompt(Sitting) ->
    Qs = case maps:get(questions, Sitting, []) of
        [] -> <<"The questions are printed on the paper.">>;
        List -> unicode:characters_to_binary(["The questions:\n" | [io_lib:format("~p. ~ts (~p marks)~n", [maps:get(n, Q), maps:get(text, Q), maps:get(marks, Q, 1)]) || Q <- List]])
    end,
    Scheme = case maps:get(scheme, Sitting, <<>>) of
        <<>> -> %% 31 Oct (photo bench on the committed code): "give 1 mark" beside a question listed as 2 marks gave right work 1 of
        %% 2, which the marking rightly reads as not mastered; a fully correct question earns all of its worth
        <<"No mark scheme was given: a fully correct question (right method and right answer) earns every mark it is worth; a right method that did not reach the answer earns part of them.">>;
        S -> <<"The teacher's mark scheme (follow it exactly, including method marks):\n", S/binary>>
    end,
    unicode:characters_to_binary([
        "You are marking a student's finished exam paper (", maps:get(level, Sitting, <<"any level">>), ") from photos of its pages, "
        "taken after the exam. Each photo is labelled with its page number before it.\n",
        Qs, "\n", Scheme, "\n\n"
        "First read the paper's own details from what is written on it: the student's name exactly as written, and the class,\n"
        "candidate or admission number and date when the paper has them. Copy the name letter for letter, accents included;\n"
        "never guess a name that cannot be read: leave it empty and say why in name_note.\n"
        "If no page of the student's work can be read in the photos (no paper, too dark or blurred to read), mark nothing and\n"
        "return ONLY {\"readable\":false,\"why\":\"one plain sentence of what the photos show\"}. A page that is in view but\n"
        "left empty IS readable: its questions are not_yet, with the diagnosis that they were left blank.\n\n",
        witness_mark:ink_is_work(),
        "For every question, judge the THINKING as well as the final answer:\n"
        "- \"steps\" are the student's own lines for the question in the order they appear; \"wrote\" is the ink exactly as\n"
        "  written (copy it, never describe it); crossed_out is true for a line struck through to replace it; slashes drawn\n"
        "  through digits to cancel them are part of the line, so say so in it (\"16/64 with both 6s struck\");\n"
        "- \"page\" is the photo the line is on (1 for the first); \"box\" is where the line is on that photo as [left, top,\n"
        "  right, bottom] in thousandths of the photo's width and height (0 to 1000), around the handwriting only;\n"
        "- \"printed\" is where the question itself is printed, {\"page\":1,\"box\":[...]} around its first printed line, the\n"
        "  same way; null when the question is not printed on the paper;\n"
        "- a right final answer reached by a wrong method is \"right_answer_wrong_thinking\" (for example cancelling digits\n"
        "  that are not common factors, or two mistakes that cancel each other out);\n"
        "- \"mastered\" is right with right thinking and full marks (a slip the student corrected themselves still counts);\n"
        "- \"part_way\" is a right start that did not reach the answer, or a right answer written with no working when the\n"
        "  question needs a step that appears nowhere (the diagnosis says only the answer was written); a line that shows\n"
        "  its own calculation IS working, and a one-step answer that is itself the method is judged on its own;\n"
        "- \"not_yet\" is a wrong answer or a wrong method;\n"
        "- out_of is what the question is worth as listed; marks is how many of those were earned;\n"
        "- the diagnosis is ONE plain sentence naming the exact misconception, never just \"wrong\"; empty when mastered;\n"
        "- \"slip\" is the number of the step (1 for the first) where the thinking went wrong; null when mastered;\n"
        "- \"capabilities\": for every question that is not mastered, the one or two of these seven thinking capabilities\n"
        "  its mastery work should build, by name: ", capability_list(), "; empty when mastered;\n",
        witness_mark:skill_rule(),
        witness_mark:fingerprint_rule(),
        "- confidence is how sure you are of the result, 0 to 1.\n"
        "Return JSON only:\n"
        "{\"student\":{\"name\":\"...\",\"class\":\"...\",\"number\":\"...\",\"date\":\"...\",\"name_note\":\"\"},"
        "\"questions\":[{\"n\":1,\"printed\":{\"page\":1,\"box\":[0,0,0,0]},\"final_answer\":\"...\","
        "\"steps\":[{\"wrote\":\"...\",\"crossed_out\":false,\"page\":1,\"box\":[0,0,0,0]}],"
        "\"result\":\"mastered|right_answer_wrong_thinking|part_way|not_yet\",\"marks\":0,\"out_of\":2,\"diagnosis\":\"...\","
        "\"slip\":null,\"capabilities\":[\"...\"],\"skill\":\"...\",", witness_mark:fingerprint_json(), "\"confidence\":0.9}]}"]).

capability_list() -> lists:join(", ", witness_mark:capabilities()).

%% Fetch(Url) -> {ok, Bytes}: how a page's photo is read (the host's signed link; a test hands its own).
mark(Key, Pages, Sitting) -> mark(Key, Pages, Sitting, #{}).
mark(Key, Pages, Sitting, Opts) ->
    Fetch = maps:get(fetch, Opts, fun witness_meta:fetch/1),
    Gray = maps:get(gray, Opts, fun(Url) -> witness_media:gray_image(Url, 600) end),
    %% the page's ink colour, which tells a student's pen from the printed questions (a test's own pages give none)
    Tint = maps:get(tint, Opts, case maps:is_key(gray, Opts) of true -> fun(_) -> none end; false -> fun(Url) -> witness_media:tint_image(Url, 600) end end),
    %% every reading of one paper (the first, and an unsure question's second and third) shares one cache key, so the
    %% pages sent again are read from Meta's prompt cache (31 Oct, judges' panel: rereads sent every page again)
    CacheKey = <<"witness-paper-", (integer_to_binary(erlang:phash2([maps:get(url, P, <<>>) || P <- Pages])))/binary>>,
    Read = maps:get(read, Opts, fun(K, Content, Effort) -> witness_meta:read_content(K, ?SPARK, Content, #{effort => Effort, cache_key => CacheKey}) end),
    %% 31 Oct: the engine that reads it (Muse Spark on the Meta Model API, or Muse Spark Open through witness_open), for
    %% its price and its name on the result
    Price = maps:get(price, Opts, {tokens, ?SPARK}),
    case content(Pages, Fetch) of
        {ok, Images} ->
            Content = [#{type => input_text, text => prompt(Sitting)} | Images],
            case Read(Key, Content, <<"medium">>) of
                {ok, Text, Usage} ->
                    case witness_mark:parse(Text) of
                        {ok, #{questions := Qs0} = M} ->
                            Qs = witness_mark:fit(Qs0, Sitting),
                            Cost = witness_meta:cost(Price, Usage),
                            Marked = again(Key, Content, Sitting, Read, Price, #{questions => Qs, cost_usd => Cost}),
                            {ok, Marked#{questions => place(maps:get(questions, Marked), Pages, Gray, Tint),
                                         student => maps:get(student, M, #{}), pages => length(Pages)}};
                        E -> E
                    end;
                E -> E
            end;
        E -> E
    end.

%% 3 Nov (a real student's three papers, against his teacher's own marks): three of the nine question pages were
%% photographed sideways, and that is where the marking lost three of the ten wrong answers (an option's value read from
%% the wrong place on a turned page). One quick look at small copies of the pages says which way up each one is, so the
%% host can turn them upright before they are marked.
orient(Key, Pages) -> orient(Key, Pages, #{}).
orient(Key, Pages, Opts) ->
    Small = maps:get(small, Opts, fun(Url) -> witness_media:small(Url, 640) end),
    Read = maps:get(read, Opts, fun(K, Content) -> witness_meta:read_content(K, ?SPARK, Content, #{effort => <<"low">>}) end),
    case content(Pages, fun(Url) -> Small(Url) end, <<"image/jpeg">>) of
        {ok, Images} ->
            %% asked as "which edge is the top", not "how many degrees": live on 3 Nov, degrees found every sideways page
            %% but turned two of three the wrong way
            Ask = <<"Each photo below is one page of a student's exam paper, labelled with its page number. A page may have "
                    "been photographed sideways or upside down. For each page, look at the printed text and say which edge "
                    "of the photo the top of the printed page is at: \"top\" (it reads normally), \"left\", \"right\" or "
                    "\"bottom\". Judge from the printed text, not the handwriting or the table under the paper. Answer with "
                    "JSON only: {\"pages\": [{\"n\": 1, \"top\": \"top\"}]}">>,
            case Read(Key, [#{type => input_text, text => Ask} | Images]) of
                {ok, Text, Usage} -> {ok, turns(Text, [N || #{n := N} <- Pages]), witness_meta:cost({tokens, ?SPARK}, Usage)};
                E -> E
            end;
        E -> E
    end.

%% only the pages asked about, only a page whose top is at another edge; anything else reads as upright
turns(Text, Ns) ->
    Found = case re:run(Text, <<"\\{.*\\}">>, [dotall, {capture, first, binary}]) of
        {match, [J]} -> try json:decode(J) of #{<<"pages">> := L} when is_list(L) -> L; _ -> [] catch _:_ -> [] end;
        nomatch -> []
    end,
    %% the page's top at the photo's left edge comes up with a quarter turn clockwise; at the right, three quarters
    Turn = #{<<"left">> => 90, <<"bottom">> => 180, <<"right">> => 270},
    maps:from_list([{N, maps:get(T, Turn)} || #{<<"n">> := N, <<"top">> := T} <- Found, lists:member(N, Ns), maps:is_key(T, Turn)]).

%% each page as an image the model reads, labelled with its number
content(Pages, Fetch) -> content(Pages, Fetch, undefined).
content(Pages, Fetch, AsMime) ->
    try
        {ok, lists:append([begin
                               {ok, Bytes} = Fetch(Url),
                               Mime = case AsMime of undefined -> maps:get(mime, P, <<"image/jpeg">>); _ -> AsMime end,
                               [#{type => input_text, text => iolist_to_binary(["Page ", integer_to_list(N), ":"])},
                                #{type => input_image, image_url => <<"data:", Mime/binary, ";base64,", (base64:encode(Bytes))/binary>>}]
                           end || #{n := N, url := Url} = P <- Pages])}
    catch error:{badmatch, E} -> E
    end.

%% unsure questions read again at high effort, a split settled by a third reading (as a filmed paper is)
again(Key, Content, Sitting, Read, Price, #{questions := Qs} = Marked) ->
    Reading = fun() ->
        case Read(Key, Content, <<"high">>) of
            {ok, T, U} -> case witness_mark:parse(T) of {ok, #{questions := Q2}} -> {ok, witness_mark:fit(Q2, Sitting), U}; E -> E end;
            E -> E
        end
    end,
    case witness_mark:unsure(Qs) andalso Reading() of
        false -> Marked;
        {ok, Second, U2} ->
            Rec = witness_mark:reconcile(Qs, Second),
            Cost = maps:get(cost_usd, Marked) + witness_meta:cost(Price, U2),
            case witness_mark:split(Rec) andalso Reading() of
                false -> Marked#{questions => witness_mark:decide(Rec, Qs, Second, []), cost_usd => Cost, read_twice => true};
                {ok, Third, U3} -> Marked#{questions => witness_mark:decide(Rec, Qs, Second, Third), read_twice => true, read_thrice => true,
                                           cost_usd => Cost + witness_meta:cost(Price, U3)};
                _ -> Marked#{questions => witness_mark:decide(Rec, Qs, Second, []), cost_usd => Cost, read_twice => true}
            end;
        _ -> Marked
    end.

%% Every line put on its own ink, page by page; a page that cannot be read for its ink keeps Spark's boxes with room.
place(Qs, Pages, Gray) -> place(Qs, Pages, Gray, fun(_) -> none end).
place(Qs, Pages, Gray, Tint) ->
    Placed = lists:foldl(
        fun(#{n := P, url := Url}, Acc) ->
            Items = lists:append([[{{q, maps:get(n, Q)}, B} || #{page := Pp, box := B} <- [maps:get(printed, Q, #{})], Pp =:= P] ++
                                  [{{s, maps:get(n, Q), I}, maps:get(spot, S)} || {I, S} <- lists:enumerate(maps:get(steps, Q, [])),
                                                                                 maps:get(page, S, 0) =:= P, is_list(maps:get(spot, S, none))]
                                  || Q <- Qs]),
            Boxes = case Items of
                [] -> [];
                _ -> try Gray(Url) of
                         {ok, W, H, G} ->
                             T = case (try Tint(Url) catch _:_ -> none end) of {ok, W, H, Tb} -> Tb; _ -> none end,
                             witness_page:place(G, T, W, H, [B || {_, B} <- Items],
                                                [case Key of {q, _} -> printed; _ -> hand end || {Key, _} <- Items]);
                         _ -> [none || _ <- Items]
                     catch _:_ -> [none || _ <- Items]
                     end
            end,
            lists:foldl(fun({{Id, Spot}, Box}, A) -> A#{Id => case Box of none -> witness_page:loose(Spot); _ -> Box end} end,
                        Acc, lists:zip(Items, Boxes))
        end, #{}, Pages),
    [Q#{steps => [case maps:get({s, N, I}, Placed, none) of none -> S; Box -> S#{box => Box} end
                  || {I, S} <- lists:enumerate(maps:get(steps, Q, []))],
        printed => case maps:get({q, N}, Placed, none) of none -> maps:get(printed, Q, null); Box -> (maps:get(printed, Q))#{place => Box} end}
     || #{n := N} = Q <- Qs].
