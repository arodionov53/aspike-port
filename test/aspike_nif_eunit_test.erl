-module(aspike_nif_eunit_test).

-include_lib("eunit/include/eunit.hrl").

-define(NAMESPACE, <<"test">>).
-define(SET, <<"eunit_set">>).

all_test_() ->
    {setup,
        fun setup/0,
        fun cleanup/1,
        [
            {"connection", fun test_connection/0},
            {"cdt_put_get", fun test_cdt_put_get/0},
            {"cdt_delete_by_keys", fun test_cdt_delete_by_keys/0},
            {"cdt_delete_by_keys_batch", fun test_cdt_delete_by_keys_batch/0},
            {"map_put_and_segment_tag_get", fun test_map_put_and_segment_tag_get/0},
            {"key_put_get_remove", fun test_key_put_get_remove/0},
            {"key_exists", fun test_key_exists/0},
            {"cdt_put_get_sync_sync", fun test_cdt_put_get_sync_sync/0},
            {"cdt_put_get_async_async", fun test_cdt_put_get_async_async/0},
            {"cdt_put_get_sync_async", fun test_cdt_put_get_sync_async/0},
            {"cdt_put_get_async_sync", fun test_cdt_put_get_async_sync/0},
            {"cdt_put_all_together_sync_sync", fun test_cdt_put_all_together_sync_sync/0},
            {"cdt_put_all_together_async_async", fun test_cdt_put_all_together_async_async/0},
            {"cdt_put_all_together_sync_async", fun test_cdt_put_all_together_sync_async/0},
            {"cdt_put_all_together_async_sync", fun test_cdt_put_all_together_async_sync/0},
            {"get_absent_record_sync", fun test_get_absent_record_sync/0},
            {"get_absent_record_async", fun test_get_absent_record_async/0},
            {"multi_bin_write", fun test_multi_bin_write/0},
            {"batch_insert_large_bin", fun test_batch_insert_large_bin/0},
            {"cdt_put_then_map_put_same_bin", fun test_cdt_put_then_map_put_same_bin/0}
        ]
    }.

setup() ->
    aspike_nif_test:init(),
    ok.

cleanup(_) ->
    ok.

test_connection() ->
    ?assert(aspike_nif:is_connected()).

test_cdt_put_get() ->
    PK = <<"eunit_user_1">>,
    Bins = [
        {<<"profile">>, [<<"name">>, <<0, 1, 0, 2, 1>>, 100, <<"city">>, <<0, 1, 0, 2, 2>>, 200]},
        {<<"settings">>, [<<"theme">>, <<0, 1, 0, 2, 3>>, 300, <<"lang">>, <<0, 1, 0, 2, 4>>, 400]}
    ],
    PutRes = aspike_nif_test:cdt_put(?NAMESPACE, ?SET, PK, Bins, 300),
    assert_put_ok(PutRes),

    {ok, ReadData} = aspike_nif_test:cdt_get(?NAMESPACE, ?SET, PK),
    assert_cdt_bins_match(Bins, ReadData).

test_cdt_delete_by_keys() ->
    PK = <<"eunit_user_del">>,
    Bins = [
        {<<"profile">>, [<<"first">>, <<0, 1, 0, 3, 1>>, 10, <<"last">>, <<0, 1, 0, 3, 2>>, 20]}
    ],
    PutRes = aspike_nif_test:cdt_put(?NAMESPACE, ?SET, PK, Bins, 300),
    assert_put_ok(PutRes),

    DelRes = aspike_nif_test:cdt_delete_by_keys(?NAMESPACE, ?SET, PK, <<"profile">>, [<<"first">>]),
    ?assertMatch({ok, _}, DelRes),

    {ok, ReadData} = aspike_nif_test:cdt_get(?NAMESPACE, ?SET, PK),
    Expected = [{<<"profile">>, [<<"last">>, <<0, 1, 0, 3, 2>>, 20]}],
    assert_cdt_bins_match(Expected, ReadData).

test_cdt_delete_by_keys_batch() ->
    PK1 = <<"eunit_batch_1">>,
    PK2 = <<"eunit_batch_2">>,
    Bins1 = [{<<"data">>, [<<"a">>, <<0, 1, 0, 4, 1>>, 1, <<"b">>, <<0, 1, 0, 4, 2>>, 2]}],
    Bins2 = [{<<"data">>, [<<"a">>, <<0, 1, 0, 4, 3>>, 3, <<"c">>, <<0, 1, 0, 4, 4>>, 4]}],

    assert_put_ok(aspike_nif_test:cdt_put(?NAMESPACE, ?SET, PK1, Bins1, 300)),
    assert_put_ok(aspike_nif_test:cdt_put(?NAMESPACE, ?SET, PK2, Bins2, 300)),

    BatchDel = [{PK1, [<<"a">>]}, {PK2, [<<"a">>]}],
    BatchRes = aspike_nif_test:cdt_delete_by_keys_batch(?NAMESPACE, ?SET, <<"data">>, BatchDel),
    ?assertMatch({ok, _}, BatchRes),

    {ok, Read1} = aspike_nif_test:cdt_get(?NAMESPACE, ?SET, PK1),
    assert_cdt_bins_match([{<<"data">>, [<<"b">>, <<0, 1, 0, 4, 2>>, 2]}], Read1),

    {ok, Read2} = aspike_nif_test:cdt_get(?NAMESPACE, ?SET, PK2),
    assert_cdt_bins_match([{<<"data">>, [<<"c">>, <<0, 1, 0, 4, 4>>, 4]}], Read2).

test_map_put_and_segment_tag_get() ->
    PK = <<"eunit_map_1">>,
    Map = #{
        <<"key_one">> => <<"value_1">>,
        <<"key_two">> => <<"value_2">>
    },
    PutRes = aspike_nif:map_put(?NAMESPACE, ?SET, PK, <<"mapbin">>, 5, Map),
    ?assertMatch({ok, done}, PutRes),

    {ok, ReadMap} = aspike_nif_test:segment_tag_get(?NAMESPACE, ?SET, PK, <<"mapbin">>),
    ?assert(is_map(ReadMap)),
    ?assertEqual(<<"value_1">>, maps:get(<<"key_one">>, ReadMap)),
    ?assertEqual(<<"value_2">>, maps:get(<<"key_two">>, ReadMap)).

test_key_put_get_remove() ->
    PK = "eunit_kv_1",
    PutRes = aspike_nif:key_put("test", "eunit_set", PK, [{"mybin", 12345}]),
    ?assertMatch({ok, _}, PutRes),

    GetRes = aspike_nif:key_get("test", "eunit_set", PK),
    ?assertMatch({ok, _}, GetRes),

    RemoveRes = aspike_nif:key_remove("test", "eunit_set", PK),
    ?assertMatch({ok, _}, RemoveRes).

test_key_exists() ->
    PK = "eunit_exists_1",
    aspike_nif:key_put("test", "eunit_set", PK, [{"mybin", 99}]),
    ExistsRes = aspike_nif:key_exists("test", "eunit_set", PK),
    ?assertMatch({ok, _}, ExistsRes).

test_get_absent_record_sync() ->
    test_get_absent_record(sync).

test_get_absent_record_async() ->
    test_get_absent_record(async).

test_get_absent_record(Mode) ->
    PK = <<"nonexistent_record_", (atom_to_binary(Mode))/binary, "_",
           (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    Result = cdt_get(Mode, ?NAMESPACE, ?SET, PK),
    ?assertMatch({error, _}, Result).

test_multi_bin_write() ->
    PK = <<"eunit_multi_bin_", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    RTTL = erlang:system_time(seconds) + 600,

    Bins = [
        {<<"fcap_map">>, [<<"campaign.1001">>, <<0, 0, 0, 0, 0, 0, 0, 2>>, RTTL]},
        {<<"fcap_map">>, [<<"campaign.1002">>, <<0, 0, 0, 0, 0, 0, 0, 3>>, RTTL]},
        {<<"pending_fcap">>, [<<"campaign.2001">>, <<0, 0, 0, 0, 0, 0, 0, 4>>, RTTL]},
        {<<"pending_fcap">>, [<<"campaign.2002">>, <<0, 0, 0, 0, 0, 0, 0, 5>>, RTTL]},
        {<<"segments">>, [<<"segment.3001">>, <<0, 0, 0, 0, 0, 0, 0, 1>>, RTTL]},
        {<<"segments">>, [<<"segment.3002">>, <<0, 0, 0, 0, 0, 0, 0, 1>>, RTTL]}
    ],
    lists:foreach(fun(Bin) ->
        PutRes = cdt_put(async, ?NAMESPACE, ?SET, PK, [Bin], 60),
        assert_put_ok(PutRes)
    end, Bins),

    {ok, ReadData} = cdt_get(sync, ?NAMESPACE, ?SET, PK),

    FcapData = proplists:get_value(<<"fcap_map">>, ReadData, []),
    PendingData = proplists:get_value(<<"pending_fcap">>, ReadData, []),
    SegmentData = proplists:get_value(<<"segments">>, ReadData, []),

    FcapMap = read_data_to_map(FcapData),
    PendingMap = read_data_to_map(PendingData),
    SegmentMap = read_data_to_map(SegmentData),

    ?assertEqual(2, maps:size(FcapMap)),
    ?assertEqual(2, maps:size(PendingMap)),
    ?assertEqual(2, maps:size(SegmentMap)),

    ?assert(maps:is_key(<<"campaign.1001">>, FcapMap)),
    ?assert(maps:is_key(<<"campaign.1002">>, FcapMap)),
    ?assert(maps:is_key(<<"campaign.2001">>, PendingMap)),
    ?assert(maps:is_key(<<"campaign.2002">>, PendingMap)),
    ?assert(maps:is_key(<<"segment.3001">>, SegmentMap)),
    ?assert(maps:is_key(<<"segment.3002">>, SegmentMap)).

test_batch_insert_large_bin() ->
    PK = <<"eunit_batch_large_", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    RTTL = erlang:system_time(seconds) + 600,

    Value1 = <<0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 102, 80, 160, 144, 0, 0, 0, 0, 102, 79, 125, 154>>,
    Value2 = <<0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 102, 80, 160, 144, 0, 0, 0, 0, 102, 79, 125, 155>>,
    Value3 = <<0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 102, 80, 160, 144, 0, 0, 0, 0, 102, 79, 125, 156>>,
    Value4 = <<0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 102, 80, 160, 144, 0, 0, 0, 0, 102, 79, 125, 157>>,

    Bins = [
        {<<"fcap_map">>, [
            <<"campaign.171629.3701802">>, Value1, RTTL + 100,
            <<"campaign.171629.3701803">>, Value2, RTTL + 200,
            <<"campaign.171629.3701804">>, Value3, RTTL + 300,
            <<"campaign.171629.3701805">>, Value4, RTTL + 400
        ]}
    ],
    PutRes = cdt_put(sync, ?NAMESPACE, ?SET, PK, Bins, 60),
    assert_put_ok(PutRes),

    {ok, ReadData} = cdt_get(async, ?NAMESPACE, ?SET, PK),
    {<<"fcap_map">>, FcapData} = lists:keyfind(<<"fcap_map">>, 1, ReadData),
    ActMap = read_data_to_map(FcapData),

    ?assertEqual(4, maps:size(ActMap)),
    ?assertEqual([
        <<"campaign.171629.3701802">>,
        <<"campaign.171629.3701803">>,
        <<"campaign.171629.3701804">>,
        <<"campaign.171629.3701805">>
    ], lists:sort(maps:keys(ActMap))),

    {ActVal1, _} = maps:get(<<"campaign.171629.3701802">>, ActMap),
    {ActVal2, _} = maps:get(<<"campaign.171629.3701803">>, ActMap),
    {ActVal3, _} = maps:get(<<"campaign.171629.3701804">>, ActMap),
    {ActVal4, _} = maps:get(<<"campaign.171629.3701805">>, ActMap),
    ?assertEqual(Value1, ActVal1),
    ?assertEqual(Value2, ActVal2),
    ?assertEqual(Value3, ActVal3),
    ?assertEqual(Value4, ActVal4).

test_cdt_put_then_map_put_same_bin() ->
    PK = <<"eunit_cdt_map_mix_", (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    BinName = <<"mixed_bin">>,
    TTL = erlang:system_time(seconds) + 600,

    Bins = [{BinName, [<<"key_from_cdt">>, <<1, 2, 3, 4>>, TTL]}],
    PutRes = cdt_put(sync, ?NAMESPACE, ?SET, PK, Bins, 60),
    assert_put_ok(PutRes),

    Map = #{<<"key_from_map">> => <<"map_value">>},
    MapRes = aspike_nif:map_put(?NAMESPACE, ?SET, PK, BinName, 5, Map),
    ?assertMatch({ok, _}, MapRes),

    GetRes = cdt_get(sync, ?NAMESPACE, ?SET, PK),
    ?assertMatch({ok, _}, GetRes).

test_cdt_put_all_together_sync_sync() ->
    test_cdt_put_all_together(sync, sync).

test_cdt_put_all_together_async_async() ->
    test_cdt_put_all_together(async, async).

test_cdt_put_all_together_sync_async() ->
    test_cdt_put_all_together(sync, async).

test_cdt_put_all_together_async_sync() ->
    test_cdt_put_all_together(async, sync).

test_cdt_put_all_together(WriteMode, ReadMode) ->
    PK = <<"eunit_all_", (atom_to_binary(WriteMode))/binary, "_",
           (atom_to_binary(ReadMode))/binary, "_",
           (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    BinName = <<"fcap_map">>,

    Key1 = <<"campaign.281271.3950012">>,
    Key2 = <<"campaign.281271.3950013">>,
    Key3 = <<"campaign.281271.3950014">>,
    Value1 = <<0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 105, 248, 162, 138, 0, 0, 0, 0, 105, 247, 95, 55>>,
    Value2 = <<0, 0, 0, 0, 0, 0, 0, 3, 0, 0, 0, 0, 105, 248, 162, 138, 0, 0, 0, 0, 105, 247, 95, 55, 0, 0, 0, 0, 105, 244, 188, 168>>,
    Value3 = <<0, 0, 0, 0, 0, 0, 0, 4, 0, 0, 0, 0, 105, 248, 162, 138, 0, 0, 0, 0, 105, 247, 95, 55, 0, 0, 0, 0, 105, 244, 188, 168>>,

    TTL1 = 1778593418,
    TTL2 = 1779111818,
    TTL3 = 1781099018,

    Bins = [
        {BinName, [
            Key3, Value3, TTL3,
            Key2, Value2, TTL2,
            Key1, Value1, TTL1
        ]}
    ],
    PutRes = cdt_put(WriteMode, ?NAMESPACE, ?SET, PK, Bins, 60),
    assert_put_ok(PutRes),

    {ok, ReadData} = cdt_get(ReadMode, ?NAMESPACE, ?SET, PK),
    {BinName, FcapData} = lists:keyfind(BinName, 1, ReadData),
    ActMap = read_data_to_map(FcapData),

    ?assertEqual(3, maps:size(ActMap)),
    ?assertEqual([Key1, Key2, Key3], lists:sort(maps:keys(ActMap))),

    {ActualValue1, ActualTTL1} = maps:get(Key1, ActMap),
    {ActualValue2, ActualTTL2} = maps:get(Key2, ActMap),
    {ActualValue3, ActualTTL3} = maps:get(Key3, ActMap),
    ?assertEqual(Value1, ActualValue1),
    ?assertEqual(Value2, ActualValue2),
    ?assertEqual(Value3, ActualValue3),
    ?assertEqual(TTL1, ActualTTL1),
    ?assertEqual(TTL2, ActualTTL2),
    ?assertEqual(TTL3, ActualTTL3).

test_cdt_put_get_sync_sync() ->
    test_cdt_put_get_mixed(sync, sync).

test_cdt_put_get_async_async() ->
    test_cdt_put_get_mixed(async, async).

test_cdt_put_get_sync_async() ->
    test_cdt_put_get_mixed(sync, async).

test_cdt_put_get_async_sync() ->
    test_cdt_put_get_mixed(async, sync).

test_cdt_put_get_mixed(WriteMode, ReadMode) ->
    PK = <<"eunit_mixed_", (atom_to_binary(WriteMode))/binary, "_",
           (atom_to_binary(ReadMode))/binary, "_",
           (integer_to_binary(erlang:unique_integer([positive])))/binary>>,
    TTL = 5,

    WrittenItems = lists:map(fun(N) ->
        Key = <<"key_", (integer_to_binary(N))/binary>>,
        Value = <<<<0, 0, 0, 0, 0, 0, 0>>/binary, (integer_to_binary(N))/binary>>,
        ExpTTL = erlang:system_time(seconds) + TTL,
        Bins = [{<<"data">>, [Key, Value, ExpTTL]}],
        PutRes = cdt_put(WriteMode, ?NAMESPACE, ?SET, PK, Bins, TTL),
        assert_put_ok(PutRes),
        {Key, Value, ExpTTL}
    end, [1, 2, 3]),

    {ok, ReadData} = cdt_get(ReadMode, ?NAMESPACE, ?SET, PK),
    {<<"data">>, DataValues} = lists:keyfind(<<"data">>, 1, ReadData),
    ActMap = read_data_to_map(DataValues),
    ?assertEqual(3, maps:size(ActMap)),

    lists:foreach(fun({Key, Value, ExpTTL}) ->
        ?assert(maps:is_key(Key, ActMap)),
        {ActualValue, ActualTTL} = maps:get(Key, ActMap),
        ?assertEqual(Value, ActualValue),
        ?assertEqual(ExpTTL, ActualTTL)
    end, WrittenItems).

%% Helpers

assert_put_ok({ok, "put"}) -> ok;
assert_put_ok({ok, <<"put">>}) -> ok;
assert_put_ok(Other) -> ?assertEqual({ok, <<"put">>}, Other).

%% Converts read data flat list [Key, {Value, TTL, WriteTime}, ...] into a map
%% #{Key => {Value, TTL}} (ignoring WriteTime which is added by the NIF)
read_data_to_map(FlatList) ->
    read_data_to_map(FlatList, #{}).

read_data_to_map([], Acc) ->
    Acc;
read_data_to_map([Key, {Value, TTL, _WriteTime} | Rest], Acc) ->
    read_data_to_map(Rest, Acc#{Key => {Value, TTL}});
read_data_to_map([Key, {Value, TTL} | Rest], Acc) ->
    read_data_to_map(Rest, Acc#{Key => {Value, TTL}}).

%% Converts write data flat list [Key, Value, TTL, ...] into a map
%% #{Key => {Value, TTL}}
write_data_to_map(FlatList) ->
    write_data_to_map(FlatList, #{}).

write_data_to_map([], Acc) ->
    Acc;
write_data_to_map([Key, Value, TTL | Rest], Acc) ->
    write_data_to_map(Rest, Acc#{Key => {Value, TTL}}).

%% Asserts that CDT bins written match what was read back.
%% Compares each bin by name, converts both sides to maps, and uses assertEqual.
assert_cdt_bins_match(ExpectedBins, ActualBins) ->
    ?assertEqual(length(ExpectedBins), length(ActualBins)),
    SortedExpected = lists:sort(ExpectedBins),
    SortedActual = lists:sort(ActualBins),
    lists:foreach(fun({{BinName, ExpValues}, {ActualBinName, ActualValues}}) ->
        ?assertEqual(BinName, ActualBinName),
        ExpMap = write_data_to_map(ExpValues),
        ActMap = read_data_to_map(ActualValues),
        ?assertEqual(ExpMap, ActMap)
    end, lists:zip(SortedExpected, SortedActual)).

-define(POLICY, {3, 250, 30000, 1000}).
-define(ASYNC_TTW, 1000).

cdt_put(sync, Namespace, Set, Key, Bins, TTL) ->
    aspike_nif:cdt_put_sync(Namespace, Set, Key, Bins, TTL, ?POLICY);
cdt_put(async, Namespace, Set, Key, Bins, TTL) ->
    Ref = make_ref(),
    case aspike_nif:cdt_put_async(Ref, Namespace, Set, Key, Bins, TTL, ?POLICY) of
        {ok, in_progress} -> await_async(Ref);
        {ok, Response} -> {ok, Response};
        {error, {_, _, Msg}} -> {error, Msg}
    end.

cdt_get(sync, Namespace, Set, Key) ->
    aspike_nif:cdt_get_sync(Namespace, Set, Key, ?POLICY);
cdt_get(async, Namespace, Set, Key) ->
    Ref = make_ref(),
    case aspike_nif:cdt_get_async(Ref, Namespace, Set, Key, ?POLICY) of
        {ok, in_progress} -> await_async(Ref);
        {ok, Response} -> {ok, Response};
        {error, {_, _, Msg}} -> {error, Msg}
    end.

await_async(Ref) ->
    receive
        {ok, Ref, Response} -> {ok, Response};
        {error, Ref, {_, _, Msg}} -> {error, Msg}
    after ?ASYNC_TTW ->
        {error, timeout}
    end.
