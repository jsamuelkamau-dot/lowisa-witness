#!/usr/bin/env escript
%%! -pa _build/default/lib/witness/ebin
%% panel31_probe.escript <out_dir> <a page photo.jpg> <answer.wav or none>
%%
%% Four live questions the 12-judge panel asked of Meta's API (31 Oct 2026), answered by calling it:
%%   1. structured output: does /responses take text.format json_schema for Muse Spark, and does it hold the shape?
%%   2. prompt caching: does /responses take prompt_cache_key, and does a repeat report cached input tokens?
%%   3. SAM 3.1 on a photo: does an input_image with a short noun phrase ("handwriting", "word") come back with boxes?
%%   4. Muse Image and Voice Transcribe, live: the three learners' corrected step drawn (witness_draw:run/3), and one
%%      spoken answer written down (witness_meta:transcribe/2), each with its cost.
%% Everything it gets back is written to <out_dir>/probe-31oct.json (images and transcript beside it); the key comes from
%% MODEL_API_KEY and is never printed.
main([Dir, Photo, Wav]) ->
    application:ensure_all_started(inets), application:ensure_all_started(ssl),
    Key = case os:getenv("MODEL_API_KEY") of false -> io:format("set MODEL_API_KEY~n"), halt(2); K -> list_to_binary(K) end,
    ok = filelib:ensure_dir(filename:join(Dir, "x")),
    R1 = structured(Key),
    io:format("1 structured: ~p~n", [maps:get(accepted, R1)]),
    R2 = caching(Key),
    io:format("2 caching: ~p~n", [maps:get(accepted, R2)]),
    {ok, Jpg} = file:read_file(Photo),
    R3 = sam_image(Key, Jpg),
    io:format("3 sam image: ~p~n", [[{P, maps:get(status, X)} || #{prompt := P} = X <- R3]]),
    R4 = drawn(Key, Dir),
    io:format("4 drawn: ~p~n", [[maps:get(learner, X) || X <- R4]]),
    R5 = case Wav of "none" -> #{status => <<"skipped">>}; _ -> heard(Key, Wav, Dir) end,
    io:format("5 transcribe: ~p~n", [maps:get(status, R5)]),
    ok = file:write_file(filename:join(Dir, "probe-31oct.json"),
                         json:encode(#{run_at => list_to_binary(calendar:system_time_to_rfc3339(erlang:system_time(second))),
                                       structured_output => R1, prompt_cache => R2, sam_image => R3, muse_image => R4, transcribe => R5})).

structured(Key) ->
    Schema = #{type => object, additionalProperties => false, required => [<<"misconception">>, <<"evidence">>],
               properties => #{misconception => #{type => string}, evidence => #{type => array, items => #{type => string}}}},
    Req = #{model => <<"muse-spark-1.3">>, reasoning => #{effort => <<"low">>}, max_output_tokens => 2000,
            text => #{format => #{type => json_schema, name => fingerprint, strict => true, schema => Schema}},
            input => [#{type => message, role => user, content => [#{type => input_text,
                text => <<"A student wrote: 1/2 + 1/3 = 2/5. Name the misconception and quote the evidence.">>}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R} ->
            Text = witness_meta:text_of(R),
            Parsed = try json:decode(Text) catch _:_ -> not_json end,
            #{accepted => true, text => Text, whole_reply_is_json => is_map(Parsed),
              holds_shape => is_map(Parsed) andalso is_binary(maps:get(<<"misconception">>, Parsed, x)) andalso is_list(maps:get(<<"evidence">>, Parsed, x))};
        {error, {Code, Msg}} -> #{accepted => false, status => Code, message => bin(Msg)};
        {error, E} -> #{accepted => false, error => bin(io_lib:format("~0p", [E]))}
    end.

caching(Key) ->
    Long = iolist_to_binary(lists:duplicate(400, <<"The teacher's mark scheme: method marks for every line of working. ">>)),
    Req = #{model => <<"muse-spark-1.3">>, reasoning => #{effort => <<"low">>}, max_output_tokens => 300, prompt_cache_key => <<"witness-probe-31oct">>,
            input => [#{type => message, role => user, content => [#{type => input_text, text => <<Long/binary, " Reply OK.">>}]}]},
    case witness_meta:responses(Key, Req) of
        {ok, R1} ->
            {ok, R2} = witness_meta:responses(Key, Req),
            Cached = fun(R) -> maps:get(<<"cached_tokens">>, maps:get(<<"input_tokens_details">>, maps:get(<<"usage">>, R, #{}), #{}), null) end,
            #{accepted => true, first_cached => Cached(R1), second_cached => Cached(R2),
              input_tokens => maps:get(<<"input_tokens">>, maps:get(<<"usage">>, R2, #{}), null)};
        {error, {Code, Msg}} -> #{accepted => false, status => Code, message => bin(Msg)};
        {error, E} -> #{accepted => false, error => bin(io_lib:format("~0p", [E]))}
    end.

sam_image(Key, Jpg) ->
    Url = <<"data:image/jpeg;base64,", (base64:encode(Jpg))/binary>>,
    [begin
         Req = #{model => <<"sam-3.1">>, metadata => #{include_confidence => <<"true">>},
                 input => [#{type => message, role => user, content => [#{type => input_text, text => P}, #{type => input_image, image_url => Url}]}]},
         case witness_meta:responses(Key, Req) of
             {ok, R} -> T = witness_meta:text_of(R),
                        #{prompt => P, status => ok, text_bytes => byte_size(T), text_head => binary:part(T, 0, min(600, byte_size(T))),
                          usage => maps:get(<<"usage">>, R, #{})};
             {error, {Code, Msg}} -> #{prompt => P, status => Code, message => bin(Msg)};
             {error, E} -> #{prompt => P, status => error, error => bin(io_lib:format("~0p", [E]))}
         end
     end || P <- [<<"handwriting">>, <<"word">>, <<"number">>]].

drawn(Key, Dir) ->
    Sitting = #{level => <<"Year 9">>, questions => [#{n => 4, text => <<"A product costs $100. Its price increases by 50%, then decreases by 50%. What is its final price? A $100 B $75 C $50 D $150">>, marks => 3}]},
    Learners = [{<<"a">>, [<<"+50% - 50% = 0%">>, <<"so it stays at $100.">>], <<"percentage changes cancel">>},
                {<<"b">>, [<<"100 + 50 = 150">>, <<"150 - 50 = 100">>], <<"50% taken as a fixed $50">>},
                {<<"c">>, [<<"Half up, half down. Same price.">>], <<"takes the second change of the original amount">>}],
    [begin
         Q = #{n => 4, final_answer => <<"A $100">>, result => <<"not_yet">>, diagnosis => D,
               steps => [#{t => null, wrote => W, crossed_out => false} || W <- Steps]},
         case (try witness_draw:run(Key, Q, Sitting) catch Cl:Er -> {Cl, Er} end) of
             {ok, #{bytes := Bytes, format := Fmt, lines := Lines, changed := Ch}, Cost} ->
                 File = <<"drawn-learner-", L/binary, ".", (bin(Fmt))/binary>>,
                 ok = file:write_file(filename:join(Dir, File), Bytes),
                 #{learner => L, file => File, lines => Lines, changed => Ch, cost_usd => Cost};
             Other -> #{learner => L, error => bin(io_lib:format("~0p", [Other]))}
         end
     end || {L, Steps, D} <- Learners].

heard(Key, WavFile, Dir) ->
    {ok, Wav} = file:read_file(WavFile),
    case witness_meta:transcribe(Key, Wav) of
        {ok, Text, Secs} ->
            R = #{status => ok, transcript => Text, audio_seconds => Secs, cost_usd => witness_meta:cost(transcribe, Secs),
                  audio => <<"Leo's answer to Lo, read aloud by a synthetic voice (Amazon Polly), 16 kHz WAV">>},
            ok = file:write_file(filename:join(Dir, "transcript-31oct.json"), json:encode(R)),
            R;
        {error, E} -> #{status => error, error => bin(io_lib:format("~0p", [E]))}
    end.

bin(B) when is_binary(B) -> B;
bin(L) when is_list(L) -> unicode:characters_to_binary(L);
bin(A) when is_atom(A) -> atom_to_binary(A);
bin(X) -> bin(io_lib:format("~0p", [X])).
