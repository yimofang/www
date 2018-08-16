%% @author hyf
%% @doc @todo Add description to mod_action_fixgroupchat.


-module(mod_action_fixgroupchat).
-include("session.hrl").
-include("errorcode.hrl").
-include("action.hrl").
-include("macro.hrl").
-include("logger.hrl").

-define(AC_CS_FXIGROUPCHAT, 31003).
-define(AC_SC_FIXGROUPCHAT_R, 61003).
 
-define(AC_SC_FIXGROUPCHAT, 21003).


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
		  sendmsg_to_user/7
          ,get_resultparam/6
		]).

process_action(MsgID,Session,Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,ReceiverLen,Receivers,GroupID,Level,_,Content}->
		 #session{sessionid=SessionID,userid=SenderUserID,appcode =AppCode,usertype=UserType} = Session,	 
         MsgTime = emipian_msg_log:get_msgtime(MsgID),
		 Receivers2 = 
	       if 
             ReceiverLen>0 ->Receivers;
             true -> 
			   X =("[{\"id\":\""++binary_to_list(GroupID)++"\",\"type\":1"++"}]"),
				list_to_binary(X)
          end,
		 
		  case rfc4627:decode(Receivers2) of
			 {ok,Receivers1,_} -> 
				 
				 
			  send_msg(Session,Action,StampTime,GroupID,Receivers1,Level,MsgID,Content,MsgTime),

              {waitmsg};
             _->
			  {Reuslt,ToDataBase} = get_resultparam(Action,?EC_CMDERROR,StampTime,MsgID,MsgTime,{}),	
		      {ok,Reuslt,ToDataBase}
           end
	  end.
	
 get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	   {ok,StampTime,ReceiverLen,Receivers,GroupID,Level,ContentLen,Content}->
	   {stamptime,StampTime,receiverlen,ReceiverLen,receivers,Receivers,contentlen,
        ContentLen,content,Content,groupid,GroupID}
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

    {ok,{?AC_SC_FIXGROUPCHAT_R,Code,ReParam}}.


sendmsg_to_terminal(Action,MsgID,SynNo,Param,Session,SenderUserID,MsgTime,ChatObj,AddtionInfo)->
	#session{userid =ReceiverUserID,usertype =UserType} = Session,
	Content = emipian_util:lookuprecordvalue(content, Param),
%%	ChatObj =1,
	UserAddtionInfo = emipian_msg_log:get_user_addtioninfo(MsgID, ReceiverUserID),
	Data =  get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,
									ChatObj,MsgTime,UserAddtionInfo,AddtionInfo),
  	sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content).


send_msg(SenderSession,Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime)->
	#session{userid =SenderUserID}=SenderSession,
    emipian_msg_log:save_userreceiver(MsgID, SenderUserID,?CHATSTATUS_ONLY_REC,SenderUserID,MsgTime,{},?CHATSTYPE_FIXGROUP),
	emipian_srv_fixgroupchat:processsrv
	   (SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime}).

	
sendmsg_to_user(SenderSession, MsgID, Content, MsgTime, ReceiveUserID, 
				UserAddtionInfo,AddtionInfo)->
    #session{userid = SenderUserID,usertype=UserType,sessionid=SessionID } = SenderSession,
	
   Status = if 
             SenderUserID=:=ReceiveUserID ->?CHATSTATUS_SELF;
             true ->?CHATSTATUS_NOT_SEND
           end, 	
	
  case save_userreceiver(MsgID,ReceiveUserID,Status,SenderUserID,MsgTime,UserAddtionInfo,?CHATSTYPE_FIXGROUP) of
	  {duplicate,_}->ok;
	  {ok,SynNo} ->
		ChatObj =1,
		Data =  get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,
									ChatObj,MsgTime,UserAddtionInfo,AddtionInfo),
        Sessions =  emipian_sm:get_usersession(SessionID, ReceiveUserID),
	    sendmsg_to_terminals(MsgID,SynNo,SenderUserID,Sessions,Data,Content,AddtionInfo)
   end. 
	


save_userreceiver(MsgID,UserID,Status,SenderUserID,SendTime,UserAddtionInfo,Type)->
   emipian_msg_log:save_userreceiver(MsgID, UserID,Status,SenderUserID,SendTime,UserAddtionInfo,Type).	

sendmsg_to_terminals(_,_,_,[],_,_,_)
   ->ok;
sendmsg_to_terminals(MsgID,SynNo,SenderUserID,[Session|T],Data,Content,AddtionInfo)->
	 emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,yes),
     sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content,AddtionInfo),
     sendmsg_to_terminals(MsgID,SynNo,SenderUserID,T,Data,Content,AddtionInfo).

sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content,AddtionInfo)->
     #session{selfpid=PID,status =Status,sessionid =SessionID,userid=UserID} = Session,
      ?INFO_MSG("mod_action_fixgroupchat Send:MsgID:~p,userid:~p,SelfPid:~p,Status:~p,SessionID:~p ~n", [MsgID,UserID,PID,Status,SessionID]),
  
	   if 
		 Status =:=?STATUS_ONLINE ->

         try			 
           PID ! {msg,?AC_SC_FIXGROUPCHAT,MsgID,SynNo,Data}
		 catch
			 _:_->ok 
		  end;		 
           true->ok
     end,
    case Content of
	 no ->ok;	
     _-> 
	Sender101 = 
     try
	 emipian_util:lookuprecordvalue(s101, AddtionInfo)
	 catch
       _:_-><<"">>
     end,		 
        emipian_apns:sendapns(Session,getAPNSData(Content),SenderUserID,Sender101)
    end.
	 



sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content)->
     #session{selfpid=PID,status =Status} = Session,
   try	 
     PID ! {msg,?AC_SC_FIXGROUPCHAT,MsgID,SynNo,Data}
	 catch
		 _:_->ok 
	  end.
getAPNSData(Content)
  ->Content.



get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,ChatObj,MsgTime,
					UserAddtionInfo,AddtionInfo)->
  ContentLength = byte_size(Content),
  MsgID1 = emipian_util:str_to_binayid(MsgID),
  SenderUserID1 = emipian_util:str_to_binayid(SenderUserID),
  GroupID   =emipian_util:lookuprecordvalue(orgid, UserAddtionInfo),
  GroupID1  =emipian_util:str_to_binayid(GroupID),
  if ChatObj=:=1 ->
   AddtionInfoJson = getaddtionjson(UserAddtionInfo,AddtionInfo,UserType),		

   AddtionInfoSize  = byte_size(AddtionInfoJson);
   true->
       AddtionInfoJson = <<"">>,		
       AddtionInfoSize  = byte_size(AddtionInfoJson)
   end,	   
  <<MsgID1:40/binary,SynNo:32/little,SenderUserID1:40/binary,MsgTime:64/little, 
	ChatObj:8/little,ContentLength:32/little, 
	Content:ContentLength/binary,GroupID1:40/binary,
	AddtionInfoSize:32/little,AddtionInfoJson/binary>>. 



parse_param(Param)->
  Total = byte_size(Param),  
  Rest10 = 
	  if 
		Total<?CMDMINLEN ->
			StampTime = 0,
			ReceiverLen =0,
			Receivers = <<"">>,
			cmderror;
		 true->
	          <<StampTime:64/little,_:32/little,ReceiverLen:32/little,Rest/binary>> = Param,
		      Len1 = byte_size(Rest),
  			  if
				Len1<ReceiverLen+4 ->
					Receivers = <<"">>,
					cmderror;
			     true->
					 if
 				        ReceiverLen>0 ->  
 		                   <<Receivers:ReceiverLen/binary,Rest1/binary>> = Rest,
					     Rest1;
				        true->
					      Receivers = <<"">>,
					      Rest
                     end 
			   end		 
      end,
  
     case Rest10 of 
        cmderror->cmderror;
        _->
		  <<ContentLen:32/little,Rest2/binary>>	 =  Rest10,
		  Len2 = byte_size(Rest2),
		   if 
			   Len2 =/= ContentLen+41 ->cmderror;
		       true->
				<<Content:ContentLen/binary,GroupID:40/binary,Level:8/little>> = Rest2,
		        {ok,StampTime,ReceiverLen,Receivers,emipian_util:binary_to_str(GroupID),Level,
               ContentLen,Content}
		   end
     end.


get_resultparam(Action,Code,StampTime,MsgID,MsgTime,AddtionInfo)->
   MsgID1 = emipian_util:str_to_binayid(MsgID),
   Return = {?AC_SC_FIXGROUPCHAT_R,Code,<<StampTime:64/little,MsgID1/binary,MsgTime:64/little>>},
   ToDataBase = 	
   if
	 Code>=0 ->
   	 {action,?AC_SC_FIXGROUPCHAT_R,code,0,addtioninfo,AddtionInfo};
   	 true->{action,?AC_SC_FIXGROUPCHAT_R,code,Code}
   end,
   {Return,ToDataBase}.


getaddtionjson(UserAddtionInfo,AddtionInfo,UserType) ->

	CardID = 
	try
	  emipian_util:lookuprecordvalue(cardid, AddtionInfo)
    catch
     _:_-><<"">>
    end,
	S101 = 
     try
	 emipian_util:lookuprecordvalue(s101, AddtionInfo)
	 catch
       _:_-><<"">>
     end,		 
	GroupType = emipian_util:lookuprecordvalue(grouptype, UserAddtionInfo), 
	Group101 = emipian_util:lookuprecordvalue(groupname, UserAddtionInfo), 

	Dict = dict:new(),
	  Dict1  = dict:store("cardid", CardID,Dict),
	  Dict2 = dict:store("s101", S101,Dict1),
	  Dict3 = dict:store("grouptype", GroupType,Dict2),
      Dict4 = 
        if 
          GroupType=:=110;GroupType=:=111 ->
	              dict:store("groupname", Group101,Dict3);
          true->Dict3
        end,
	
    list_to_binary(rfc4627:encode(Dict4)).




