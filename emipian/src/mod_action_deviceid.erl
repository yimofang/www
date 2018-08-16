%% @author hyf
%% @doc @todo Add description to mod_action_deviceid.


-module(mod_action_deviceid).
-include(  "session.hrl").
-include("errorcode.hrl").
-include("logger.hrl").
 
-define(AC_CS_DEVICEID, 30007).
-define(AC_SC_DEVICEID_R, 60007).
 
%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_sendfields_fromparam/2,get_msgstamptime/1]).



%% ====================================================================
%% Internal functions
%% ====================================================================

process_action(_MsgID,Session,_Action,Param)-> 
	#session{sessionid=SessionID,appos =AppOS} = Session,
	if 
		(AppOS=:=1) or (AppOS=:=4) ->
			emipian_sm:update_termialno(SessionID,Param),
       {Reuslt,ToDataBase} = get_resultparam(?AC_CS_DEVICEID,?EC_SUCCESS),	
	   {ok,Reuslt,ToDataBase}; 		
		true->
       {Reuslt,ToDataBase} = get_resultparam(?AC_CS_DEVICEID,?EC_ERROR),	
	   {ok,Reuslt,ToDataBase}		
	end.


get_sendfields_fromparam(_,Param)->
  {deviceid,Param}.

get_msgstamptime(_)->{ok,0}.

get_resultparam(Action,Code)->
   Return = {?AC_SC_DEVICEID_R,Code},
   ToDataBase = {action,?AC_SC_DEVICEID_R,code,Code},
   {Return,ToDataBase}.

