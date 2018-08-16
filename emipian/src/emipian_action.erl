%% @author hyf
%% @doc @todo Add description to emipian_action.


-module(emipian_action). 
-include("action.hrl").
-include("errorcode.hrl").
-include("session.hrl").
-include("logger.hrl").
%% ====================================================================
%% API functions
%% ====================================================================
-export([handshake/1,doaction/2,loginaction/3,handlereturn/3]).


 
%% ====================================================================
%% Internal functions
%%  handshake
%%  return:
%%   ->ok
%%   ->error

 
%% ====================================================================
 
%%handshake(Data)->
%%    ?INFO_MSG("handshake :~p ~n.", [Data]),
%%	ok.

handshake((Data))->
	<<Len:32/little,Cmd:8/little,Action:32/little,Random:6/binary,CRC32:32/little>> = (Data),
  CRC1 = erlang:crc32(Random),
  if CRC32=:=CRC1
	  ->ok;
	  true-> error
  end.


%%doaction(Session,<<Cmd:1/little,Rest/binary>>) when Cmd<40->
	
%%	ok;


%% ====================================================================
%% return
%% {ok/terminate/resume/noresp/noresult,Data}
%% Data ={Code,Action,Param,Addition}
%% 
%% Addition ={Session} for login
%% ====================================================================
doaction(Session, Data)   when is_binary(Data) 
->

  	Size = byte_size(Data), 
    if
	   Size<5->
	        MsgID =emipian_util:get_uuid(),
	        emipian_msg_log:save_msg_log(MsgID, Session,  Data),
	        {noresp,terminate};
	   true-> 
		    <<Cmd:8/little,Rest/binary>> =Data,
 	  	    parse_action(Session,Rest)
	
    end;
doaction(Session, Data) 
  
  ->ok.



loginaction(Session, Data,AuthMethod)   when is_binary(Data) ->
	Size = byte_size(Data), 
    if
	   Size<5->
   
	      MsgID =emipian_util:get_uuid(),
	      emipian_msg_log:save_msg_log(MsgID, Session,  Data),
	      {noresp,terminate};
	   true-> 	
		    <<_:8/little,Rest/binary>> =Data,
		    <<Action:32/little,Rest1/binary>> =Rest,

			MsgID =emipian_util:get_uuid(),

			Return= mod_action_login:process_action(MsgID,Session, Action, Rest1,AuthMethod),

			case Return of
				cmderror->
					Param = get_errorresultparam_record(),	 
			       emipian_msg_log:update_msg_result(Action,MsgID,Param),
			       {noresp,terminate};
				{Atom,Result,ToBase}->

					  emipian_msg_log:update_msg_result(Action,MsgID, ToBase),
					{Atom,Result}
%%				    erlang:insert_element(1, Result,Atom)
     end
	end;
loginaction(Session, Data,AuthMethod) 
  ->ok.

parse_action(Session,Data)->
	 MsgID =emipian_util:get_uuid(),
	 <<Action:32/little,Rest/binary>> =Data,
	 
	 SaveResult = emipian_msg_log:save_msg_log(MsgID, Session, Action, Rest),
     Muti = case gen_action_mod:get_msgstamptime(Action, Rest) of
			{ok,0} ->0;
		    {ok,StampTime}-> 
		        #session{userid=UserID} = Session, 
				MuResult = emipian_msg_log:find_samemsg(MsgID,UserID, StampTime),
		        case MuResult of
		            no->0;
                    {yes,MsgID1,StampTime1,Action1,Result1,SendTime} ->						
						Param2 = {code,?EC_DUPCMD,msgid,MsgID1},
		                emipian_msg_log:update_msg_result(Action,MsgID,Param2),
						

						case Result1 of
							{} ->0;
							_->
								gen_action_mod:get_sendparam_fromfields(Action1, StampTime1, MsgID1, SendTime,Result1)
						end	
		        end;
			cmderror->cmderror
         end,
	 
	  case SaveResult of
            cmderror-> {noresp,terminate};
         _->
  		  case Muti of
		    0->
		    %%  emipian_msg_log:save_msg_log(MsgID, Session, Action, Rest),
		      Return= gen_action_mod:process_action(MsgID,Session, Action, Rest),
			  
                handlereturn(Action,MsgID,Return);
		 	cmderror->
			   Param1 = get_errorresultparam_record(),	 
		       emipian_msg_log:update_msg_result(Action,MsgID,Param1),
		       {noresp,terminate};
		    _->Muti
		    end
         end.         
	     
get_errorresultparam_record()->
   	get_Coderesultparam_record(?EC_CMDERROR).
   
get_Coderesultparam_record(Code)->
   	 {code,Code}.

 
handlereturn(Action,MsgID,Return) ->
   case Return of
	 cmderror->
	   Param = get_errorresultparam_record(),	 
       emipian_msg_log:update_msg_result(Action,MsgID,Param),
       {noresp,terminate};
     {noresp}->{noresp,ok};
     {noresp,ok}->{noresp,ok};
	 {noresp,terminate}->{noresp,terminate};  
	 {Atom,Result,ToBase}->
        emipian_msg_log:update_msg_result(Action,MsgID, ToBase),
		{Atom,Result};
      {waitmsg} ->
         {waitmsg};
	   _->
	     Param = get_Coderesultparam_record(?EC_UNEXCEPTERROR),	 
         emipian_msg_log:update_msg_result(Action,MsgID,Param),
		 {noresp,terminate}
    end.
