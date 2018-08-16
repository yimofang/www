%% @author hyf
%% @doc @todo Add description to mod_action_cxsinglechat.


-module(mod_action_cxsinglechat).

-include("session.hrl").
-include("errorcode.hrl").

-define(AC_CS_CXGROUPCHAT, 32001).
 
-define(AC_SC_GROUPCHAT, 21001).


-define(CMDMINLEN, 20). 

%% ====================================================================
%% API functions
%% ====================================================================
-export([
		  process_action/4
		  ,get_msgstamptime/1,
           get_sendfields_fromparam/2
		]).



process_action(_MsgID,Session,Action,Param)-> 
	  Result =   parse_param(Param),
      case Result of
		 cmderror -> cmderror;
		 {ok,SenderUserID,StartTime,EndTime,StartPos,Count}->

	     send_msg(Session,SenderUserID,0,StartTime,EndTime,StartPos,Count),
		 {noresp,ok}
	  end.
	
 get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	   {ok,SenderUserID,StartTime,EndTime,StartPos,Count}->
	   {senderuserid,emipian_util:binary_to_str(SenderUserID),starttime,StartTime,endtime,EndTime,startpos,StartPos,count,Count}
     end.

get_msgstamptime(_Param)->
	   {ok,0}.




send_msg(Session,SenderUserID,Type,StartTime,EndTime,StartPos,Count) ->
	
	emipian_srv_cxsinglechat:process
	   (Session,SenderUserID,Type,StartTime,EndTime,StartPos,Count),
	ok.


parse_param(Param)->
  Total = byte_size(Param),  
  if 
	Total<64 ->
	   cmderror;
	 true->
       <<SenderUserID:40/binary,StartTime:64/little,EndTime:64/little,
		StartPos:32/little,Count:32/little>> = Param,
    {ok,emipian_util:binary_to_str(SenderUserID),StartTime,EndTime,StartPos,Count}
  end.

