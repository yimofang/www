%% @author hyf
%% @doc @todo Add description to srv_enterchatroom.


-module(srv_enterchatroom).
-include("session.hrl").
-include("logger.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).

process(SenderSession,{UserID,NickName,ChatRoomNo}) ->
    spawn(?MODULE,handle_action,[SenderSession,{UserID,NickName,ChatRoomNo}]). 



handle_action(SenderSession,{UserID,NickName,ChatRoomNo}) -> 
	try
     send(SenderSession,{UserID,NickName,ChatRoomNo})
	after
	 exit(normal)   
	end.

processsrv(SenderSession,{UserID,NickName,ChatRoomNo})->

	send(SenderSession,{UserID,NickName,ChatRoomNo}).


%% ====================================================================
%% Internal functions
%% ====================================================================


send(SenderSession,{UserID,NickName,ChatRoomNo})->
    #session{sessionid= SessionID,appcode = AppCode,userid = SenderUserID,selfpid = MsgPid} =SenderSession,
  
    OnlineUsers = emipian_msg_log:get_chatroom_online(SessionID,ChatRoomNo),
    sendnext(SenderSession,ChatRoomNo,NickName,OnlineUsers)
    ,sendchat(SenderSession,ChatRoomNo)
.
	

sendnext(_,_,_,[]) ->
ok;
sendnext(SenderSession,ChatRoomNo,NickName,[H|T]) ->
    mod_action_enterchatroom:sendmsg_to_terminal(SenderSession,ChatRoomNo,NickName,H),
sendnext(SenderSession,ChatRoomNo,NickName,T).


sendchat(SenderSession,ChatRoomNo)->
	  #session{userid =SenderUserID} = SenderSession,
      UserChats = emipian_msg_log:get_chatroom_chat(SenderUserID,ChatRoomNo),
	  		 ?INFO_MSG("srv_enterchatroom sendchat =~p~n.", [UserChats]),	 

	  emipian_auto:send_user_nosendmessage(UserChats,SenderSession,0).

