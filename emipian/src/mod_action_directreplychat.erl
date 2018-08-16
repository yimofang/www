%% @author hyf
%% @doc @todo Add description to mod_action_directreplychat.


-module(mod_action_directreplychat).


-include("session.hrl").
-include("errorcode.hrl").
-include( "action.hrl").
-include("macro.hrl").
-include("logger.hrl").

-define(AC_CS_DRIECTREPLYCHAT, 31008).
-define(AC_SC_DRIECTREPLYCHAT_R, 61008).
 
-define(AC_SC_DRIECTREPLYCHAT, 21011).


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
		 ,get_resultparam/7
		]).



process_action(MsgID,Session,Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,ReceiverLen,Receivers,ContentLen,Content}->
		 #session{userid=SenderUserID,appcode =AppCode,usertype=UserType} = Session,	 
         MsgTime = emipian_msg_log:get_msgtime(MsgID),
		 Receivers2 = Receivers,
		 
		  case rfc4627:decode(Receivers2) of
			 {ok,Receivers1,_} ->
			  send_msg(Session,Action,StampTime,Receivers1,MsgID,Content,MsgTime),
              {waitmsg};
             _->
			  {Reuslt,ToDataBase} = get_resultparam(Action,?EC_CMDERROR,StampTime,MsgID,MsgTime,<<"">>,{}),	
		      {ok,Reuslt,ToDataBase}
           end
	  end.
	
 get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	  {ok,StampTime,ReceiverLen,Receivers,ContentLen,Content}->
	   {stamptime,StampTime,receiverlen,ReceiverLen,receivers,Receivers,contentlen,
        ContentLen,content,Content}
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

    {ok,{?AC_SC_DRIECTREPLYCHAT_R,Code,ReParam}}.

sendmsg_to_terminal(Action,MsgID,SynNo,Param,Session,SenderUserID,MsgTime,ChatObj,AddtionInfo)->
	#session{userid =ReceiverUserID,usertype =UserType} = Session,
	Content = emipian_util:lookuprecordvalue(content, Param),
%%	ChatObj =1,
	CompanyID = emipian_util:lookuprecordvalue(companyid, AddtionInfo),
	UserAddtionInfo = emipian_msg_log:get_user_addtioninfo(MsgID, ReceiverUserID),
	Data =  get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,
									ChatObj,MsgTime,UserAddtionInfo,AddtionInfo),
  	  sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content).

   

%% ====================================================================
%% Internal functions
%% ====================================================================

send_msg(SenderSession,Action,StampTime,Receivers,MsgID,Content,MsgTime)->
	#session{userid =SenderUserID ,selfpid=Pid}=SenderSession,
	emipian_msg_log:save_userreceiver
       (MsgID, SenderUserID,?CHATSTATUS_ONLY_REC,
	    SenderUserID,MsgTime,{},?CHATSTYPE_DIRECTREPLY),
	mod_srv_directreplychat:processsrv
	   (SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime}),
	ok.

sendmsg_to_user(SenderSession, MsgID, Content, MsgTime, ReceiveUserID, 
				UserAddtionInfo,AddtionInfo)->
    #session{userid = SenderUserID,usertype=UserType,sessionid=SessionID } = SenderSession,
   Status = if 
             SenderUserID=:=ReceiveUserID ->?CHATSTATUS_SELF;
             true ->?CHATSTATUS_NOT_SEND
           end, 	
  case save_userreceiver(MsgID,ReceiveUserID,Status,SenderUserID,MsgTime,UserAddtionInfo,?CHATSTYPE_DIRECTREPLY) of
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
      ?INFO_MSG("mod_action_groupchat Send:Msgid:~p,userid:~p,SelfPid:~p,Status:~p,SessionID:~p ~n", [MsgID,UserID,PID,Status,SessionID]),
  
	   if 
		 Status =:=?STATUS_ONLINE ->
		 try	 
           PID ! {msg,?AC_SC_DRIECTREPLYCHAT,MsgID,SynNo,Data}
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
     PID ! {msg,?AC_SC_DRIECTREPLYCHAT,MsgID,SynNo,Data}
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

  <<MsgID1:40/binary,SynNo:32/little,MsgTime:64/little, 
	ChatObj:8/little,ContentLength:32/little, 
	Content:ContentLength/binary>>. 
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
		  <<ContentLen:32/little,Content/binary>>	 =  Rest10,
		  Len2 = byte_size(Content),
		   if 
			   Len2 =/= ContentLen ->cmderror;
		       true->
		        {ok,StampTime,ReceiverLen,Receivers,ContentLen,Content}
		   end
     end.


get_resultparam(Action,Code,StampTime,MsgID,MsgTime,CompanyID,AddtionInfo)->

	MsgID1 = emipian_util:str_to_binayid(MsgID),
   Return = {?AC_SC_DRIECTREPLYCHAT_R,Code,<<StampTime:64/little,MsgID1/binary,MsgTime:64/little>>},
   ToDataBase = 	
   if
	 Code=:=0 ->
   	 {action,?AC_SC_DRIECTREPLYCHAT_R,code,Code,companyid,CompanyID,addtioninfo,AddtionInfo};
   	 true->{action,?AC_SC_DRIECTREPLYCHAT_R,code,Code}
   end,
   {Return,ToDataBase}.
