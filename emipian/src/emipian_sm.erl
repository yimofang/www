%% @author hyf
%% @doc @todo Add description to emipian_session.

 
-module(emipian_sm).

-include("emipian.hrl").
-include("logger.hrl").
-include("session.hrl").
-include("macro.hrl").
 
%% ====================================================================
%% API functions
%% ====================================================================
-export([
        open_session/2 
	    ,close_session/3
		,get_session/1
		,searchsameterminal/1
		,searchconditionterminal/1		
		,update_session/2
		,get_usersession/2
		,get_all_pids/0
		,cleanallsessionpid/0
		,delsessionpid/1
		,updatesessionstatus/2
		,update_termialno/2
]).



%% ====================================================================
%% Internal functions
%% 
%% ====================================================================


open_session(newsession,Session) ->

	SessionID =emipian_util:get_uuid() ,%% string:to_upper(uuid:to_string(uuid:uuid4())),
	SessionExtID =emipian_util:get_uuid() ,%% string:to_upper(uuid:to_string(uuid:uuid4())),


	Session1 = Session#session{sessionid = SessionID,sessionextid=SessionExtID},

	Connection =emipian_msgdb:getconnection(),
	
  try
    Session2 = getsessionfields(Session1),
	 MainPid = emipian_util:lookuprecordvalue(mainpid, Session2),
	 clean_mainpid(MainPid),
     DataName = <<"tblsession">>,
     mongo:insert(Connection, DataName, Session2),
	
	 {ok,Session1}
   after

	   emipian_msgdb:disconnection(Connection)
	
   end;


open_session(oldsession,Session) ->
   #session{sessionid = SessionID,selfpid=PeerPID}=Session,
  	  Connection = emipian_msgdb:getconnection(),
	  try
	    case mongo:find_one(Connection,  <<"tblsession">>, {sessionid,SessionID,status,{'$ne',?STATUS_DELETED}}) of
		  {}->  {no};
		  {Session1}->	
			  Session0 = getsessionrecord(Session1),
              Session2=Session0#session{selfpid = PeerPID},
			  Session3=			  getsessionfields(Session2),
    	      MainPid = emipian_util:lookuprecordvalue(mainpid, Session3),

  	          clean_mainpid(MainPid),
			  mongo:insert(Connection, <<"tblsession">>, Session3),
			   {ok,Session2}
			  end
	  after
		emipian_msgdb:disconnection(Connection)
	  end.  


backsession(Connection,Session) ->
	mongo:insert(Connection, <<"tblsessionbak">>, Session).
	
	
  
close_session(SessionID,Mainlink,Pid) ->
  if 	
	  Mainlink=:=0->close_session0(SessionID);
     true-> close_session1(SessionID,Pid)
   end.
 

close_session0(SessionID) ->
%%   emipian_msg_log:cancel_terminal_receive(SessionID),
   Connection = emipian_msgdb:getconnection(),
   try
	   case mongo:find_one(Connection,  <<"tblsession">>, {sessionid,SessionID}) of
	   {}->  {no};
		{Session1}->	
		  Session0 = getsessionrecord(Session1),
		  #session{selfpid = PeerPID,pids=Pids} = Session0,
	      stoplinkofsession(Pids),
%%          Command = {'$set', {status,?STATUS_DELETED},'$set', {mainpid,<<>>},'$set', {sidepids,[]}},	   
%%           mongo:update(Connection, <<"tblsession">>,
%%				   {sessionid,SessionID},Command)
		           mongo:delete_one(Connection, <<"tblsession">>,  {sessionid,SessionID}),
	              backsession(Connection,Session1)
	   end
   after
	 emipian_msgdb:disconnection(Connection)
   end.

close_session1(SessionID,Pid) ->
	
   Connection = emipian_msgdb:getconnection(),
   try	
	 case mongo:find_one(Connection,  <<"tblsession">>, {sessionid,SessionID,status,{'$ne',?STATUS_DELETED}}) of
		  {}->  {no};
		  {Session1}->	
			  Session0 = getsessionrecord(Session1),
			  #session{selfpid = PeerPID,pids=Pids} = Session0,
			  stoplinkofsession([Pid]),
			  BPid = pid_to_binary(Pid),
			  Command = {'$pull', {sidepids,BPid}},
			  mongo:update(Connection, <<"tblsession">>,
								   {sessionid,SessionID},Command)		   
    end
   after
	 emipian_msgdb:disconnection(Connection)
   end.

update_session(Session,MainLink)->
	#session{sessionid = SessionID,selfpid=Selfpid} =Session,
    Connection = emipian_msgdb:getconnection(),
    try	
		if 
		  MainLink=:=0 -> 	
			close_session0(SessionID),
			Session2 = getsessionfields(Session),
		    MainPid = emipian_util:lookuprecordvalue(mainpid, Session2),
	         clean_mainpid(MainPid),
		    mongo:insert(Connection, <<"tblsession">>, Session2);
 		   true->
  	        BPid = pid_to_binary(Selfpid),
	        Command = {'$addToSet', {sidepids,BPid}},
	        mongo:update(Connection, <<"tblsession">>,
						   {sessionid,SessionID},Command)		
		end
    after
	 emipian_msgdb:disconnection(Connection)
    end.


update_termialno(SessionID,TerminalNo) ->

    Connection = emipian_msgdb:getconnection(),
    try	

			      Command = {'$set', {termialno,TerminalNo}},
			      mongo:update(Connection, <<"tblsession">>,
								   {sessionid,SessionID},Command)		
    after
	 emipian_msgdb:disconnection(Connection)
    end.

stoplinkofsession([])
  ->ok;
stoplinkofsession([Pid|Pids])
  ->
  case Pid of
   not_found ->ok;
   _->
	  try 
	    Pid!{stop}
	   catch
		 _:_->ok  
	   end	   
  end,
  stoplinkofsession(Pids).
get_usersession(SessionID,UserID)->
  Connection = emipian_msgdb:getconnection(),
  try
	  WhereCmd ={sessionid,{'$ne',SessionID},userid,UserID,status,{'$ne',?STATUS_DELETED}}, 
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblsession">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
 	 lists:map(fun getsessionrecord/1, Result)
  after
     emipian_msgdb:disconnection(Connection)
  end.	
	

get_session(SessionID)->
  Connection = emipian_msgdb:getconnection(),
  try
    case mongo:find_one(Connection,  <<"tblsession">>, {sessionid,SessionID}) of
	  {}->  not_found;
	  {Session1}->	
		  getsessionrecord(Session1)
		  end
  after
	emipian_msgdb:disconnection(Connection)
  end. 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 寻找相同的终端
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

searchsameterminal(Session)
  ->
	  #session{sessionid=SessionID,appcode = AppCode,appos =AppOS,userid=UserID,
				customcode=CustomCode
			  } = Session,
  Connection = emipian_msgdb:getconnection(),
  try	  
	WhereCmd =   
		  if AppOS<?APPMOBILE_MAX->
			{userid,UserID,appcode,AppCode,appos,{'$lt',?APPMOBILE_MAX},sessionid,{'$ne',SessionID},status,{'$ne',?STATUS_DELETED}};
          true->
		    {userid,UserID,appcode,AppCode,appos,AppOS,sessionid,{'$ne',SessionID},status,{'$ne',?STATUS_DELETED}}
  	      end,
	    {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblsession">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	 	 lists:map(fun getsessionrecord/1, Result)
	
  after
	emipian_msgdb:disconnection(Connection)
  end. 

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 寻找符合条件的终端
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

searchconditionterminal({AppOs,CustomCode,AppCode})
  ->
   
	WhereCmd = 
	   case {AppOs,CustomCode,AppCode} of
	   {-1,-1,-1}->{status,{'$ne',?STATUS_DELETED}};
	   {AppOs,-1,-1}->
		   {appos,AppOs,status,{'$ne',?STATUS_DELETED}};
	   {-1,-1,AppCode}->
		   {appcode,AppCode,status,{'$ne',?STATUS_DELETED}};
	 	{-1,CustomCode,-1}->
		   {customcode,CustomCode,status,{'$ne',?STATUS_DELETED}};
	   {AppOs,CustomCode,-1}->
		   {appos,AppOs,customcode,CustomCode,status,{'$ne',?STATUS_DELETED}};
	 	{AppOs,-1,AppCode}->
		   {appos,AppOs,appcode,AppCode,status,{'$ne',?STATUS_DELETED}};
	 	{-1,CustomCode,AppCode}->
		   {customcode,CustomCode,appcode,AppCode,status,{'$ne',?STATUS_DELETED}};
	   
		{AppOs,CustomCode,AppCode}->
		   {appos,AppOs,customcode,CustomCode,appcode,AppCode,status,{'$ne',?STATUS_DELETED}}
	   
	   end,
      Connection = emipian_msgdb:getconnection(),
        try	  
	    {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblsession">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	 	
	 lists:map(fun getsessionrecord/1, Result)
   after
	emipian_msgdb:disconnection(Connection)
   end. 

get_all_pids() ->
 Connection = emipian_msgdb:getconnection(),
  try
	  WhereCmd ={}, 
	   {true, {result, Result}} = mongo:command(Connection,
	    {aggregate, <<"tblsession">>, pipeline,
	      [
	        {'$match', WhereCmd}
	      ]
		 }),  
	 lists:map(fun getsessionpid/1,Result)
  after
     emipian_msgdb:disconnection(Connection)
  end.	
 

getsessionfields(Session)->

 	#session{sessionid=SessionID,userid=UserID,usertype=UserType,appos=AppOS,appcode=AppCode,
    customcode=Customcode,termialno=TemrialNo,termialname=TermialName,lang=Lang,version=Version,s_peerip=IP1,
    selfpid=Pid,node=Node,logintime = LoginTime,authcodetime=AuthcodeTime,status=Status,
			 sessionextid = SessioneExtID} = Session,

		MainPid = pid_to_binary(Pid),
		
    Session1 ={sessionid,SessionID,userid,UserID,usertype,UserType,appos,AppOS,appcode,AppCode,
    customcode,Customcode,termialno,TemrialNo,termialname,TermialName,lang,Lang,version,Version,s_peerip,IP1,
			   mainpid,MainPid,node,Node,logintime,LoginTime,authcodetime,AuthcodeTime,sidepids,[]
			  ,status,Status,sessionextid,SessioneExtID
			  
			  },
		
    Session1.

getsessionrecord(Session) ->
  SessionID = emipian_util:lookuprecordvalue(sessionid, Session),
  UserID = emipian_util:lookuprecordvalue(userid, Session),
  UserType = emipian_util:lookuprecordvalue(usertype, Session),
  AppOS = emipian_util:lookuprecordvalue(appos, Session),
  AppCode = emipian_util:lookuprecordvalue(appcode, Session),
  Customcode = emipian_util:lookuprecordvalue(customcode, Session),
  TemrialNo = emipian_util:lookuprecordvalue(termialno, Session),
  Lang = emipian_util:lookuprecordvalue(lang, Session),
  Version = emipian_util:lookuprecordvalue(version, Session),
  IP1 = emipian_util:lookuprecordvalue(s_peerip, Session),
  MainPid = emipian_util:lookuprecordvalue(mainpid, Session),
  Node = emipian_util:lookuprecordvalue(node, Session),
  SidePids = emipian_util:lookuprecordvalue(sidepids, Session),
  AuthcodeTime = emipian_util:lookuprecordvalue(authcodetime, Session),
  LoginTime = emipian_util:lookuprecordvalue(logintime, Session),
  Status  =emipian_util:lookuprecordvalue(status, Session),
  TermialName  =
	  case emipian_util:lookuprecordvalue(termialname, Session) of
		   not_found-><<"">>;
	      Value1 ->Value1	  
	 end,	  

  
  SessioneExtID  =
	   case emipian_util:lookuprecordvalue(sessionextid, Session) of
		  not_found-><<"">>;
	      ID ->ID
	   end,
  
  Pid = 
	if  MainPid=:=not_found ->not_found;
	   true ->   binary_to_pid(MainPid)
    end,
  Pids = 
   if  SidePids=:=not_found ->[];
	   true ->  
       lists:map(fun binary_to_pid/1, SidePids)
   end,
  Session1 = #session{sessionid=SessionID,userid=UserID,usertype=UserType,appos=AppOS,appcode=AppCode,
  customcode=Customcode,termialno=TemrialNo,termialname=TermialName,lang=Lang,version=Version,s_peerip=IP1,selfpid=Pid,
					  node=Node,logintime = LoginTime,authcodetime=AuthcodeTime,pids=Pids,status=Status
					 ,sessionextid =SessioneExtID},
   Session1.


getsessionpid(Session) ->
  MainPid = emipian_util:lookuprecordvalue(mainpid, Session),
  Pid  = binary_to_pid(MainPid),
  Pid.

pid_to_binary(PID) when is_pid(PID)->
   list_to_binary(pid_to_list(PID));
pid_to_binary(PID) -><<>>.  

binary_to_pid(BPID) ->
   try list_to_pid(binary_to_list(BPID)) of
	   Pid ->Pid
   catch
	   _:_-> not_found
   end.

delsessionpid(Session)->
  #session{sessionid=SessionID,selfpid=Pid} = Session,
  BPid = pid_to_binary(Pid),

 Connection = emipian_msgdb:getconnection(),
   try
     Command = {'$pull', {sidepids,BPid}},	   
     mongo:update(Connection, <<"tblsession">>,
				   {sessionid,SessionID},Command),
     Command1 = {'$set', {mainpid,<<>>}},
     mongo:update(Connection, <<"tblsession">>,
				   {sessionid,SessionID,mainpid,BPid},Command1)
  after
     emipian_msgdb:disconnection(Connection)
  end.	
    

cleanallsessionpid()->
 Connection = emipian_msgdb:getconnection(),
  try
    Command = {'$set', {mainpid,<<>>},'$set', {sidepids,[]}},
    mongo:update(Connection, <<"tblsession">>,{},Command,false,true)
   after
    emipian_msgdb:disconnection(Connection)
  end.	


updatesessionstatus(Session,Status)->
  #session{sessionid=SessionID} = Session,

 Connection = emipian_msgdb:getconnection(),
   try
   Command = {'$set', {status,Status}},	   
   mongo:update(Connection, <<"tblsession">>,
				   {sessionid,SessionID},Command)
   after
     emipian_msgdb:disconnection(Connection)
  end.	

clean_mainpid(MainPid) ->
%%   emipian_msg_log:cancel_terminal_receive(SessionID),
   Connection = emipian_msgdb:getconnection(),
   
   WhereCmd ={mainpid,MainPid},
   Command = {'$set', {mainpid,<<>>},'$set', {sidepids,[]}},
   try
	  mongo:update(Connection, <<"tblsession">>,WhereCmd,Command,false,true)
   after
	 emipian_msgdb:disconnection(Connection)
   end.