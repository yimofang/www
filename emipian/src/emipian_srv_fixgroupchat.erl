% @author hyf
%% @doc @todo Add description to emipian_srv_fixgroupchat.


-module(emipian_srv_fixgroupchat).
-include("session.hrl").


%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).



process(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime}) ->
    spawn(?MODULE,handle_action,[SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime}]). 



handle_action(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime}) -> 
 	try
    getcangroupreceivers(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime})	
	after
	 exit(normal)   
	end.
processsrv(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime})->
  getcangroupreceivers(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime}).
%% ====================================================================
%% Internal functions
%% ====================================================================


getcangroupreceivers(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime}
					)->
	#session{appcode = AppCode,userid= SenderUserID,selfpid=MsgPid} =SenderSession,
	
	GroupID0 = binary_to_list(GroupID),
	RLen = length(Receivers),
	XMLReceivers = 
	if 
	  RLen>0 ->
	          emipian_util:json_to_xmlforgroupreceiver(Receivers);
	  true->  "<A><id>"++GroupID0++"</id><type>1</type></A>"
    end,
    S ="CALL c_sp_EnumCanReceiveFixGroupMsgUsers(\""++GroupID0++"\",\""++binary_to_list(SenderUserID)++"\",\""++
		   XMLReceivers++"\","++integer_to_list(Level,10)++",@AReturnCode);"++
          "SELECT @AReturnCode", 
    PoolName = emipian_mysqldb:getpoolname(AppCode),
	Connection = emipian_mysqldb:getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	case  ReturnCodeCuror of
		not_found ->
			{ActionResult,ToDabase}  = mod_action_fixgroupchat:get_resultparam(Action,-1,StampTime,MsgID,MsgTime,{}),
            MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
		error -> 
			{ActionResult,ToDabase}  = mod_action_fixgroupchat:get_resultparam(Action,-1,StampTime,MsgID,MsgTime,{}),
            MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  RetunCode = mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1), 
          if
			  RetunCode<0 ->
                 {ActionResult,ToDabase}  = mod_action_fixgroupchat:get_resultparam(Action,RetunCode,StampTime,MsgID,MsgTime,{}),
                 MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
	          true->		  
				  DataCuror2 = mysql_op:get_resultdata(Result,2),
				  Index21  = mysql_op:get_fieldIndex(DataCuror2, <<"fsCardID">>),
		          Index22  = mysql_op:get_fieldIndex(DataCuror2, <<"fs101">>),
				AddtionInfo =
                   case mysql_op:firstrow(DataCuror2) of
				   norow ->{};
 				   DataCuror21->
	                  CardID = mysql_op:getfielddataAsStr(DataCuror21, Index21), 
	                  S101 = mysql_op:getfielddataAsStr(DataCuror21, Index22), 
                      {cardid,CardID,s101,S101}
                  end, 
                  {ActionResult,ToDabase} = mod_action_fixgroupchat:get_resultparam(Action,0,StampTime,MsgID,MsgTime,AddtionInfo),
                  
				  MsgPid !{result,Action,MsgID,{ok,ActionResult,ToDabase}},
				  DataCuror3 = mysql_op:get_resultdata(Result,3),
				  Index31  = mysql_op:get_fieldIndex(DataCuror3, <<"fsUserID">>),
		          Index32  = mysql_op:get_fieldIndex(DataCuror3, <<"fsOrgID">>),
		          Index33  = mysql_op:get_fieldIndex(DataCuror3, <<"fnGroupType">>),
		          Index34  = mysql_op:get_fieldIndex(DataCuror3, <<"fsGroupName">>),
				  case mysql_op:firstrow(DataCuror3) of
				   norow ->ok;
 				   DataCuror31->
                    sendnext(SenderSession,DataCuror31,{Index31,Index32,Index33,Index34},MsgID,Content,MsgTime,AddtionInfo)
                  end 
		 end	  
	end
      after
       emipian_mysqldb:disconnection(PoolName,Connection)
      end.	

sendnext(SenderSession,DataCuror,Indexes,MsgID,Content,MsgTime,AddtionInfo) ->

	 {Index1,Index2,Index3,Index4} = Indexes,
	 ReceiveUserID = mysql_op:getfielddataAsStr(DataCuror, Index1), 
	 SubGroupID = mysql_op:getfielddataAsStr(DataCuror, Index2), 
	 GroupType = mysql_op:getfielddataAsInt(DataCuror, Index3), 
	 GroupName = mysql_op:getfielddataAsStr(DataCuror, Index4), 
	 UserAddtionInfo = {orgid,SubGroupID,grouptype,GroupType,groupname,GroupName},

	mod_action_fixgroupchat:sendmsg_to_user(SenderSession, MsgID, Content, MsgTime, ReceiveUserID, 
				UserAddtionInfo,AddtionInfo),
    DataCuror1 = mysql_op:nextrow(DataCuror),
	case DataCuror1 of
		eof->ok;
		_->sendnext(SenderSession,DataCuror1,Indexes,MsgID,Content,MsgTime,AddtionInfo)
	end.	


