
-define(VERSION, emipian_config:get_version()).

-define(MYHOSTS, emipian_config:get_myhosts()).

-define(MYNAME, hd(emipian_config:get_myhosts())).

-define(MYLANG, emipian_config:get_mylang()).

-define(MSGS_DIR, filename:join(["priv", "msgs"])).

-define(CONFIG_PATH, <<"e:/etc/police/msg/conf/emiage.cfg">>).

-define(LOG_PATH, <<"e:/etc/police/msg/logs/emiage.log">>).

-define(S2STIMEOUT, 600000).

%%-define(DBGFSM, true).
-record(scram,
        {storedkey = <<"">>,
         serverkey = <<"">>,
         salt = <<"">>,
         iterationcount = 0 :: integer()}).

-type scram() :: #scram{}.

-define(SCRAM_DEFAULT_ITERATION_COUNT, 4096).