%% @author hyf
%% @doc @todo Add description to emipian_mysqldb.

-include("logger.hrl").

-module(emipian_mysqldb).

%% ====================================================================
%% API functions
%% ====================================================================
-export([getuserinfoforaid/3,getgroupsenderinfo/3,getunkownuserinfoforaid/3,
		 getuserinfoforgroup/4,
		 getuserinfoforcompany/4,
		 getuserinfoforaid/4,
		 getpoolname/1,getconnection/1,disconnection/2,getusernickname/2]).



%% ====================================================================
%% Internal functions
%% ====================================================================

getconnection(Pool) ->

  Conn =  poolboy:checkout(Pool),

	   Conn.
  
%% case mongo:connect("127.0.0.1", 27017, <<"emipian">>, safe, master, []) of
%%   {ok, Connection}-> Connection;
%%   _->error
%%  end.
disconnection(Pool,Connection)->
  case 	Connection of
   fail->ok;	
   full->ok; 	  
    _->poolboy:checkin(Pool,Connection)
end.	
%%	 gen_server:call(Connection, {stop,1}).


%% ====================================================================
%%  get userid from mysql
%%  userid
%%  error : integer
%% ====================================================================
getpoolname(AppCode)->
     MysqlP ="mysql_1",%%++integer_to_list(AppCode),
     list_to_existing_atom(MysqlP).
%%	 case AppCode of
%%				0->mysql0m;
%%				_->undefine
%%	  end.
getuserinfoforaid(SenderUserID,Aid,AppCode,1)->
	 {Aid,<<"1111">>,<<"1111">>,<<"1111">>,<<"1111">>}.
	
getuserinfoforaid(SenderUserID,Aid,AppCode)->
	XMLAid1 = "<A>"++emipian_util:to_xml(Aid)++"</A>",
    
	S="CALL c_sp_GetChatSendUsersInfo(\""++binary_to_list(SenderUserID)
         ++"\",\""++XMLAid1++"\","++"@AReturnCode);SELECT @AReturnCode",
    PoolName = getpoolname(AppCode),
	Connection = getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	RetunCode = case  ReturnCodeCuror of
		not_found -> -1;
		error -> -1;
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1) 
    end,		
		
	if 
        RetunCode<0 -> RetunCode;
		true->
		 DataCuror = mysql_op:get_resultdata(Result,2),
	     DataCuror1 = mysql_op:firstrow(DataCuror),
		 Index1  = mysql_op:get_fieldIndex(DataCuror, <<"fnErrorCode">>),
		 Index2  = mysql_op:get_fieldIndex(DataCuror, <<"fsReceiveUserID">>),
		 Index3  = mysql_op:get_fieldIndex(DataCuror, <<"fsAid">>),
%%		 Index4  = mysql_op:get_fieldIndex(DataCuror, <<"fsCardID">>),
		 Index5  = mysql_op:get_fieldIndex(DataCuror, <<"fs101">>),
		 Index6  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderUserID">>),
%%		 Index7  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderCardID">>),
		 Index8  = mysql_op:get_fieldIndex(DataCuror, <<"fsSender101">>),
		 if 
			 Index1 =:= 0;Index2 =:= 0-> -1;
		     true->
				  Error = mysql_op:getfielddataAsInt(DataCuror1, Index1),
				  if 
					  Error<0 ->Error;
					  true->
				      ReceiverUserID = mysql_op:getfielddataAsStr(DataCuror1, Index2),
				      Aid = mysql_op:getfielddataAsStr(DataCuror1, Index3),
	%%			      ReceiverCardID = mysql_op:getfielddataAsStr(DataCuror1, Index4),
                      ReceiverCardID = <<"">>, 
                      SenderCardID = <<"">>, 
				      Receiver101 = mysql_op:getfielddataAsStr(DataCuror1, Index5),
				      SenderUserID = mysql_op:getfielddataAsStr(DataCuror1, Index6),
				    %%  SenderCardID = mysql_op:getfielddataAsStr(DataCuror1, Index7),
				      Sender101 = mysql_op:getfielddataAsStr(DataCuror1, Index8),
					  {ReceiverUserID,ReceiverCardID,Receiver101,SenderCardID,Sender101}
				 end 
		 end
     end
	  after
       disconnection(PoolName,Connection)
      end.	


getuserinfoforcompany(SenderUserID,Aid,CompanyID,AppCode)->
	XMLAid1 = "<A>"++emipian_util:to_xml(Aid)++"</A>",
    
	S="CALL c_sp_GetCompanyChatUserInfo(\""++binary_to_list(SenderUserID)
         ++"\",\""++XMLAid1++"\",\""++binary_to_list(CompanyID)++"\","++"@AReturnCode);SELECT @AReturnCode",
    PoolName = getpoolname(AppCode),
	Connection = getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	RetunCode = case  ReturnCodeCuror of
		not_found -> -1;
		error -> -1;
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1) 
    end,		
		
	if 
        RetunCode<0 -> RetunCode;
		true->
		 DataCuror = mysql_op:get_resultdata(Result,2),
	     DataCuror1 = mysql_op:firstrow(DataCuror),
		 Index1  = mysql_op:get_fieldIndex(DataCuror, <<"fnErrorCode">>),
		 Index2  = mysql_op:get_fieldIndex(DataCuror, <<"fsReceiveUserID">>),
		 Index3  = mysql_op:get_fieldIndex(DataCuror, <<"fsAid">>),
		 Index4  = mysql_op:get_fieldIndex(DataCuror, <<"fsCardID">>),
		 Index5  = mysql_op:get_fieldIndex(DataCuror, <<"fs101">>),
		 Index6  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderUserID">>),
		 Index7  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderCardID">>),
		 Index8  = mysql_op:get_fieldIndex(DataCuror, <<"fsSender101">>),

		 if 
			 Index1 =:= 0;Index2 =:= 0-> -1;
		     true->
				  Error = mysql_op:getfielddataAsInt(DataCuror1, Index1),
				  if 
					  Error<0 ->Error;
					  true->
				      ReceiverUserID = mysql_op:getfielddataAsStr(DataCuror1, Index2),
				      Aid = mysql_op:getfielddataAsStr(DataCuror1, Index3),
				      ReceiverCardID = mysql_op:getfielddataAsStr(DataCuror1, Index4),
				      Receiver101 = mysql_op:getfielddataAsStr(DataCuror1, Index5),
				      SenderUserID = mysql_op:getfielddataAsStr(DataCuror1, Index6),
				      SenderCardID = mysql_op:getfielddataAsStr(DataCuror1, Index7),
				      Sender101 = mysql_op:getfielddataAsStr(DataCuror1, Index8),
					  {ReceiverUserID,ReceiverCardID,Receiver101,SenderCardID,Sender101}
				 end 
		 end
     end
	  after
       disconnection(PoolName,Connection)
      end.	



getuserinfoforgroup(SenderUserID,Aid,GroupID,AppCode)->
	XMLAid1 = "<A>"++emipian_util:to_xml(Aid)++"</A>",
    
	S="CALL c_sp_GetGroupChatUserInfo(\""++binary_to_list(SenderUserID)
         ++"\",\""++XMLAid1++"\",\""++binary_to_list(GroupID)++"\","++"@AReturnCode);SELECT @AReturnCode",
    PoolName = getpoolname(AppCode),
	Connection = getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	RetunCode = case  ReturnCodeCuror of
		not_found -> -1;
		error -> -1;
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1) 
    end,		
		
	if 
        RetunCode<0 -> RetunCode;
		true->
		 DataCuror = mysql_op:get_resultdata(Result,2),
	     DataCuror1 = mysql_op:firstrow(DataCuror),
		 Index1  = mysql_op:get_fieldIndex(DataCuror, <<"fnErrorCode">>),
		 Index2  = mysql_op:get_fieldIndex(DataCuror, <<"fsReceiveUserID">>),
		 Index3  = mysql_op:get_fieldIndex(DataCuror, <<"fsAid">>),
		 Index4  = mysql_op:get_fieldIndex(DataCuror, <<"fsCardID">>),
		 Index5  = mysql_op:get_fieldIndex(DataCuror, <<"fs101">>),
		 Index6  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderUserID">>),
		 Index7  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderCardID">>),
		 Index8  = mysql_op:get_fieldIndex(DataCuror, <<"fsSender101">>),

		 if 
			 Index1 =:= 0;Index2 =:= 0-> -1;
		     true->
				  Error = mysql_op:getfielddataAsInt(DataCuror1, Index1),
				  if 
					  Error<0 ->Error;
					  true->
				      ReceiverUserID = mysql_op:getfielddataAsStr(DataCuror1, Index2),
				      Aid = mysql_op:getfielddataAsStr(DataCuror1, Index3),
				      ReceiverCardID = mysql_op:getfielddataAsStr(DataCuror1, Index4),
				      Receiver101 = mysql_op:getfielddataAsStr(DataCuror1, Index5),
				      SenderUserID = mysql_op:getfielddataAsStr(DataCuror1, Index6),
				      SenderCardID = mysql_op:getfielddataAsStr(DataCuror1, Index7),
				      Sender101 = mysql_op:getfielddataAsStr(DataCuror1, Index8),
					  {ReceiverUserID,ReceiverCardID,Receiver101,SenderCardID,Sender101}
				 end 
		 end
     end
	  after
       disconnection(PoolName,Connection)
      end.	


  getgroupsenderinfo(GroupID,SenderUserID,AppCode)->
	GroupID0 = binary_to_list(GroupID),
     S="CALL c_sp_GetGroupSenderRight(\""++GroupID0++"\",\""++binary_to_list(SenderUserID)++
       "\",@AReturnCode);"++
      "SELECT @AReturnCode",
    PoolName = getpoolname(AppCode),
	Connection = getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	RetunCode = case  ReturnCodeCuror of
		not_found -> -1;
		error -> -1;
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1) 
	 end,
     if 
      RetunCode>=0 ->
     	DataCuror = mysql_op:get_resultdata(Result,2),
		 Index1  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderGroupID">>),
		 Index2  = mysql_op:get_fieldIndex(DataCuror, <<"fsComapnyID">>),
		 Index3  = mysql_op:get_fieldIndex(DataCuror, <<"fsCardID">>),
		 Index4  = mysql_op:get_fieldIndex(DataCuror, <<"fs101">>),
		 Index5  = mysql_op:get_fieldIndex(DataCuror, <<"fnContact">>),
		 Index6  = mysql_op:get_fieldIndex(DataCuror, <<"fnType">>),
		 Index7  = mysql_op:get_fieldIndex(DataCuror, <<"fsCompany101">>),
		 DataCuror1 = mysql_op:firstrow(DataCuror),
		 SenderGroupID = mysql_op:getfielddataAsStr(DataCuror1, Index1), 
		 ComapnyID = mysql_op:getfielddataAsStr(DataCuror1, Index2), 
		 CardID = mysql_op:getfielddataAsStr(DataCuror1, Index3), 
		 S101 = mysql_op:getfielddataAsStr(DataCuror1, Index4), 
		 Contact = mysql_op:getfielddataAsInt(DataCuror1, Index5), 
		 Type = mysql_op:getfielddataAsInt(DataCuror1, Index6), 
		 Company101 = mysql_op:getfielddataAsStr(DataCuror1, Index7),
		
		{RetunCode,SenderGroupID,ComapnyID,CardID,S101,Contact,Type,Company101};
     true->RetunCode
     end
     after
       disconnection(PoolName,Connection)
     end.	

  getfixgroupsenderinfo(GroupID,SenderUserID,AppCode)->
	GroupID0 = binary_to_list(GroupID),
     S="CALL c_sp_GetGroupSenderRight(\""++GroupID0++"\",\""++binary_to_list(SenderUserID)++
       "\",@AReturnCode);"++
      "SELECT @AReturnCode",
    PoolName = getpoolname(AppCode),
	Connection = getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	RetunCode = case  ReturnCodeCuror of
		not_found -> -1;
		error -> -1;
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1) 
	 end,
     if 
      RetunCode>=0 ->
     	DataCuror = mysql_op:get_resultdata(Result,2),
		 Index1  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderGroupID">>),
		 Index2  = mysql_op:get_fieldIndex(DataCuror, <<"fsComapnyID">>),
		 Index3  = mysql_op:get_fieldIndex(DataCuror, <<"fsCardID">>),
		 Index4  = mysql_op:get_fieldIndex(DataCuror, <<"fs101">>),
		 Index5  = mysql_op:get_fieldIndex(DataCuror, <<"fnContact">>),
		 Index6  = mysql_op:get_fieldIndex(DataCuror, <<"fnType">>),
		 Index7  = mysql_op:get_fieldIndex(DataCuror, <<"fsCompany101">>),
		 DataCuror1 = mysql_op:firstrow(DataCuror),
		 SenderGroupID = mysql_op:getfielddataAsStr(DataCuror1, Index1), 
		 ComapnyID = mysql_op:getfielddataAsStr(DataCuror1, Index2), 
		 CardID = mysql_op:getfielddataAsStr(DataCuror1, Index3), 
		 S101 = mysql_op:getfielddataAsStr(DataCuror1, Index4), 
		 Contact = mysql_op:getfielddataAsInt(DataCuror1, Index5), 
		 Type = mysql_op:getfielddataAsInt(DataCuror1, Index6), 
		 Company101 = mysql_op:getfielddataAsStr(DataCuror1, Index7),
		
		{RetunCode,SenderGroupID,ComapnyID,CardID,S101,Contact,Type,Company101};
     true->RetunCode
     end
       
      after
       disconnection(PoolName,Connection)
      end.	


getunkownuserinfoforaid(SenderUserID,Aid,AppCode)->
	XMLAid1 = "<A>"++emipian_util:to_xml(Aid)++"</A>",
    
	S="CALL c_sp_GetChatUnknownSendUsersInfo(\""++binary_to_list(SenderUserID)
         ++"\",\""++XMLAid1++"\","++"@AReturnCode);SELECT @AReturnCode",
    PoolName = getpoolname(AppCode),
	Connection = getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnCodeCuror = mysql_op:get_resultdata(Result,1),
	RetunCode = case  ReturnCodeCuror of
		not_found -> -1;
		error -> -1;
		_->
		  ReturnCodeCuror1 = mysql_op:firstrow(ReturnCodeCuror),
		  mysql_op:getfielddataAsInt(ReturnCodeCuror1, 1) 
    end,		
		
	if 
        RetunCode<0 -> RetunCode;
		true->
		 DataCuror = mysql_op:get_resultdata(Result,2),
	     DataCuror1 = mysql_op:firstrow(DataCuror),
		 Index1  = mysql_op:get_fieldIndex(DataCuror, <<"fnErrorCode">>),
		 Index2  = mysql_op:get_fieldIndex(DataCuror, <<"fsReceiveUserID">>),
		 Index3  = mysql_op:get_fieldIndex(DataCuror, <<"fsAid">>),
		 Index4  = mysql_op:get_fieldIndex(DataCuror, <<"fsCardID">>),
		 Index5  = mysql_op:get_fieldIndex(DataCuror, <<"fs101">>),
		 Index6  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderUserID">>),
		 Index7  = mysql_op:get_fieldIndex(DataCuror, <<"fsSenderCardID">>),
		 Index8  = mysql_op:get_fieldIndex(DataCuror, <<"fsSender101">>),

		 if 
			 Index1 =:= 0;Index2 =:= 0-> -1;
		     true->
				  Error = mysql_op:getfielddataAsInt(DataCuror1, Index1),
				  if 
					  Error<0 ->Error;
					  true->
				      ReceiverUserID = mysql_op:getfielddataAsStr(DataCuror1, Index2),
				      Aid = mysql_op:getfielddataAsStr(DataCuror1, Index3),
				      ReceiverCardID = mysql_op:getfielddataAsStr(DataCuror1, Index4),
				      Receiver101 = mysql_op:getfielddataAsStr(DataCuror1, Index5),
				      SenderUserID = mysql_op:getfielddataAsStr(DataCuror1, Index6),
				      SenderCardID = mysql_op:getfielddataAsStr(DataCuror1, Index7),
				      Sender101 = mysql_op:getfielddataAsStr(DataCuror1, Index8),
					  {ReceiverUserID,ReceiverCardID,Receiver101,SenderCardID,Sender101}
				 end 
		 end
     end
	  after
       disconnection(PoolName,Connection)
      end.	



getusernickname(UserID,AppCode)->
	S="CALL c_sp_GetUserNickName(\""++binary_to_list(UserID)
         ++"\","++"@AReNickName);SELECT @AReNickName",
    PoolName = getpoolname(AppCode),
	Connection = getconnection(PoolName),
	try
	Result =lists:reverse( mysql:fetch(Connection,S)),
	ReturnNickNameCuror = mysql_op:get_resultdata(Result,1),
	RetunNickName = case  ReturnNickNameCuror  of
		not_found -> -1;
		error -> -1;
		_->
		  ReturnNickNameCuror1 = mysql_op:firstrow(ReturnNickNameCuror),
		  mysql_op:getfielddataAsStr(ReturnNickNameCuror1, 1) 
       end		
	  after
       disconnection(PoolName,Connection)
      end.		