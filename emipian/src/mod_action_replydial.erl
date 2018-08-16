%% @author hyf
%% @doc @todo Add description to mod_action_replydial.


-module(mod_action_replydial).
-include(  "session.hrl").
-include("errorcode.hrl").
-include("logger.hrl").
 -include("macro.hrl").

-define(CMDMINLEN, 41).
-define(AC_CS_REPLYDIAL, 30102).
-define(AC_SC_SENDSTATUS, 22102).

%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_sendfields_fromparam/2,get_msgstamptime/1]).
-export([sendmsg_status/3]).


process_action(MsgID,Session,_Action,Param)-> 
		 #session{sessionid=SessionID,userid=SenderUserID,customcode=CustomCode,selfpid =PID} = Session,	 
   Result =   parse_param(Param),
   case Result of
		 cmderror -> cmderror;
		 {ok,PeerMsgID,Status}->
           process_redial(PeerMsgID,PID,Status),
		   {noresp,ok}
	  end.
get_msgstamptime(_)->{ok,0}.

get_sendfields_fromparam(_,Param)->
 Total = byte_size(Param),  
	 if 
		Total<?CMDMINLEN ->
			cmderror;
         true->
 		  <<MsgID:40/binary,Status:8/little>> = Param,
		  MsgID0 = emipian_util:binary_to_str(MsgID),
	      {msgid,MsgID0,status,Status}
     end.



%% ====================================================================
%% Internal functions
%% ====================================================================

parse_param(Param)->
  Total = byte_size(Param),  
	  if 
		Total<?CMDMINLEN ->
			cmderror;
		 true->
	        <<PeerMsgID0:40/binary,Status:8/little>> = Param,
	        PeerMsgID = emipian_util:binary_to_str(PeerMsgID0),
            {ok,PeerMsgID,Status} 
      end.



process_redial(MsgID,PID,Status)->
  Value = emipian_msgdb:get_dialinfo(MsgID),
  case Value of
	  not_found ->
		 StatusData = get_sendmessagedata(MsgID,?HANG_STATUS_QX),
		 sendmsg_status(MsgID,PID,StatusData),
		  emipian_msg_log:update_dialinfo(MsgID, ?DAIL_STATUS_HANGOFF);
       _->
		 DialSessionID  = emipian_msg_log:getfieldvalue(Value, sendersessionid),
		 DialStatus  = emipian_msg_log:getfieldvalue(Value, status),
        case DialStatus of
			?DAIL_STATUS_SENDING ->
				 DialPid = getdialpid(DialSessionID),
				 case DialPid of
				    not_found->
						StatusData = get_sendmessagedata(MsgID,?HANG_STATUS_QX),
						sendmsg_status(MsgID,PID,StatusData),
						emipian_msg_log:update_dialinfo(MsgID, ?DAIL_STATUS_HANGOFF);
					 _->
					 case 	Status of
					  ?HANG_STATUS_SUCESS-> 
						try 
						  {MeetingID,MeetingPass} = emipian_meet:createMeeting(),
						  StatusData2 =  get_sendmessagedata(MsgID,MeetingID,MeetingPass),
		                   emipian_msg_log:update_dialinfo(MsgID, ?HANG_STATUS_SUCESS,MeetingID,MeetingPass),		
		        	
		   				  sendmsg_status(MsgID,PID,StatusData2),
		   				  sendmsg_status(MsgID,DialPid,StatusData2)
						catch
						   _:_-> 
						   StatusData1 = get_sendmessagedata(MsgID,?HANG_STATUS_MEETERROR),
		                   emipian_msg_log:update_dialinfo(MsgID, ?DAIL_STATUS_EXCEPOTION),		
		   				  sendmsg_status(MsgID,PID,StatusData1),
		   				  sendmsg_status(MsgID,DialPid,StatusData1)
						end;
					 _->
						 StatusData1 = get_sendmessagedata(MsgID,Status),
		                 emipian_msg_log:update_dialinfo(MsgID,Status),		
		   				 sendmsg_status(MsgID,DialPid,StatusData1)
		            end
				 end;
		   _->
              	StatusData1 = get_sendmessagedata(MsgID,?HANG_STATUS_COMPLETE),
		   	    sendmsg_status(MsgID,PID,StatusData1) 
        end 
  end.

getdialpid(SessionID)->
   Session = emipian_sm:get_session(SessionID),
   case Session of
    not_found->not_found;
   _->
     #session{selfpid=Pid} = Session,
	  case Pid of
         not_found->not_found;
		 _->
			case  erlang:is_process_alive(Pid) of 
			   true ->Pid;
				_->not_found
			end 
	  end		 
   end.

sendmsg_status(MsgID,Receiver,Data) when erlang:is_pid(Receiver) ->
  try	 
    Receiver ! {msg,?AC_SC_SENDSTATUS,MsgID,0,Data}
  catch
	 _:_->ok 
    end;
sendmsg_status(MsgID,SenderSessionID,Status)->
		StatusData1 = get_sendmessagedata(MsgID,Status),
		Pid = getdialpid(SenderSessionID),
		if is_pid(Pid)
			 -> 
			   case erlang:is_process_alive(Pid) of
				  true -> 
			     sendmsg_status(MsgID,Pid,StatusData1);
				  _->ok 
			   end;   
		   true->ok
		end.   



get_sendmessagedata(MsgID,Status)->
  MsgID1 = emipian_util:str_to_binayid(MsgID),
  <<MsgID1:40/binary,Status:8/little,0:8/little>>. 

get_sendmessagedata(MsgID,MeetingID,MeetingPass)->
  MsgID1 = emipian_util:str_to_binayid(MsgID),
  MeetingJson = getmeetingjson({MeetingID,MeetingPass}),
  MeetingJsonLen  =  byte_size(MeetingJson),
  <<MsgID1:40/binary,0:8/little,MeetingJsonLen:32/little,MeetingJson/binary>>. 

getmeetingjson({MeetingID,MeetingPass}) ->
	Dict = dict:new(),
	Dict1 =  dict:store("meetingid", MeetingID,Dict),
	Dict2 = dict:store("meetingpass", MeetingPass,Dict1),
    list_to_binary(rfc4627:encode(Dict2)).
