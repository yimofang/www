%% @author hyf
%% @doc @todo Add description to emipian_msg_log.


-module(emipian_msg_log).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
		 save_msg_log/5
		 ,save_msg_log/4
		,save_msg_log/3
%%		,update_msg_result/5
		,update_msg_result/3
%%		,update_msg_result/6
		,save_userreceiver/7
		,save_terminalreceiver/4,
		 find_samemsg/3
		,get_msgtime/1
%%		 ,update_login_result/5
		,save_login_log/4,
		 update_terminal_receivestatus/2
		,update_user_receivestatus/2,
		 save_sc_msg_log/4
		,cancel_terminal_receive/1
		,find_ternimal_no_sendmsg/3
		,find_user_no_sendmsg/3
		,find_user_no_sendmsg_special/3	
		,getfieldvalue/2	
	    ,get_sendmsg/1
		,get_user_addtioninfo/2
		,search_user_orgmsg/7
		,search_user_singlemsg/7
		,find_sys_sendmsg/3
	     ,save_dial_meeting/12
		,update_dialinfo/2
		,update_dialinfo/4
		,get_dialinfo/1
		,find_no_sendtel/1		
		,find_no_timeouttel/0
        ,get_dailmsg/1
		,get_receiverstatus/1
        ,save_client_chatroom/4
        ,get_chatroom_online/2
        ,clear_chat_session/2
		,get_chatroom_user_nickname/1
		,update_client_chatroom/1
		,delete_chatroom_chat/2
		,get_invalide_chatroom_client/1
		,chatroom_user_online/2
		,get_chatroom_chat/2
		,clear_chat_session/0
		,get_chatroom_from_sessionid/1
		,online_session/2
		]).

-include("session.hrl").
-include("action.hrl").
-include("macro.hrl").
-include("logger.hrl").
%% ====================================================================
%%  Internal functions
%%
%%  tblmsglog
%%  msgid :uuid  
%%  senderinfo : from SenderSession
%%  userid usertype appcode customcode appos  lang version terminalno 
%%  action : from Action
%%  sendtime
%%  param  :
%%  from Param
%%  result:   code
%%            action
%%            orgid
%%            resultparam  
%%
%%   status 0-正常     20-指令错误

%%  tblmsgchat
%%  msgid :uuid  
%%  senderinfo : from SenderSession
%%  userid usertype appcode customcode appos  lang version terminalno 
%%  action : from Action
%%  sendtime
%%  param  :
%%  from Param
%%  result:   code
%%            action
%%            orgid
%%            resultparam  
%%            addtioninfo :orgid
%%
%%   status 0-正常   10 未到期   11 已过期  20-指令错误
%%
%%  tbluserreceiver
%%   recvid  
%%   msgid
%%   userid
%%   status       0 未发送 1-发送成功   2-本人发，不用重发  3-仅记录    11 已过期   20-指令错误 
%%   
%%    orgid  群标识，固定群标识，部门标识
%%    addtioninfo :orgid  ,sessionid 
%%    senderuserid   
%%    sendtime 
%%    type 0-个人  1-群  2-固定群      
%%     
%%
%%%  tblusermaxrevid db.tblusermaxrevid.ensureIndex({"userid":1},{"unique":true})
%%   maxrecvid  
%%%   userid

%%  tblternimalreceiver
%%  sessionid 
%%  recvid
%%  msgid
%%  receiverinfo
%%     userid usertype appcode customcode appos lang version terminalno 
%%  lastsendtime 
%%  status   
%%        0 未发送 1-发送成功  10-清除，无需再次发送  20-指令错误
%%  receivetime
%%  sendtimes 
%%  
%%  tbldialmeet 
%%   msgid,sessionid,stamptime ,
%%   sendertime lastsendertime validtime  senderuserid receiveruserid  status
%%    meetingid ,meetingpass   
%%    status 0-not send to peer  1-sending     2-sended wait to response 
%%    5 responed  6 compelete    10 timeout
%%    tblchatroom
%%   sessionid, userid,nickname,roomno, entertime,exittime
%%
%%
%% ====================================================================

save_msg_log(MsgID,SenderSession,Action,Param,Status) 
 %%  when is_binary(Param) 
  ->
   Param1=gen_action_mod:get_sendfields_fromparam(Action, Param),
 
    case Param1 of 
      cmderror ->
        save_msg_log(MsgID,SenderSession,Param,?CHATSTATUS_CMDERROR),
        cmderror;
      _->
	  emipian_msgdb:save_msg_log(MsgID, SenderSession, Action, Param1,Status)
   end.

save_msg_log(MsgID,SenderSession,Action,Param) 
  when is_binary(Param) 
   ->save_msg_log(MsgID,SenderSession,Action,Param,?CHATSTATUS_NOT_SEND); 
save_msg_log(MsgID,SenderSession,Param,Status) ->
	emipian_msgdb:save_msg_log(MsgID, SenderSession, ?AC_NOACTION, Param,Status).

save_msg_log(MsgID,SenderSession,Param) ->
	save_msg_log(MsgID, SenderSession, Param,?CHATSTATUS_NOT_SEND).

save_sc_msg_log(MsgID,SenderSession,Action,Param) ->
	emipian_msgdb:save_msg_log(MsgID, SenderSession, Action, Param).


save_login_log(MsgID,SenderSession,Action,Param) ->
	Param1=mod_action_login:get_sendfields_fromparam(Action, Param),

	emipian_msgdb:save_msg_log(MsgID, SenderSession, Action, Param1).

update_msg_result(Action,MsgID,Param) ->
    emipian_msgdb:update_msg_result(Action,MsgID,Param),

	ok.

save_userreceiver(MsgID,UserID,Status,SenderUserID,MsgTime,UserAddtionInfo,Type) ->
	emipian_msgdb:save_userreceiver(MsgID, UserID,Status,SenderUserID,MsgTime,UserAddtionInfo,Type).

save_terminalreceiver(MsgID,RevID,ReceiverSession,Retry)
  ->emipian_msgdb:save_terminalreceiver(MsgID,RevID,ReceiverSession,Retry).




update_terminal_receivestatus(RevID,SessionID) ->
	emipian_msgdb:update_terminal_receivestatus(RevID,SessionID).

update_user_receivestatus(RevID,UserID) ->
	emipian_msgdb:update_user_receivestatus(RevID,UserID).

	
get_msgtime(MsgID)->
	emipian_msgdb:get_msgtime(MsgID).
find_samemsg(MsgID,UserID, StampTime)->
	emipian_msgdb:find_samemsg(MsgID,UserID, StampTime).

cancel_terminal_receive(SessionID) ->
	emipian_msgdb:cancel_terminal_receive(SessionID).

find_ternimal_no_sendmsg(SessionID,Skip,Limit)->
	emipian_msgdb:find_ternimal_no_sendmsg(SessionID, Skip, Limit).

find_user_no_sendmsg(UserID,Skip,Limit) ->
  emipian_msgdb:find_user_no_sendmsg(UserID, Skip, Limit).

find_user_no_sendmsg_special(Session,Skip,Limit) ->
	emipian_msgdb:find_user_no_sendmsg_special(Session, Skip, Limit).

getfieldvalue(Data,FieldName) ->
	emipian_msgdb:getfieldvalue(Data, FieldName).
get_sendmsg(MsgID) ->
	emipian_msgdb:get_sendmsg(MsgID).
 
get_user_addtioninfo(MsgID,UserID) ->
    emipian_msgdb:get_user_addtioninfo(MsgID,UserID).

search_user_orgmsg(UserID,GroupID,StartTime,EndTime,Type,Skip,Limit) ->
    emipian_msgdb:search_user_orgmsg(UserID,GroupID,StartTime,EndTime,Type,Skip,Limit).

search_user_singlemsg(UserID,GroupID,StartTime,EndTime,Type,Skip,Limit) ->
    emipian_msgdb:search_user_singlemsg(UserID,GroupID,StartTime,EndTime,Type,Skip,Limit).


find_sys_sendmsg(Session,Skip,Limit) ->
	emipian_msgdb:find_sys_sendmsg(Session,Skip,Limit).




save_dial_meeting(MsgID,Action,SenderSessionID,SenderUserID,ReceiverUserID,ReceiverSessionID,
 StampTime,ValidLong,Status,AddtionJson,SenderCardID,Sender101) ->
  emipian_msgdb:save_dial_meeting(MsgID,Action,SenderSessionID,SenderUserID,ReceiverUserID,ReceiverSessionID,
 StampTime,ValidLong,Status,AddtionJson,SenderCardID,Sender101). 

update_dialinfo(MsgID,Status,MeetingID,MeetingPass) 
 ->emipian_msgdb:update_dialinfo(MsgID,Status,MeetingID,MeetingPass) .
get_dialinfo(MsgID) ->
   emipian_msgdb:get_dialinfo(MsgID) .

update_dialinfo(MsgID,Data)->
  emipian_msgdb:update_dialinfo(MsgID,Data).

find_no_sendtel(UserID)->
	emipian_msgdb:find_no_sendtel(UserID).
find_no_timeouttel()->
	emipian_msgdb:find_no_timeouttel().

get_dailmsg(MsgID)
->emipian_msgdb:get_dailmsg(MsgID).

get_receiverstatus(UserID) ->
   emipian_msgdb:get_receiverstatus(UserID).

save_client_chatroom(SessionID,UserID,NickName,ChatRoomNo) ->
   emipian_msgdb:save_client_chatroom(SessionID,UserID,NickName,ChatRoomNo).

get_chatroom_online(SessionID,ChatRoomNo) ->
   emipian_msgdb:get_chatroom_online(SessionID,ChatRoomNo).

clear_chat_session(SessionID,ChatRoomNo) ->
emipian_msgdb:clear_chat_session(SessionID,ChatRoomNo).

get_chatroom_user_nickname(SessionID)->
   emipian_msgdb:get_chatroom_user_nickname(SessionID).

update_client_chatroom(Session)->
emipian_msgdb:update_client_chatroom(Session).

 delete_chatroom_chat(SessionID,ChatRoomNo)->
 emipian_msgdb:delete_chatroom_chat(SessionID,ChatRoomNo).
get_invalide_chatroom_client(Timeout) ->
emipian_msgdb:get_invalide_chatroom_client(Timeout).

chatroom_user_online(UserID,ChatRoomNo) ->
emipian_msgdb:chatroom_user_online(UserID,ChatRoomNo) .

get_chatroom_chat(UserID,ChatRoomNo) ->
emipian_msgdb:get_chatroom_chat(UserID,ChatRoomNo).

clear_chat_session()->
emipian_msgdb:clear_chat_session().

get_chatroom_from_sessionid(SessionID) ->
	emipian_msgdb:get_chatroom_from_sessionid(SessionID).

online_session(SessionID,ChatRoomNo)->
	emipian_msgdb:online_session(SessionID,ChatRoomNo).