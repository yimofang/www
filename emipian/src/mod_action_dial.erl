%% @author hyf
%% @doc @todo Add description to emipian_dial.


-module(mod_action_dial).
-include(  "session.hrl").
-include("errorcode.hrl").
-include("logger.hrl").
 -include("macro.hrl").

-define(CMDMINLEN, 48).
-define(AC_CS_DIAL, 30101).
-define(AC_CS_DIAL_R, 60101).


-define(AC_SC_DIALING, 22101).


%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_sendfields_fromparam/2,get_msgstamptime/1]).
-export([sendmsg_to_terminal/2]).

process_action(MsgID,Session,Action,Param)-> 
		 #session{sessionid=SessionID,userid=SenderUserID,customcode=CustomCode,appcode =AppCode} = Session,	 
   Result =   parse_param(Param),
   case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,ReceiverUserID,AddtionJsonLen,AddtionJson} ->
               UserResult = emipian_mysqldb:getunkownuserinfoforaid(ReceiverUserID, SenderUserID, AppCode),
                  if 
		                is_integer(UserResult) -> 
	
			         {Reuslt,ToDataBase} = get_resultparam(Action,UserResult,StampTime,MsgID), 
			         {ok,Reuslt,ToDataBase};
                    true-> 
				     {_,SenderCardID,Sender101,_,_} =UserResult,
			         {Reuslt,ToDataBase} = get_resultparam(Action,0,StampTime,MsgID), 
			         process_dial(SenderUserID,SessionID,Action,StampTime,CustomCode,
							   MsgID,ReceiverUserID,AddtionJsonLen,AddtionJson,SenderCardID,Sender101),			
			         {ok,Reuslt,ToDataBase}
			  end  
  end.


get_sendfields_fromparam(_,Param)->
 Total = byte_size(Param),  
	 if 
		Total<?CMDMINLEN ->
				 ?INFO_MSG("Dail get_sendfields_fromparam error:~p-~p ~n.", [Total,Param]),	 

			cmderror;
         true->
 		  <<StampTime:64/little,ReceiverUserID0:40/binary,AddtionJsonLen:32/little,AddtionJson/binary>> = Param,
		  ReceiverUserID = emipian_util:binary_to_str(ReceiverUserID0),
		  ?INFO_MSG("Dail get_sendfields_fromparam Sucess:~p-~p ~n.", [StampTime,ReceiverUserID]),	 

		  {stamptime,StampTime,receiveruserid,ReceiverUserID,addtionjson,AddtionJson}
     end.

get_msgstamptime(_)->{ok,0}.





%% ====================================================================
%% Internal functions
%% ====================================================================
get_resultparam(Action,Code,StampTime,MsgID)
->
   MsgID1 = emipian_util:str_to_binayid(MsgID), 
  
   Return = {?AC_CS_DIAL_R,Code,<<StampTime:64/little,MsgID1/binary>>},
   ToDataBase =  {action,?AC_CS_DIAL_R,code,Code},
   {Return,ToDataBase}.


parse_param(Param)->
  Total = byte_size(Param),  
	  if 
		Total<?CMDMINLEN ->
			cmderror;
		 true->
	        <<StampTime:64/little,ReceiverUserID0:40/binary,AddtionJsonLen:32/little,AddtionJson/binary>> = Param,
	        ReceiverUserID = emipian_util:binary_to_str(ReceiverUserID0),
			JsonLen = byte_size(AddtionJson),
			if JsonLen=:=AddtionJsonLen ->
              {ok,StampTime,ReceiverUserID,AddtionJsonLen,AddtionJson};
			   true ->cmderror
		    end  
      end.

process_dial(SenderUserID,SessionID,Action,StampTime,CustomCode,MsgID,ReceiverUserID,
			 AddtionJsonLen,AddtionJson,SenderCardID,Sender101)
  ->
          PeerSession = find_user_session(SessionID,CustomCode,ReceiverUserID),
  	      TimeOut = get_timeout(),

		  case PeerSession of 
            not_found->
			   PeerStatus =?DAIL_STATUS_INIT,
			   ReceiverSessionID = <<"">>,
               save_dial_meeting(MsgID,Action,SessionID,SenderUserID,ReceiverUserID,
								 ReceiverSessionID,
 					   StampTime,TimeOut,PeerStatus,AddtionJson,SenderCardID,Sender101) ;
            _->  
			Data = get_sendmessagedata(MsgID,SenderUserID,AddtionJsonLen,AddtionJson,SenderCardID,Sender101),
            #session{sessionid =ReceiverSessionID,selfpid=ReceiverPid} = PeerSession,
                        
            sendmsg_to_terminal(MsgID,Sender101,PeerSession,Data,AddtionJson),
			
			PeerStatus = 
				case ReceiverPid of
					not_found->?DAIL_STATUS_INIT;
				   _->
					  case   erlang:is_process_alive(ReceiverPid) of
			            true ->	
          					?DAIL_STATUS_SENDING;
                        _->	?DAIL_STATUS_INIT
					   end	  

			    end,		
				
            save_dial_meeting(MsgID,Action,SessionID,SenderUserID,ReceiverUserID,ReceiverSessionID,
 					   StampTime,TimeOut,PeerStatus,AddtionJson,SenderCardID,Sender101) 
		end.

find_user_session(SessionID,CustomCode,ReceiverUserID)->
      Sessions =  emipian_sm:get_usersession(SessionID, ReceiverUserID),
      Session0 = findonlinemobile(CustomCode,Sessions),
      case  Session0 of
            not_found->findmacmobile(CustomCode,Sessions);
            _-> Session0
      end.

%% 在线手机，Custom，iPhone APns 手机，PC

findonlinemobile(CustomCode,[])->not_found;
findonlinemobile(CustomCode,[H|T]) ->
     #session{selfpid=PID,status =Status,sessionid =SessionID,customcode=Customcode0} = H,
    if PID=/=not_found,Status=:=0,CustomCode =:= Customcode0
         ->H;
        true->findonlinemobile(CustomCode,T)
    end.

findmacmobile(CustomCode,[])->not_found;
findmacmobile(CustomCode,[H|T]) ->
     #session{selfpid=PID,status =Status,sessionid =SessionID,appos = Appos,
             customcode=Customcode0,termialno = DeviceID} = H,
    if Appos=:=?APPOS_IOS,CustomCode =:= Customcode0
         ->H;
         true->findmacmobile(CustomCode,T)
    end.


sendmsg_to_terminal(MsgID,Sender101,Session,Data,AddtionJson)->
     #session{selfpid=PID,status =Status,sessionid =SessionID,userid=UserID,customcode =AppCode } = Session,
	 		   	?INFO_MSG("send apns before 0..... ~n.", []),  
	 if 
		  Status =:=?STATUS_ONLINE ->
			  
   		  try	 
            PID ! {msg,?AC_SC_DIALING,MsgID,0,Data}
          catch
			 _:_->ok 
          end,
		   	?INFO_MSG("send apns before 1..... ~n.", []),
			emipian_apns:sendapns(Session,Sender101);
		  true->
			   	?INFO_MSG("send apns before 2..... ~n.", []),
			emipian_apns:sendapns(Session,Sender101)

     end.


sendmsg_to_terminal(ReceiverSession,Value)->
		#session{sessionid=ReceiverSessionID,selfpid =PID,userid =ReceiverUserID} = ReceiverSession,
	MsgID = emipian_msg_log:getfieldvalue(Value, msgid),
	AddtionJson = emipian_msg_log:getfieldvalue(Value, addtionjson),
	AddtionJsonLen = byte_size(AddtionJson),
	ValidTime  = emipian_msg_log:getfieldvalue(Value, validtime),
	SenderSessionID = emipian_msg_log:getfieldvalue(Value, sendersessionid),
	SenderUserID  =	emipian_msg_log:getfieldvalue(Value, senderuserid),
	SenderCardID =emipian_msg_log:getfieldvalue(Value, sendercardid),
	Sender101  =emipian_msg_log:getfieldvalue(Value, sender101),
	CurrentTime  = os:timestamp() ,
	if CurrentTime>ValidTime ->
      emipian_msg_log:update_dialinfo(MsgID, ?HANG_STATUS_CS),
	  mod_action_replydial:sendmsg_status(MsgID, SenderSessionID, ?HANG_STATUS_CS);
   true->		
	  RStatus =emipian_msg_log:get_receiverstatus(ReceiverUserID),  
	 case RStatus of
		 1->
 	       Data = get_sendmessagedata(MsgID,SenderUserID,AddtionJsonLen,AddtionJson,SenderCardID,Sender101),
           emipian_msg_log:update_dialinfo(MsgID, ?DAIL_STATUS_SENDING),
           emipian_msg_log:update_dialinfo(MsgID, ReceiverSessionID),
 	       try	 
           PID ! {msg,?AC_SC_DIALING,MsgID,0,Data}
          catch
	        _:_->ok 
          end;
		_->
		   emipian_msg_log:update_dialinfo(MsgID, ?HANG_STATUS_ZX),
	       mod_action_replydial:sendmsg_status(MsgID, SenderSessionID, ?HANG_STATUS_ZX)
	 end
	end.

save_dial_meeting(MsgID,Action,SenderSessionID,SenderUserID,ReceiverUserID,ReceiverSessionID,
  StampTime,ValidLong,Status,AddtionJson,SenderCardID,Sender101) 
  ->
  emipian_msg_log:save_dial_meeting(MsgID,Action,SenderSessionID,SenderUserID,ReceiverUserID,ReceiverSessionID,
   StampTime,ValidLong,Status,AddtionJson,SenderCardID,Sender101).


get_sendmessagedata(MsgID,SenderUserID,AddtionJsonLen,AddtionJson,SenderCardID,Sender101)->
     MsgID1 = emipian_util:str_to_binayid(MsgID),
     case rfc4627:decode(AddtionJson) of
	  {ok,Data1,_} -> 
			 case  rfc4627:get_field(Data1, "type") of
				 {ok,Type0} ->Type = Type0;
				 _->Type=0
			 end;
	      _->
             Type =0
		end, 
 	Dict = dict:new(),
	Dict1 =  dict:store("cardid", SenderCardID,Dict),
	Dict2 = dict:store("s101", Sender101,Dict1),
	Dict3 = dict:store("senderuserid", SenderUserID,Dict2),
	Dict4 = dict:store("type", Type,Dict3),

	AddtionJson0= list_to_binary(rfc4627:encode(Dict4)),
    AddtionJsonLen0 = byte_size(AddtionJson0),
  <<MsgID1:40/binary,AddtionJsonLen0:32/little,AddtionJson0/binary>>. 



get_timeout()->
  case emipian_meet:get_meeting(timeout) of
    not_found-> 120000;
    Value ->Value
  end.
   