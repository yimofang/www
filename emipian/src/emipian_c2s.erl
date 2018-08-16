%% @author hyf
%% @doc @todo Add description to emipian_c2s.

 
-module(emipian_c2s).
-update_info({update, 0}).

-define(GEN_FSM, gen_fsm).

-define(NEW_CMD, 40).

-behaviour(?GEN_FSM).

%% External exports
-export([start/2,
	 start_link/2,
	 socket_type/0,
	 broadcast/4,
	 send_data/2,	 
     wait_for_handshake/2,
     wait_for_login/2,
     wait_for_command/2,
		 	 terminate/3,
		 handle_info/3,
		 handle_event/3,
		 handle_sync_event/4,
		 code_change/4
         ]).

%% gen_fsm callbacks
-export([init/1
     ]).
%% wait_for_handshake , wait_for_login,wait_for_command,wait_for_resume
-include("emipian.hrl").
-include("logger.hrl").
-include("session.hrl").
-include("errorcode.hrl").
-include("action.hrl").
-include("macro.hrl").

-include("jlib.hrl").

%%-include("mod_privacy.hrl").

-define(SETS, gb_sets).
-define(DICT, dict).

%% pres_a contains all the presence available send (either through roster mechanism or directed).
%% Directed presence unavailable remove user from pres_a.
-record(state, {sessioninfo::session(),socket,
		sockmod,
		socket_monitor,
		access,
		shaper,
		process_status,		%% connected,handshake,login
		authenticated = false,
		authmethod,

		resumetimeout		
			   }).

%-define(DBGFSM, true).

-ifdef(DBGFSM).

-define(FSMOPTS, [{debug, [trace]}]).

-else.

-define(FSMOPTS, []).

-endif.

%% Module start with or without supervisor:
-ifdef(NO_TRANSIENT_SUPERVISORS).
-define(SUPERVISOR_START, ?GEN_FSM:start(emipian_c2s, [SockData, Opts],
					 fsm_limit_opts(Opts) ++ ?FSMOPTS)).
-else.
-define(SUPERVISOR_START, supervisor:start_child(emipian_c2s_sup,
						 [SockData, Opts])).
-endif.

%% This is the timeout to apply between event when starting a new
%% session:
-define(C2S_HANDSHAKE_TIMEOUT, 60000).

-define(C2S_LOGIN_TIMEOUT, 90000).

-define(POLICY_VIOLATION_ERR(Lang, Text),
	?SERRT_POLICY_VIOLATION(Lang, Text)).

-define(INVALID_FROM, ?SERR_INVALID_FROM).

%% XEP-0198:

%%%----------------------------------------------------------------------
%%% API
%%%----------------------------------------------------------------------
start(SockData, Opts) ->
    ?SUPERVISOR_START.

start_link(SockData, Opts) ->
    ?GEN_FSM:start_link(emipian_c2s, [SockData, Opts],
			fsm_limit_opts(Opts) ++ ?FSMOPTS).

socket_type() -> bin_stream.

%% Return Username, Resource and presence information

broadcast(FsmRef, Type, From, Packet) ->
    FsmRef ! {broadcast, Type, From, Packet}.


%%%----------------------------------------------------------------------
%%% Callback functions from gen_fsm
%%%----------------------------------------------------------------------

%%----------------------------------------------------------------------
%% Func: init/1
%% Returns: {ok, StateName, StateData}          |
%%          {ok, StateName, StateData, Timeout} |
%%          ignore                              |
%%          {stop, StopReason}
%%----------------------------------------------------------------------
init([{SockMod, Socket}, Opts]) ->
     Shaper = case lists:keysearch(shaper, 1, Opts) of
	       {value, {_, S}} -> S;
	       _ -> none
	     end,
   %%  HandShakeSize = case lists:keysearch(handshakesize, 1,
%%					       Opts)
%%			      of
%%				    {value, {_, Size}} -> Size;
%%			    _ -> 0
%5			  end,

      AuthMethod = case lists:keysearch(auth_method, 1,
  					       Opts)
			      of
			    {value, {_, Method}} -> Method;
			    _ -> authcode
	            end,	 
     Timeout = case lists:keysearch(resumetimeout, 1,
					       Opts)
			      of
			    {value, {_, Time}} -> Time;
			    _ -> 0
			  end,	 
    SecretNew = case lists:keysearch(secretnew, 1,
					       Opts)
			      of
			    {value, {_, Value}} -> Value;
			    _ -> ""
			  end,	
    SecretOld = case lists:keysearch(secretold, 1,
					       Opts)
			      of
			    {value, {_, Value1}} -> Value1;
			    _ -> ""
			  end,	

	 IP = peerip(SockMod, Socket),
	{IPDest,_} =IP, 
	S_IP = emipian_util:ip_to_str(IP),
    %% Check if IP is blacklisted:
	  Socket1 =Socket,
	  SocketMonitor = SockMod:monitor(Socket1),
	  StateData = #state{socket = Socket1, sockmod = SockMod,
			     socket_monitor = SocketMonitor,
			     shaper = Shaper, authmethod=AuthMethod,
					 
	             sessioninfo=#session{userid = <<"systemid">>,secretnew=SecretNew,
									  secretold=SecretOld,s_peerip=S_IP,
									  peerip=IP,selfpid=self(),node=node()},				 
			     resumetimeout = Timeout
			     },
     case AuthMethod of
		authcode->
	     {ok, wait_for_handshake, StateData, ?C2S_HANDSHAKE_TIMEOUT};
		nocode->
	     {ok, wait_for_handshake, StateData, ?C2S_HANDSHAKE_TIMEOUT};
		 ip->
		 IPs =  lists:keysearch(ips, 1, Opts),	
		 case IPs of
			 false ->    {stop,  normal};
			 {value, {_, IPsValue}} -> IPsValue,
             case emipian_util:compareIPs(IPsValue, IPDest) of
				yes->
	             {ok, wait_for_command, StateData, Timeout};
				_-> {stop, normal}
			 end
		 end;
 		_->{stop, normal}
     end.  		 

%% Return list of all available resources of contacts,
get_subscribed(FsmRef) ->
    (?GEN_FSM):sync_send_all_state_event(FsmRef,
					 get_subscribed, 1000).

fsm_next_state(StateName, StateData) ->
	      #state{sessioninfo=Session,resumetimeout=TimeOut} =  StateData,	
    {next_state, StateName, StateData,TimeOut}.

fsm_stop_state(Reason, StateData) ->
    {stop, normal, StateData}.


%%----------------------------------------------------------------------
%% Func: StateName/2
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%%----------------------------------------------------------------------

wait_for_handshake(closed, StateData) ->
    {stop, normal, StateData};
wait_for_handshake(timeout, StateData) ->
    {stop, normal, StateData};
wait_for_handshake(Data, StateData) ->
		#state{authmethod=AuthMethod} =  StateData,
	    case AuthMethod of 
		 nocode ->
				send_data(StateData,{?NEW_CMD,?AC_SC_HANDSHAKE_R,?EC_SUCCESS,<<>>}),
				{next_state,wait_for_login,  StateData,?C2S_LOGIN_TIMEOUT};
		   
		  _->
			case emipian_action:handshake(Data) of 
				ok->
					send_data(StateData,{?NEW_CMD,?AC_SC_HANDSHAKE_R,?EC_SUCCESS,<<>>}),
					{next_state,wait_for_login,  StateData,?C2S_LOGIN_TIMEOUT};
				error->
				   send_data(StateData,{?NEW_CMD,?AC_SC_HANDSHAKE_R,?EC_HANDFAIL,<<>>}),
				{stop ,normal,  StateData}
		  end	
end.		

%%----------------------------------------------------------------------
%% Func: terminate/3
%% Purpose: Shutdown the fsm
%% Returns: any
%%----------------------------------------------------------------------

terminate(_Reason, StateName, StateData) ->
	#state{sessioninfo=Session} =  StateData,
    (StateData#state.sockmod):close(StateData#state.socket),
    emipian_sm:delsessionpid(Session),
    emipian_msg_log:update_client_chatroom(Session),
	ok. 


%% ====================================================================
%%  return
%% {ok/terminate/resume,Data} || {noresp,ok/terminate}
%% Data ={Code,Action,Param,Addition}
%% Addition ={}
%% Addition ={Session} for login
%% ====================================================================
wait_for_getrandom(closed, StateData) ->
    {stop, normal, StateData};
wait_for_getrandom(timeout, StateData) ->
    {stop, normal, StateData};
wait_for_getrandom(Data, StateData) ->
	 ok.
wait_for_login(closed, StateData) ->
    {stop, normal, StateData};

wait_for_login(timeout, StateData) ->
    {stop, normal, StateData};
wait_for_login(Data, StateData) ->
		#state{sessioninfo=Session,resumetimeout=TimeOut,authmethod=AuthMethod} =  StateData,

		Result = emipian_action:loginaction(Session,Data,AuthMethod),
		

		case  Result of
		  {ok,{Action,Code,Param,Session1,MainLink}} ->
     		StateData1=StateData#state{sessioninfo=Session1},
			     #session{sessionid =SessionID,userid=UserID} = Session1,

			send_data(StateData,{?NEW_CMD,Action,Code,Param}),
			if 
				MainLink =:=0 ->
			      emipian_auto:process(self(),Session1, <<"1111">>);
				true->ok
			end,
	   	    {next_state,wait_for_command,  StateData1,TimeOut};
		  {resume,{Action,Code,Param,_,_}} ->
			send_data(StateData,{?NEW_CMD,Action,Code,Param}),
	   	    {next_state,wait_for_login, StateData,TimeOut};
		  {terminate,{Action,Code,Param,_,_}} ->
			send_data(StateData,{?NEW_CMD,Action,Code,Param}),
	   	     {stop ,normal,  StateData};
		 _->
		 	{stop ,normal,  StateData}
	   end.
wait_for_command(closed, StateData) ->
    {stop, normal, StateData};
wait_for_command(timeout, StateData) ->
	#state{sessioninfo=Session} =  StateData,
	emipian_sm:updatesessionstatus(Session, ?STATUS_OFFLINE),
	     #session{sessionid =SessionID,userid=UserID} = Session,

	{stop, normal, StateData};

wait_for_command(Data, StateData) ->
      #state{sessioninfo=Session,resumetimeout=TimeOut} =  StateData,
	   process_action(Session, Data),
	  {next_state,wait_for_command,StateData,TimeOut}.

process_action(Session, Data)
  ->
	emipian_srv_action:process(self(), Session, Data).



peerip(SockMod, Socket) ->
    IP = case SockMod of
	   gen_tcp -> inet:peername(Socket);
	   _ -> SockMod:peername(Socket)
	 end,
    case IP of
      {ok, IPOK} -> IPOK;
      _ -> undefined
    end.



fsm_limit_opts(Opts) ->
    case lists:keysearch(max_fsm_queue, 1, Opts) of
      {value, {_, N}} when is_integer(N) -> [{max_queue, N}];
      _ ->
	  case emipian_config:get_option(
                 max_fsm_queue,
                 fun(I) when is_integer(I), I > 0 -> I end) of
            undefined -> [];
	    N -> [{max_queue, N}]
	  end
    end.


send_data(StateData, {CMD,Action,Code,Param}) ->
	  Data = <<CMD:8/little,Action:32/little,Code:32/little,Param/binary>>,
      Data1 =binary:copy(Data), 
      send_data(StateData, Data1); 	
send_data(StateData, Data) ->
	 #state{sessioninfo=Session} = StateData,
	  #session{status =Status,sessionid =SessionID,userid=UserID,
			   selfpid = SelfPid} = Session,
	Length = byte_size(Data)+4,
	Alldata = <<Length:32/little,Data/binary>>,
   Alldata1 =binary:copy(Alldata), 
    case catch (StateData#state.sockmod):send(StateData#state.socket, Alldata1) of
      {'EXIT', _} ->
 	   (StateData#state.sockmod):close(StateData#state.socket);
	  _->ok
    end.
%% Func: handle_info/3
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%%----------------------------------------------------------------------
%% handle_info({code, Code}, StateName, StateData) ->
%%    send_data(code,StateData, Code).
%%    fsm_next_state(StateName, StateData).


%% Func: handle_info/3

%%----------------------------------------------------------------------
 handle_info({msg,Action,MsgID,RevID,Data},StateName,StateData) ->
	  #state{sessioninfo=ReceiverSession,resumetimeout=TimeOut} = StateData,
	  #session{status =Status,sessionid =SessionID,mainlink=MainLink,
			   selfpid = SelfPid} = ReceiverSession,
      case   Status of
	      ?STATUS_ONLINE->
		   send_data(StateData, <<?NEW_CMD:8/little,Action:32/little,Data/binary>>),
		   fsm_next_state(wait_for_command, StateData);
          ?STATUS_LOGINING->
		   send_data(StateData, <<?NEW_CMD:8/little,Action:32/little,Data/binary>>),
		   fsm_next_state(wait_for_command, StateData);
	      _->
           emipian_sm:close_session(SessionID,MainLink,SelfPid) ,
	       fsm_stop_state(close, StateData)
	  end;
handle_info({eof,Data},StateName,StateData) ->
		   send_data(StateData, <<?NEW_CMD:8/little,?AC_SC_EOF:32/little,Data/binary>>),
		   fsm_next_state(wait_for_command, StateData);
 
 handle_info({session,NewSession},StateName,StateData) ->
			#state{resumetimeout=TimeOut} =  StateData,
	 	StateData1=StateData#state{sessioninfo=NewSession},
			
        #session{selfpid=PID,status =Status,sessionid =SessionID,userid=UserID} = NewSession,
			
	   	 {next_state,wait_for_command,StateData1,TimeOut};


 handle_info({kick,Action,MsgID,Data},StateName,StateData) ->
	  #state{sessioninfo=ReceiverSession} = StateData,
	  #session{status =Status,sessionid =SessionID } = ReceiverSession,
      case   Status  of
		   ?STATUS_LOGINING ->
	       send_data(StateData, <<?NEW_CMD:8/little,Action:32/little,Data/binary>>);
		   ?STATUS_ONLINE ->
	       send_data(StateData, <<?NEW_CMD:8/little,Action:32/little,Data/binary>>);
	      _->ok
	  end,
      emipian_sm:close_session(SessionID,0,0), 
      fsm_stop_state(kick, StateData);
handle_info({result,Action,MsgID,Return},_StateName,StateData) ->
	 Result = emipian_action:handlereturn(Action,MsgID,Return),
	 prcessresult(Result,_StateName,StateData); 
   
handle_info({status,Return},_StateName,StateData) ->
	prcessresult(Return,_StateName,StateData);
	

handle_info(system_shutdown, StateName, StateData) ->

	{stop, normal, StateData};

handle_info({stop},_,StateData) ->
      fsm_stop_state(stop, StateData). 


prcessresult(Return,_StateName,StateData) ->
     #state{resumetimeout=TimeOut} =  StateData,
	 try
     case Return of
	     {ok,{ReAction,Code,Param}} ->
			send_data(StateData,{?NEW_CMD,ReAction,Code,Param}),
	   	    {next_state,wait_for_command,StateData,TimeOut};
		  {ok,{ReAction,Code}} ->
			send_data(StateData,{?NEW_CMD,ReAction,Code,<<"">>}),
	   	    {next_state,wait_for_command,StateData,TimeOut};

		 {ok,{ReAction,Code,Param,Session1}} ->
			send_data(StateData,{?NEW_CMD,ReAction,Code,Param}),
			StateData1=StateData#state{sessioninfo=Session1},
	   	    {next_state,wait_for_command,StateData1,TimeOut};
		  {resume,{ReAction,Code,Param}} ->
			send_data(StateData,{?NEW_CMD,ReAction,Code,Param}),
	   	    {next_state,wait_for_command, StateData,TimeOut};
		  {terminate,{ReAction,Code,Param}} ->
			send_data(StateData,{?NEW_CMD,ReAction,Code,Param}),
	   	    {stop ,normal,  StateData};
		  {noresp,ok} ->
	   	    {next_state,wait_for_command,StateData,TimeOut};
		  {noresp,terminate} ->
  		     {stop ,normal,  StateData};
          {waitmsg}->
	   	    {next_state,wait_for_command,StateData,TimeOut};
			_->
		 {stop ,normal,  StateData}
      end
	 catch
		_:_->{next_state,wait_for_command, StateData,TimeOut} 
     end.


%%----------------------------------------------------------------------
%% Func: handle_event/3
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%%----------------------------------------------------------------------
handle_event(_Event, StateName, StateData) ->
    fsm_next_state(StateName, StateData).
handle_sync_event(_Event, _From, StateName,
		  StateData) ->
    Reply = ok,
	fsm_next_state( StateName, StateData).

code_change(_OldVsn, StateName, StateData, _Extra) ->
    {ok, StateName, StateData}.