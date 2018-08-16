%% @author hyf
%% @doc @todo Add description to mod_action_companysinglechat.


-module(mod_action_companysinglechat).

 
-include("session.hrl").
-include("errorcode.hrl").
-include("action.hrl").
-include("logger.hrl").
-include("macro.hrl").
-define(AC_CS_COMPANYSINGLECHAT, 31004).
-define(AC_CS_COMPANYSINGLECHAT_R, 61004).
 
-define(AC_SC_COMPANYSINGLECHAT, 21007).

-define(CMDMINLEN, 20).




%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_sendfields_fromparam/2
		 ,get_msgstamptime/1
		]).

-export([
		 sendmsg_to_terminal/9
		 ,get_sendparam_fromfields/5
		]).

%% ====================================================================
%% Internal functions
%% ====================================================================


%% ====================================================================
%% Must implement API or action
%% return
%% {ok/terminate/resume/noresult,Data}
%% Data ={Action,Code,Param,Addition} || {Code,Action,Param}
%%
%% Addition ={}
%%
%%
%% ====================================================================

process_action(MsgID,Session,_Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,ReceiverLen,Receivers,_,Content,CompanyID}->
		 #session{sessionid=SessionID,userid=SenderUserID,appcode =AppCode} = Session,	 
         MsgTime = emipian_msg_log:get_msgtime(MsgID),
		 if ReceiverLen>0
			 -> 
		  case rfc4627:decode(Receivers) of
			 {ok,Receivers1,_} -> 
		      {FailReceivers,SMSReceivers,SucessInfos} = 
				  sendmsg_to_users(SessionID,AppCode,MsgID,SenderUserID,Content,0,MsgTime,
								   Receivers1,CompanyID,[],[],[]),
			  {Reuslt,ToDataBase} = get_resultparam(?AC_CS_COMPANYSINGLECHAT,?EC_SUCCESS,StampTime,MsgID,MsgTime,
										FailReceivers,SMSReceivers,SucessInfos),
		      {ok,Reuslt,ToDataBase};
             _->
			   {Reuslt,ToDataBase} = get_resultparam(?AC_CS_COMPANYSINGLECHAT,?EC_CMDERROR,StampTime,MsgID,MsgTime,[],[],[]),
			  {ok,Reuslt,ToDataBase}
           end;
		 true->
	          {Reuslt,ToDataBase} = get_resultparam(?AC_CS_COMPANYSINGLECHAT,?EC_CMDERROR,StampTime,MsgID,MsgTime,[],[],[]),
			  {ok,Reuslt,ToDataBase}
		end	
	  end.

get_sendparam_fromfields(_Action,StampTime,MsgID,SendTime,Result)->
		 ?INFO_MSG("get_sendparam_fromfields Result:~p~n.", [Result]),	 

	Code = emipian_util:lookuprecordvalue(code, Result),
    Param = emipian_util:lookuprecordvalue(param, Result),
	FailReceivers = emipian_util:lookuprecordvalue(failreceiver, Param),
	SMSReceivers = emipian_util:lookuprecordvalue(smsreceiver, Param),
	
	Sucessinfos = emipian_util:lookuprecordvalue(sucessinfo, Param),

	?INFO_MSG("get_sendparam_fromfields P,C,F,S:~p,~p,~p,~p~n.", [Param,Code,FailReceivers,SMSReceivers]),	 
	
    MsgID1 = emipian_util:str_to_binayid(MsgID),
    FSize = byte_size(FailReceivers),
    SSize = byte_size(SMSReceivers),
	InfoSize=byte_size(Sucessinfos), 	 
	SendTime0 = emipian_util:get_mstime(SendTime),
    ReParam = <<StampTime:64/little,MsgID1/binary,SendTime0:64/little,FSize:32/little,FailReceivers/binary,
	  SSize:32/little,SMSReceivers/binary,InfoSize:32/little,Sucessinfos/binary>>,
    {ok,{?AC_CS_COMPANYSINGLECHAT_R,Code,ReParam}}.

%% get Send record for save DB
  
get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	   {ok,StampTime,ReceiverLen,Receivers,ContentLen,Content,CompanyID}->
	   {stamptime,StampTime,receiverlen,ReceiverLen,receivers,Receivers,contentlen,ContentLen,content,Content,companyid,CompanyID}
     end.

get_msgstamptime(Param)->
	 Total = byte_size(Param), 
	 ?INFO_MSG("parse_action :~p-~p ~n.", [Total,Param]),	 
	 if
 	 Total<?CMDMINLEN ->cmderror;
	 true-> <<StampTime:64/little,_/binary>> = Param,
			{ok,StampTime}
	 end.
  
sendmsg_to_terminal(_Action,MsgID,SynNo,Param,Session,SenderUserID,MsgTime,ChatObj,_)->
   Content = emipian_util:lookuprecordvalue(content, Param),
   CompanyID = emipian_util:lookuprecordvalue(companyid, Param),

   #session{userid =ReceiverUserID} = Session, 
		 
	 UserAddtionInfo = emipian_msg_log:get_user_addtioninfo(MsgID, ReceiverUserID),
 	  Data =  get_sendmessagedata(MsgID,SenderUserID,Content,0,SynNo,ChatObj,MsgTime,CompanyID,UserAddtionInfo),
      sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,no).
%% ====================================================================
%% pasre param
%% return
%% {ok,ReceiverLen,Receivers,ContentLen,Content}|cmderror
%% 
%% 
%%
%%
%% ====================================================================

parse_param(Param)->
  Total = byte_size(Param),  
  if 
		Total<?CMDMINLEN ->cmderror;
		 true->
	          <<StampTime:64/little,_:32/little,ReceiverLen:32/little,Rest/binary>> = Param,
		      Len1 = byte_size(Rest),
			  if
				 Len1<ReceiverLen+4 -> cmderror;
				 true->
 		              <<Receivers:ReceiverLen/binary,ContentLen:32/little,Rest0/binary>> = Rest,
		              Len2 = byte_size(Rest0),
					  if 
						 Len2=/=ContentLen+40   -> cmderror;
						 true->
 		                     <<Content:ContentLen/binary,CompanyID/binary>> = Rest0,
							 
							 {ok,StampTime,ReceiverLen,Receivers,ContentLen,Content,emipian_util:binary_to_str(CompanyID)}
                       end
			  end		 
  end.

get_resultparam(Action,Code,StampTime,MsgID,MsgTime,FailedReceivers,SMReceivers,SucessInfos)->
   FLen = length(FailedReceivers),
   SLen = length(SMReceivers),
   SInfoLen = length(SucessInfos),

   FSize= if 
	   FLen>0 ->
		   SFailReceiver = list_to_binary(rfc4627:encode(FailedReceivers)),
		   byte_size(SFailReceiver);
		true->
			SFailReceiver = <<"">>,
			0   
	end,	   
    SSize= if 
	   SLen>0 ->
		   SSMReceiver = list_to_binary(rfc4627:encode(SMReceivers)),
		   byte_size(SSMReceiver);
		true->
			SSMReceiver = <<"">>,
			0   
	end,	
   
     SInfoSize= if 
	   SInfoLen>0 ->
		  SucessInfos1 =  lists:map(fun maptoobj/1, SucessInfos),
		   SSucessInfo = list_to_binary(rfc4627:encode(SucessInfos1)),
		   byte_size(SSucessInfo);
		true->
			SSucessInfo = <<"">>,
			0   
	end,	   
   
   MsgID1 = emipian_util:str_to_binayid(MsgID),
   Return = {?AC_CS_COMPANYSINGLECHAT_R,Code,<<StampTime:64/little,MsgID1/binary,MsgTime:64/little,FSize:32/little,SFailReceiver/binary,
	  SSize:32/little,SSMReceiver/binary,SInfoSize:32/little,SSucessInfo/binary>>},
   ToDataBase = 	
   if
	 Code=:=0 ->
   	 {action,?AC_CS_COMPANYSINGLECHAT_R,code,Code,param,{failreceiver,SFailReceiver,smsreceiver,SSMReceiver,sucessinfo,SSucessInfo}};
   	 true->{action,?AC_CS_COMPANYSINGLECHAT_R,code,Code}
   end, 
   {Return,ToDataBase}.
   




%% ====================================================================
%% 将接收者存到数据库中
%%
%% return
%% {ok,ReceiverLen,Receivers,ContentLen,Content}|cmderror

%% ====================================================================

save_userreceiver(MsgID,UserID,Status,SenderUserID,SendTime,UserAddtionInfo,Type)->
   emipian_msg_log:save_userreceiver(MsgID, UserID,Status,SenderUserID,SendTime,UserAddtionInfo,Type).	

%% ====================================================================
%% 组装发送数据
%% ====================================================================
 
get_sendmessagedata(MsgID,SenderUserID,Content,ChatType,SynNo,ChatObj,
					MsgTime,CompanyID,UserAddtionInfo)->
  ContentLength = byte_size(Content),
  MsgID1 = emipian_util:str_to_binayid(MsgID),
  SenderUserID1 = emipian_util:str_to_binayid(SenderUserID),
  CompanyID1  = emipian_util:str_to_binayid(CompanyID),

  if ChatObj=:=1 ->
   AddtionInfoJson = getaddtionjson(UserAddtionInfo),		

   AddtionInfoSize  = byte_size(AddtionInfoJson);
   true->
       AddtionInfoJson = <<"">>,		
       AddtionInfoSize  = byte_size(AddtionInfoJson)
   end,	
  <<MsgID1:40/binary,SynNo:32/little,ChatType:8/little,SenderUserID1:40/binary,MsgTime:64/little, 
	ChatObj:8/little,ContentLength:32/little, Content/binary,CompanyID1:40/binary,AddtionInfoSize:32/little,AddtionInfoJson/binary>>. 

sendmsg_to_user(SessionID,MsgID,SenderUserID,Content,ChatType,MsgTime,ReceiveUserID,CompanyID,UserAddtionInfo)->
  Status = if 
             SenderUserID=:=ReceiveUserID ->?CHATSTATUS_SELF;
             true ->?CHATSTATUS_NOT_SEND
           end,  

  case save_userreceiver(MsgID,ReceiveUserID,Status,SenderUserID,MsgTime,UserAddtionInfo,?CHATSTYPE_SINGLE) of
	 	  {duplicate,_}->ok;
	  {ok,SynNo} ->
		ChatObj =1,
		Data =  get_sendmessagedata(MsgID,SenderUserID,Content,ChatType,SynNo,ChatObj,MsgTime,CompanyID,UserAddtionInfo),
        Sessions =  emipian_sm:get_usersession(SessionID, ReceiveUserID),
	    sendmsg_to_terminals(MsgID,SynNo,SenderUserID,Sessions,Data,Content,UserAddtionInfo)
   end. 

sendmsg_to_terminals(_,_,_,[],_,_,_)
   ->ok;
sendmsg_to_terminals(MsgID,SynNo,SenderUserID,[Session|T],Data,Content,UserAddtionInfo)->
	 emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,yes),
     sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content,UserAddtionInfo),
     sendmsg_to_terminals(MsgID,SynNo,SenderUserID,T,Data,Content,UserAddtionInfo).

sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content,UserAddtionInfo)->
     #session{selfpid=PID,status =Status,sessionid =SessionID,userid=UserID} = Session,
      ?INFO_MSG("mod_action_companysinglechat Send:~p,SelfPid:~p,Status:~p,SessionID:~p ~n", [UserID,PID,Status,SessionID]),

	   if 
		 Status =:=?STATUS_ONLINE ->
   		  try	 
            PID ! {msg,?AC_SC_COMPANYSINGLECHAT,MsgID,SynNo,Data}
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
	 emipian_util:lookuprecordvalue(s101, UserAddtionInfo)
	 catch
       _:_-><<"">>
     end,			 
		 
        emipian_apns:sendapns(Session,getAPNSData(Content),SenderUserID,Sender101)
    end.
	 

sendmsg_to_terminalcx(MsgID,SynNo,_SenderUserID,Session,Data,_Content)->
     #session{selfpid=PID} = Session,
	 try
     PID ! {msg,?AC_SC_COMPANYSINGLECHAT,MsgID,SynNo,Data}
	 catch
		 _:_->ok 
	 end.
  
sendmsg_to_users(_,_,_,_,_,_,_,[],_,FailReceivers,SMReceivers,SucessInfos)->
	{FailReceivers,SMReceivers,SucessInfos};

sendmsg_to_users(SessionID,AppCode,MsgID,SenderUserID,Content,ChatType,MsgTime,
				 [Receiver|RestUsers],CompanyID,FailReceivers,SMReceivers,SucessInfos)->
	ReceiverUserInfo = emipian_mysqldb:getuserinfoforcompany(SenderUserID,Receiver,CompanyID, AppCode),
    if 
		  is_integer(ReceiverUserInfo) -> 
		  FailReceivers0 = FailReceivers++[Receiver],
   	      sendmsg_to_users (SessionID,AppCode,MsgID,SenderUserID,Content,ChatType,MsgTime,RestUsers,CompanyID,FailReceivers0,SMReceivers,SucessInfos);
		true->
		  {ReceiverUserID,ReceiverCardID,Receiver101,SenderCardID,Sender101} =ReceiverUserInfo,
		  UserAddtionInfo = {cardid,SenderCardID,s101,Sender101},
		  SucessInfo ={aid,Receiver,userid,ReceiverUserID,cardid,ReceiverCardID,s101,Receiver101},
		  SucessInfos1 = SucessInfos++[SucessInfo], 
          sendmsg_to_user(SessionID,MsgID,SenderUserID,Content,ChatType,MsgTime,ReceiverUserID,CompanyID,UserAddtionInfo),
	      sendmsg_to_users (SessionID,AppCode,MsgID,SenderUserID,Content,ChatType,MsgTime,RestUsers,CompanyID,FailReceivers,SMReceivers,SucessInfos1)
   end.
		 
getaddtionjson(UserAddtionInfo) ->

	CardID = emipian_util:lookuprecordvalue(cardid, UserAddtionInfo), 
	S101 = emipian_util:lookuprecordvalue(s101, UserAddtionInfo), 
	Dict = dict:new(),
	Dict1 =  dict:store("cardid", CardID,Dict),
	Dict2 = dict:store("s101", S101,Dict1),
    list_to_binary(rfc4627:encode(Dict2)).

maptoobj(N)->
	{obj,emipian_util:recordtojson(N)}.
  
getAPNSData(Content)
  ->Content.

