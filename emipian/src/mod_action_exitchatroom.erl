%% @author hyf
%% @doc @todo Add description to mod_action_exitchatroom.


-module(mod_action_exitchatroom).

-include("session.hrl").
-include("errorcode.hrl").
-include("logger.hrl").
-include("macro.hrl").

-define(CMDMINLEN, 2).
-define(AC_CS_EXITCHATROOM, 30021).
-define(AC_CS_EXITCHATROOM_R, 60021).


-define(AC_SC_EXITCHATROOM, 22006).


%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_msgstamptime/1,get_sendfields_fromparam/2]).
-export([sendmsg_to_terminal/3]).

process_action(MsgID,Session,Action,Param)-> 
		 #session{sessionid=SessionID,userid=UserID,customcode=CustomCode,appcode =AppCode} = Session,	 
   Result =   parse_param(Param),
   case Result of
		 cmderror -> cmderror;
		   {ok,ChatRoomNo}->
			    {Reuslt,ToDataBase} = get_resultparam(Action,0,ChatRoomNo), 
                 process_exitroom(Session,Action,CustomCode,ChatRoomNo),
			      {ok,Reuslt,ToDataBase}
			  
  end.
get_sendfields_fromparam(_,Param)->
 Total = byte_size(Param),  
	 if 
		Total<?CMDMINLEN ->

			cmderror;
         true->
 		 	  <<ChatRoomNo:16/little>> = Param,

		  {chatroomno,ChatRoomNo}
     end.
get_msgstamptime(_)->{ok,0}.


%% ====================================================================
%% Internal functions
%% ====================================================================
get_resultparam(Action,Code,ChatRoomNo)
->
 
  
   Return = {?AC_CS_EXITCHATROOM_R,Code,<<"">>},
   ToDataBase =  {action,?AC_CS_EXITCHATROOM_R,code,Code,chatroomno,ChatRoomNo},
   {Return,ToDataBase}.


parse_param(Param)->
  Total = byte_size(Param),  
	  if 
		Total<?CMDMINLEN ->
			cmderror;
		 true->
		  <<ChatRoomNo:16/little>> = Param,
              {ok,ChatRoomNo}
      end.

process_exitroom(Session,Action,CustomCode,ChatRoomNo)
  ->
	 #session{sessionid=SessionID,userid=UserID} = Session,	 
     emipian_msg_log:clear_chat_session(SessionID,ChatRoomNo),
     srv_exitchatroom:process(Session,{UserID,ChatRoomNo}).

sendmsg_to_terminal(SenderSession,ChatRoomNo,Value)->
	#session{userid =UserID} = SenderSession,
	PeerSessionID = emipian_msg_log:getfieldvalue(Value, sessionid),
    PeerSession = emipian_sm:get_session(PeerSessionID),
	#session{selfpid =PeerPID} = PeerSession,
    SenderData = get_sendmessagedata(ChatRoomNo,UserID),
       try	 
           PeerPID ! {msg,?AC_SC_EXITCHATROOM,<<"">>,0,SenderData}
          catch
	        _:_->ok 
        end.

get_sendmessagedata(ChatRoomNo,UserID)->
 	Dict = dict:new(),
	Dict1 =  dict:store("userid", UserID,Dict),
	AddtionJson0= list_to_binary(rfc4627:encode(Dict1)),
    AddtionJsonLen0 = byte_size(AddtionJson0),
  <<ChatRoomNo:16/little,AddtionJsonLen0:32/little,AddtionJson0/binary>>. 



get_timeout()->
  case emipian_meet:get_meeting(timeout) of
    not_found-> 120000;
    Value ->Value
  end.
   





