-module(aspike_nif_not_connected_test).

-include_lib("eunit/include/eunit.hrl").

-define(NAMESPACE, <<"test">>).
-define(SET, <<"test_set">>).
-define(KEY, <<"test_key">>).
-define(POLICY, {3, 250, 30000, 1000}).

all_test_() ->
    {setup,
        fun setup/0,
        fun cleanup/1,
        [
            {"cdt_put_sync not connected", fun cdt_put_sync_not_connected/0},
            {"cdt_get_sync not connected", fun cdt_get_sync_not_connected/0},
            {"cdt_put_async not connected", fun cdt_put_async_not_connected/0},
            {"cdt_get_async not connected", fun cdt_get_async_not_connected/0},
            {"cdt_delete_by_keys_sync not connected", fun cdt_delete_by_keys_sync_not_connected/0},
            {"cdt_delete_by_keys_async not connected", fun cdt_delete_by_keys_async_not_connected/0},
            {"cdt_delete_by_keys_batch_sync not connected", fun cdt_delete_by_keys_batch_sync_not_connected/0},
            {"cdt_delete_by_keys_batch_async not connected", fun cdt_delete_by_keys_batch_async_not_connected/0},
            {"segment_tag_get_sync not connected", fun segment_tag_get_sync_not_connected/0},
            {"segment_tag_get_async not connected", fun segment_tag_get_async_not_connected/0}
        ]
    }.

setup() ->
    % Calling any function ensures the module (and NIF) is loaded via on_load.
    % We intentionally do NOT call connect() — operations should fail with not_connected.
    aspike_nif:is_connected(),
    ok.

cleanup(_) ->
    ok.

cdt_put_sync_not_connected() ->
    Bins = [{<<"bin">>, [<<"k">>, <<1, 2, 3>>, 100]}],
    Result = aspike_nif:cdt_put_sync(?NAMESPACE, ?SET, ?KEY, Bins, 300, ?POLICY),
    assert_not_connected(Result).

cdt_get_sync_not_connected() ->
    Result = aspike_nif:cdt_get_sync(?NAMESPACE, ?SET, ?KEY, ?POLICY),
    assert_not_connected(Result).

cdt_put_async_not_connected() ->
    Ref = make_ref(),
    Bins = [{<<"bin">>, [<<"k">>, <<1, 2, 3>>, 100]}],
    Result = aspike_nif:cdt_put_async(Ref, ?NAMESPACE, ?SET, ?KEY, Bins, 300, ?POLICY),
    assert_not_connected(Result).

cdt_get_async_not_connected() ->
    Ref = make_ref(),
    Result = aspike_nif:cdt_get_async(Ref, ?NAMESPACE, ?SET, ?KEY, ?POLICY),
    assert_not_connected(Result).

cdt_delete_by_keys_sync_not_connected() ->
    Result = aspike_nif:cdt_delete_by_keys_sync(?NAMESPACE, ?SET, ?KEY, <<"bin">>, [<<"k">>]),
    assert_not_connected(Result).

cdt_delete_by_keys_async_not_connected() ->
    Ref = make_ref(),
    Result = aspike_nif:cdt_delete_by_keys_async(Ref, ?NAMESPACE, ?SET, ?KEY, <<"bin">>, [<<"k">>]),
    assert_not_connected(Result).

cdt_delete_by_keys_batch_sync_not_connected() ->
    Result = aspike_nif:cdt_delete_by_keys_batch_sync(?NAMESPACE, ?SET, <<"bin">>, [{?KEY, [<<"k">>]}]),
    assert_not_connected(Result).

cdt_delete_by_keys_batch_async_not_connected() ->
    Ref = make_ref(),
    Result = aspike_nif:cdt_delete_by_keys_batch_async(Ref, ?NAMESPACE, ?SET, <<"bin">>, [{?KEY, [<<"k">>]}]),
    assert_not_connected(Result).

segment_tag_get_sync_not_connected() ->
    Result = aspike_nif:segment_tag_get_sync(?NAMESPACE, ?SET, ?KEY, <<"tag">>),
    assert_not_connected(Result).

segment_tag_get_async_not_connected() ->
    Ref = make_ref(),
    Result = aspike_nif:segment_tag_get_async(Ref, ?NAMESPACE, ?SET, ?KEY, <<"tag">>),
    assert_not_connected(Result).

assert_not_connected(Result) ->
    ?assertMatch({error, {_, _, _}}, Result),
    {error, {_NifCode, _AspikeCode, Msg}} = Result,
    ?assertEqual("not_connected", Msg).
