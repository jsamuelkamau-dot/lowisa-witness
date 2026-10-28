#!/usr/bin/env escript
%%! -pa C:/lw-witness-scratch/ebin
%% photo_cmp.escript <cases.json>: the research's comparison, marking from a photo of the finished page only. Each clip's
%% last frame is marked by Muse Spark with the same marking prompt (worded for a photo) and the same scheme, and scored
%% against the truth as bench.escript scores the video. Writes bench_results_photo.json.
main([CasesFile]) ->
    {ok, _} = application:ensure_all_started([inets, ssl]),
    Key = list_to_binary(os:getenv("MK")),
    {ok, J} = file:read_file(CasesFile),
    Dir = filename:dirname(CasesFile),
    Out = [run(Key, Dir, C) || C <- json:decode(J)],
    ok = file:write_file(filename:join(Dir, "bench_results_photo.json"), json:encode(Out)),
    io:format("~p papers~n", [length(Out)]).

run(Key, Dir, #{<<"id">> := Id, <<"sitting">> := S0, <<"truth">> := Truth}) ->
    Clip = filename:join(Dir, binary_to_list(Id) ++ ".mp4"), Jpg = filename:join(Dir, binary_to_list(Id) ++ "_last.jpg"),
    _ = os:cmd("C:/lw-witness-scratch/ffmpeg.exe -v error -y -sseof -0.4 -i " ++ Clip ++ " -frames:v 1 -vf scale=720:-2 -q:v 3 " ++ Jpg),
    {ok, Img} = file:read_file(Jpg),
    Sitting = #{level => maps:get(<<"level">>, S0), kind => maps:get(<<"kind">>, S0),
                questions => [#{n => N, text => T, marks => M} || #{<<"n">> := N, <<"text">> := T, <<"marks">> := M} <- maps:get(<<"questions">>, S0)]},
    P0 = witness_mark:prompt(Sitting),
    P = lists:foldl(fun({A, B}, Acc) -> binary:replace(Acc, A, B, [global]) end, P0,
                    [{<<"from a video of their desk while they worked">>, <<"from a photo of their finished paper">>},
                     {<<"Watch the whole video.">>, <<"Read the whole page.">>},
                     {<<"the video">>, <<"the photo">>}]),
    Req = #{model => <<"muse-spark-1.3">>, reasoning => #{effort => <<"medium">>}, max_output_tokens => 16000,
            input => [#{type => message, role => user, content => [#{type => input_text, text => P},
                       #{type => input_image, image_url => <<"data:image/jpeg;base64,", (base64:encode(Img))/binary>>}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            case witness_mark:parse(witness_meta:text_of(R)) of
                {ok, #{questions := Qs0}} ->
                    Qs = witness_mark:fit(Qs0, Sitting),
                    #{id => Id, questions => [#{n => maps:get(n, Q), result => maps:get(result, Q), truth => lists:nth(maps:get(n, Q), Truth),
                                                diagnosis => maps:get(diagnosis, Q, <<>>)} || Q <- Qs, is_integer(maps:get(n, Q, x)), maps:get(n, Q) =< length(Truth)],
                      cost => witness_meta:cost({tokens, <<"muse-spark-1.3">>}, maps:get(<<"usage">>, R, #{}))};
                E -> #{id => Id, error => iolist_to_binary(io_lib:format("~0p", [E]))}
            end;
        E -> #{id => Id, error => iolist_to_binary(io_lib:format("~0p", [E]))}
    end.
