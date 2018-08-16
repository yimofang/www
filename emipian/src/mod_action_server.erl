%% @author hyf
%% @doc @todo Add description to emipian_action_server.


-module(mod_action_server).

-include("session.hrl").
-include("action.hrl").
-include("macro.hrl").
-include("errorcode.hrl").
-include("logger.hrl").


-define(AC_SS_SERVER,     71099).
-define(AC_SC_SINGLESYSMSG, 21004).
-define(CMDMINLEN, 30).
-define(AC_CS_SERVER_R,   71099).




%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,start/0,get_sendfields_fromparam/2,
		 get_msgstamptime/1
          ]).


-export([
		 sendmsg_to_terminal/9
		, sendmsg_to_user/6
          
		]).

%% ====================================================================
%% Internal functions
%% ====================================================================

start() ->ok.
%% ====================================================================
%% Must implement API or action
%%
%%
%% ====================================================================

process_action(MsgID,_Session,Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,StartTime,EndTime,ReceiversLen,Receivers,ContentsLen,Contents,APNSLen,APNS}->
         SessionID = <<"">>,
		 MsgTime = emipian_msg_log:get_msgtime(MsgID),
         SenderUserID = ?SYSTEMID,
		 send_msg(SenderUserID,?AC_SC_SINGLESYSMSG,StampTime,MsgID,Receivers,Contents,APNS,MsgTime),
	%%	 {Reuslt,ToDataBase} = get_resultparam(Action,0,StampTime,MsgID),	
	%%	 {ok,Reuslt,ToDataBase}
       {noresp,ok}
	  end.

%% ====================================================================
%% get result record for save DB
%% ====================================================================



%% get Send record for save DB

get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	    {ok,StampTime,StartTime,EndTime,ReceiversLen,Receivers,ContentsLen,Contents,APNSLen,APNS}->
	   {stamptime,StampTime,starttime,StartTime,endtime,EndTime,receiverslen,ReceiversLen,receivers,Receivers,contentslen,ContentsLen,
		content,Contents,apnslen,APNSLen,apns,APNS}
     end.

get_msgstamptime(Param)->
	 Total = byte_size(Param),  
	 if
 	 Total<?CMDMINLEN ->cmderror;
	 true-> <<StampTime:64/little,_/binary>> = Param,
			{ok,StampTime}
	 end.


  
%% ====================================================================
%% pasre param
%% return
%% {ok,ReceiverLen,Receivers,ContentLen,Content}|cmderror
%% 
%% 
%%
%%
%% ====================================================================

parse_param(Param)->
  Total = byte_size(Param),  
  if 
		Total<?CMDMINLEN->cmderror;
		 true->
    <<StampTime:64/little,StartTime:64/little,EndTime:64/little,ReceiversLen:32/little,Rest/binary>> = Param,
         %%   <<StampTime:64/little,ReceiversLen:32/little,Rest/binary>> = Param,
		      Len1 = byte_size(Rest),
			  if
				 Len1<ReceiversLen+4 -> cmderror;
				 true->
 		              <<Receivers:ReceiversLen/binary,ContentsLen:32/little,Rest1/binary>> = Rest,
		              Len2 = byte_size(Rest1),
					  if 
						 Len2<ContentsLen+4 -> cmderror;
						 true->
 		                      <<Contents:ContentsLen/binary,APNSLen:32/little,Rest2/binary>> = Rest1,
					           if 
								  APNSLen>0 -> 
					                  Len3 = byte_size(Rest2),
							          if 
						                 Len3<APNSLen -> cmderror;
						                true->
 		                                  <<APNS:APNSLen/binary,_Rest0/binary>> = Rest2,
                                         {ok,StampTime,StartTime,EndTime,ReceiversLen,Receivers,ContentsLen,Contents,APNSLen,APNS}
								      end;
                                  true-> APNS = <<"">>,
                                         {ok,StampTime,StartTime,EndTime,ReceiversLen,Receivers,ContentsLen,Contents,APNSLen,APNS}
                               end
					  end
			  end 
  end.
	  
 

sendmsg_to_terminal(Action,MsgID,SynNo1,Param,Session,_,MsgTime,_,AddtionInfo)->
	 #session{lang=Lang,userid=ReceiveUserID} = Session,
	%% #actionparam{content=Contents}  = Param,
	 Contents = emipian_util:lookuprecordvalue(content, Param),
     Content = get_sendcontentdata(Contents,Lang),
	   SenderUserID = ?SYSTEMID,
	 case Content of
		  cmderror->cmderror; 
		  _->
		    Content1= list_to_binary(Content),	  
		      case save_userreceiver(MsgID,ReceiveUserID,MsgTime) of
	          {ok,SynNo} ->
			    Data =  get_sendmessagedata(MsgID,SenderUserID,Content1,SynNo,MsgTime),
	            emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,yes),
	            sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content1);
			   {duplicate,SynNo} ->
				     case SynNo1 of
						 -1->ok;
						 _->
						    Data =  get_sendmessagedata(MsgID,SenderUserID,Content1,SynNo,MsgTime),
				            emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,yes),
				            sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content1)
					  end;		 
			  _->ok
			  end
			%%   sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,no)
	 end.


%% ====================================================================
%% 将接收者存到数据库中
%%
%% return
%% {ok,ReceiverLen,Receivers,ContentLen,Content}|cmderror

%% ====================================================================
 
save_userreceiver(MsgID,UserID,MsgTime)->
   emipian_msg_log:save_userreceiver(MsgID, UserID,0,?SYSTEMID,MsgTime,{},0).





sendmsg_to_user(MsgID,SenderUserID,Receiver,Contents,APNS,MsgTime)->
  case save_userreceiver(MsgID,Receiver,MsgTime) of
		  {duplicate,_}->ok;
	  {ok,SynNo} ->
        Sessions =  emipian_sm:get_usersession(<<"">>, Receiver),
	    sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,Sessions,Contents,APNS)
   end. 

sendmsg_to_terminals(_,_,_,_,[],_,_)
   ->ok;
sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,[Session|T],Contents,APNS)->
	 #session{lang=Lang} = Session,
   try
	 Content = get_sendcontentdata(Contents,Lang),
	 case Content of
	  cmderror->cmderror; 
	  _->
	  Content1= list_to_binary(Content),	  
	 Data =  get_sendmessagedata(MsgID,SenderUserID,Content1,SynNo,MsgTime),
	  emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,yes),
	 sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content1,APNS), 
     sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,T,Contents,APNS)
    end
   catch
     _:_->ok
  end.


sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content,APNS)->
     #session{selfpid=PID,status =Status,sessionid =SessionID,userid=UserID} = Session,
      ?INFO_MSG("mod_action_server Send:~p,SelfPid:~p,Status:~p,SessionID:~p ~n", [UserID,PID,Status,SessionID]),
 	  if 
		 Status =:=?STATUS_ONLINE ->
         emipian_route:sendmsg(Session, {msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data});

       true->ok
       end,
     APNSLen =byte_size(APNS),
	 if APNSLen>0 ->
	  emipian_apns:sendapns(Session,APNS,SenderUserID);
	  true->ok
     end.
 %%   end.

%% ====================================================================
%% 组装发送数据
%% ====================================================================



 get_sendmessagedata(MsgID,SenderUserID,Content,SynNo,MsgTime)->
  ContentLength = byte_size(Content),
  MsgID1 = emipian_util:str_to_binayid(MsgID),
  SenderUserID1 = emipian_util:str_to_binayid(SenderUserID),
  
  <<MsgID1:40/binary,SynNo:32/little,SenderUserID1:40/binary,MsgTime:64/little, 
	ContentLength:32/little, Content/binary>>. 

get_sendcontentdata(Contents,Lang)->
   case rfc4627:decode(Contents) of
	  {ok,Contents1,_} -> 
		  Content = get_content(Contents1,Lang),
	      Content;
      _->cmderror 
	end.

get_content(Contents,Lang)->
	
	Content1 = get_langcontent(Contents,Lang),
	case Content1 of
	   no->
		   Content2 = get_langcontent(Contents,1),
		   case Content2 of
			no->
 		        Content3 = get_langcontent(Contents,0),
				case Content3 of
				     no->
						 [Content4|_] =Content3,
						 Content4;
				     cmderror->cmderror;
                     _->Content3
				end;	
   		     cmderror->cmderror;
			  _-> Content2
		   end;	   
		cmderror->cmderror;
		_->Content1
    end.     
	
	
get_langcontent([],_)->
	no;
get_langcontent([Content|T],Lang)->
   CLang = rfc4627:get_field(Content, "lang"),	
   case CLang of
	   not_found->
		 if
			 Lang=:=0->rfc4627:encode(Content);
			true->
			 get_langcontent(T,Lang)
		 end;
       {ok,Lang} ->rfc4627:encode(Content);
	   _-> get_langcontent(T,Lang)
   end.
	






	 
sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content)->
     #session{selfpid=PID,status =Status} = Session,
	 try
					 emipian_route:sendmsg(Session,{msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data})
 
   %%  PID ! {msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data}
	 catch
		 _:_->ok 
	  end.

send_msg(SenderUserID,Action,StampTime,MsgID,Receivers,Content,APNS,MsgTime)->

%%	emipian_msg_log:save_userreceiver(MsgID, SenderUserID,?CHATSTATUS_ONLY_REC,SenderUserID,StampTime,{},?CHATSTYPE_GROUP),
	srv_server:processsrv
	   (SenderUserID,{Action,StampTime,MsgID,Receivers,Content,APNS,MsgTime}),
	ok.

get_resultparam(Action,Code,StampTime,MsgID)->

   MsgID1 = emipian_util:str_to_binayid(MsgID),
   Return = {Action,Code,<<StampTime:64/little,MsgID1/binary>>},
   ToDataBase = 	
   if
	 Code=:=0 ->
   	 {action,Action,code,Code};
   	 true->{action,Action,code,Code}
   end,
   {Return,ToDataBase}.


getAPNSData(Content)
  ->Content.


