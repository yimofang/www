%% @author hyf
%% @doc @todo Add description to srv_exitchatroom.


-module(srv_exitchatroom).

-include("session.hrl").
-include("logger.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).

process(SenderSession,{UserID,ChatRoomNo}) ->
    spawn(?MODULE,handle_action,[SenderSession,{UserID,ChatRoomNo}]). 



handle_action(SenderSession,{UserID,ChatRoomNo}) -> 
	try
     send(SenderSession,{UserID,ChatRoomNo})
	after
	 exit(normal)   
	end.

processsrv(SenderSession,{UserID,ChatRoomNo})->
  	send(SenderSession,{UserID,ChatRoomNo}).


%% ====================================================================
%% Internal functions
%% ====================================================================


send(SenderSession,{UserID,ChatRoomNo})->
    #session{sessionid= SessionID,appcode = AppCode,userid = SenderUserID,selfpid = MsgPid} =SenderSession,
  
    OnlineUsers = emipian_msg_log:get_chatroom_online(SessionID,ChatRoomNo),
    sendnext(SenderSession,ChatRoomNo,OnlineUsers). 
	

sendnext(_,_,[]) ->
ok;
sendnext(SenderSession,ChatRoomNo,[H|T]) ->
  

	mod_action_exitchatroom:sendmsg_to_terminal(SenderSession,ChatRoomNo,H),
    
	sendnext(SenderSession,ChatRoomNo,T).
