-module(suite_helper).

-include_lib("common_test/include/ct.hrl").


-compile([export_all]).

init(Config0) ->
    Config = init_pg_db(Config0),
    set_env(stats_hero, [{estatsd_host, "localhost"},
                         {estatsd_port, random_bogus_port()},
                         {udp_socket_pool_size, 1}]),

    application:set_env(pooler, pools,
                        [[{name, sqerl},
                          {max_count, 2},
                          {init_count, 2},
                          {start_mfa, {sqerl_client, start_link, []}}]]),

    set_env(oc_chef_authz,
            [{authz_service, [{root_url, "http://test-authz-service:2323"},
                              {timeout, 2000},
                              {init_count, 5},
                              {max_count, 50},
                              {ibrowse_options, [{connect_timeout, 5000}]}]},
             {couchdb_host, "localhost"},
             {couchdb_port, 6984},
             {authz_superuser_id, <<"beefbeefbeef">>}]),

    set_env(sqerl,
            [{db_host, "localhost"},
             {db_port, ?config(pg_port, Config)},
             {db_user, os:getenv("USER")},
             {db_pass, "sesame1-ignored"},
             {db_name, ?config(pg_name, Config) },
             {idle_check, 10000},
             {prepared_statements, {oc_chef_authz_db, statements, [pgsql]}},
             {column_transforms,
              [{<<"created_at">>, {sqerl_transformers, convert_YMDHMS_tuple_to_datetime}},
               {<<"updated_at">>, {sqerl_transformers, convert_YMDHMS_tuple_to_datetime}}]}]),

    [ ok = ensure_started(A) || A <- needed_apps() ],
    Config.

set_env(App, AppConfig) ->
    [ application:set_env(App, Key, Value) || {Key, Value} <- AppConfig ].

needed_apps() ->
    [ibrowse, pooler, stats_hero, crypto, public_key, ssl, epgsql, sqerl, oc_chef_authz].

stop(Config) ->
    [ application:stop(A) || A <- lists:reverse(needed_apps()) ],
    ct:pal("~s", [stop_pg_db(Config)]),
    ok.

ensure_started(App) ->
    case application:start(App) of
        ok ->
            ok;
        {error, {already_started, App}} ->
            ok;
        E ->
            E
    end.

random_bogus_port() ->
    {ok, S} = gen_udp:open(0, [binary, {active, once}]),
    {ok, Port} = inet:port(S),
    gen_udp:close(S),
    Port.

init_pg_db(Config) ->
    DataDir = ?config(data_dir, Config),
    DbName = "oc_chef_authz_itests",
    CommonDir = filename:join([DataDir, "../common"]),
    Schema = filename:join([CommonDir, "schema.sql"]),
    ECSchema = filename:join([CommonDir, "deps", "enterprise-chef-server-schema"]),
    OSCSchema = filename:join([ECSchema, "deps", "chef-server-schema"]),

    PgData = filename:join(DataDir, "pg_data"),
    PgLog = filename:join(DataDir, "pg.log"),
    Port = random_bogus_port(),
    PortStr = integer_to_list(Port),
    CMDS = [
            ["mkdir -p", DataDir],
            ["initdb -D", PgData],
            ["pg_ctl -D", PgData, "-l", PgLog, "-o \"-p", PortStr, "\" start"],
            %% db start is async, sleep? :(
            ["sleep 1 && createdb -p", PortStr, DbName],
            ["cd", OSCSchema, "&& sqitch --engine pg --db-name", DbName,
             "--db-port", PortStr, "deploy"],
            ["cd", ECSchema, "&& sqitch --engine pg --db-name", DbName,
             "--db-port", PortStr, "deploy"],
            ["psql -p", PortStr, DbName, "<", Schema]
           ],
    ct:pal("~s", [run_cmds(CMDS)]),
    [{pg_port, Port}, {pg_data, PgData}, {pg_log, PgLog}, {pg_name, DbName} | Config ].

stop_pg_db(Config) ->
    PgData = ?config(pg_data, Config),
    CMDS = [
            ["pg_ctl -D", PgData, "-m fast", "stop"],
            ["rm -rf", ?config(data_dir, Config)]
           ],
    run_cmds(CMDS).

run_cmds(CMDS) ->
    [ begin
          CC = space_join(C),
          [CC, "\n", os:cmd(CC), "\n\n"]
      end || C <- CMDS ].

space_join(L) ->
    [ [Elt, " "] || Elt <- L ].

cleanup_test_case(Config) ->
    Tables = ?config(tables, Config),
    [delete_all_from_table(TableName) || TableName <- Tables],
    Config.

delete_all_from_table(TableName) ->
    Result = case sqerl:adhoc_delete(TableName, all) of
        {ok, Count} ->
            Count;
        Error ->
            throw(Error)
    end,
    error_logger:info_msg("Delete ~p: ~p", [TableName, Result]),
    ok.
