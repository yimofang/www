%% @author hyf
%% @doc @todo Add description to emipian_srv_groupchat.


-module(emipian_srv_groupchat).

-include("session.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).



process(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID}) ->
    spawn(?MODULE,handle_action,[SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID}]). 



handle_action(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID}) -> 
	try
     getcangroupreceivers(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID})
	after
	 exit(normal)   
	end.

processsrv(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID})->
  	getcangroupreceivers(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID}).


%% ====================================================================
%% Internal functions
%% ====================================================================


getcangroupreceivers(SenderSession,{Action,StampTime,GroupID,Receivers,Level,MsgID,Content,MsgTime,CompanyID}
					)->
	GroupID0 = binary_to_list(GroupID),
	#session{appcode = AppCode,userid = SenderUserID,selfpid = MsgPid} =SenderSession,
	RLen = length(Receivers),
	XMLReceivers = 
	if 
	  RLen>0 ->
	          emipian_util:json_to_xmlforgroupreceiver(Receivers);
	  true->  "<A><id>"++GroupID0++"</id><type>1</type></A>"
    end,
    S ="CALL c_sp_EnumCanReceiveGroupMsgUsers(\""++GroupID0++"\",\""++binary_to_list(SenderUserID)
          ++"\",\""++XMLReceivers++"\","++
          integer_to_list(Level,10)++",@AReturnCode);"++
          "SELECT @AReturnCode", 
    PoolName = emipian_mysqldb:getpoolname(AppCode),
	Connection = emipian_mysqldb:getconnection(PoolName),
	try

	
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	case  ReturnCodeCuror of
		not_found -> 
			{ActionResult,ToDabase}  = mod_action_groupchat:get_resultparam(Action,-1,
														StampTime,MsgID,MsgTime,CompanyID,{}),
            MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
		error -> 
			{ActionResult,ToDabase}  = mod_action_groupchat:get_resultparam(Action,-1,
														StampTime,MsgID,MsgTime,CompanyID,{}),
            MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  RetunCode = mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1), 
          if
			  RetunCode<0 ->
			    {ActionResult,ToDabase}  = mod_action_groupchat:get_resultparam(Action,RetunCode,
														StampTime,MsgID,MsgTime,CompanyID,{}),
                MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}};
				  
	          true->		  
				 DataCuror2 = mysql_op:get_resultdata(Result,2),
				  
		         Index21  = mysql_op:get_fieldIndex(DataCuror2, <<"fsSenderGroupID">>),
%%		         Index22  = mysql_op:get_fieldIndex(DataCuror2, <<"fsComapnyID">>),
%%		         Index23  = mysql_op:get_fieldIndex(DataCuror2, <<"fsCardID">>),
		         Index24  = mysql_op:get_fieldIndex(DataCuror2, <<"fsNickName">>),
		         Index25  = mysql_op:get_fieldIndex(DataCuror2, <<"fnContact">>),
	        	 Index26  = mysql_op:get_fieldIndex(DataCuror2, <<"fnType">>),
%%		         Index27  = mysql_op:get_fieldIndex(DataCuror2, <<"fsCompany101">>),
		         Index28  = mysql_op:get_fieldIndex(DataCuror2, <<"fnGroupType">>),
		         Index29  = mysql_op:get_fieldIndex(DataCuror2, <<"fsOwnerID">>),

				  AddtionInfo = 
				   case mysql_op:firstrow(DataCuror2) of  
				       norow ->{};
					   DataCuror21->
			   			     SenderGroupID = mysql_op:getfielddataAsStr(DataCuror21, Index21), 
%%				        	 ComapnyID = mysql_op:getfielddataAsStr(DataCuror21, Index22), 
%%					         CardID = mysql_op:getfielddataAsStr(DataCuror21, Index23), 
					         NickName = mysql_op:getfielddataAsStr(DataCuror21, Index24), 
					         Contact = mysql_op:getfielddataAsInt(DataCuror21, Index25), 
					         Type = mysql_op:getfielddataAsInt(DataCuror21, Index26), 
%%					         Company101 = mysql_op:getfielddataAsStr(DataCuror21, Index27),
                             GroupType  =mysql_op:getfielddataAsInt(DataCuror21, Index28),
					         OwnerUserID = mysql_op:getfielddataAsStr(DataCuror21, Index29),
                             ComapnyID = <<"">>, 
                             CardID = <<"">>, 
                             Company101 = <<"">>, 
						     {companyid,ComapnyID,cardid,CardID,nickname,NickName,contact,Contact,
											 company101,Company101,orgid,SenderGroupID,grouptype,GroupType,owneruserid,OwnerUserID}
				   end,
                   {ActionResult,ToDabase} = mod_action_groupchat:get_resultparam(Action,0,StampTime,MsgID,MsgTime,CompanyID,AddtionInfo),
                    MsgPid!{result,Action,MsgID,{ok,ActionResult,ToDabase}},

			        DataCuror3 = mysql_op:get_resultdata(Result,3),
				     Index31  = mysql_op:get_fieldIndex(DataCuror3, <<"fsUserID">>),
		             Index32  = mysql_op:get_fieldIndex(DataCuror3, <<"fsOrgID">>),
  		             Index33  = mysql_op:get_fieldIndex(DataCuror3, <<"fsGroupName">>),
		             Index34  = mysql_op:get_fieldIndex(DataCuror3, <<"fnGroupType">>),
		             Index35  = mysql_op:get_fieldIndex(DataCuror3, <<"fsOwnerID">>),
				   case mysql_op:firstrow(DataCuror3) of
				   norow ->ok;
 				    DataCuror31->
                     sendnext(SenderSession,DataCuror31,{Index31,Index32,Index33,Index34,Index35},MsgID,Content,MsgTime,CompanyID,AddtionInfo)
                   end 
		   end	
         
	  end
      after
       emipian_mysqldb:disconnection(PoolName,Connection)
      end.	


sendnext(SenderSession,DataCuror,Indexes,MsgID,Content,MsgTime,CompanyID,AddtionInfo) ->
	{Index1,Index2,Index3,Index4,Index5} = Indexes,
	 ReceiveUserID = mysql_op:getfielddataAsStr(DataCuror, Index1), 
	 SubGroupID = mysql_op:getfielddataAsStr(DataCuror, Index2), 
	 GroupName = mysql_op:getfielddataAsStr(DataCuror, Index3), 
     GroupType  =mysql_op:getfielddataAsInt(DataCuror, Index4),
    OwnerUserID = mysql_op:getfielddataAsStr(DataCuror, Index5),


	UserAddtionInfo = {orgid,SubGroupID,orgname,GroupName,grouptype,GroupType,owneruserid,OwnerUserID},
  	 mod_action_groupchat:sendmsg_to_user(SenderSession, MsgID, 
										  Content,  MsgTime, ReceiveUserID, 
										 CompanyID,UserAddtionInfo,AddtionInfo),
     DataCuror1 = mysql_op:nextrow(DataCuror),
 	 case DataCuror1 of
		eof->ok;
		_->sendnext(SenderSession,DataCuror1,Indexes,MsgID,Content,MsgTime,CompanyID,AddtionInfo)
	 end.	
