%% @author hyf
%% @doc @todo Add description to mod_action_enterchatromm.


-module(mod_action_enterchatroom).

-include(  "session.hrl").
-include("errorcode.hrl").
-include("logger.hrl").
 -include("macro.hrl").

-define(CMDMINLEN, 2).
-define(AC_CS_ENTERCHATROOM, 30020).
-define(AC_CS_ENTERCHATROOM_R, 60020).


-define(AC_SC_ENTERCHATROOM, 22005).


%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,get_msgstamptime/1,get_sendfields_fromparam/2]).
-export([sendmsg_to_terminal/4]).

process_action(MsgID,Session,Action,Param)-> 
		 #session{sessionid=SessionID,userid=UserID,customcode=CustomCode,appcode =AppCode} = Session,	 
   Result =   parse_param(Param),
   case Result of
		 cmderror -> cmderror;
		   {ok,ChatRoomNo}->
                  NickName = emipian_mysqldb:getusernickname(UserID, AppCode),
                  if 
		             is_integer(NickName) -> 
			         {Reuslt,ToDataBase} = get_resultparam(Action,NickName,ChatRoomNo), 
			         {ok,Reuslt,ToDataBase};
                    true-> 

			      %%   {Reuslt,ToDataBase} = get_resultparam(Action,0,ChatRoomNo), 
                     process_enterroom(Session,Action,CustomCode,NickName,ChatRoomNo),
			         {waitmsg}
					 %%   {ok,Reuslt,ToDataBase}
			  end  
  end.

get_sendfields_fromparam(_,Param)->
 Total = byte_size(Param),  
	 if 
		Total<?CMDMINLEN ->
				 ?INFO_MSG("Dail get_sendfields_fromparam error:~p-~p ~n.", [Total,Param]),	 

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

  
   Return = {?AC_CS_ENTERCHATROOM_R,Code,<<"">>},
   ToDataBase =  {action,?AC_CS_ENTERCHATROOM_R,code,Code,chatroomno,ChatRoomNo},
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

process_enterroom(Session,Action,CustomCode,NickName,ChatRoomNo)
  ->
	 #session{sessionid=SessionID,userid=UserID,selfpid=PID} = Session,	 
     
	 emipian_msgdb:save_client_chatroom(SessionID,UserID,NickName,ChatRoomNo),
  %%   {Reuslt,ToDataBase} = get_resultparam(Action,0,ChatRoomNo),
	 {ActionResult,ToDabase}  = get_resultparam(Action,0,ChatRoomNo),
     PID!{result,Action,<<"">>,{ok,ActionResult,ToDabase}},
	 srv_enterchatroom:process(Session,{UserID,NickName,ChatRoomNo}).
sendmsg_to_terminal(SenderSession,ChatRoomNo,NickName,Value)->
	#session{selfpid =PID,userid =UserID} = SenderSession,
    SenderData = get_sendmessagedata(ChatRoomNo,UserID,NickName),

	PeerSessionID = emipian_msg_log:getfieldvalue(Value, sessionid),
    PeerSession = emipian_sm:get_session(PeerSessionID),
	if PeerSession=:=not_found ->
		   PeerUserID = <<"">>,
		   PeerPID = not_found;
	    
	   true->
	   #session{selfpid =PeerPID,userid =PeerUserID} = PeerSession,
	   PeerNickName = emipian_msg_log:getfieldvalue(Value, nickname),
        ReceiverData = get_sendmessagedata(ChatRoomNo,PeerUserID,PeerNickName),
       try	 
           PID ! {msg,?AC_SC_ENTERCHATROOM,<<"">>,0,ReceiverData},
           PeerPID ! {msg,?AC_SC_ENTERCHATROOM,<<"">>,0,SenderData}
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
   


