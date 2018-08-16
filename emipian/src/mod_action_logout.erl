%% @author hyf
%% @doc @todo Add description to mod_action_logout.
 

-module(mod_action_logout).

%% ====================================================================
%% API functions
%% ====================================================================
-export(  [process_action/4,get_sendfields_fromparam/2,get_msgstamptime/1]).
-include("session.hrl").


%% ====================================================================
%% Internal functions
%% ====================================================================

process_action(MsgID,Session,Action,Param)-> 

	#session{sessionid=SessionID,mainlink=MainLink,
			   selfpid = SelfPid} = Session,
	emipian_sm:close_session(SessionID,MainLink,SelfPid),
	emipian_timer_chatroom:processchatroom(SessionID),
	{noresp,terminate}.

get_sendfields_fromparam(_,_)->
  {param,<<"">>}.

get_msgstamptime(_)->{ok,0}.
