%% @author hyf
%% @doc @todo Add description to mod_action_switch.


-module(mod_action_switch).
 
%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_sendfields_fromparam/2,get_msgstamptime/1]).
-include("session.hrl").


%% ====================================================================
%% Internal functions
%% ====================================================================
 
process_action(_MsgID,Session,_Action,_Param)-> 

	#session{sessionid=SessionID,appos =AppOS,mainlink=MainLink,
			   selfpid = SelfPid} = Session,
    Session1 = Session#session{status=1},
	if 
		(AppOS=:=1) or (AppOS=:=4) ->
			emipian_sm:update_session(Session1,1),
         	{noresp,ok};
		true->
	        emipian_sm:close_session(SessionID,1,1),
  	        {noresp,terminate}
	end.

get_sendfields_fromparam(_,_)->
  {param,<<"">>}.

get_msgstamptime(_)->{ok,0}.
