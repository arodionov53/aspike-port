-module(as_render).

-export([
    hosts_render/1,
    info_render/2,
    node_render/1,
    advice/1
]).

-spec hosts_render({ok, [{string(), string(), non_neg_integer()}]} | {error, string()}) -> 
    {ok, [{inet:ip_address() | string(), string(), non_neg_integer()}]} | {error, string()}.
hosts_render({ok, Lst}) ->
    {ok, [{get_address(A), T, P} || {A, T, P} <- Lst]};
hosts_render(X) ->
    X.

-spec get_address(string()) -> string() | inet:ip_address().
get_address(A) ->
    case inet:parse_address(A) of
        {ok, R} -> R;
        _ -> A
    end.

-spec node_render({term(), string()}) ->
    {term(), string()} | {ok, {inet:ip_address(), non_neg_integer()}}.
node_render({ok, S}) ->
    [A, P] = string:split(S, ":"),
    case inet:parse_address(A) of
        {ok, R} -> {ok, {R, list_to_integer(P)}};
        E -> {error, {E, S}}
    end;
node_render(Arg) ->
    Arg.

-spec advice(string()) -> {use, [string()]}.
advice(_) ->
    {use, [
        "bins",
        "sets",
        "node",
        "namespaces",
        "udf-list",
        "sindex-list:",
        "edition",
        "get-config"
    ]}.

% @doc Butifies different help function results
-spec info_render({error | ok, string()}, string()) -> {error, string()} | {ok, map()}.
info_render({error, Reason}, Item) ->
    {error, {Reason, advice(Item)}};
info_render({ok, Info}, Item) ->
    [F | Tail] = string:split(string:chomp(Info), "\t", all),
    Res =
        case Item of
            "sets" ->
                sets_render(Tail);
            "bins" ->
                bins_render(Tail);
            "sindex-list:" ->
                sindexes_render(Tail);
            "namespaces" ->
                namespaces_render(Tail);
            _ ->
                case re:run(Item, "get-config") of
                    {match, _} -> config_render(Tail);
                    _ -> Tail
                end
        end,
    {ok, {F, Res}}.

sets_render(Sets) ->
    set_render([string:split(S, ";", all) || S <- Sets]).

set_render([]) ->
    [];
set_render([R | Tail]) ->
    X = [string:split(I, ":", all) || I <- R],
    Y = [[list_to_tuple(string:split(I, "=", leading)) || I <- L] || L <- X],
    Z = [maps:from_list([{A, value_render(B)} || {A, B} <- [T || T <- L, size(T) == 2]]) || L <- Y],
    [Z | set_render(Tail)].

bins_render(Bins) ->
    L = [string:split(X, ",", all) || X <- string:split(Bins, ";", all), X /= []],
    [bin_render(string:split(B, ",", all)) || B <- L].

bin_render([]) ->
    [];
bin_render([[A, B | Bins] | Tail]) ->
    [A1, A2] = string:split(A, "="),
    [A11, A12] = string:split(A1, ":"),
    [B1, B2] = string:split(B, "="),
    [
        maps:from_list([
            {"ns", A11},
            {A12, value_render(A2)},
            {B1, value_render(B2)},
            {"names", Bins}
        ])
        | bin_render(Tail)
    ].

sindexes_render(Indexes) ->
    sindex_render([string:split(Ind, ":", all) || Ind <- Indexes]).

sindex_render([]) ->
    [];
sindex_render([F | Tail]) ->
    X = [string:split(E, "=", leading) || E <- F],
    Y = [list_to_tuple(S) || S <- X, length(S) == 2],
    Z = maps:from_list([{A, value_render(B)} || {A, B} <- Y]),
    [Z | sindex_render(Tail)].

config_render(Conf) ->
    X = string:split(Conf, ";", all),
    Y = [L || L <- [string:split(S, "=", leading) || S <- X], length(L) == 2],
    maps:from_list([{A, value_render(B)} || [A, B] <- Y]).

namespaces_render([]) -> [];
namespaces_render([A | Tail]) -> string:split(A, ";", all) ++ namespaces_render(Tail).

-spec value_render(string()) -> false | true | integer() | float() | string().
value_render("false") ->
    false;
value_render("true") ->
    true;
value_render("null") ->
    null;
value_render(V) ->
    case string:to_integer(V) of
        {N, []} ->
            N;
        _ ->
            case string:to_float(V) of
                {F, []} -> F;
                _ -> V
            end
    end.
