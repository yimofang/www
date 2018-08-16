%% @author hyf
%% @doc @todo Add description to emipian_timer_chatroom.


-module(emipian_timer_chatroom).

-include("session.hrl").
-include("macro.hrl").
-include("logger.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-record(state, {timeout,interval}).
-export([init/1,handle_info/2,start_link/2]).

-export([processchatroom/1]).



start_link(IntervalTime,Timeout) ->
    gen_server:start_link(?MODULE,
			  [IntervalTime,Timeout], []).
init([IntervalTime,Timeout])->

	{ok, #state{interval=IntervalTime,timeout=Timeout},Timeout}.


handle_info(timeout,State )->
	#state{interval=IntervalTime,timeout = TimeOut} =State ,
    processchatroomtimeout(IntervalTime),
    {noreply,State,TimeOut}.


processchatroomtimeout(IntervalTime)->
 Result = emipian_msg_log:get_invalide_chatroom_client(IntervalTime),

 case Result of
	not_found->ok;
	 _->
	process(Result),
	processchatroomtimeout(IntervalTime)

 end.	 
 
processchatroom(SessionID)->
 Result = emipian_msg_log:get_chatroom_from_sessionid(SessionID),

 case Result of
	not_found->ok;
	 _->
	processes(Result)
 end.

processes([])->ok;
processes([H|T])->
	process(H),
	processes(T).
	
process(Result)->
  SessionID = emipian_util:lookuprecordvalue(sessionid, Result),
  UserID = emipian_util:lookuprecordvalue(userid, Result),
  ChatRoomNo = emipian_util:lookuprecordvalue(chatroomno, Result),

%%  emipian_msg_log:delete_chatroom_chat(SessionID, ChatRoomNo),
  emipian_msg_log:clear_chat_session(SessionID,ChatRoomNo),
  case emipian_msg_log:chatroom_user_online(UserID, ChatRoomNo) of
  not_found->
	  SenderSession = emipian_sm:get_session(SessionID),  

		srv_exitchatroom:process(SenderSession, {UserID,ChatRoomNo}),
	  ok;
	_->ok  
  end.



