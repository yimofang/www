%% @author hyf
%% @doc @todo Add description to emipian_srv_action.


-module(emipian_srv_action).

%% ====================================================================
%% API functions
%% ====================================================================
-export([process/3,handle_action/3]).

process(SelfPID,Session,Data) ->
    spawn(?MODULE,handle_action,[SelfPID,Session,Data]). 

handle_action(SelfPID,Session,Data) -> 
	Return = emipian_action:doaction(Session, Data),
	try
	SelfPID !{status,Return} 
	catch
	_:_->ok
	after
		 exit(normal)   
	end.	


