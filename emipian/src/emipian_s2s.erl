%% @author hyf
%% @doc @todo Add description to emipian_c2s.

 
-module(emipian_s2s).

-update_info({update, 0}).

-define(GEN_FSM, gen_fsm).

-behaviour(?GEN_FSM).
 
%% External exports
-export([start/2,
	 stop/1,
	 start_link/2,
	 socket_type/0,
	 broadcast/4,
     wait_for_handshake/2,
     wait_for_login/2,
     wait_for_command/2
         ]).

%% gen_fsm callbacks
-export([init/1
     ]).
%% wait_for_handshake , wait_for_login,wait_for_command,wait_for_resume
-include("emipian.hrl").
-include("logger.hrl").
-include("session.hrl").

-include("jlib.hrl").

%%-include("mod_privacy.hrl").

-define(SETS, gb_sets).
-define(DICT, dict).

%% pres_a contains all the presence available send (either through roster mechanism or directed).
%% Directed presence  unavailable remove user from pres_a.
-record(state, {sessioninfo::session(),socket,
		sockmod,
		socket_monitor,   

		access,
		shaper,
		process_status,		%% connected,handshake,login
		authenticated = false,
	
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
    ?GEN_FSM:start_link(emipian_s2s, [SockData, Opts],
			fsm_limit_opts(Opts) ++ ?FSMOPTS).

socket_type() -> bin_stream.

%% Return Username, Resource and presence information

broadcast(FsmRef, Type, From, Packet) ->
    FsmRef ! {broadcast, Type, From, Packet}.

stop(FsmRef) -> (?GEN_FSM):send_event(FsmRef, closed).

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
%%			    {value, {_, Size}} -> Size;
%%			    _ -> 0
%5			  end,
     Timeout = case lists:keysearch(resumetimeout, 1,
					       Opts)
			      of
			    {value, {_, Time}} -> Time;
			    _ -> 0
			  end,	 
    IP = peerip(SockMod, Socket),
    %% Check if IP is blacklisted:
	  Socket1 =Socket,
	  SocketMonitor = SockMod:monitor(Socket1),
	  StateData = #state{socket = Socket1, sockmod = SockMod,
			     socket_monitor = SocketMonitor,
			     shaper = Shaper, 
	             sessioninfo=#session{peerip=IP},				 
			     resumetimeout = Timeout
			     },

	  {ok, wait_for_handshake, StateData, ?C2S_HANDSHAKE_TIMEOUT}.

%% Return list of all available resources of contacts,
get_subscribed(FsmRef) ->
    (?GEN_FSM):sync_send_all_state_event(FsmRef,
					 get_subscribed, 1000).



%%----------------------------------------------------------------------
%% Func: StateName/2
%% Returns: {next_state, NextStateName, NextStateData}          |
%%          {next_state, NextStateName, NextStateData, Timeout} |
%%          {stop, Reason, NewStateData}
%%----------------------------------------------------------------------


wait_for_handshake(timeout, StateData) ->
    {stop, normal, StateData};
wait_for_handshake(Data, StateData) ->
	?INFO_MSG("wait_for_handshake :~n ~p--~p ~n.", [Data,StateData]),
		case emipian_action:handshake(Data, <<>>) of 
			ok-> {next_state,wait_for_login,  StateData,?C2S_LOGIN_TIMEOUT};
			error->{stop ,normal,  StateData}
end.		

wait_for_login(timeout, StateData) ->
    {stop, normal, StateData};
wait_for_login(Data, StateData) ->
		?INFO_MSG("wait_for_login :~n ~p--~p ~n.", [Data,StateData]),
	    #state{resumetimeout=TimeOut} =  StateData,
		{next_state,wait_for_command,  StateData,TimeOut}.
	 

wait_for_command(timeout, StateData) ->
    {stop, normal, StateData};
wait_for_command(Data, StateData) ->
	?INFO_MSG("wait_for_command :~n ~p--~p ~n.", [Data,StateData]),	
	#state{resumetimeout=TimeOut} =  StateData,
	{next_state,wait_for_command,  StateData,TimeOut}.

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


send_data(StateData, Data) ->
    ?DEBUG("Send  on stream = ~p", [Data]),
	Length = byte_size(Data)+4,
    case catch (StateData#state.sockmod):send(StateData#state.socket, <<Length:32/little>>) of
      {'EXIT', _} ->
 	   (StateData#state.sockmod):close(StateData#state.socket)
	 
    end,
	case catch (StateData#state.sockmod):send(StateData#state.socket, Data) of
      {'EXIT', _} ->
	  (StateData#state.sockmod):close(StateData#state.socket);
      _ ->
	  ok
    end.
