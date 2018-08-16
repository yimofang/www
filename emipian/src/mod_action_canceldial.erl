%% @author hyf
%% @doc @todo Add description to mod_action_canceldial.


-module(mod_action_canceldial).
-include(  "session.hrl").
-include("errorcode.hrl").
-include("logger.hrl").
 -include("macro.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-define(CMDMINLEN, 40).
-export([process_action/4,get_sendfields_fromparam/2,get_msgstamptime/1]).

process_action(MsgID,Session,Action,Param)-> 
		 #session{sessionid=SessionID,userid=SenderUserID,customcode=CustomCode} = Session,	 
   Result =   parse_param(Param),
   case Result of
		 cmderror -> cmderror;
		 {ok,PeerMsgID} ->
	        process_cancel(SenderUserID,PeerMsgID),	
		    {noresp,ok}
  end.


get_sendfields_fromparam(_,Param)->
 Total = byte_size(Param),  
	 if 
		Total<?CMDMINLEN ->
			cmderror;
         true->
 		 <<MsgID0/binary>> = Param,
	       MsgID = emipian_util:binary_to_str(MsgID0),
	      {msgid,MsgID}
     end.

get_msgstamptime(_)->{ok,0}.

%% ====================================================================
%% Internal functions
%% ====================================================================

parse_param(Param)->
  Total = byte_size(Param),  
	  if 
		Total<?CMDMINLEN ->
			cmderror;
		 true->
	        <<MsgID0/binary>> = Param,
	        MsgID = emipian_util:binary_to_str(MsgID0),
			
            {ok,MsgID} 
      end.

process_cancel(UserID,MsgID)
 ->
   Result = emipian_msg_log:get_dailmsg(MsgID),
   case Result of
     not_found-> ok;
     _->
     	 SendersessionID  = emipian_msg_log:getfieldvalue(Result, sendersessionid),
     	 ReceiverSessionID  = emipian_msg_log:getfieldvalue(Result, receiversessionid),
     	 SendersUserID  = emipian_msg_log:getfieldvalue(Result, senderuserid),

		 DialStatus  = emipian_msg_log:getfieldvalue(Result, status),

         if DialStatus=:=?DAIL_STATUS_SENDING ->
            mod_action_replydial:sendmsg_status(MsgID,ReceiverSessionID,?HANG_STATUS_QX),
            emipian_msg_log:update_dialinfo(MsgID, ?HANG_STATUS_QX);
           true->ok
         end,  

         if DialStatus=:=?DAIL_STATUS_INIT ->
           emipian_msg_log:update_dialinfo(MsgID, ?HANG_STATUS_QX);
           true->ok
         end, 
 
         if DialStatus=:=?HANG_STATUS_SUCESS ->
            if UserID =:=SendersUserID ->
              mod_action_replydial:sendmsg_status(MsgID,ReceiverSessionID,?HANG_STATUS_QX);
              true ->
              mod_action_replydial:sendmsg_status(MsgID,SendersessionID,?HANG_STATUS_QX)
            end; 
           true->ok
         end  
   end.


	