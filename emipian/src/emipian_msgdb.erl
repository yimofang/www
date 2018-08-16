%% @author hyf
%% @doc @todo Add description to emipian_msgdb.


-module(emipian_msgdb).
-include("session.hrl").
-include("errorcode.hrl").
-include("macro.hrl").
-include("logger.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([save_msg_log/5
		,save_msg_log/4
		,save_userreceiver/7
		,find_samemsg/3,
		 get_msgtime/1

	%%	,update_login_result/3
		,update_msg_result/3
		,save_terminalreceiver/4
		,update_user_receivestatus/2
		,update_terminal_receivestatus/2
		,cancel_terminal_receive/1
		,find_ternimal_no_sendmsg/3
		,find_user_no_sendmsg/3
		,find_user_no_sendmsg_special/3
		,getfieldvalue/2
		,get_sendmsg/1
		,update_log_status_user/2
		,update_log_status_terminal/2
		,get_user_addtioninfo/2
		,search_user_orgmsg/7
		,search_user_singlemsg/7
		,find_sys_sendmsg/3
		,getconnection/0
		,disconnection/1
		,get_dialinfo/1
		,save_dial_meeting/12
		,update_dialinfo/2
		,update_dialinfo/4
		,find_no_sendtel/1
		,find_no_timeouttel/0
         , get_dailmsg/1
		,get_receiverstatus/1
       ,save_client_chatroom/4
       ,get_chatroom_online/2
       ,clear_chat_session/2
	   ,get_chatroom_user_nickname/1
	   ,update_client_chatroom/1
		,get_invalide_chatroom_client/1	
		,chatroom_user_online/2	
       ,get_chatroom_chat/2		
		,delete_chatroom_chat/2
		,clear_chat_session/0
        ,get_chatroom_from_sessionid/1
		,online_session/2
				]).



%% ====================================================================
%% Internal functions
%% ====================================================================

getconnection() ->
  Result = poolboy:checkout(mongodb_1),
  Result.
  
%% case mongo:connect("127.0.0.1", 27017, <<"emipian">>, safe, master, []) of
%%   {ok, Connection}-> Connection;
%%   _->error
%%  end.
disconnection(Connection)->
  case Connection of
     fail->ok;	
     full->ok;  
     _->poolboy:checkin(mongodb_1,Connection)
  end.	  
%%	 gen_server:call(Connection, {stop,1}).

save_msg_log(MsgID,SenderSession,Action,Param,Status) ->	
  Connection =getconnection(),
  try
  	#session{sessionid=SessionID,userid=UserID,usertype=UserType,appos=AppOS,appcode=AppCode,
    customcode=Customcode,termialno=TemrialNo,lang=Lang,version=Version,s_peerip=IP1} = SenderSession,	
 
    Sendtime  = os:timestamp() ,%% list_to_binary(Sendtime2),

  %%   "b" : {
 %%   "$date" : 1425291039977
 %5 }
 
    OneMsg = {msgid,MsgID,action,Action, sessionid,SessionID,status,Status
			 ,senderinfo,{userid,UserID,usertype,UserType,appos,AppOS,appcode,AppCode
                         ,customcode,Customcode,termialno,TemrialNo,lang,Lang
						 ,version,Version
						 ,peerip, IP1
						
						 }
			 ,param,Param
	         ,sendtime,Sendtime	,status,Status

			},
	
     DataName = 
      if  
         Action >31000,Action <32000 ->
                <<"tblmsgchat">>;
         Action >70000,Action <71999 ->
                <<"tblmsgchat">>;
         true-><<"tblmsglog">>
      end,
            
     mongo:insert(Connection, DataName, OneMsg)
   after
     disconnection(Connection)
   end.

save_msg_log(MsgID,SenderSession,Action,Param) ->	
 save_msg_log(MsgID,SenderSession,Action,Param,?CHATSTATUS_NOT_SEND).

update_msg_result(Action,MsgID,ResultParam)->
	Connection =getconnection(),

   try
      Command = {'$set', {result,ResultParam}},
     DataName = 
      if  
         Action >31000,Action <32000 ->
                <<"tblmsgchat">>;
         Action >70000,Action <71999 ->
                <<"tblmsgchat">>;
         true-><<"tblmsglog">>
      end,
		  mongo:update(Connection,DataName, {msgid,MsgID},Command),
	  ok
    after
		disconnection(Connection)
    end.

  
%%diconnection()->
%%	mongo:unc
  
%% ====================================================================
%% save_msg_log(MsgID,SenderSession,Action,Param,Valitime) ->	
%%  {ok, Connection} = mongo:connect("127.0.0.1", 27017, <<"emipian">>, safe, master, []),
%%  {sessionid=SessionID,userid=UserID,usertype=UserType,appos=AppOS,appcode=AppCode,
%%   customcode=Customcode,termialno=TemrialNo,lang=Lang,version=Version,peerip=IP} = SenderSession,	
%%   Sendtime = os:timestamp(),
%%   OneMsg = {msgid,MsgID,action,Action, sessionid,SessionID
%%			 ,senderinfo,{userid,UserID,usertype,UserType,appos,AppOS,appcode,AppCode
%%                         ,customcode,Customcode,termialno,TemrialNo,lang,Lang,version
%%						 ,Version,peerip,IP}
%%			 ,param,Param
%%	         ,sendtime,Sendtime	
%%			 ,validtime,Valitime
%%			},
 %%    mongo:insert(Connection, <<"tblmsglog">>, OneMsg).
%% ====================================================================

		  
save_userreceiver(MsgID,UserID,Status,SenderUserID,MsgTime,UserAddtionInfo,Type) -> 
	  Connection = getconnection(),
	  try
	    case mongo:find_one(Connection,  <<"tbluserreceiver">>, {msgid,MsgID,userid,UserID}) of
		  {}->
			  case mongo:find_one(Connection, <<"tblusermaxrevid">>, {userid,UserID}) of
				  {}->
					   NewID=1,
		        	   mongo:insert(Connection, <<"tblusermaxrevid">>, {userid,UserID,maxrecvid,1});
				  {Data}->
					  {ID} = bson:lookup(maxrecvid,  Data),
					  NewID = ID+1,
                      Command = {'$set', {maxrecvid, NewID}},
					  mongo:update(Connection, <<"tblusermaxrevid">>, {userid,UserID},Command) 
			   end,
              Command1 = {'$set', {addtioninfo,UserAddtionInfo}},
			  mongo:update(Connection, <<"tbluserreceiver">>, {msgid, MsgID,status,3},Command1), 
			  mongo:insert(Connection, <<"tbluserreceiver">>, 
							{msgid,MsgID,userid,UserID,recvid,NewID,status,Status,
							 senderuserid,SenderUserID,sendtime,os:timestamp(),msgtime,MsgTime,addtioninfo,UserAddtionInfo,type,Type}),
		      {ok,NewID};
		 
		  {Data}->	
			  {NewID} = bson:lookup(recvid,  Data),
		      {duplicate,NewID} 
	    end
	  after
		disconnection(Connection)
	  end.  
		  

get_msgtime(MsgID)->
   Connection =getconnection(),
   try
	   case mongo:find_one(Connection,  <<"tblmsgchat">>, {msgid,MsgID}) of
	   {}->   0; 
	   {Data} ->
		   {MsgTime} = bson:lookup(sendtime, Data),
		   
		   emipian_util:get_mstime(MsgTime)
	   end
   after
	  disconnection(Connection)
   end.	   


%% ====================================================================
%% Find the same msg
%% return
%% {yes,MsgID,Result} |no
%%
%% ====================================================================
find_samemsg(MsgID,UserID,StampTime)->
   Connection =getconnection(),
   try
	  WhereCmd = {msgid,{'$ne',MsgID}, 'senderinfo.userid',UserID,
				  'param.stamptime',StampTime,result,{'$exists',true },
                  
				  'result.code',{'$ne',?EC_DUPCMD }},
	 case mongo:find_one(Connection, <<"tblmsgchat">>, WhereCmd) of
	    {}->no;
        {Data} ->
			{Result} = bson:lookup(result, Data),
			{Action} = bson:lookup(action, Data),

			{MsgID1}  = bson:lookup(msgid, Data),
            {SendTime} = bson:lookup(sendtime, Data),
			{yes,MsgID1,StampTime,Action,Result,SendTime}
	end
  after
	  disconnection(Connection)
  end.	 

save_terminalreceiver(MsgID,RevID,ReceiverSession,Retry) ->
  Connection =getconnection(),
  try
  	#session{sessionid=SessionID,userid=UserID,usertype=UserType,appos=AppOS,appcode=AppCode,
    customcode=Customcode,termialno=TemrialNo,lang=Lang,version=Version,s_peerip=IP1}
    = ReceiverSession,
  	Sendtime =os:timestamp(),  
    case mongo:find_one(Connection,  <<"tblternimalreceiver">>, {msgid,MsgID,sessionid,SessionID}) of
	     {}->
	         Sendtimes = [Sendtime],
	         OneMsg = {msgid,MsgID,sessionid,SessionID,status,?CHATSTATUS_NOT_SEND,recvid,RevID
				 ,receiverinfo,{userid,UserID,usertype,UserType,appos,AppOS,
								appcode,AppCode
	                         ,customcode,Customcode,termialno,TemrialNo,
								lang,Lang
							 ,version,Version
							 ,peerip, IP1
							 }
				 ,lastsendtime,Sendtime
		         ,sendtimes,Sendtimes	
				},
              mongo:insert(Connection, <<"tblternimalreceiver">>, OneMsg),
              ok; 
	     {Data}->
		   if
			  Retry=:=yes ->

		       Command = {'$set', {lastsendtime,Sendtime},'$addToSet',{sendtimes,Sendtime}},
		        mongo:update(Connection, <<"tblternimalreceiver">>,
					   {msgid,MsgID,'receiverinfo.userid',UserID},Command);
			  true->ok
            end, 
		    duplicate
     end	
    after
	   disconnection(Connection)		
	end. 	
 
 

cancel_terminal_receive(SessionID) ->
  Connection = getconnection(),
  try
	  CancelTime = os:timestamp(),
	  Command = {'$set', {status,?CHATSTATUS_CANCEL,canceltime,CancelTime}},
	  WhereCmd ={'sessionid',SessionID,status,?CHATSTATUS_NOT_SEND},
	  mongo:update(Connection, <<"tblternimalreceiver">>,WhereCmd,Command,false,true)
  after
    disconnection(Connection)
  end.


update_log_status_user(MsgID,Status)->
 Connection = getconnection(),
 try
   Command = {'$set', {status,Status}},
   WhereCmd ={status,?CHATSTATUS_NOT_SEND,msgid,MsgID},
   mongo:update(Connection, <<"tbluserreceiver">>,WhereCmd,Command,false,true)
 after 
   disconnection(Connection)
 end.

 
update_user_receivestatus(RevID,UserID) ->
  Connection = getconnection(),
  try
	  Command = {'$set', {status,?CHATSTATUS_SENDED}},
	%%  WhereCmd ={userid,UserID,status,0,recvid,{'$lte',RevID}},
	  WhereCmd ={userid,UserID,status,?CHATSTATUS_NOT_SEND,recvid,RevID},
	  
	  mongo:update(Connection, <<"tbluserreceiver">>,WhereCmd,Command,false,true)
  after
     disconnection(Connection)
  end.

update_log_status_terminal(MsgID,Status)->
 Connection = getconnection(),
 try
	  Command = {'$set', {status,Status}},
	  WhereCmd ={status,?CHATSTATUS_NOT_SEND,msgid,MsgID},
	  mongo:update(Connection, <<"tblternimalreceiver">>,WhereCmd,Command,false,true)
 after
    disconnection(Connection)
 end.

update_terminal_receivestatus(RevID,SessionID) ->
  Connection = getconnection(),
  try
	  ReceiveTime = os:timestamp(),
	  Command = {'$set', {status,?CHATSTATUS_SENDED,receivetime,ReceiveTime}},
	  WhereCmd ={sessionid,SessionID,status,?CHATSTATUS_NOT_SEND,recvid,RevID},
	
	  %%  WhereCmd ={sessionid,SessionID,status,0,recvid,{'$lte',RevID}},
	  mongo:update(Connection, <<"tblternimalreceiver">>,WhereCmd,Command,false,true)
  after
     disconnection(Connection)
  end.


find_ternimal_no_sendmsg(SessionID,Skip,Limit) ->
  Connection = getconnection(),
  try
	  WhereCmd ={sessionid,SessionID,'$or',[{status,?CHATSTATUS_NOT_SEND},{status,?CHATSTATUS_CANCEL}]}, %%{'$sort',{recvid,-1}}},
	  Sort   ={recvid, 1},
	  
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblternimalreceiver">>, pipeline,
	      [
	        {'$match', WhereCmd},
	        {'$skip', Skip},		
	        {'$limit', Limit},
	        {'$sort', Sort}
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end.

search_user_orgmsg(UserID,GroupID,StartTime,EndTime,Type,Skip,Limit) ->
  Start = emipian_util:get_erlangtime(StartTime),	
  End = emipian_util:get_erlangtime(EndTime),	

  Connection = getconnection(),
  try
	  WhereCmd =
		  case {StartTime,EndTime} of 
		  {0,0} ->
		    {userid,UserID,'addtioninfo.orgid',GroupID,type,Type};
		  {StartTime,0} ->
		    {userid,UserID,'addtioninfo.orgid',GroupID,type,Type,sendtime,{'$gte',Start}};
		  {0,EndTime} ->
		    {userid,UserID,'addtioninfo.orgid',GroupID,type,Type,sendtime,{'$lte',End}};
		  {StartTime,EndTime} ->
		    {userid,UserID,'addtioninfo.orgid',GroupID,type ,Type,sendtime,{'$gte',Start,'$lte',End}}
          end,
 	  Sort   ={sendtime, -1},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tbluserreceiver">>, pipeline,
	      [
	        {'$match', WhereCmd},
	        {'$skip', Skip},		
	        {'$limit', Limit},
	        {'$sort', Sort}
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end.


search_user_singlemsg(UserID,SenderUserID,StartTime,EndTime,Type,Skip,Limit) ->
  Start = emipian_util:get_erlangtime(StartTime),	
  End = emipian_util:get_erlangtime(EndTime),	

  Connection = getconnection(),
  try
	  WhereCmd =
		  case {StartTime,EndTime} of 
		  {0,0} ->
			   {
				'$or', 
					   [
						{userid,UserID,senderuserid,SenderUserID, type,Type},
			            {userid,SenderUserID,senderuserid,UserID , type,Type}
				 
			           ]
					  
			   };

		  {StartTime,0} ->
			  
			   {
				'$or', 
					   [
						{userid,UserID,senderuserid,SenderUserID,sendtime,{'$gte',Start},  type,Type},
			            {userid,SenderUserID,senderuserid,UserID ,sendtime,{'$gte',Start},  type,Type}
				 
			           ]
					  
			   };
				  
		  {0,EndTime} ->
			   {
				'$or', 
					   [
						{userid,UserID,senderuserid,SenderUserID,sendtime,{'$lte',End}, type,Type},
			            {userid,SenderUserID,senderuserid,UserID ,sendtime,{'$lte',End},  type,Type}
				 
			           ]
					  
			   };
		  {StartTime,EndTime} ->
			   {
				'$or', 
					   [
						{userid,UserID,senderuserid,SenderUserID,sendtime,{'$gte',Start,'$lte',End}, type,Type},
			            {userid,SenderUserID,senderuserid,UserID ,sendtime,{'$gte',Start,'$lte',End}, type,Type}
				 
			           ]
					  
			   }

          end,
 	  Sort   ={sendtime, -1},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tbluserreceiver">>, pipeline,
	      [
	        {'$match', WhereCmd},

	        {'$skip', Skip},		
	        {'$limit', Limit},
	        {'$sort', Sort}			
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end.

get_user_addtioninfo(MsgID,UserID) ->
   Connection =getconnection(),
   WhereCmd ={userid,UserID,msgid,MsgID},
   try
	   case mongo:find_one(Connection,  <<"tbluserreceiver">>, WhereCmd) of
	   {}->   <<"">>; 
	   {Data} ->
		   {AddtionInfo} = bson:lookup(addtioninfo, Data),
            AddtionInfo
	   end
   after
	  disconnection(Connection)
   end.	   	


find_user_no_sendmsg(UserID,Skip,Limit) ->
 Connection = getconnection(),
 try
	  WhereCmd ={userid,UserID,status,?CHATSTATUS_NOT_SEND,type,{'$lte',?CHATSTYPE_MAX_LOGIN_SEND}},
	  Sort   ={recvid, 1},
	  
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tbluserreceiver">>, pipeline,
	      [
	        {'$match', WhereCmd},
	        {'$sort', Sort}
	      ]
		 }),  
	  Result
  after
     disconnection(Connection)
 end.

find_sys_sendmsg(Session,Skip,Limit) ->
	  #session{sessionid=SessionID,appcode = AppCode,appos =AppOS,userid=UserID,
				customcode=CustomCode
			  } = Session,	
 Connection = getconnection(),
 try
	 	   Currenttime  =emipian_util:get_curtimestamp(), %% os:timestamp(),
	    %% ?INFO_MSG("Currenttime ~p ~n", [Currenttime]),
	  WhereCmd ={action,{'$gt',71000,'$lt',73000}
				,status,?CHATSTATUS_NOT_SEND
				 
 			 ,'param.receivers.online',-1
			 ,'$or',[{'param.receivers.appcode',-1},{'param.receivers.appcode',AppCode}]	
			 ,'$or',[{'param.receivers.appos',-1},{'param.receivers.appos',AppOS}]
			 ,'$or',[{'param.receivers.customcode',-1},{'param.receivers.customcode',CustomCode}]
			 ,'$or',[{'param.endtime',0},{'param.endtime',{'$gt',Currenttime}}]
				
			 ,'$or',[{'param.starttime',0},{'param.starttime',{'$lt',Currenttime}}]
				},
	  Sort   ={sendtime, 1},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblmsgchat">>, pipeline,
	      [
	        {'$match', WhereCmd},
	     %%   {'$limit', Limit},
	     %%   {'$skip', Skip},
	        {'$sort', Sort}
						
	      ]
		 }),  
	  Result
  after
     disconnection(Connection)
 end.
getfieldvalue(Data,FieldName) ->
   case bson:lookup(FieldName, Data) of
	 {}->not_found;
  	 {Value} ->Value
	end.   
    
get_sendmsg(MsgID) ->
  Connection = getconnection(),
  try
	case mongo:find_one(Connection,  <<"tblmsgchat">>, {msgid,MsgID}) of
		{} ->
			not_found;
		{Value} ->
			Value
	end
 after
   disconnection(Connection)
 end.	
find_user_no_sendmsg_special(Session,Skip,Limit) ->
 [].



save_dial_meeting(MsgID,Action,SenderSessionID,SenderUserID,ReceiverUserID,ReceiverSessionID,
 StampTime,Timeout,Status,AddtionJson,SenderCardID,Sender101) ->
  SendTime  = os:timestamp() ,
  ValidTime = emipian_util:addtime(SendTime, Timeout),
  Connection =getconnection(),
 
  try
    Sendtime  = os:timestamp() ,%% list_to_binary(Sendtime2),
    OneMsg = {msgid,MsgID,action,Action, sendersessionid,SenderSessionID,senderuserid,SenderUserID,
              receiveruserid,ReceiverUserID,
			  receiversessionid,ReceiverSessionID,
			  status,Status,
              stamptime,StampTime,sendtime,SendTime,
              validtime,ValidTime,lasttime,SendTime,addtionjson,AddtionJson,
			  sendercardid,SenderCardID,sender101,Sender101
			},
     mongo:insert(Connection, <<"tbldialmeet">>, OneMsg)
   after
     disconnection(Connection)
  end.	

update_dialinfo(MsgID,Data) when is_integer(Data)-> 
    Command = {'$set', {status,Data}},
	Connection =getconnection(),
   try
 	  mongo:update(Connection,<<"tbldialmeet">>, {msgid,MsgID},Command),
	  ok
    after
		disconnection(Connection)
    end;

update_dialinfo(MsgID,Data) ->
    Command = {'$set', {receiversessionid,Data}},
	Connection =getconnection(),
   try
 	  mongo:update(Connection,<<"tbldialmeet">>, {msgid,MsgID},Command),
	  ok
    after
		disconnection(Connection)
    end.

update_dialinfo(MsgID,Status,MeetingID,MeetingPass) ->
  Command = {'$set', {status,Status,meetingid,MeetingID,meetingpass,MeetingPass}},
	Connection =getconnection(),
   try
 	  mongo:update(Connection,<<"tbldialmeet">>, {msgid,MsgID},Command),
	  ok
    after
		disconnection(Connection)
    end.
get_dialinfo(MsgID) ->
  Connection = getconnection(),
  try
	case mongo:find_one(Connection,  <<"tbldialmeet">>, {msgid,MsgID}) of
		{} ->
			not_found;
		{Value} ->
			Value
	end
 after
   disconnection(Connection)
 end.	


find_no_sendtel(UserID)->

Connection = getconnection(),
  try
	  WhereCmd ={receiveruserid,UserID,status,?DAIL_STATUS_INIT},
	  Sort   ={sendtime, 1},
	  
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tbldialmeet">>, pipeline,
	      [
	        {'$match', WhereCmd},
	        {'$sort', Sort}
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end. 	


find_no_timeouttel()->

Connection = getconnection(),
  try
	  WhereCmd ={status,{'$gte',?DAIL_STATUS_INIT}},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tbldialmeet">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end. 	

get_dailmsg(MsgID) ->
  Connection = getconnection(),
  try
	case mongo:find_one(Connection,  <<"tbldialmeet">>, {msgid,MsgID}) of
		{} ->
			not_found;
		{Value} ->
			Value
	end
 after
   disconnection(Connection)
 end.	


get_receiverstatus(UserID) ->
 Connection = getconnection(),
 try
	  Currenttime  = os:timestamp(),
	  WhereCmd ={'$or',[{senderuserid,UserID,'$or',[{status,{'$gte',30}}]}, %% ,{status,0}
				        {receiveruserid,UserID,'$or',[{status,{'$gte',30}}]}]	%% ,{status,0}	
				},
	  Sort   ={sendtime, 1},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tbldialmeet">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	  if 
		  length(Result)=:=0 ->0;
					      true->1 
	  end						   
  after
     disconnection(Connection)
 end.

clear_chat_session(SessionID,UserID,ChatRoomNo) ->
   Connection = emipian_msgdb:getconnection(),
   try
       mongo:delete(Connection, <<"tblchatroom">>,  {userid,UserID,chatroomno,ChatRoomNo})
   after
	 emipian_msgdb:disconnection(Connection)
   end.

clear_chat_session(SessionID,ChatRoomNo) ->
   Connection = emipian_msgdb:getconnection(),
   try
       mongo:delete(Connection, <<"tblchatroom">>,  {sessionid,SessionID,chatroomno,ChatRoomNo})
   after
	 emipian_msgdb:disconnection(Connection)
   end.

clear_chat_session() ->
   Connection = emipian_msgdb:getconnection(),
   try
       mongo:delete(Connection, <<"tblchatroom">>,  {})
   after
	 emipian_msgdb:disconnection(Connection)
   end.


save_client_chatroom(SessionID,UserID,NickName,ChatRoomNo) ->
 Connection =getconnection(),
  try
 
    clear_chat_session(SessionID,UserID,ChatRoomNo),    
    Entertime  = os:timestamp() ,%% list_to_binary(Sendtime2),
    OneMsg = {sessionid,SessionID,userid,UserID,nickname,NickName,chatroomno
			 ,ChatRoomNo,status,0,entertime,Entertime,exittime,Entertime},
	
     DataName = <<"tblchatroom">>,
            
     mongo:insert(Connection, DataName, OneMsg)
   after
     disconnection(Connection)
   end.



update_client_chatroom(Session) ->
 #session{sessionid =SessionID} = Session,
 Connection =getconnection(),
  try
    Exittime  = os:timestamp() ,%% list_to_binary(Sendtime2),
    
	Command = {'$set',{status,100,exittime,Exittime}},
	

	
     DataName = <<"tblchatroom">>,
     mongo:update(Connection,DataName, {sessionid,SessionID},Command)
   after
     disconnection(Connection)
   end.


get_chatroom_online(SessionID,ChatRoomNo) ->
 Connection = getconnection(),
  try
	   WhereCmd ={chatroomno,ChatRoomNo,sessionid,{'$ne',SessionID}},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblchatroom">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end. 	

get_chatroom_from_sessionid(SessionID) ->
 Connection = getconnection(),
  try
	   WhereCmd ={sessionid,SessionID},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblchatroom">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end.

get_chatroom_user_nickname(SessionID) ->
 %%	  #session{sessionid =SessionID} = Session,	
 Connection = getconnection(),
  try
	case mongo:find_one(Connection,  <<"tblchatroom">>, {sessionid,SessionID}) of
		{} ->
		not_found;
	{Value} -> 
		  {NickName} = bson:lookup(nickname,  Value),
		  NickName
   end	 
  after
     disconnection(Connection)
  end. 	


chatroom_user_online(UserID,ChatRoomNo) ->
 Connection = getconnection(),
  try
    case mongo:find_one(Connection,  <<"tblchatroom">>, {userid,UserID,chatroomno,ChatRoomNo}) of
        {} -> not_found;
	    {Data}->found
		end
  after
     disconnection(Connection)
  end. 	
clear1_chatroom(Timeout) ->
   Currenttime  = emipian_util:subtracttime(os:timestamp(),Timeout),
   Connection = emipian_msgdb:getconnection(),
   try
	   
      mongo:delete(Connection, <<"tblchatroom">>,  {status,100,exittime,{'$lt',Currenttime}})
   after
	 emipian_msgdb:disconnection(Connection)
   end.


get_invalide_chatroom_client(Timeout) ->
   Currenttime  = emipian_util:subtracttime(os:timestamp(),Timeout),
   Connection = emipian_msgdb:getconnection(),
   try
	   WhereCmd ={status,100,exittime,{'$lt',Currenttime}},  
	    case mongo:find_one(Connection,  <<"tblchatroom">>, WhereCmd) of
        {} -> not_found;
			{Data}->Data
		end
%%	 delete_chatroom_chat(Connection,Result) 					 
   after
	 emipian_msgdb:disconnection(Connection)
   end.




 delete_chatroom_chat(SessionID,ChatRoomNo)->
 %%  {SessionID} = bson:lookup(sessionid,  H),
 %%  {ChatRoomNo} = bson:lookup(chatroomno,  H),
   Command = {'$set', {status,10}},
   Connection = emipian_msgdb:getconnection(),
   try 
      mongo:update(Connection, <<"tbluserreceiver">>,
					   {'addtioninfo.chatroomno',ChatRoomNo,'addtioninfo.sessionid',SessionID,type,?CHATSTYPE_CHATROOM,status,0},Command)
  after
	 emipian_msgdb:disconnection(Connection)
   end.

get_chatroom_chat(UserID,ChatRoomNo) ->
 Connection = getconnection(),
  try
	   WhereCmd ={'addtioninfo.chatroomno',ChatRoomNo,userid,UserID,type,?CHATSTYPE_CHATROOM,status,0},
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tbluserreceiver">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	 Result
  after
     disconnection(Connection)
  end. 	

online_session(SessionID,ChatRoomNo)->
   Connection = getconnection(),
  try
    case mongo:find_one(Connection,  <<"tblchatroom">>, {sessionid,SessionID,chatroomno,ChatRoomNo}) of
        {} -> not_found;
	    {Data}->found
		end
  after
     disconnection(Connection)
  end. 	


%% delete_chatroom_chat(Connection,T).