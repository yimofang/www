%% @author hyf
%% @doc @todo Add description to srv_sysmutimsg.


-module(srv_sysmutimsg).

%% ====================================================================
%% API functions
%% ====================================================================
-export([process/2,handle_action/2,processsrv/2]).



process(SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}}) ->
    spawn(?MODULE,handle_action,[SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}}]). 



handle_action(SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}}) -> 
	try
     send(SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}})
	after
	 exit(normal)   
	end.

processsrv(SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}})->
  	send(SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}}).

send(SenderUserID,{Action,StampTime,MsgID,Content,{Os,CCode,ACode}}) ->
		Sessions = emipian_sm:searchconditionterminal({Os,CCode,ACode}),
    	mod_action_sysmutimsg:sendmsg_to_user(MsgID,SenderUserID,Content,StampTime, Sessions),
	ok.