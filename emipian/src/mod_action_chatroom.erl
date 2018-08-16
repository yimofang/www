%% @author hyf
%% @doc @todo Add description to mod_action_chatroom.


-module(mod_action_chatroom).

-include("session.hrl").
-include("errorcode.hrl").
-include( "action.hrl").
-include("macro.hrl").
-include("logger.hrl").

-define(AC_CS_CHATROOM,   31006).
-define(AC_SC_CHATROOM_R, 61006).
 
-define(AC_SC_CHATROOM, 21009).


-define(CMDMINLEN, 20).

%% ====================================================================
%% API functions
%% ====================================================================
-export([
		  process_action/4
		  ,get_msgstamptime/1,
           get_sendfields_fromparam/2
		]).

-export([
		  get_sendparam_fromfields/5
		  ,sendmsg_to_terminal/9
		]).



-export([
		  sendmsg_to_user/6
		 ,get_resultparam/5
		]).



process_action(MsgID,Session,Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,ValidTime,ChatRoomNo,ContentLen,Content}->
			 
         MsgTime = emipian_msg_log:get_msgtime(MsgID),
		 #session{sessionid = SessionID } = Session,
		 send_msg(Session,Action,StampTime,ChatRoomNo,MsgID,Content,MsgTime),
		  {waitmsg} 
	  end.
	
 get_sendfields_fromparam(_,Param)->
	Result = parse_param(Param),
	case Result of
	   cmderror->cmderror;
		 {ok,StampTime,ValidTime,ChatRoomNo,ContentLen,Content}->
	      {stamptime,StampTime,validtime,ValidTime,chatroomno,ChatRoomNo,contentlen, ContentLen,content,Content};
	   _->
         cmderror  
     end.

get_msgstamptime(Param)->
	 Total = byte_size(Param), 
	 if
 	 Total<?CMDMINLEN ->cmderror;
	 true-> <<StampTime:64/little,_/binary>> = Param,
			{ok,StampTime}
	 end.

get_sendparam_fromfields(_Action,StampTime,MsgID,SendTime,Result)->
	Code = emipian_util:lookuprecordvalue(code, Result),
 	
    MsgID1 = emipian_util:str_to_binayid(MsgID),
	SendTime0 = emipian_util:get_mstime(SendTime),
 
    ReParam = <<StampTime:64/little,MsgID1/binary,SendTime0:64/little>>,

    {ok,{?AC_SC_CHATROOM_R,Code,ReParam}}.

%%      Mod:sendmsg_to_terminal(Action,MsgID,SynNo,Param,Session,
%%							   SenderUserID,MsgTime,ChatObj,AddtionInfo);
sendmsg_to_terminal(_Action,MsgID,SynNo,Param,Session,SenderUserID,MsgTime,ChatObj,AddtionInfo)->
	#session{userid =ReceiverUserID,usertype =UserType} = Session,
	Content = emipian_util:lookuprecordvalue(content, Param),
%%	ChatObj =1,
	     ?INFO_MSG("mod_action_chatroom sendmsg_to_terminal1 ~p--~p \~n", [AddtionInfo,Content]),

	UserAddtionInfo = emipian_msg_log:get_user_addtioninfo(MsgID, ReceiverUserID),
	     ?INFO_MSG("mod_action_chatroom sendmsg_to_terminal2 ~p--~p \~n", [UserAddtionInfo,ReceiverUserID]),

	Data =  get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,
									ChatObj,MsgTime,UserAddtionInfo),
  	  sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content).

   

%% ====================================================================
%% Internal functions
%% ====================================================================
 
getsenderinfo(GroupID,SenderUserID,AppCode)->
   case emipian_mysqldb:getgroupsenderinfo(GroupID, SenderUserID, AppCode) of
	 -1 ->-1;
	   {RetunCode,SenderGroupID,ComapnyID,CardID,S101,Contact,Type,Company101} ->
	   {RetunCode,SenderGroupID,ComapnyID,CardID,S101,Contact,Type,Company101};
	  RetunCode ->RetunCode
   end.  
  
  

send_msg(SenderSession,Action,StampTime,ChatRoomNo,MsgID,Content,MsgTime)->
	#session{userid =SenderUserID ,selfpid=Pid}=SenderSession,
	emipian_msg_log:save_userreceiver(MsgID, SenderUserID,?CHATSTATUS_ONLY_REC,SenderUserID,MsgTime,{},?CHATSTYPE_CHATROOM),
	srv_chatroom:process
	   (SenderSession,{Action,StampTime,MsgID,Content,MsgTime,ChatRoomNo}),
	ok.

sendmsg_to_user(SenderSession, MsgID, Content, MsgTime, ReceiveUserID, 
				UserAddtionInfo)->
    #session{userid = SenderUserID,usertype=UserType,sessionid=SessionID } = SenderSession,
   Status = if 
             SenderUserID=:=ReceiveUserID ->?CHATSTATUS_SELF;
             true ->?CHATSTATUS_NOT_SEND
           end, 	
	case save_userreceiver(MsgID,ReceiveUserID,Status,SenderUserID,MsgTime,UserAddtionInfo,?CHATSTYPE_CHATROOM) of
	  {duplicate,_}->ok;
	  {ok,SynNo} ->
		ChatObj =1,
		Data =  get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,
									ChatObj,MsgTime,UserAddtionInfo),
        Sessions =  emipian_sm:get_usersession(SessionID, ReceiveUserID),
	
	    sendmsg_to_terminals(MsgID,SynNo,SenderUserID,Data,Content,UserAddtionInfo,Sessions)
   end.


sendmsg_to_terminals(MsgID,SynNo,SenderUserID,Data,Content,UserAddtionInfo,[])->

	ok;

sendmsg_to_terminals(MsgID,SynNo,SenderUserID,Data,Content,UserAddtionInfo,[H|T])->
	ChatRoomNo = emipian_util:lookuprecordvalue(chatroomno, UserAddtionInfo), 
	#session{sessionid = ReceiverSessionID} =H,
	
	case emipian_msg_log:online_session(ReceiverSessionID, ChatRoomNo) of
		found->
	   sendmsg_to_terminal(MsgID,SynNo,SenderUserID,H,Data,Content,UserAddtionInfo);
	    _->ok	
	end,	
    sendmsg_to_terminals(MsgID,SynNo,SenderUserID,Data,Content,UserAddtionInfo,T).



save_userreceiver(MsgID,UserID,Status,SenderUserID,SendTime,UserAddtionInfo,Type)->
   emipian_msg_log:save_userreceiver(MsgID, UserID,Status,SenderUserID,SendTime,UserAddtionInfo,Type).	



sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content,UserAddtionInfo)->
     #session{selfpid=PID,status =Status,sessionid =SessionID,userid=UserID} = Session,
      ?INFO_MSG("mod_action_chatroom Send:Msgid:~p,userid:~p,SelfPid:~p,Status:~p,SessionID:~p ~n", [MsgID,UserID,PID,Status,SessionID]),
  
	   if 
		 Status =:=?STATUS_ONLINE ->
         emipian_route:sendmsg(Session,{msg,?AC_SC_CHATROOM,MsgID,SynNo,Data}); 
           true->ok
     end.



sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content)->
     #session{selfpid=PID,status =Status} = Session,
         emipian_route:sendmsg(Session,{msg,?AC_SC_CHATROOM,MsgID,SynNo,Data}).

getAPNSData(Content)
  ->Content.


get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,ChatObj,MsgTime,
					UserAddtionInfo)->
  ChatRoomNo = emipian_util:lookuprecordvalue(chatroomno, UserAddtionInfo), 
  ContentLength = byte_size(Content),
  MsgID1 = emipian_util:str_to_binayid(MsgID),
  SenderUserID1 = emipian_util:str_to_binayid(SenderUserID),
  if ChatObj=:=1 ->
   AddtionInfoJson = getaddtionjson(UserAddtionInfo,UserType),		

   AddtionInfoSize  = byte_size(AddtionInfoJson);
   true->
       AddtionInfoJson = <<"">>,		
       AddtionInfoSize  = byte_size(AddtionInfoJson)
   end,	   
  
    <<MsgID1:40/binary,SynNo:32/little,ChatRoomNo:16/little,0:8/little,SenderUserID1:40/binary,MsgTime:64/little, 
	ChatObj:8/little,ContentLength:32/little, 
	Content:ContentLength/binary,AddtionInfoSize:32/little,AddtionInfoJson:AddtionInfoSize/binary>>. 
parse_param(Param)->
  Total = byte_size(Param),  
    if 
		Total<?CMDMINLEN ->
			cmderror;
		 true->
	        <<StampTime:64/little,ValidTime:32/little,ChatRoomNo:16/little,ContentLen:32/little,Content/binary>> = Param,
		    Len2 = byte_size(Content),
		    if 
			   Len2 =/= ContentLen ->cmderror;
		       true->
		        {ok,StampTime,ValidTime,ChatRoomNo,ContentLen,Content}
		    end
     end.


get_resultparam(Action,Code,StampTime,MsgID,MsgTime)->

	MsgID1 = emipian_util:str_to_binayid(MsgID),
   Return = {?AC_SC_CHATROOM_R,Code,<<StampTime:64/little,MsgID1/binary,MsgTime:64/little>>},
   ToDataBase = 	
   if
	 Code=:=0 ->
   	 {action,?AC_SC_CHATROOM_R,code,Code};
   	 true->{action,?AC_SC_CHATROOM_R,code,Code}
   end,
   {Return,ToDataBase}.


getaddtionjson(UserAddtionInfo,UserType) ->

	NickName = emipian_util:lookuprecordvalue(nickname, UserAddtionInfo), 
	Dict = dict:new(),
	Dict1 = 
	  dict:store("nickname", NickName,Dict),
	  list_to_binary(rfc4627:encode(Dict1)).
