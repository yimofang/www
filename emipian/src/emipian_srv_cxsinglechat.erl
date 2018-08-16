%% @author hyf
%% @doc @todo Add description to emipian_srv_cxsinglechat.


-module(emipian_srv_cxsinglechat).

%% 

-include("session.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/7,handle_action/7,processsrv/7]).


process(Session,SenderUserID,Type,StartTime,EndTime,StartPos,Count) ->
    spawn(?MODULE,handle_action,[Session,SenderUserID,Type,StartTime,EndTime,StartPos,Count]). 



handle_action(Session,SenderUserID,Type,StartTime,EndTime,StartPos,Count) -> 
    try
    processsrv(Session,SenderUserID,Type,StartTime,EndTime,StartPos,Count)	
	after
	 exit(normal)   
	end.
   
processsrv(Session,SenderUserID,Type,StartTime,EndTime,StartPos,Count)->
	#session{userid=UserID} = Session,
	Result = emipian_msg_log:search_user_singlemsg(UserID, SenderUserID, StartTime, EndTime, Type, StartPos, Count),
	case Result of
     [] ->send_cxmessage([],Session,0);
     H ->send_cxmessage(H,Session,0)
    end.

%% ====================================================================
%% Internal functions
%% ====================================================================

send_cxmessage([],Session,Count)->
	     #session{selfpid=PID} = Session,
		 Data = <<Count:32/little>>,
		 try	 
           PID ! {eof,Data}
         catch
			_:_->ok 
         end;
send_cxmessage([H|T],Session,Count)->
	 MsgID = emipian_msg_log:getfieldvalue(H, msgid),
	 RevID = emipian_msg_log:getfieldvalue(H, recvid),
	 Status = emipian_msg_log:getfieldvalue(H, status),

	 Status = emipian_msg_log:getfieldvalue(H, status),
     try
	 send_terminalmessage(Session,MsgID,RevID,Status)
     catch
       _:_->ok
     end,  
	send_cxmessage(T,Session,Count+1).


send_terminalmessage(Session,MsgID,RevID,Status) ->
		#session{userid =ReceiverUserID} = Session, 
 case emipian_msg_log:get_sendmsg(MsgID) of
	 not_found->ok;
		 Value ->
			 Action =emipian_msg_log:getfieldvalue(Value, action),
			 Param  = emipian_msg_log:getfieldvalue(Value, param),
			 MsgTime0  = emipian_msg_log:getfieldvalue(Value, sendtime),
			 MsgTime   = emipian_util:get_mstime(MsgTime0),
		     Senderinfo = emipian_msg_log:getfieldvalue(Value, senderinfo),
		     SenderUserID = emipian_msg_log:getfieldvalue(Senderinfo, userid),
		
			 Result = emipian_msg_log:getfieldvalue(Value, result),
			 AddtionInfo =
			 try
			   emipian_msg_log:getfieldvalue(Result,addtioninfo)
			 catch
				 _:_->{}
		     end,		 
		 ChatObj =
			 if SenderUserID=:=ReceiverUserID
				  ->0;
				true ->1
			 end,
		 Mod = gen_action_mod:get_actionmod(Action),
		 case Mod of
			undefined ->ok;
			_->			  

				Mod:sendmsg_to_terminal(Action, MsgID, RevID, Param,
									    Session, SenderUserID, MsgTime,ChatObj,AddtionInfo)
		 

		 end,
      ok
  end. 
