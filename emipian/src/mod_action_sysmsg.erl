%% @author hyf
%% @doc @todo Add description to mod_action_srvmsg.


-module(mod_action_sysmsg).


-include("session.hrl").
-include("action.hrl").
-include("macro.hrl").
-include("errorcode.hrl").
-include("logger.hrl").

-define(AC_SS_SINGLEMSG, 70001).

-define(AC_SC_SINGLESYSMSG, 21004).
-define(CMDMINLEN, 20).




%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,start/0,get_sendfields_fromparam/2,
		 get_msgstamptime/1
          ]).


-export([
		 sendmsg_to_terminal/9
          
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

process_action(MsgID,Session,Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,_,_,_,Receivers,_,Contents}->
%%		 #session{sessionid=SessionID,userid=SenderUserID} = Session,
         SessionID = <<"">>,
         SenderUserID = ?SYSTEMID,
         MsgTime = emipian_msg_log:get_msgtime(MsgID),
		  case rfc4627:decode(Receivers) of
			 {ok,Receivers1,_} -> 
		      sendmsg_to_users(SessionID,MsgID,SenderUserID,Contents,MsgTime,Receivers1),		 
		      {noresp,ok};
             _->
			  {noresp,terminate}
           end
	  end.

%% ====================================================================
%% get result record for save DB
%% ====================================================================



%% get Send record for save DB

get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	   {ok,StampTime,ValidTime,ReceiverLen,Receivers,ContentLen,Content}->
	    EndTime =emipian_util:addtime(os:timestamp(), ValidTime*60*1000), 	   
	   {stamptime,StampTime,validtime,ValidTime,receiverlen,ReceiverLen,endtime,EndTime,
		receivers,Receivers,contentlen,ContentLen,content,Content}
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
	          <<StampTime:64/little,ValidTime:32/little,ReceiverLen:32/little,Rest/binary>> = Param,
		      Len1 = byte_size(Rest),
			  if
				 Len1<ReceiverLen+4 -> cmderror;
				 true->
 		              <<Receivers:ReceiverLen/binary,ContentLen:32/little,Content/binary>> = Rest,
		              Len2 = byte_size(Content),
					  if 
						Len2=/=ContentLen   -> cmderror;
						 true->{ok,StampTime,ValidTime,ReceiverLen,Receivers,ContentLen,Content}
                       end
			  end		 
  end.
 

sendmsg_to_terminal(Action,MsgID,SynNo,Param,Session,SenderUserID,MsgTime,_,AddtionInfo)->
	 #session{lang=Lang} = Session,
	%% #actionparam{content=Contents}  = Param,
   try
	 Contents = emipian_util:lookuprecordvalue(content, Param),
     Content = get_sendcontentdata(Contents,Lang),
	 case Content of
		  cmderror->cmderror; 
		  _->
		    Content1= list_to_binary(Content),	  
			Data =  get_sendmessagedata(MsgID,SenderUserID,Content1,SynNo,MsgTime),
			 sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,no)
	 end
   catch
	  _:_->ok 
	 end.  


%% ====================================================================
%% 将接收者存到数据库中
%%
%% return
%% {ok,ReceiverLen,Receivers,ContentLen,Content}|cmderror

%% ====================================================================
 
save_userreceiver(MsgID,UserID,MsgTime)->
   emipian_msg_log:save_userreceiver(MsgID, UserID,0,?SYSTEMID,MsgTime,{},0).	

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
%% {_,Content1}	= Content,
  
 %% case rfc4627:decode(Content1) of
	%%   {ok,Obj,_} -> 
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
  %% end.			   
	

sendmsg_to_user(SessionID,MsgID,SenderUserID,Contents,MsgTime,ReceiveUserID)->
  case save_userreceiver(MsgID,ReceiveUserID,MsgTime) of
		  {duplicate,_}->ok;
	  {ok,SynNo} ->
        Sessions =  emipian_sm:get_usersession(SessionID, ReceiveUserID),
	    sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,Sessions,Contents)
   end. 

sendmsg_to_terminals(_,_,_,_,[],_)
   ->ok;
sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,[Session|T],Contents)->
	 #session{lang=Lang} = Session,
   try
	 Content = get_sendcontentdata(Contents,Lang),
	 case Content of
	  cmderror->cmderror; 
	  _->
	  Content1= list_to_binary(Content),	  
	 Data =  get_sendmessagedata(MsgID,SenderUserID,Content1,SynNo,MsgTime),
	  emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,yes),
	 sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content1), 
     sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,T,Contents)
    end
   catch
     _:_->ok
  end.


sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content)->
     #session{selfpid=PID,status =Status,sessionid =SessionID,userid=UserID} = Session,
      ?INFO_MSG("mod_action_sysmsg Send:~p,SelfPid:~p,Status:~p,SessionID:~p ~n", [UserID,PID,Status,SessionID]),
 	  if 
		 Status =:=?STATUS_ONLINE ->
         emipian_route:sendmsg(Session, {msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data});

       true->ok
       end,
    case Content of
	 no ->ok;	
     _-> 
		 	Sender101 = <<"">>, 
        emipian_apns:sendapns(Session,getAPNSData(Content),SenderUserID,Sender101)
    end.
	 
sendmsg_to_terminalcx(MsgID,SynNo,SenderUserID,Session,Data,Content)->
     #session{selfpid=PID,status =Status} = Session,
         emipian_route:sendmsg(Session, {msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data}).
sendmsg_to_users(_,_,_,_,_,[])->ok;

sendmsg_to_users(SessionID,MsgID,SenderUserID,Content,MsgTime,
				 [ReceiveUserID|RestUserUserID])->
    sendmsg_to_user(SessionID,MsgID,SenderUserID,Content,MsgTime,ReceiveUserID),
	sendmsg_to_users (SessionID,MsgID,SenderUserID,Content,MsgTime,RestUserUserID).

getAPNSData(Content)
  ->Content.