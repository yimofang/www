%% @author hyf
%% @doc @todo Add description to srv_server.


-module(srv_server).

%% ====================================================================
%% API functions
%% ====================================================================
%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).



process(SenderUserID,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}) ->
    spawn(?MODULE,handle_action,[SenderUserID,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}]). 



handle_action(SenderUserID,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}) -> 
	try
     send(SenderUserID,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime})
	after
	 exit(normal)   
	end.

processsrv(SenderUserID,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime})->
  	send(SenderUserID,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}).

send(SenderUserID,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}) ->
        
   case rfc4627:decode(Receivers) of
	  {ok,Receivers1,_} -> 
		  sends(SenderUserID,Receivers1,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}); 
    _->cmderror 
	end.


sends(SenderUserID,[],{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}) ->ok;

sends(SenderUserID,[Receiver|T],{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}) ->
        
   	mod_action_server:sendmsg_to_user(MsgID,SenderUserID,Receiver,Contents,APNS,MsgTime),

     sends(SenderUserID,T,{Action,StampTime,MsgID,Receivers,Contents,APNS,MsgTime}).
