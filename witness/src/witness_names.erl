%%%-------------------------------------------------------------------
%%% witness_names — whose paper it is (2026-10-29, From Exam to Mastery).
%%%
%%% The name is read from the photographed paper, as the student wrote it; the class list is the names students gave
%%% when they joined the exam. A paper is linked to a student only on one clear match; a near one waits for the teacher
%%% with the likely names, so a Mastery Plan never reaches the wrong student.
%%%
%%%   match(Name, Roster) -> {match, Entry} | {close, [Entry]} | none      Roster = [#{uid, name}]
%%%   key(Name) -> [Word]                   lower case, accents and marks gone, words in order
%%%-------------------------------------------------------------------
-module(witness_names).
-export([match/2, key/1, score/2]).

match(Name, Roster) ->
    case key(Name) of
        [] -> none;
        K ->
            Scored = lists:reverse(lists:keysort(1, [{score(K, key(maps:get(name, E, <<>>))), E} || E <- Roster, is_map(E)])),
            case Scored of
                [{S1, E1} | Rest] when S1 >= 0.9 ->
                    %% clear only when no one else on the list is as close (two Amanis are the teacher's to tell apart)
                    case [E || {S, E} <- Rest, S >= S1 - 0.05] of
                        [] -> {match, E1};
                        Close -> {close, [E1 | Close]}
                    end;
                [{S1, _} | _] when S1 >= 0.6 -> {close, [E || {S, E} <- Scored, S >= 0.6]};
                _ -> none
            end
    end.

key(Name) when is_binary(Name) ->
    case unicode:characters_to_binary(Name) of
        B when is_binary(B) -> words(B);
        _ -> []                                                         %% not text: no name to match
    end;
key(_) -> [].

words(Name) ->
    Plain = << <<C/utf8>> || <<C/utf8>> <= unicode:characters_to_nfd_binary(string:lowercase(Name)), not mark(C) >>,
    [W || W <- string:lexemes(<< <<(case letter(C) of true -> <<C/utf8>>; false -> <<" ">> end)/binary>> || <<C/utf8>> <= Plain >>, " "), W =/= <<>>].

%% 1.0 the same words; 0.95 the same words in another order ("Wanjiru Amani"); 0.9 one is the other with an initial or
%% a word left out ("Amani W.", "Amani Wanjiru Njeri"); below that, how near the letters are (a misread letter).
score(A, B) when A =:= B, A =/= [] -> 1.0;
score([], _) -> 0.0;
score(_, []) -> 0.0;
score(A, B) ->
    case lists:sort(A) =:= lists:sort(B) of
        true -> 0.95;
        false ->
            case covers(A, B) orelse covers(B, A) of
                true -> 0.9;
                false ->
                    Ja = iolist_to_binary(lists:join(<<" ">>, A)), Jb = iolist_to_binary(lists:join(<<" ">>, B)),
                    La = string:length(Ja), Lb = string:length(Jb),
                    1.0 - distance(unicode:characters_to_list(Ja), unicode:characters_to_list(Jb)) / max(La, Lb)
            end
    end.

%% every word of the shorter name is a word, or the initial of a word, of the longer, the first word the same
covers([F | Short], [F | Long]) when length(Short) =< length(Long) ->
    lists:all(fun(W) -> lists:any(fun(L) -> L =:= W orelse (string:length(W) =:= 1 andalso binary:first(L) =:= binary:first(W)) end, Long) end, Short);
covers(_, _) -> false.

distance(A, B) ->
    {D, _} = lists:foldl(
        fun(Ca, {Prev, I}) ->
            {Row, _} = lists:foldl(
                fun({Cb, Up, Diag}, {[Left | _] = Acc, _}) ->
                    {[lists:min([Left + 1, Up + 1, Diag + case Ca =:= Cb of true -> 0; false -> 1 end]) | Acc], x}
                end, {[I], x}, lists:zip3(B, tl(Prev), lists:droplast(Prev))),
            {lists:reverse(Row), I + 1}
        end, {lists:seq(0, length(B)), 1}, A),
    lists:last(D).

mark(C) -> (C >= 16#300 andalso C =< 16#36F) orelse (C >= 16#1AB0 andalso C =< 16#1AFF).
letter(C) -> (C >= $a andalso C =< $z) orelse (C >= $0 andalso C =< $9) orelse C > 127.
