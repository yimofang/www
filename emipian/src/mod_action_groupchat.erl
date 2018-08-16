%% @doc @todo Add description to mod_action_groupchat.


-module(mod_action_groupchat).

-include("session.hrl").
-include("errorcode.hrl").
-include( "action.hrl").
-include("macro.hrl").
-include("logger.hrl").

-define(AC_CS_GROUPCHAT, 31002).
-define(AC_SC_GROUPCHAT_R, 61002).
 
-define(AC_SC_GROUPCHAT, 21002).


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
		  sendmsg_to_user/8
		 ,get_resultparam/7
		]).



process_action(MsgID,Session,Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,ReceiverLen,Receivers,GroupID,Level,CompanyID,_,Content}->
		 #session{userid=SenderUserID,appcode =AppCode,usertype=UserType} = Session,	 
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
			  send_msg(Session,Action,StampTime,GroupID,Receivers1,Level,MsgID,Content,MsgTime,CompanyID),
              {waitmsg};
             _->
			  {Reuslt,ToDataBase} = get_resultparam(Action,?EC_CMDERROR,StampTime,MsgID,MsgTime,<<"">>,{}),	
		      {ok,Reuslt,ToDataBase}
           end
	  end.
	
 get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	   {ok,StampTime,ReceiverLen,Receivers,GroupID,Level,CompanyID,ContentLen,Content}->
	   {stamptime,StampTime,receiverlen,ReceiverLen,receivers,Receivers,contentlen,
        ContentLen,content,Content,groupid,GroupID,companyid,CompanyID}
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

    {ok,{?AC_SC_GROUPCHAT_R,Code,ReParam}}.

sendmsg_to_terminal(Action,MsgID,SynNo,Param,Session,SenderUserID,MsgTime,ChatObj,AddtionInfo)->
	#session{userid =ReceiverUserID,usertype =UserType} = Session,
	Content = emipian_util:lookuprecordvalue(content, Param),
%%	ChatObj =1,
	CompanyID = emipian_util:lookuprecordvalue(companyid, AddtionInfo),
	UserAddtionInfo = emipian_msg_log:get_user_addtioninfo(MsgID, ReceiverUserID),
	Data =  get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,
									ChatObj,MsgTime,CompanyID,UserAddtionInfo,AddtionInfo),
  	  sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content).

   

%% ====================================================================
%% Internal functions
%% ====================================================================
 
  


send_msg(SenderSession,Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID)->
	#session{userid =SenderUserID ,selfpid=Pid}=SenderSession,
	emipian_msg_log:save_userreceiver(MsgID, SenderUserID,?CHATSTATUS_ONLY_REC,SenderUserID,MsgTime,{},?CHATSTYPE_GROUP),
	emipian_srv_groupchat:processsrv
	   (SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID}),
	ok.

sendmsg_to_user(SenderSession, MsgID, Content, MsgTime, ReceiveUserID, 
				CompanyID,UserAddtionInfo,AddtionInfo)->
    #session{userid = SenderUserID,usertype=UserType,sessionid=SessionID } = SenderSession,
   Status = if 
             SenderUserID=:=ReceiveUserID ->?CHATSTATUS_SELF;
             true ->?CHATSTATUS_NOT_SEND
           end, 	
  case save_userreceiver(MsgID,ReceiveUserID,Status,SenderUserID,MsgTime,UserAddtionInfo,?CHATSTYPE_GROUP) of
	  {duplicate,_}->ok;
	  {ok,SynNo} ->
		ChatObj =1,
		Data =  get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,
									ChatObj,MsgTime,CompanyID,UserAddtionInfo,AddtionInfo),
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
         emipian_route:sendmsg(Session,{msg,?AC_SC_GROUPCHAT,MsgID,SynNo,Data});

           true->ok
     end,
    case Content of
	 no ->ok;	
     _-> 
	SenderNickName = 
     try
	 emipian_util:lookuprecordvalue(nickname, AddtionInfo)
	 catch
       _:_-><<"">>
     end,			 
        emipian_apns:sendapns(Session,getAPNSData(Content),SenderUserID,SenderNickName)
    end.
	 

sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content)->
     #session{selfpid=PID,status =Status} = Session,
	 try
     PID ! {msg,?AC_SC_GROUPCHAT,MsgID,SynNo,Data}
     catch
		_:_->ok 
	 end.	 

getAPNSData(Content)
  ->Content.


get_sendmessagedata(MsgID,SenderUserID,UserType,Content,SynNo,ChatObj,MsgTime,CompanyID,
					UserAddtionInfo,AddtionInfo)->
  ContentLength = byte_size(Content),
  MsgID1 = emipian_util:str_to_binayid(MsgID),
  SenderUserID1 = emipian_util:str_to_binayid(SenderUserID),
  CompanyID1   =  emipian_util:str_to_binayid(CompanyID),
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
	CompanyID1:40/binary,AddtionInfoSize:32/little,AddtionInfoJson:AddtionInfoSize/binary>>. 
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
			   Len2 =/= ContentLen+81 ->cmderror;
		       true->
				<<Content:ContentLen/binary,GroupID:40/binary,Level:8/little,CompanyID/binary>> = Rest2,
		        {ok,StampTime,ReceiverLen,Receivers,emipian_util:binary_to_str(GroupID),Level
                ,emipian_util:binary_to_str(CompanyID),ContentLen,Content}
		   end
     end.


get_resultparam(Action,Code,StampTime,MsgID,MsgTime,CompanyID,AddtionInfo)->

	MsgID1 = emipian_util:str_to_binayid(MsgID),
   Return = {?AC_SC_GROUPCHAT_R,Code,<<StampTime:64/little,MsgID1/binary,MsgTime:64/little>>},
   ToDataBase = 	
   if
	 Code=:=0 ->
   	 {action,?AC_SC_GROUPCHAT_R,code,Code,companyid,CompanyID,addtioninfo,AddtionInfo};
   	 true->{action,?AC_SC_GROUPCHAT_R,code,Code}
   end,
   {Return,ToDataBase}.


getaddtionjson(UserAddtionInfo,AddtionInfo,UserType) ->

	NickName = emipian_util:lookuprecordvalue(nickname, AddtionInfo), 
    GroupName   =
	  case emipian_util:lookuprecordvalue(orgname, UserAddtionInfo) of
			not_found -><<"">>;
		    Name ->Name
	  end,	
     	
    GroupType   =
	  case emipian_util:lookuprecordvalue(grouptype, UserAddtionInfo) of
			not_found ->0;
		    Type ->Type
	  end,	

   OwnerUserID   =
	  case emipian_util:lookuprecordvalue(owneruserid, UserAddtionInfo) of
			not_found -><<"">>;
		    OwnerID ->OwnerID
	  end,	
	Dict = dict:new(),
	Dict1 = 
	  dict:store("nickname", NickName,Dict),
	


	Dict4 = 
	  dict:store("groupname", GroupName,Dict1),
	Dict5 = 
	  dict:store("grouptype", GroupType,Dict4),
%%	Dict6 = 
%%	  dict:store("owneruserid", OwnerUserID,Dict5),

	  list_to_binary(rfc4627:encode(Dict5)).
