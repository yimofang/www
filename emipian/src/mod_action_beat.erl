%% @author hyf
%% @doc @todo Add description to mod_action_beat.


-module(mod_action_beat).

%% ====================================================================
%% API functions
%% ====================================================================
-include("errorcode.hrl").
-include("session.hrl").
-include(  "action.hrl").
-include(  "logger.hrl").
-define(CMDMINLEN, 5).
-export([process_action/4,get_msgstamptime/1,
		 get_sendfields_fromparam/2]).



process_action(_,Session,_,Param)-> 
   Len = byte_size(Param),	
   #session{userid=UserID,sessionid=SessionID} = Session,
   if 
	    Len=:=4 ->
		 <<SynNo:32/little>> = Param,
		  emipian_msg_log:update_user_receivestatus(SynNo,UserID), 
		  emipian_msg_log:update_terminal_receivestatus(SynNo,SessionID), 

       {Reuslt,ToDataBase} = get_resultparam(?AC_SC_BEAT_R,?EC_SUCCESS),	
	   {ok,Reuslt,ToDataBase}; 
	   true ->cmderror	   
     end.	
get_msgstamptime(_)->
	{ok,0}.
 
	
get_sendfields_fromparam(_,Param)->
	 Len = byte_size(Param),	
     if 
	    Len=:=4 ->	 
	    <<SynNo:32/little>> = Param,
	    {synno,SynNo};
	    true ->cmderror	   
     end.	

%% ====================================================================
%% Internal functions
%% ====================================================================


get_resultparam(ReAction,Code)->
   Return = {ReAction,Code},
   ToDataBase = {action,ReAction,code,Code},
   {Return,ToDataBase}.
