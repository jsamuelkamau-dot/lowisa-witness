-module(witness_meta_tests).
-include_lib("eunit/include/eunit.hrl").

chat_request_is_openai_shaped_test() ->
    {Url, Body} = witness_meta:chat_request(<<"muse-spark-1.3">>, [#{role => user, content => <<"hi">>}],
                                            #{max_output_tokens => 900, cache_key => <<"k">>}),
    ?assertEqual("https://api.meta.ai/v1/chat/completions", Url),
    ?assertMatch(#{model := <<"muse-spark-1.3">>, max_completion_tokens := 900, stream := true,
                   stream_options := #{include_usage := true}, prompt_cache_key := <<"k">>,
                   reasoning_effort := <<"low">>}, Body).

caller_effort_wins_test() ->
    {_, Body} = witness_meta:chat_request(<<"muse-spark-1.3">>, [], #{reasoning_effort => <<"high">>}),
    ?assertMatch(#{reasoning_effort := <<"high">>, max_completion_tokens := 4096}, Body),
    ?assertNot(maps:is_key(prompt_cache_key, Body)).

multipart_carries_purpose_and_file_test() ->
    B = witness_meta:multipart("XX", <<"a.mp4">>, <<"video/mp4">>, <<1, 2, 3>>),
    ?assertNotEqual(nomatch, binary:match(B, <<"name=\"purpose\"\r\n\r\nuser_data">>)),
    ?assertNotEqual(nomatch, binary:match(B, <<"filename=\"a.mp4\"\r\nContent-Type: video/mp4\r\n\r\n", 1, 2, 3>>)),
    ?assertNotEqual(nomatch, binary:match(B, <<"--XX--\r\n">>)).

text_of_joins_output_text_test() ->
    R = #{<<"output">> => [#{<<"content">> => [#{<<"type">> => <<"output_text">>, <<"text">> => <<"a">>}]},
                           #{<<"type">> => <<"reasoning">>},
                           #{<<"content">> => [#{<<"type">> => <<"output_text">>, <<"text">> => <<"b">>}]}]},
    ?assertEqual(<<"ab">>, witness_meta:text_of(R)),
    ?assertEqual(<<>>, witness_meta:text_of(#{})).

costs_follow_published_prices_test() ->
    ?assertEqual(50 * 0.0002, witness_meta:cost(sam_video, 10)),        %% 50-frame minimum
    ?assert(abs(witness_meta:cost(sam_video, 285) - 0.057) < 1.0e-9),
    ?assert(abs(witness_meta:cost(transcribe, 1800) - 0.09) < 1.0e-9),
    %% the day-1 marking call: 10,138 in, 2,432 out on Muse Spark 1.3
    C = witness_meta:cost({tokens, <<"muse-spark-1.3">>}, #{<<"input_tokens">> => 10138, <<"output_tokens">> => 2432}),
    ?assert(abs(C - (10138 * 1.25 + 2432 * 4.25) / 1.0e6) < 1.0e-12),
    W = witness_meta:cost({tokens, <<"muse-wonder-1.0">>}, #{<<"prompt_tokens">> => 1000000, <<"completion_tokens">> => 0}),
    ?assertEqual(4.0, W).
