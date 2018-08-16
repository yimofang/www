%% @author hyf
%% @doc @todo Add description to emipian_logger.


-module(emipian_logger).

%% API
-export([start/0, reopen_log/0, get/0, set/1, get_log_path/0]).

-include("emipian.hrl").

-type loglevel() :: 0 | 1 | 2 | 3 | 4 | 5.

-spec start() -> ok.
-spec get_log_path() -> string().
-spec reopen_log() -> ok.
-spec get() -> {loglevel(), atom(), string()}.
-spec set(loglevel() | {loglevel(), list()}) -> {module, module()}.

%%%===================================================================
%%% API
%%%===================================================================
%% @doc Returns the full path to the ejabberd log file.
%% It first checks for application configuration parameter 'log_path'.
%% If not defined it checks the environment variable EJABBERD_LOG_PATH.
%% And if that one is neither defined, returns the default value:
%% "ejabberd.log" in current directory.
get_log_path() ->
    case application:get_env(emipian, log_path) of
	{ok, Path} ->
	    Path;
	undefined ->
	    case os:getenv("EMIPIAN_LOG_PATH") of
		false ->
		    ?LOG_PATH;
		Path ->
		    Path
	    end
    end.



get_pos_integer_env(Name, Default) ->
    case application:get_env(emipian, Name) of
        {ok, I} when is_integer(I), I>0 ->
            I;
        undefined ->
            Default;
        {ok, Junk} ->
            error_logger:error_msg("wrong value for ~s: ~p; "
                                   "using ~p as a fallback~n",
                                   [Name, Junk, Default]),
            Default
    end.
get_pos_string_env(Name, Default) ->
    case application:get_env(emipian, Name) of
        {ok, L} when is_list(L) ->
            L;
        undefined ->
            Default;
        {ok, Junk} ->
            error_logger:error_msg("wrong value for ~s: ~p; "
                                   "using ~p as a fallback~n",
                                   [Name, Junk, Default]),
            Default
    end.

start() ->
    application:load(sasl),
    application:set_env(sasl, sasl_error_logger, false),
    application:load(lager),
    ConsoleLog = get_log_path(),
    Dir = filename:dirname(ConsoleLog),
    ErrorLog = filename:join([Dir, "error.log"]),
    CrashLog = filename:join([Dir, "crash.log"]),
    LogRotateDate = get_pos_string_env(log_rotate_date, ""),
    LogRotateSize = get_pos_integer_env(log_rotate_size, 10*1024*1024),
    LogRotateCount = get_pos_integer_env(log_rotate_count, 1),
    LogRateLimit = get_pos_integer_env(log_rate_limit, 100),
    application:set_env(lager, error_logger_hwm, LogRateLimit),
    application:set_env(
      lager, handlers,
      [{lager_console_backend, info},
       {lager_file_backend, [{file, ConsoleLog}, {level, info}, {date, LogRotateDate},
                             {count, LogRotateCount}, {size, LogRotateSize}]},
       {lager_file_backend, [{file, ErrorLog}, {level, error}, {date, LogRotateDate},
                             {count, LogRotateCount}, {size, LogRotateSize}]}]),
    application:set_env(lager, crash_log, CrashLog),
    application:set_env(lager, crash_log_date, LogRotateDate),
    application:set_env(lager, crash_log_size, LogRotateSize),
    application:set_env(lager, crash_log_count, LogRotateCount),
    emipian:start_app(lager),
    ok.

reopen_log() ->
    lager_crash_log ! rotate,
    lists:foreach(
      fun({lager_file_backend, File}) ->
              whereis(lager_event) ! {rotate, File};
         (_) ->
              ok
      end, gen_event:which_handlers(lager_event)).

get() ->
    case lager:get_loglevel(lager_console_backend) of
        none -> {0, no_log, "No log"};
        emergency -> {1, critical, "Critical"};
        alert -> {1, critical, "Critical"};
        critical -> {1, critical, "Critical"};
        error -> {2, error, "Error"};
        warning -> {3, warning, "Warning"};
        notice -> {3, warning, "Warning"};
        info -> {4, info, "Info"};
        debug -> {5, debug, "Debug"}
    end.

set(LogLevel) when is_integer(LogLevel) ->
    LagerLogLevel = case LogLevel of
                        0 -> none;
                        1 -> critical;
                        2 -> error;
                        3 -> warning;
                        4 -> info;
                        5 -> debug
                    end,
    case lager:get_loglevel(lager_console_backend) of
        LagerLogLevel ->
            ok;
        _ ->
            ConsoleLog = get_log_path(),
            lists:foreach(
              fun({lager_file_backend, File} = H) when File == ConsoleLog ->
                      lager:set_loglevel(H, LagerLogLevel);
                 (lager_console_backend = H) ->
                      lager:set_loglevel(H, LagerLogLevel);
                 (_) ->
                      ok
              end, gen_event:which_handlers(lager_event))
    end,
    {module, lager};
set({_LogLevel, _}) ->
    error_logger:error_msg("custom loglevels are not supported for 'lager'"),
    {module, lager}.

