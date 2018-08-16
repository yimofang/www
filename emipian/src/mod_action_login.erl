%% @author hyf
%% @doc @todo Add description to mod_action_login.


-module(mod_action_login).
-include("session.hrl").
-include("macro.hrl").
-include("logger.hrl").


-define(AC_CS_LOGIN, 30001).
-define(AC_CS_RELOGIN, 30002).
-define(AC_CS_RANDOM, 30006).
-define(AC_SC_LOGIN_R, 60001).
-define(AC_SC_RANDOM_R, 60006).



-define(CMDMINLEN, 5).

%% ====================================================================
%% API functions
%% ====================================================================
-export([process_action/5,start/0,get_sendfields_fromparam/2,get_msgstamptime/1]).
 

%% -include( "action.hrl").
-include("errorcode.hrl").
%% ====================================================================
%% Internal functions
%% ====================================================================
start() ->ok.
%% ====================================================================
%% Must implement API or action
%% return
%% {ok/terminate/resume,Data}
%% Data ={Action,Code,Param,Addition}
%% Addition ={}
%%
%%
%% ====================================================================
	
process_action(MsgID,Session,Action,Param,AuthMethod)-> 
	case Action of
    ?AC_CS_LOGIN->
	   Result= login(first,MsgID,Session,Action,Param,AuthMethod);
    ?AC_CS_RELOGIN->
	  Result= login(relogin,MsgID,Session,Action,Param);
	?AC_CS_RANDOM->
	  Result= login(random,MsgID,Session,Action,Param);	
	  _->Result =cmderror
  end, 
	case Result of
	 {ok,Session1,MainLink}->	
	 {Result0,ToDataBase} = get_resultparam(?AC_CS_LOGIN,?EC_SUCCESS,Session1,MainLink),
		 {ok,Result0,ToDataBase}; 
	 {fail} ->
		 {Result0,ToDataBase} = get_resultparam(?AC_CS_LOGIN,?EC_LOGINFAIL,Session,0),
		 {terminate,Result0,ToDataBase};
	 {invalid} ->
		 {Result0,ToDataBase} = get_resultparam(?AC_CS_LOGIN,?EC_SESSIONINVALID,Session,0),
		 {resume,Result0,ToDataBase};
	 cmderror->cmderror
 end.

		 

get_sendfields_fromparam(Action,Param)->
 case Action of
    ?AC_CS_LOGIN->
		
		
	<<UserID:40/binary,UserType:8/little,AppOs:8/little,AppCode:16/little,CusomCode:16/little,
    Lang:8/little,Version1:20/binary,AuthCode:32/binary,AuthcodeTimeStamp:64/little, TermialName1:32/binary,_Rest/binary>> = Param,
	UserID1 = emipian_util:binary_to_str(UserID),
	Version = emipian_util:binary_to_str(Version1),
	TermialName =  emipian_util:binary_to_str(TermialName1),
    {userid,UserID1,usertype,UserType,appos,AppOs,appcode,AppCode,cusomcode,CusomCode,termialno,<<"">>,
    termialname,TermialName,
    authcodetimestamp,AuthcodeTimeStamp, lang,Lang
	,version,Version,authcode,AuthCode
	};
    ?AC_CS_RELOGIN->
	  <<SessionID0:36/binary,Rest/binary>> = Param,
	  	  RSize = byte_size(Rest),
		  MainLink = 
			   if 
				   RSize =:=0 -> 0;
				   true ->
					    <<MainLink0:32/little>> = Rest,
						MainLink0
			  end,		   
		{sessionid,emipian_util:binary_to_str(SessionID0),mainlink,MainLink};
	?AC_CS_RANDOM->
		<<Count:8/little>> = Param,
		{count,Count};
    _->cmderror
  end.

get_msgstamptime(_)->
	{ok,0}.



%% ====================================================================
%% Internal functions
%%return:
%%  1){ok,Session1}
%%  2){fail}
%%  3)cmderror Param of Command  error
%%
%% ====================================================================
login(first,MsgID,Session,Action,Param,AuthMethod)->
	<<UserID1:40/binary,UserType:8/little,AppOs:8/little,AppCode:16/little,CusomCode:16/little,
    Lang:8/little,Version1:20/binary,AuthCode:32/binary,AuthcodeTimeStamp:64/little,
	  TermialName1:32/binary,_Rest/binary>> = Param,
	UserID = emipian_util:binary_to_str(UserID1),
    Version = emipian_util:binary_to_str(Version1),
	TermialName =  emipian_util:binary_to_str(TermialName1),
	AuthcodeTime = emipian_util:get_erlangtime(AuthcodeTimeStamp),
	#session{randomcode = Random,secretnew =	 SecretNew,secretold =	 SecretOld} = Session,	
    Session1 =Session#session{
              userid =UserID ,
			  usertype=UserType,
              appos = AppOs,
              appcode=AppCode,
              customcode=CusomCode,
              termialno = <<"">>,
	          termialname = TermialName,
              lang = Lang,	 
		      version =Version,
			  authcodetime = AuthcodeTime,
			  status = ?STATUS_LOGINING,
		      logintime = os:timestamp(),
			  mainlink=0				 
						  },
	case emipian_msg_log:save_login_log(MsgID, Session1, Action, Param) of
	    cmderror->
			
			cmderror;
	    _->
	    case checkauth(UserID,AuthCode,Random,SecretNew,SecretOld,AuthcodeTimeStamp,AuthMethod) of
		ok->	
		    case emipian_sm:open_session(newsession, Session1) of
			  {ok,Session2}	-> 
				  {ok,Session2,0};
			  _->
 
				  {fail}
			end;	
		_->		
			{fail}
	   end
    end.	
%% ====================================================================
%% Internal functions
%%%% Internal functions
%%return:
%%  1){ok,Session1}
%%  2){fail}
%%  3)cmderror Param of Command  error
%% ====================================================================
login(relogin,MsgID,Session,Action,Param)->
   #session{peerip=PeerIP,s_peerip=S_Peerip,selfpid=Selfpid
		   ,node=Node} =Session,
  <<SessionID0:36/binary,Rest/binary>> = Param,
  
  case emipian_msg_log:save_login_log(MsgID, Session, Action, Param) of
	    cmderror->cmderror;
	    _->
		  RSize = byte_size(Rest),
		  
		   MainLink = 
			   if 
				   RSize =:=0 -> 0;
				   true ->
					    <<MainLink0:32/little>> = Rest,
						MainLink0
			  end,		   
		  SessionID = emipian_util:binary_to_str(SessionID0) ,
		  Session1 = emipian_sm:get_session(SessionID),
		  case Session1 of
			  not_found->{invalid};
			  _->
				Status0 = 
					if 
						MainLink=:=0 -> ?STATUS_LOGINING;
						true  ->?STATUS_ONLINE
		            end, 						 
		%%     #session{status=Status,sessionid =SessionID} = Session1,

		        Session2 = Session1#session{status=Status0,peerip=PeerIP,mainlink=MainLink,
											s_peerip=S_Peerip,
											selfpid=Selfpid,node=Node,
										    logintime = os:timestamp()	
											},
				   emipian_sm:update_session(Session2,MainLink),
				{ok,Session2,MainLink}
			end
  end;
		

login(random,MsgID,Session,Action,Param)->
	Session1 = Session,
	<<Count:8/little>> = Param,
	{ok,Session1,0}.

checkauth(UserID,AuthCode,Random,SecretNew,SecretOld,AuthcodeTimeStamp,nocode)
->ok;
checkauth(UserID,AuthCode,Random,SecretNew,SecretOld,AuthcodeTimeStamp,AuthMethod)->
	SLogin = integer_to_list(AuthcodeTimeStamp,10),
	AuthCode0 = string:to_lower(binary_to_list(AuthCode)),
    
	Context = erlang:md5_init(),
	Context1 =  erlang:md5_update(Context, UserID),
	Context2 =  erlang:md5_update(Context1, SLogin),
	Context3 =  erlang:md5_update(Context2, SecretNew),
	Md50 = erlang:md5_final(Context3),
	Md5heX = emipian_util:list_to_hex(binary_to_list(Md50)),
	Md5heX0 = string:to_lower(Md5heX),
    if 
		AuthCode0=:=Md5heX0
		  ->ok;
		true->
			Context4 =  erlang:md5_update(Context2, SecretOld),
			Md51 = erlang:md5_final(Context4),
			Md5heX1 = emipian_util:list_to_hex(binary_to_list(Md51)),
			Md5heX01 = string:to_lower(Md5heX1),
	        if 
			 AuthCode0=:=Md5heX01
		       ->ok;
			 true -> fail
			end
	end.


get_resultparam(Action,Code,Session,MainLink)->
	
   if
	 Code=:=0 ->
     #session{sessionid=SessionID} = Session;
	 true->SessionID = <<"">>
  end,
        SessionID1 =emipian_util:str_to_binayid36(SessionID),	
   Return = 
	  {?AC_SC_LOGIN_R,Code,SessionID1,Session,MainLink},
   ToDataBase = 	
   if
	 Code=:=0 ->
	 
   	 {action,?AC_SC_LOGIN_R,code,Code,param,SessionID1,mainlink,MainLink};
   	 true->{action,?AC_SC_LOGIN_R,code,Code}
   end,
   {Return,ToDataBase}.


	