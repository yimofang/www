

-module(emipian_socket_server).
-behaviour(gen_server).
-define(TCP_SEND_TIMEOUT, 15000).
-include("logger.hrl").

-export([start/6, start_link/6, stop/1]).
-export([init/1, handle_call/3, handle_cast/2, terminate/2, code_change/3,
         handle_info/2]).


-record(emipian_socket_state,
        {
         port,
         acceptor_pool_size=16,
         max=2048,
         ip=any,
         listen=null,
         nodelay=false,
         ssl=false,
         opts,
         module,
         acceptor_pool=sets:new()
         }).

-define(is_old_state(State), not is_record(State, mochiweb_socket_server)).

start(PortIP, Module, SockOpts, Port, IPS,Opts) ->
    ChildSpec = {PortIP,
		 {?MODULE, start_link, [PortIP, Module, SockOpts, Port, IPS,Opts]},
		 transient,
		 brutal_kill,
		 worker,
		 [?MODULE]},
    supervisor:start_child(emipian_listeners, ChildSpec).

start_link(PortIP, Module, SockOpts, Port, IPS,Opts) ->
   gen_server:start_link(?MODULE,[PortIP, Module, SockOpts, Port, IPS,Opts],[]).



init([PortIP, Module, SockOpts, Port, IPS,Opts]) ->
    process_flag(trap_exit, true),

	 Ssl = case lists:keysearch(ssl, 1, Opts) of
	   {value, {_, S}} -> S;
	   _ -> false
	 end,

  AcceptpoolSize = 
	  case lists:keysearch(acceptpoolsize, 1, Opts) of
	   {value, {_, S1}} -> S1;
	   _ -> 16
	 end,

  MaxConnected = 
	  case lists:keysearch(maxconnected, 1, Opts) of
	   {value, {_, S2}} -> S2;
	   _ -> 2048
	 end,

  Socket = bind_tcp_port(PortIP, Module, SockOpts, Port, IPS,Opts,Ssl),
  State = #emipian_socket_state{ssl = Ssl,acceptor_pool_size=AcceptpoolSize,
            max=MaxConnected,listen=Socket,opts = Opts,module=Module},
  State1 = new_acceptor_pool(State),

  {ok,State1}.
 

new_acceptor_pool(State=#emipian_socket_state{acceptor_pool_size=Size}) ->
    lists:foldl(fun (_, S) -> new_acceptor(S) end, State, lists:seq(1, Size)).

new_acceptor(State=#emipian_socket_state{acceptor_pool=Pool,
       opts =Opts,listen=Listen,module=Module}) ->
    Pid = emipian_acceptor:start_link(self(), Listen, Module, Opts),

    State#emipian_socket_state{
      acceptor_pool=sets:add_element(Pid, Pool)}.



handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call(_Message, _From, State) ->
    Res = error,
    {reply, Res, State}.


handle_cast({accepted, Pid, Timing},
            State) ->
    {noreply, recycle_acceptor(Pid, State)}.

terminate(_Reason, #emipian_socket_state{listen=Listen}) ->
    gen_server:cast(Listen, close).


code_change(_OldVsn, State, _Extra) ->
    State.
stop(Name) when is_atom(Name) orelse is_pid(Name) ->
    gen_server:call(Name, stop).

recycle_acceptor(Pid, State=#emipian_socket_state{
                        acceptor_pool=Pool,
                        acceptor_pool_size=PoolSize,
                        max=Max
                        }) ->
    %% A socket is considered to be active from immediately after it
    %% has been accepted (see the {accepted, Pid, Timing} cast above).
    %% This function will be called when an acceptor is transitioning
    %% to an active socket, or when either type of Pid dies. An acceptor
    %% Pid will always be in the acceptor_pool set, and an active socket
    %% will be in that set during the transition but not afterwards.
    case sets:is_element(Pid, Pool) of
      true->
		Pool1 = sets:del_element(Pid, Pool),
        NewSize = sets:size(Pool1),

       State1 = State#emipian_socket_state{
               acceptor_pool=Pool1},
      %% Spawn a new acceptor only if it will not overrun the maximum socket
      %% count or the maximum pool size.
       case NewSize  < Max  of
        true -> new_acceptor(State1);
        false -> State1
        end;
	false ->
        NewSize = sets:size(Pool),

		State
	end.	

handle_info({'EXIT', Pid, normal}, State) ->

    {noreply, recycle_acceptor(Pid, State)};
handle_info({'EXIT', Pid, Reason},
            State=#emipian_socket_state{acceptor_pool=Pool}) ->

    case sets:is_element(Pid, Pool) of
        true ->
            %% If there was an unexpected error accepting, log and sleep.

            timer:sleep(100);
        false ->
            ok
    end,
    {noreply, recycle_acceptor(Pid, State)}.




bind_tcp_port(PortIP, Module, SockOpts, Port, IPS,Opts,Ssl) ->
    try 
		 ListenSocket = listen_tcp(PortIP, Module, SockOpts, Port, IPS,Opts,Ssl),
       Socket = if Ssl=:=true ->
            {ssl,ListenSocket};
        true->
		   ListenSocket
        end,
         ets:insert(listen_sockets, {PortIP,Socket }),
         Socket
    catch
	throw:{error, Error} ->
	    ?ERROR_MSG(Error, [])
    end.


listen_tcp(PortIP, Module, SockOpts, Port, IPS,Opts,Ssl) ->

    case ets:lookup(listen_sockets, PortIP) of
	[{PortIP, ListenSocket}] ->
	    ets:delete(listen_sockets, Port),
	    ListenSocket;
	_ ->
	    SockOpts2 = try erlang:system_info(otp_release) >= "R13B" of
			    true -> [{send_timeout_close, true} | SockOpts];
			    false -> SockOpts
			catch
			    _:_ -> []
	        end,  
		 if Ssl=:=true -> 
				SSlOption0 = case lists:keysearch(ssloption, 1, Opts) of
	                {value, {_, S1}} -> S1;
	             _ -> []
			     end,	
				SSlOption = emipian_config:binary_to_strings(SSlOption0),
				%% SSlOption =[{certfile,"E:/etc/emiage/msg/conf/ssl3.cer"} ,{keyfile,"E:/etc/emiage/msg/conf/ssl3.key"},{password,"111111"}],
				SockOpts3 = lists:append(SockOpts2,SSlOption),
               Res = ssl:listen(Port, [binary,
	 				{packet, 0}
					,{active, false}
%%					,{reuseaddr, true}
					,{nodelay, true}
%%					,{send_timeout, ?TCP_SEND_TIMEOUT}
%%					,{keepalive, true} 
					| SockOpts3]);

        true->
	      Res = gen_tcp:listen(Port, [binary,
					{packet, 0},
					{active, false},
					{reuseaddr, true},
					{nodelay, true},
                    {exit_on_close, false},
									  
					{send_timeout, ?TCP_SEND_TIMEOUT},
					{keepalive, true} |
					SockOpts2])
          end,
	    case Res of
		{ok, ListenSocket} ->
		    ListenSocket;
		{error, Reason} ->
		    socket_error(Reason, PortIP, Module, SockOpts, Port, IPS)
	    end
    end.

socket_error(Reason, PortIP, Module, SockOpts, Port, IPS) ->
    ReasonT = case Reason of
		  eaddrnotavail ->
		      "IP address not available: " ++ IPS;
		  eaddrinuse ->
		      "IP address and port number already used: "
			  ++binary_to_list(IPS)++" "++integer_to_list(Port);
		  _ ->
		      format_error(Reason)
	      end,
    ?ERROR_MSG("Failed to open socket:~n  ~p~nReason: ~s",
	       [{Port, Module, SockOpts}, ReasonT]),
    throw({Reason, PortIP}).

format_error(Reason) ->
    case inet:format_error(Reason) of
	"unknown POSIX error" ->
	    atom_to_list(Reason);
	ReasonStr ->
	    ReasonStr
    end.

