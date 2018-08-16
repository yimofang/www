%% @author hyf
%% @doc @todo Add description to mod_action_getchatroom.


-module(mod_action_getchatroom).

-include(  "session.hrl").
-include("errorcode.hrl").
-include("logger.hrl").
 -include("macro.hrl").

-define(CMDMINLEN, 2).
-define(AC_CS_GETCHATROOM, 30022).
-define(AC_CS_GETCHATROOM_R, 60022).


-define(AC_SC_GETCHATROOM, 22005).


%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_msgstamptime/1,get_sendfields_fromparam/2]).
-export([sendmsg_to_terminal/3,get_resultparam/4]).

process_action(MsgID,Session,Action,Param)-> 
		 #session{sessionid=SessionID,userid=UserID,customcode=CustomCode,appcode =AppCode} = Session,	 
   Result =   parse_param(Param),
   case Result of
		 cmderror -> cmderror;
		   {ok,ChatRoomNo}->
                     process_getroom(Session,Action,CustomCode,ChatRoomNo),
			         {waitmsg}
					 %%   {ok,Reuslt,ToDataBase}
  end.

get_sendfields_fromparam(_,Param)->
 Total = byte_size(Param),  
	 if 
		Total<?CMDMINLEN ->
				 ?INFO_MSG("Get Chatroom get_sendfields_fromparam error:~p-~p ~n.", [Total,Param]),	 

			cmderror;
         true->
 		 	  <<ChatRoomNo:16/little>> = Param,

		  {chatroomno,ChatRoomNo}
     end.


get_msgstamptime(_)->{ok,0}.


%% ====================================================================
%% Internal functions
%% ====================================================================
get_resultparam(Action,Code,Count,ChatRoomNo)
->
   Return = {?AC_CS_GETCHATROOM_R,Code,<<ChatRoomNo:16/little,Count:16/little>>},
   ToDataBase =  {action,?AC_CS_GETCHATROOM_R,code,Code,chatroomno,ChatRoomNo},
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

process_getroom(Session,Action,CustomCode,ChatRoomNo)
  ->
	 #session{sessionid=SessionID,userid=UserID,selfpid=PID} = Session,	 
  %%   {Reuslt,ToDataBase} = get_resultparam(Action,0,ChatRoomNo),
	 %% {ActionResult,ToDabase}  = get_resultparam(Action,0,ChatRoomNo),
    %% PID!{result,Action,<<"">>,{ok,ActionResult,ToDabase}},
				 ?INFO_MSG("Enter srv_getchatroom :~p-~p ~n.", [ChatRoomNo,UserID]),	 

	 srv_getchatroom:process(Session,{Action,UserID,ChatRoomNo}).
sendmsg_to_terminal(SenderSession,ChatRoomNo,Value)->
	#session{selfpid =PID,userid =UserID} = SenderSession,
	PeerSessionID = emipian_msg_log:getfieldvalue(Value, sessionid),
    PeerSession = emipian_sm:get_session(PeerSessionID),
	if PeerSession=:=not_found ->
		   PeerUserID = <<"">>;
	    
	   true->
	#session{userid =PeerUserID} = PeerSession,
		PeerNickName = emipian_msg_log:getfieldvalue(Value, nickname),
        ReceiverData = get_sendmessagedata(ChatRoomNo,PeerUserID,PeerNickName),
       try	 
           PID ! {msg,?AC_SC_GETCHATROOM,<<"">>,0,ReceiverData}
          catch
	        _:_->ok 
        end
    end.



get_sendmessagedata(ChatRoomNo,UserID,NickName)->
 	Dict = dict:new(),
	Dict1 =  dict:store("userid", UserID,Dict),
	Dict2 = dict:store("nickname", NickName,Dict1),

	AddtionJson0= list_to_binary(rfc4627:encode(Dict2)),
    AddtionJsonLen0 = byte_size(AddtionJson0),
  <<ChatRoomNo:16/little,AddtionJsonLen0:32/little,AddtionJson0/binary>>. 



get_timeout()->
  case emipian_meet:get_meeting(timeout) of
    not_found-> 120000;
    Value ->Value
  end.