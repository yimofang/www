%% @author hyf
%% @doc @todo Add description to mod_action_cxgroupchat.


-module(mod_action_cxgroupchat).

-include("session.hrl").
-include("errorcode.hrl").

-define(AC_CS_CXGROUPCHAT, 32002).
 

-define(AC_CS_CXFIXGROUPCHAT, 32003).
 

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
		 {ok,GroupID,StartTime,EndTime,StartPos,Count}->
		Type = 
			if 
			 Action=:=?AC_CS_CXGROUPCHAT->1;
			 Action=:=?AC_CS_CXFIXGROUPCHAT->2;
			 true->100
			end,
	     send_msg(Session,GroupID,Type,StartTime,EndTime,StartPos,Count),
		 {noresp,ok}
	  end.
	
 get_sendfields_fromparam(_,Param)->
	case parse_param(Param) of
	   cmderror->cmderror;
	   {ok,GroupID,StartTime,EndTime,StartPos,Count}->
	   {groupid,emipian_util:binary_to_str(GroupID),starttime,StartTime,endtime,EndTime,startpos,StartPos,count,Count}
     end.

get_msgstamptime(_Param)->
	   {ok,0}.




send_msg(Session,GroupID,Type,StartTime,EndTime,StartPos,Count) ->
	
	emipian_srv_cxgroupchat:process
	   (Session,GroupID,Type,StartTime,EndTime,StartPos,Count),
	ok.


parse_param(Param)->
  Total = byte_size(Param),  
  if 
	Total<64 ->
	   cmderror;
	 true->
       <<GroupID:40/binary,StartTime:64/little,EndTime:64/little,
		StartPos:32/little,Count:32/little>> = Param,
    {ok,emipian_util:binary_to_str(GroupID),StartTime,EndTime,StartPos,Count}
  end.


