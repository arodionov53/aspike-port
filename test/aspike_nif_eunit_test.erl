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
            {"key_exists", fun test_key_exists/0}
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
    ?assert(aspike_nif_test_utils:compare_cdt_data(Bins, ReadData)).

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
    ?assert(aspike_nif_test_utils:compare_cdt_data(Expected, ReadData)).

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
    ?assert(aspike_nif_test_utils:compare_cdt_data([{<<"data">>, [<<"b">>, <<0, 1, 0, 4, 2>>, 2]}], Read1)),

    {ok, Read2} = aspike_nif_test:cdt_get(?NAMESPACE, ?SET, PK2),
    ?assert(aspike_nif_test_utils:compare_cdt_data([{<<"data">>, [<<"c">>, <<0, 1, 0, 4, 4>>, 4]}], Read2)).

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

%% Helpers

assert_put_ok({ok, "put"}) -> ok;
assert_put_ok({ok, <<"put">>}) -> ok;
assert_put_ok(Other) -> ?assertEqual({ok, <<"put">>}, Other).
