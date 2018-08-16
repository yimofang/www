%% @author hyf
%% @doc @todo Add description to emipian_srv_chatroom.


-module(srv_chatroom1).


-include("session.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).



process(SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName}) ->
    spawn(?MODULE,handle_action,[SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName}]). 



handle_action(SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName}) -> 
	try
     send(SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName})
	after
	 exit(normal)   
	end.

processsrv(SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName})->
  	send(SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName}).


%% ====================================================================
%% Internal functions
%% ====================================================================


send(SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName}
					)->
	
	  #session{sessionid=SessionID} = SenderSession,
      OnlineUsers = emipian_msg_log:get_chatroom_online(SessionID,ChatRoomNo),
      sendnext(SenderSession,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName,OnlineUsers).
      


sendnext(_,_,_,_,_,_,_,[]) ->
ok;
sendnext(SenderSession,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName,[H|T]) ->
	#session{userid =SenderUserID} = SenderSession,
	PeerSessionID = emipian_msg_log:getfieldvalue(H, sessionid),
	PeerUserID = emipian_msg_log:getfieldvalue(H, userid),
	UserAddtionInfo ={sessionid,PeerSessionID,chatroomno,ChatRoomNo,nickname,NickName,userid,SenderUserID},
	mod_action_chatroom:sendmsg_to_user(SenderSession,PeerSessionID, MsgID, Content, MsgTime, PeerUserID, 
				UserAddtionInfo),
sendnext(SenderSession,StampTime,MsgID,Content,MsgTime,ChatRoomNo,NickName,T).
