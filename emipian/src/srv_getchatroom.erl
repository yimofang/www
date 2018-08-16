%% @author hyf
%% @doc @todo Add description to srv_getchatroom.


-module(srv_getchatroom).

-include("session.hrl").
-include("logger.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).

process(SenderSession,{Action,UserID,ChatRoomNo}) ->
    spawn(?MODULE,handle_action,[SenderSession,{Action,UserID,ChatRoomNo}]). 



handle_action(SenderSession,{Action,UserID,ChatRoomNo}) -> 
	try
     send(SenderSession,{Action,UserID,ChatRoomNo})
	after
	 exit(normal)   
	end.

processsrv(SenderSession,{Action,UserID,ChatRoomNo})->

	send(SenderSession,{Action,UserID,ChatRoomNo}).


%% ====================================================================
%% Internal functions
%% ====================================================================


send(SenderSession,{Action,UserID,ChatRoomNo})->
    #session{sessionid= SessionID,appcode = AppCode,userid = SenderUserID,selfpid = MsgPid} =SenderSession,
  
    OnlineUsers = emipian_msg_log:get_chatroom_online(SessionID,ChatRoomNo),

	Count  = length(OnlineUsers),

	  {ActionResult,ToDabase}  = mod_action_getchatroom:get_resultparam(Action,0,Count,ChatRoomNo),
     MsgPid!{result,Action,<<"">>,{ok,ActionResult,ToDabase}},

    sendnext(SenderSession,ChatRoomNo,OnlineUsers).
	

sendnext(_,_,[]) ->
ok;
sendnext(SenderSession,ChatRoomNo,[H|T]) ->
    mod_action_getchatroom:sendmsg_to_terminal(SenderSession,ChatRoomNo,H),
sendnext(SenderSession,ChatRoomNo,T).


