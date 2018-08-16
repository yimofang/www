
%% @author hyf
%% @doc @todo Add description to emipian_receiver.


-module(emipian_receiver).
 
-behaviour(gen_server).

%% API
-export([start_link/4,
	 start/3,
	 start/4,
	 change_shaper/2,
	 become_controller/2,		 
	 close/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2,
	 handle_info/2, terminate/2, code_change/3]).



-include("emipian.hrl").
-include("logger.hrl").

-record(state,
	{socket :: inet:socket() | p1_tls:tls_socket() | ezlib:zlib_socket(),
         sock_mod = gen_tcp :: gen_tcp | p1_tls | ezlib,
         shaper_state = none :: shaper:shaper(),
         c2s_pid :: pid(),
	     handshakesize = infinity :: non_neg_integer() | infinity,
         parse_state :: emipian_parser:parse_state(),
         timeout = infinity:: timeout()}).

-define(HIBERNATE_TIMEOUT, 90000).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
-spec start_link(inet:socket(), atom(), shaper:shaper(),
                 non_neg_integer() | infinity) -> ignore |
                                                  {error, any()} |
                                                  {ok, pid()}.

start_link(Socket, SockMod, Shaper, MaxStanzaSize) ->
    gen_server:start_link(?MODULE,
			  [Socket, SockMod, Shaper, MaxStanzaSize], []).

-spec start(inet:socket(), atom(), shaper:shaper()) -> undefined | pid().

%%--------------------------------------------------------------------
%% Function: start() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
start(Socket, SockMod, Shaper) ->
    start(Socket, SockMod, Shaper, infinity).

-spec start(inet:socket(), atom(), shaper:shaper(),
            non_neg_integer() | infinity) -> undefined | pid().

start(Socket, SockMod, Shaper, Opts) ->
    {ok, Pid} =
	supervisor:start_child(emipian_receiver_sup,
			       [Socket, SockMod, Shaper, Opts]),
    Pid.

-spec change_shaper(pid(), shaper:shaper()) -> ok.

change_shaper(Pid, Shaper) ->
    gen_server:cast(Pid, {change_shaper, Shaper}).

-spec become_controller(pid(), pid()) -> ok | {error, any()}.

become_controller(Pid, C2SPid) ->
    do_call(Pid, {become_controller, C2SPid}).

-spec close(pid()) -> ok.

close(Pid) ->
    gen_server:cast(Pid, close).


%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([Socket, SockMod, Shaper, Opts]) ->
    ShaperState = shaper:new(Shaper),
    Timeout = case SockMod of
		ssl -> 20;
		_ -> infinity
	      end,
	
     AuthMethod = case lists:keysearch(auth_method, 1,
  					       Opts)
			      of
			    {value, {_, Method}} -> Method;
			    _ -> authcode
	            end,
 
	 HandShakeSize = case AuthMethod of
	    authcode->	
           case lists:keysearch(handshakesize, 1,
  					       Opts)
			      of
			    {value, {_, Size}} -> Size;
			    _ -> -1
			end;   
	    nocode->	
           case lists:keysearch(handshakesize, 1,
  					       Opts)
			      of
			    {value, {_, Size}} -> Size;
			    _ -> -1
			end;   

     ip->-1					
	  end,
		  
    {ok,
     #state{socket = Socket, sock_mod = SockMod,
	    shaper_state = ShaperState,
	    handshakesize = HandShakeSize, timeout = Timeout}}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call({become_controller, C2SPid}, _From, State) ->
    ParseState = emipian_parser:new(C2SPid, State#state.handshakesize),
    NewState = State#state{c2s_pid = C2SPid,
			   parse_state = ParseState},
    activate_socket(NewState),
    Reply = ok,
    {reply, Reply, NewState, ?HIBERNATE_TIMEOUT}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast({change_shaper, Shaper}, State) ->
    NewShaperState = shaper:new(Shaper),
    {noreply, State#state{shaper_state = NewShaperState},
     ?HIBERNATE_TIMEOUT};
handle_cast(close, State) -> {stop, normal, State};
handle_cast(_Msg, State) ->
    {noreply, State, ?HIBERNATE_TIMEOUT}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info({Tag, _TCPSocket, Data},
	    #state{socket = Socket, sock_mod = SockMod} = State)
    when (Tag == tcp) or (Tag == ssl) ->
	  State1 = process_data(Data, State),
	  case State1 of
		  {error,_Reason}->
			  {stop, normal, State};
		  _->
           {noreply, State1, ?HIBERNATE_TIMEOUT}
	  end;
handle_info({Tag, _TCPSocket}, State)
    when (Tag == tcp_closed) or (Tag == ssl_closed) ->
    {stop, normal, State};
handle_info({Tag, _TCPSocket, Reason}, State)
    when (Tag == tcp_error) or (Tag == ssl_error) ->
    case Reason of
      timeout -> {noreply, State, ?HIBERNATE_TIMEOUT};
      _ -> {stop, normal, State}
    end;
handle_info({timeout, _Ref, activate}, State) ->
    activate_socket(State),
    {noreply, State, ?HIBERNATE_TIMEOUT};
handle_info(timeout, State) ->
    proc_lib:hibernate(gen_server, enter_loop,
		       [?MODULE, [], State]),
    {noreply, State, ?HIBERNATE_TIMEOUT};
handle_info(_Info, State) ->
    {noreply, State, ?HIBERNATE_TIMEOUT}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason,
	  #state{parse_state = ParseState,
		 c2s_pid = C2SPid} =
	      State) ->
    if C2SPid /= undefined ->
	   gen_fsm:send_event(C2SPid, closed);
       true -> ok
    end,
    catch (State#state.sock_mod):close(State#state.socket),
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) -> {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------

activate_socket(#state{socket = Socket,
		       sock_mod = SockMod}) ->
    PeerName = case SockMod of
		 gen_tcp ->
		     inet:setopts(Socket, [{active, once}]),
		     inet:peername(Socket);
		 _ ->
		     SockMod:setopts(Socket, [{active, once}]),
		     SockMod:peername(Socket)
	       end,
    case PeerName of
      {error, _Reason} -> self() ! {tcp_closed, Socket};
      {ok, _} -> ok
    end.

%% Data processing for connectors directly generating xmlelement in
%% Erlang data structure.
%% WARNING: Shaper does not work with Erlang data structure.
process_data([], State) ->
    activate_socket(State), State;
process_data(<<>>, State) ->
    activate_socket(State), State;
   
%% Data processing for connectors receivind data as string.
process_data(Data,
	     #state{parse_state = ParseState,
		    shaper_state = ShaperState, c2s_pid = C2SPid} =
		 State) ->
	
    ?DEBUG("Received Data on stream = ~p", [(Data)]),
    case emipian_parser:parse(Data, ParseState) of 
 	 {more, ParseState1} ->  
		
		 activate_socket( State #state{ parse_state = ParseState1 }),
		 State #state{ parse_state = ParseState1 };
	 {none, ParseState1} ->
		 activate_socket( State #state{ parse_state = ParseState1 }),
		 State #state{ parse_state = ParseState1 };
     {ok, ParseState1,NextData} ->
		 process_data(NextData,  State #state{ parse_state = ParseState1 });
	{error, Error} ->
	  {stop, Error,ParseState}
	end.

%%	{NewShaperState, Pause} = shaper:update(ShaperState, byte_size(Data)),
    %%if
%%	C2SPid == undefined ->
	    %%ok;
	%%Pause > 0 ->
	  %%  erlang:start_timer(Pause, self(), activate);
	%%true ->
	 %%   activate_socket(State)
    %%end,
    %%State#state{parse_state = ParseState,
%%		shaper_state = NewShaperState}.



do_send(State, Data) ->
    (State#state.sock_mod):send(State#state.socket, Data).

do_call(Pid, Msg) ->
    case catch gen_server:call(Pid, Msg) of
      {'EXIT', Why} -> {error, Why};
      Res -> Res
    end.



