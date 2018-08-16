%% @author hyf
%% @doc @todo Add description to mod_srv_directreplychat.


-module(mod_srv_directreplychat).
-include("session.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).



process(SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime}) ->
    spawn(?MODULE,handle_action,[SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime}]). 



handle_action(SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime}) -> 
	try
     send(SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime})
	after
	 exit(normal)   
	end.

processsrv(SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime})->
  	send(SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime}).


%% ====================================================================
%% Internal functions
%% ====================================================================

send(SenderSession,{Action,StampTime,Receivers,MsgID,Content,MsgTime}
					)->
	#session{appcode = AppCode,userid = SenderUserID,selfpid = MsgPid} =SenderSession,
	RLen = length(Receivers),
	XMLReceivers = emipian_util:json_to_xmlforgroupreceiver(Receivers),
	S ="CALL c_sp_EnumDirectReceiveMsgUsers(\""++binary_to_list(SenderUserID)
          ++"\",\""++XMLReceivers++"\""++
          ",@AReturnCode);"++
          "SELECT @AReturnCode", 
    PoolName = emipian_mysqldb:getpoolname(AppCode),
	Connection = emipian_mysqldb:getconnection(PoolName),
   PoolName = emipian_mysqldb:getpoolname(AppCode),
	Connection = emipian_mysqldb:getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	case  ReturnCodeCuror of
		not_found -> 
			{ActionResult,ToDabase}  = mod_action_allchat:get_resultparam(Action,-1,
														StampTime,MsgID,MsgTime,{}),
            MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
		error -> 
			{ActionResult,ToDabase}  = mod_action_allchat:get_resultparam(Action,-1,
														StampTime,MsgID,MsgTime,{}),
            MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  RetunCode = mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1), 
          if
			  RetunCode<0 ->
			    {ActionResult,ToDabase}  = mod_action_allchat:get_resultparam(Action,RetunCode,
														StampTime,MsgID,MsgTime,{}),
                MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
				  
	          true->		  
				  DataCuror2 = mysql_op:get_resultdata(Result,2),
				  
		         Index21  = mysql_op:get_fieldIndex(DataCuror2, <<"fsSenderUserID">>),
		         Index22  = mysql_op:get_fieldIndex(DataCuror2, <<"fsSender101">>),

				  AddtionInfo = 
				   case mysql_op:firstrow(DataCuror2) of  
				       norow ->{};
					   DataCuror21->
			   			     SenderUserID = mysql_op:getfielddataAsStr(DataCuror21, Index21), 
				        	 SenderS101 = mysql_op:getfielddataAsStr(DataCuror21, Index22), 
						     {s101,SenderS101}
				   end,
                   {ActionResult,ToDabase} = mod_action_allchat:get_resultparam(Action,0,StampTime,MsgID,MsgTime,AddtionInfo),
                    MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}},

			        DataCuror3 = mysql_op:get_resultdata(Result,3),
				    Index31  = mysql_op:get_fieldIndex(DataCuror2, <<"fsReceiveUserID">>),
		            Index32  = mysql_op:get_fieldIndex(DataCuror2, <<"fs101">>),

				  
				   case mysql_op:firstrow(DataCuror3) of
				   norow ->ok;
 				    DataCuror31->
                     sendnext(SenderSession,DataCuror31,{Index31,Index32},MsgID,Content,MsgTime,AddtionInfo)
                   end 
		   end	
         
	  end
      after
       emipian_mysqldb:disconnection(PoolName,Connection)
	end.	


sendnext(SenderSession,DataCuror,Indexes,MsgID,Content,MsgTime,AddtionInfo) ->
	{Index1,Index2} = Indexes,
	 ReceiveUserID = mysql_op:getfielddataAsStr(DataCuror, Index1), 


	UserAddtionInfo = {},
  	 mod_action_directreplychat:sendmsg_to_user(SenderSession, MsgID, 
										  Content,  MsgTime, ReceiveUserID, 
										 UserAddtionInfo,AddtionInfo),
     DataCuror1 = mysql_op:nextrow(DataCuror),
 	 case DataCuror1 of
		eof->ok;
		_->sendnext(SenderSession,DataCuror1,Indexes,MsgID,Content,MsgTime,AddtionInfo)
	 end.	

	
