%% @author hyf
%% @doc @todo Add description to emipian_auto.


-module(emipian_auto).

%% ====================================================================
%% API functions
%% ====================================================================
-export([process/3,handle_action/3]).

-export([send_user_nosendmessage/3]).


-include("session.hrl").
-include("macro.hrl").
-include("logger.hrl").

%% ====================================================================
%% Internal functions
%% ====================================================================
-define(AC_SC_KICK, 22001).
-define(COUNT_PER_PAGE, 100).


process(SelfPID,Session,Data) ->

    spawn(?MODULE,handle_action,[SelfPID,Session,Data]). 


      

handle_action(PrePid,Session,PreMsgID) -> 
    #session{userid=UserID,termialname=TermialName1,appos=AppOS,appcode=AppCode,
			 customcode=CustomCode}=Session,
TermialName = emipian_util:str_to_binayid(TermialName1,32),
	try
		kicksameternimal(Session,PreMsgID,AppOS,AppCode,CustomCode,TermialName),
	    send_message_terminal(Session),
	    send_message_user(Session,0),
		send_sysmessage_user(Session,0)
	after

    emipian_sm:updatesessionstatus(Session, ?STATUS_ONLINE),
	Session1 =Session#session{status = ?STATUS_ONLINE},
    PrePid !{session,Session1}
     end,
	 send_tel(Session),
	 exit(normal).   


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 寻找需要踢出的终端用户
%% 原则：同一个CustomCode，同一个AppCode 手机手机之允许一个，PC一个
%%
%%
%%

kicksameternimal(Session,PreMsgID,AppOS,AppCode,CustomCode,TermialName)->
	Sessions = emipian_sm:searchsameterminal(Session),
    kickternimals(Sessions,PreMsgID,AppOS,AppCode,CustomCode,TermialName),
   ok.
kickternimals([],_,_,_,_,_) -> ok;

kickternimals([Session|T],PreMsgID,AppOS,AppCode,CustomCode,TermialName) ->
	#session{selfpid=PID,sessionid =SessionID} = Session,
	
	MsgID =emipian_util:get_uuid(),
	Param = {premsgid,PreMsgID},
	emipian_msg_log:save_sc_msg_log(MsgID, Session, ?AC_SC_KICK, Param),
	case PID of
		not_found ->
			emipian_sm:close_session(SessionID, 0, 0);
	   _-> 

		   case   erlang:is_process_alive(PID) of
			 true ->	   
				 Data = <<AppCode:8/little,AppCode:16/little,CustomCode:16/little,TermialName/binary>>, 
	             PID ! {kick,?AC_SC_KICK,MsgID,Data};
		    _->emipian_sm:close_session(SessionID, 0, 0)
		end
    end,
	kickternimals(T,PreMsgID,AppOS,AppCode,CustomCode,TermialName),
 ok.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% 发送没有发送给该终端的信息
%% 
%%
%%
%%
send_tel(Session)->
		#session{userid=UserID} = Session,
	    Result = emipian_msg_log:find_no_sendtel(UserID),
		send_one(Session,Result).

send_one(_Session,[])
  ->ok;
send_one(Session,[H|T])->
   mod_action_dial:sendmsg_to_terminal(Session, H),
    send_next(T).

send_next([])->ok;
send_next([H|T]) ->
  
	MsgID = emipian_msg_log:getfieldvalue(H, msgid),
	SenderSessionID = emipian_msg_log:getfieldvalue(H, sendersessionid),
	mod_action_replydial:sendmsg_status(MsgID, SenderSessionID, ?HANG_STATUS_CS),
	send_next(T)
  .

send_message_terminal(Session)->
	send_message_terminal(Session,0).

send_message_terminal(Session,Start)->
	#session{sessionid=SessionID} = Session,
	Result = emipian_msg_log:find_ternimal_no_sendmsg(SessionID, Start, ?COUNT_PER_PAGE),

	case Result of
     [] ->ok;
     H ->send_ternimal_nosendmessage(H,Session,Start)
    end.


send_ternimal_nosendmessage([],Session,Start)->
  send_message_terminal(Session,Start+?COUNT_PER_PAGE);

send_ternimal_nosendmessage([H|T],Session,Start)->
	 MsgID = emipian_msg_log:getfieldvalue(H, msgid),
	 RevID = emipian_msg_log:getfieldvalue(H, recvid),
	 send_terminalmessage(Session,MsgID,RevID),
	send_ternimal_nosendmessage(T,Session,Start).

send_terminalmessage(Session,MsgID,RevID) ->
 case emipian_msg_log:get_sendmsg(MsgID) of
	 not_found->ok;
	 Value ->
			 Action =       emipian_msg_log:getfieldvalue(Value, action),
			 Param  =       emipian_msg_log:getfieldvalue(Value, param),
			 MsgTime0  =    emipian_msg_log:getfieldvalue(Value, sendtime),
			 MsgTime   =    emipian_util:get_mstime(MsgTime0),
			 Senderinfo =   emipian_msg_log:getfieldvalue(Value, senderinfo),
		     SenderUserID = emipian_msg_log:getfieldvalue(Senderinfo, userid),
			 Result = emipian_msg_log:getfieldvalue(Value, result),
			 AddtionInfo =
			 try
			   emipian_msg_log:getfieldvalue(Result,addtioninfo)
			 catch
				 _:_->{}
		     end,		 
			 
		     gen_action_mod:sendmsg_to_terminal(Action, MsgID, RevID, Param,
									    Session, SenderUserID, MsgTime,1,0,AddtionInfo,yes),		 
      ok
  end. 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 发送没有发送给该用户的信息
%%%
send_message_user(Session,Start)->
	#session{userid=UserID,sessionid=SessionID} = Session,
	Result = emipian_msg_log:find_user_no_sendmsg(UserID, Start, ?COUNT_PER_PAGE),

	case Result of
     [] ->
		 ok;
     H ->send_user_nosendmessage(H,Session,Start)
    end.

send_user_nosendmessage([],Session,Start)
  -> ok;
	%% send_message_user(Session,Start+?COUNT_PER_PAGE);
send_user_nosendmessage([Data|T],Session,Start)->

	 MsgID = emipian_msg_log:getfieldvalue(Data, msgid),
	 NewID  = emipian_msg_log:getfieldvalue(Data, recvid),

	 case emipian_msg_log:get_sendmsg(MsgID) of
		 not_found->ok;
		 Value-> 
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
			 
		     gen_action_mod:sendmsg_to_terminal(Action, MsgID, NewID, Param,
									    Session, SenderUserID, MsgTime,1,0,AddtionInfo,no)
      end,
	 send_user_nosendmessage(T,Session,Start).
	 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 发送没有发送给该用户的系统信息
%%%
send_sysmessage_user(Session,Start)->
	#session{userid=UserID} = Session,
	Result = emipian_msg_log:find_sys_sendmsg(Session,Start, ?COUNT_PER_PAGE),
	    ?INFO_MSG("send_sysmessage_user ~p ~n", [Result]),

	case Result of
     [] ->ok;
     H ->send_user_nosendsysmessage(H,Session,Start)
    end.


send_user_nosendsysmessage([],Session,Start)
  ->ok;
%% send_sysmessage_user(Session,Start+?COUNT_PER_PAGE);
send_user_nosendsysmessage([Data|T],Session,Start)->
       	     MsgID = emipian_msg_log:getfieldvalue(Data, msgid),
			 Action =emipian_msg_log:getfieldvalue(Data, action),
			 Param  = emipian_msg_log:getfieldvalue(Data, param),
			 MsgTime0  = emipian_msg_log:getfieldvalue(Data, sendtime),
			 MsgTime   = emipian_util:get_mstime(MsgTime0),
			 Result = emipian_msg_log:getfieldvalue(Data, result),
			 AddtionInfo = if Result=:=not_found -> not_found;
			            true-> emipian_msg_log:getfieldvalue(addtional, Result)
						 end,  
			 gen_action_mod:sendmsg_to_terminal(Action, MsgID, -1, Param,
									    Session, <<>>, MsgTime,1,0,AddtionInfo,no),
	 send_user_nosendsysmessage(T,Session,Start).


  








