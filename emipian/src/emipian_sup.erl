%% @author hyf
%% @doc @todo Add description to emipian_sup.


-module(emipian_sup).


-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Hooks =
	{emipian_hooks,
	 {emipian_hooks, start_link, []},
	 permanent,
	 brutal_kill,
	 worker,
	 [emipian_hooks]},
    SystemMonitor =
	{emipian_system_monitor,
	 {emipian_system_monitor, start_link, []},
	 permanent,
	 brutal_kill,
	 worker,
   [emipian_system_monitor]},	

 SM =
	{emipian_sm,
	 {emipian_sm, start_link, []},
	 permanent,
	 brutal_kill,
	 worker,
	 [emipian_sm]},
	
     Listener =
	{emipian_listener,
	 {emipian_listener, start_link, []},
	 permanent,
	 infinity,
	 supervisor,
	 [emipian_listener]},
	
    PoolsSupervisor =
	{emipian_pools,
	 {emipian_pools, start_link, []},
	 permanent,
	 infinity,
	 supervisor,
	 [emipian_pools]},
	
    ReceiverSupervisor =
	{emipian_receiver_sup,
	 {emipian_tmp_sup, start_link,
	  [emipian_receiver_sup, emipian_receiver]},
	 permanent,
	 infinity,
	 supervisor,
	 [emipian_tmp_sup]},
    C2SSupervisor =
	{
	 emipian_c2s_sup,
	 {emipian_tmp_sup, start_link, [emipian_c2s_sup, emipian_c2s]},
	 permanent,
	 infinity,
	 supervisor,
	 [emipian_tmp_sup]
	
	},

	 DialTimer =
	{emipian_timer_tel,
	 {emipian_timer_tel, start_link, [30000]},
	 permanent,
	 brutal_kill,
	 worker,
	 [emipian_timer_tel]},
	 ChatRoomTimer =
	{emipian_timer_chatroom,
	 {emipian_timer_chatroom, start_link, [380000,30000]},
	 permanent,
	 brutal_kill,
	 worker,
	 [emipian_timer_chatroom]},	

   Router =
	{emipian_route,
	 {emipian_route, start_link, []},
	 permanent,
	 brutal_kill,
	 worker,
	 [emipian_route]},

	 ChatRoomTimer =
	{emipian_timer_chatroom,
	 {emipian_timer_chatroom, start_link, [380000,30000]},
	 permanent,
	 brutal_kill,
	 worker,
	 [emipian_timer_chatroom]},	



	{ok, {{one_for_one, 10, 1},
	  [
%%	   Hooks,
%%	   SystemMonitor,
   %%   SM,
   	   ReceiverSupervisor,
	   C2SSupervisor,
	   PoolsSupervisor,
	   Listener
	   %% ,DialTimer
	   ,ChatRoomTimer
       ,Router
        ]}}.
