%% @author hyf
%% @doc @todo Add description to emipian_timer_tel.


-module(emipian_timer_tel).

-behaviour(gen_server).

-include("session.hrl").
-include("macro.hrl").
-include("logger.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-record(state, {timeout}).
-export([init/1,handle_info/2,start_link/1]).


start_link(IntervalTime) ->
    gen_server:start_link(?MODULE,
			  [IntervalTime], []).
init([IntervalTime])->
	{ok, #state{timeout=IntervalTime},IntervalTime}.


handle_info(timeout,State )->
	#state{timeout = TimeOut} =State ,
    processtimedial(),
    {noreply,State,TimeOut}.


processtimedial()->
 Result = emipian_msg_log:find_no_timeouttel(),
 processonedial(Result),
ok.

processonedial([]) ->ok;

processonedial([H|T]) ->
	
	ValidTime  = emipian_msg_log:getfieldvalue(H, validtime),
	MsgID  = emipian_msg_log:getfieldvalue(H, msgid),
	SenderSessionID  = emipian_msg_log:getfieldvalue(H, sendersessionid),

	CurrentTime  = os:timestamp() ,
	if CurrentTime>ValidTime ->
		   
		   mod_action_replydial:sendmsg_status(MsgID, SenderSessionID, ?HANG_STATUS_CS),
	       emipian_msg_log:update_dialinfo(MsgID, ?HANG_STATUS_CS);
   
		   ok;
	    true ->ok
	  
	end,
  processonedial(T).


