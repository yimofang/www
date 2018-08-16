%% @author hyf
%% @doc @todo Add description to mod_action_sysmutimsg.


-module(mod_action_sysmutimsg).


-include("session.hrl").
-include("action.hrl").
-include("macro.hrl").
-include("errorcode.hrl").
-include("logger.hrl").


-define(AC_SS_MUTIMSG,   71001).
-define(AC_SC_SINGLESYSMSG, 21004).
-define(CMDMINLEN, 30).



%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/4,start/0,get_sendfields_fromparam/2,
		 get_msgstamptime/1
          ]).


-export([
		 sendmsg_to_terminal/9
		, sendmsg_to_user/5
          
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

process_action(MsgID,_Session,_Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,StampTime,_StartTime,_EndTime,_ContentLen,Content,{Os,CCode,ACode,_OnLine}}->
%%		 #session{sessionid=SessionID,userid=SenderUserID} = Session,
         SessionID = <<"">>,
         SenderUserID = ?SYSTEMID,
         MsgTime = emipian_msg_log:get_msgtime(MsgID),
		 
%%		Sessions = emipian_sm:searchconditionterminal({Os,CCode,ACode}),
%%		sendmsg_to_user(SessionID,MsgID,SenderUserID,Content,MsgTime, Sessions),
		 send_msg(SenderUserID,?AC_SC_SINGLESYSMSG,StampTime,MsgID,Content,{Os,CCode,ACode}),
	    {noresp,ok}
	  end.

%% ====================================================================
%% get result record for save DB
%% ====================================================================



%% get Send record for save DB

get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	    {ok,StampTime,StartTime,EndTime,ContentLen,Content,{Os,CCode,ACode,OnLine}}->
%%	    EndTime =emipian_util:addtime(os:timestamp(), ValidTime*60*1000), 	   
	   {stamptime,StampTime,starttime,StartTime,endtime,EndTime,
		receivers,{appos,Os,customcode,CCode,appcode,ACode,online,OnLine},contentlen,ContentLen,content,Content}
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
	          <<StampTime:64/little,StartTime:64/little,EndTime:64/little,ReceiverLen:32/little,Rest/binary>> = Param,
		      Len1 = byte_size(Rest),
			  if
				 Len1<ReceiverLen+4 -> cmderror;
				 true->
 		              <<Receivers:ReceiverLen/binary,ContentLen:32/little,Rest2/binary>> = Rest,
		              Len2 = byte_size(Rest2),
					  if 
						Len2<ContentLen   -> cmderror;
						true ->
						   <<Content:ContentLen/binary,_/binary>> = Rest2,
		                    case rfc4627:decode(Receivers) of
							{ok,Receivers0,_} ->
								  Os0 = rfc4627:get_field(Receivers0, "appos"),	
								  CCode0 = rfc4627:get_field(Receivers0, "customcode"),	
								  ACode0 = rfc4627:get_field(Receivers0, "appcode"),	
								  OnLine0 = rfc4627:get_field(Receivers0, "online"),	
								  
	  
							  	  Os = case Os0 of
									   {ok,V1} ->V1;
										   _->-1
								      end,
	
								  ACode =case ACode0 of
									   {ok,V2} ->V2;
										   _->-1
								         end,
								  CCode = case  CCode0 of
									   {ok,V3} ->V3;
										   _->-1
								          end,
								  OnLine =case  OnLine0 of
									   {ok,V4} ->V4;
										   _->-1
								          end,								  
					                ?INFO_MSG("Os,CCode,ACode,OnLine  ~p,~p,~p,~p ~n", [Os,CCode,ACode,OnLine ]),
		  
								 {ok,StampTime,StartTime,EndTime,ContentLen,Content,{Os,CCode,ACode,OnLine}};
								_->cmderror
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
	
sendmsg_to_user(_,_,_,_,[])->ok;
sendmsg_to_user(MsgID,SenderUserID,Contents,MsgTime,[Session|T])->
%%  #session{userid=ReceiveUserID} = Session,

	#session{userid=ReceiveUserID} = Session,  

   case save_userreceiver(MsgID,ReceiveUserID,MsgTime) of
	   {_,SynNo} ->
	    sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,[Session],Contents)
   end,
    sendmsg_to_user(MsgID,SenderUserID,Contents,MsgTime,T).

sendmsg_to_terminals(_,_,_,_,[],_)
   ->ok;
sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,[Session|T],Contents)->
	 #session{lang=Lang} = Session,
	 Content = get_sendcontentdata(Contents,Lang),
	 case Content of
	  cmderror->cmderror; 
	  _->
	  Content1= list_to_binary(Content),	  
	 Data =  get_sendmessagedata(MsgID,SenderUserID,Content1,SynNo,MsgTime),
	 emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,yes),
	 sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content1), 
     sendmsg_to_terminals(MsgID,SynNo,SenderUserID,MsgTime,T,Contents)
    end.


sendmsg_to_terminal(MsgID,SynNo,SenderUserID,Session,Data,Content)->
     #session{selfpid=PID,status =Status} = Session,
 	  if 
		 Status =:=?STATUS_ONLINE ->
		 try
			 emipian_route:sendmsg(Session,{msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data})
%%           PID ! {msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data}
		   catch
			 _:_->ok 
          end;
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
	 try
					 emipian_route:sendmsg(Session,{msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data})
 
   %%  PID ! {msg,?AC_SC_SINGLESYSMSG,MsgID,SynNo,Data}
	 catch
		 _:_->ok 
	  end.

send_msg(SenderUserID,Action,StampTime,MsgID,Content,{Os,CCode,ACode})->

%%	emipian_msg_log:save_userreceiver(MsgID, SenderUserID,?CHATSTATUS_ONLY_REC,SenderUserID,StampTime,{},?CHATSTYPE_GROUP),
	srv_sysmutimsg:processsrv
	   (SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}}),
	ok.



getAPNSData(Content)
  ->Content.