%% @author hyf
%% @doc @todo Add description to emipian_srv_cxgroupchat.


-module(emipian_srv_cxgroupchat).


-include("session.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/7,handle_action/7,processsrv/7]).

process(Session,GroupID,Type,StartTime,EndTime,StartPos,Count) ->
    spawn(?MODULE,handle_action,[Session,GroupID,Type,StartTime,EndTime,StartPos,Count]). 



handle_action(Session,GroupID,Type,StartTime,EndTime,StartPos,Count) -> 
    try
	processsrv(Session,GroupID,Type,StartTime,EndTime,StartPos,Count)
	after
	 exit(normal)   
	end.


processsrv(Session,GroupID,Type,StartTime,EndTime,StartPos,Count)->
	#session{userid=UserID} = Session,
	if Type=:=1; Type=:=2->
		Result = emipian_msg_log:search_user_orgmsg(UserID, GroupID, StartTime, EndTime, Type, StartPos, Count),
		case Result of
	     [] ->send_cxmessage([],Session,0,Type);
	     H ->send_cxmessage(H,Session,0,Type)
	    end;
	   true ->ok
    end.

%% ====================================================================
%% Internal functions
%% ====================================================================

send_cxmessage([],Session,Count,Type)->
	     #session{selfpid=PID} = Session,
		 Data = <<Count:32/little>>,
		 try	 
           PID ! {eof,Data}
         catch
			_:_->ok 
         end;
send_cxmessage([H|T],Session,Count,Type)->
	 MsgID = emipian_msg_log:getfieldvalue(H, msgid),
	 RevID = emipian_msg_log:getfieldvalue(H, recvid),
	 Status = emipian_msg_log:getfieldvalue(H, status),
     try
   	  send_terminalmessage(Session,MsgID,RevID,Status,Type)
     catch
       _:_->ok
     end,  
	send_cxmessage(T,Session,Count+1,Type).


send_terminalmessage(Session,MsgID,RevID,Status,Type) ->
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
			 if Status=:=3 
				  ->0;
				true ->1
			 end,
		 if Type=:=1 ->	 
		    mod_action_groupchat:sendmsg_to_terminal(Action, MsgID, RevID, Param,
									    Session, SenderUserID, MsgTime,ChatObj,AddtionInfo);
		  true->
		     mod_action_fixgroupchat:sendmsg_to_terminal(Action, MsgID, RevID, Param,
									    Session, SenderUserID, MsgTime,ChatObj,AddtionInfo)

        end,
      ok
  end. 
