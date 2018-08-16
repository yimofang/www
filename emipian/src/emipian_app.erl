 %% @author hyf
%% @doc @todo Add description to emipian_app.


-module(emipian_app).

-behaviour(application).

-export([start_modules/0,start/2, prep_stop/1, stop/1, init/0]).

-include("emipian.hrl").
-include("logger.hrl").

%%%
%%% Application API
%%%

start(normal, _Args) ->
	io:format("enter emipian:~n" ),

    emipian_logger:start(),
    write_pid_file(),
    start_apps(),
     emipian:check_app(emipian),
  %%  randoms:start(),
    db_init(),
    start(),
    translate:start(),
 
    gen_mod:start(),
    emipian_config:start(), 
    set_loglevel_from_config(),
    shaper:start(),
    connect_nodes(),
    Sup = emipian_sup:start_link(),
%%    start_modules(),
    crypto:start(),
	ssl:start(),
	inets:start(),
	
%%	public_key:
  
	 emipian_pools:startpools(),
	 emipian_sm:cleanallsessionpid(),
	 emipian_msg_log:clear_chat_session(),
     emipian_listener:start_listeners(),

	?INFO_MSG("emipian ~s is started in the node ~p", [?VERSION, node()]),
    Sup;
start(_, _) ->
    {error, badarg}.

%% Prepare the application for termination.
%% This function is called when an application is about to be stopped,
%% before shutting down the processes of the application.
prep_stop(State) ->
    ?INFO_MSG("emipianis prep_stop in the node ~p", [State]),

	emipian_listener:stop_listeners(),
   %% stop_modules(),
    broadcast_c2s_shutdown(),
    timer:sleep(5000),
    State.

%% All the processes were killed when this function is called
stop(State) ->
    ?INFO_MSG("emipian ~s is stopped in the node ~p,~p", [?VERSION, node(),State]),
    delete_pid_file(),
  
    ok.


%%%
%%% Internal functions
%%%

start() ->
    spawn_link(?MODULE, init, []).

init() ->
    register(emipian, self()),
    loop().

loop() ->
    receive
	_ ->
	    loop()
    end.

db_init() ->
    MyNode = node(),
    DbNodes = mnesia:system_info(db_nodes),
    case lists:member(MyNode, DbNodes) of
	true ->
	    ok;
	false ->
	    ?CRITICAL_MSG("Node name mismatch: I'm [~s], "
			  "the database is owned by ~p", [MyNode, DbNodes]),
	    ?CRITICAL_MSG("Either set ERLANG_NODE in ejabberdctl.cfg "
			  "or change node name in Mnesia", []),
	    erlang:error(node_name_mismatch)
    end,
    case mnesia:system_info(extra_db_nodes) of
	[] ->
	    mnesia:create_schema([node()]);
	_ ->
	    ok
    end,
    emipian:start_app(mnesia, permanent),
    mnesia:wait_for_tables(mnesia:system_info(local_tables), infinity).

%% Start all the modules in all the hosts
start_modules() ->
    lists:foreach(
      fun(Host) ->
              Modules = emipian_config:get_option(
                          {modules, Host},
                          fun(Mods) ->
                                  lists:map(
                                    fun({M, A}) when is_atom(M), is_list(A) ->
                                            {M, A}
                                    end, Mods)
                          end, []),
              lists:foreach(
                fun({Module, Args}) ->
                        gen_mod:start_module(Host, Module, Args)
                end, Modules)
      end, ?MYHOSTS).

%% Stop all the modules in all the hosts
stop_modules() ->
    lists:foreach(
      fun(Host) ->
              Modules = emipian_config:get_option(
                          {modules, Host},
                          fun(Mods) ->
                                  lists:map(
                                    fun({M, A}) when is_atom(M), is_list(A) ->
                                            {M, A}
                                    end, Mods)
                          end, []),
              lists:foreach(
                fun({Module, _Args}) ->
                        gen_mod:stop_module_keep_config(Host, Module)
                end, Modules)
      end, ?MYHOSTS).

connect_nodes() ->
    Nodes = emipian_config:get_option(
              cluster_nodes,
              fun(Ns) ->
                      true = lists:all(fun is_atom/1, Ns),
                      Ns
              end, []),
    lists:foreach(fun(Node) ->
                          net_kernel:connect_node(Node)
                  end, Nodes).

%% If ejabberd is running on some Windows machine, get nameservers and add to Erlang
maybe_add_nameservers() ->
    case os:type() of
	{win32, _} -> add_windows_nameservers();
	_ -> ok
    end.

add_windows_nameservers() ->
    IPTs = win32_dns:get_nameservers(),
    ?INFO_MSG("Adding machine's DNS IPs to Erlang system:~n~p", [IPTs]),
    lists:foreach(fun(IPT) -> inet_db:add_ns(IPT) end, IPTs).


broadcast_c2s_shutdown() ->
    Children = emipian_sm:get_all_pids(),
    lists:foreach(
      fun(C2SPid) when node(C2SPid) == node() ->
	      C2SPid ! system_shutdown;
	 (_) ->
	      ok
      end, Children).

%%%
%%% PID file
%%%

write_pid_file() ->
    case emipian:get_pid_file() of
	false ->
	    ok;
	PidFilename ->
	    write_pid_file(os:getpid(), PidFilename)
    end.

write_pid_file(Pid, PidFilename) ->
    case file:open(PidFilename, [write]) of
	{ok, Fd} ->
	  io:format(Fd, "~s~n", [Pid]),
	    file:close(Fd);
	{error, Reason} ->
	    ?ERROR_MSG("Cannot write PID file ~s~nReason: ~p", [PidFilename, Reason]),
	    throw({cannot_write_pid_file, PidFilename, Reason})
    end.

delete_pid_file() ->
    case emipian:get_pid_file() of
	false ->
	    ok;
	PidFilename ->
	    file:delete(PidFilename)
    end.

set_loglevel_from_config() ->
    Level = emipian_config:get_option(
              loglevel,
              fun(P) when P>=0, P=<5 -> P end,
              4),
    emipian_logger:set(Level).

start_apps() ->
    emipian:start_app(sasl),
    emipian:start_app(ssl).




