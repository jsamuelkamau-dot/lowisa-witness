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
%%%   screen(Text) -> ok | {unsafe, Why}
%%%
%%% 4 Nov (independent audit, finding C): a model reading a model is not an independent guarantee, so screen/1 runs
%%% first, in plain code, with no model: a link, an email address, a phone number, a contact app or a meeting, and a
%%% short list of words no lesson for a child needs. What it catches never reaches the model or the student.
%%%-------------------------------------------------------------------
-module(witness_guard).
-export([prompt/1, parse/1, check/2, screen/1]).

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
    case screen(Text) of
        {unsafe, Why} -> {unsafe, Why, 0.0};
        ok -> ask(Key, Text)
    end.

ask(Key, Text) ->
    Req = #{model => ?MODEL, reasoning => #{effort => <<"low">>}, max_output_tokens => 1500,
            input => [#{type => message, role => user, content => [#{type => input_text, text => prompt(Text)}]}]},
    case witness_meta:structured(Key, Req, <<"safety">>, witness_meta:object(#{safe => #{type => boolean}, why => #{type => string}})) of
        {ok, R} ->
            Cost = witness_meta:cost({tokens, ?MODEL}, maps:get(<<"usage">>, R, #{})),
            case parse(witness_meta:text_of(R)) of
                ok -> {ok, Cost};
                {unsafe, Why} -> {unsafe, Why, Cost};
                E -> E
            end;
        E -> E
    end.

%% Each rule: why, then a case-blind pattern. Kept narrow, so ordinary teaching is never caught by it: a times table
%% ("120 240 360"), "the naked eye", "sexual reproduction" in a science lesson, "you can call me Lo". The model guard
%% still reads everything this lets through.
-define(RULES, [
    {<<"a link">>, <<"(https?://|www\\.)\\S+|\\b[a-z0-9-]+\\.(com|net|org|io|gg|xyz|ru|cn)(/|\\b)">>},
    {<<"an email address">>, <<"[a-z0-9._%+-]+@[a-z0-9-]+(\\.[a-z0-9-]+)*\\.[a-z]{2,}">>},
    {<<"a phone number">>, <<"\\+\\d{1,3}[\\s.-]?\\(?\\d{2,4}\\)?[\\s.-]?\\d{3,4}[\\s.-]?\\d{3,4}|\\(\\d{3}\\)\\s?\\d{3}-\\d{4}|\\b\\d{3}-\\d{3}-\\d{4}\\b">>},
    {<<"contact outside the app">>, <<"\\b(whats\\s?app|telegram|snapchat|instagram|discord|tiktok|kik|wechat|text me|dm me|message me privately|"
                                     "your (home )?address|where do you live|meet (me|up)|send (me )?(a )?(photo|picture|pic|selfie)s? of yourself)\\b">>},
    {<<"adult content">>, <<"\\b(sexy|porn|porno|nudes?|horny|erotic|onlyfans)\\b">>},
    {<<"self-harm">>, <<"\\b(kill (yourself|urself)|kys|suicide method|cut yourself|end your life|hang yourself)\\b">>},
    {<<"keep it secret">>, <<"\\b(don'?t tell (your )?(parents|mum|mom|dad|teacher)|our (little )?secret|keep this between us)\\b">>}]).

%% 4 Nov (third audit: "test curriculum cases"): an online-safety lesson names exactly what grooming looks like ("never
%% send a photo of yourself", "if an adult says 'don't tell your parents'"). For the two rules about contact and
%% secrecy, a sentence that warns against it does not count; the same words said to the student still do.
-define(WARNS, [<<"contact outside the app">>, <<"keep it secret">>]).
-define(WARNING, <<"\\bnever\\b|\\bif (an? )?(adult|someone|anyone|stranger|person|people)\\b[^.!?]*\\b(says?|asks?|tells?)\\b|"
                   "warning sign|red flag|trusted adult|without (a|your) parent|report (it|them)">>).

screen(Text) ->
    T = iolist_to_binary(Text),
    first([Why || {Why, Re} <- ?RULES, caught(Why, Re, T)]).

caught(Why, Re, T) ->
    case lists:member(Why, ?WARNS) of
        false -> re:run(T, Re, [caseless, unicode]) =/= nomatch;
        true -> lists:any(fun(S) -> re:run(S, Re, [caseless, unicode]) =/= nomatch andalso re:run(S, ?WARNING, [caseless, unicode]) =:= nomatch end,
                          re:split(T, <<"(?<=[.!?\\n])\\s+">>, [unicode]))
    end.

first([Why | _]) -> {unsafe, Why};
first([]) -> ok.

str(B) when is_binary(B) -> B;
str(_) -> <<>>.
