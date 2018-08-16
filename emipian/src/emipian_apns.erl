%% @author hyf
%% @doc @todo Add description to apns.


-module(emipian_apns).

%% ====================================================================
%% API functions
%% ====================================================================
-include("session.hrl").
-include("macro.hrl").
-include("logger.hrl").
-include("apns.hrl").

-export([sendapns/4,sendapns/2,sendapns/3]).

-export([handle_action/4,handle_action/2,handle_action/3]).


getpoolname(OS,AppCode,CustomCode)->
     ApnsP ="apns_"++integer_to_list(AppCode)++"_"++integer_to_list(CustomCode),
     list_to_existing_atom(ApnsP).

getConnection(Pool)->
    poolboy:checkout(Pool).

disConnection(Pool,Connection)->
  case 	Connection of
   fail->ok;	  
    _->poolboy:checkin(Pool,Connection)
end.

%% sendapns(ReceiverSession,Data,SenderUserID,Sender101)->ok. 

sendapns(ReceiverSession,Data,SenderUserID,Sender101) ->
    spawn(?MODULE,handle_action,[ReceiverSession,Data,SenderUserID,Sender101]). 

sendapns(ReceiverSession,Sender101) ->
	?INFO_MSG("send apns sendapns  1.....~n.", []),
    spawn(?MODULE,handle_action,[ReceiverSession,Sender101]). 

sendapns(ReceiverSession,Data,SenderUserID) ->
    spawn(?MODULE,handle_action,[ReceiverSession,Data,SenderUserID]). 

handle_action(ReceiverSession,Data,SenderUserID) -> 
 try	
  send(ReceiverSession,Data,SenderUserID)
 after
 exit(normal)
 end.

handle_action(ReceiverSession,Data,SenderUserID,Sender101) -> 
 try	
  send(ReceiverSession,Data,SenderUserID,Sender101)
 after
 exit(normal)
 end.

handle_action(ReceiverSession,AddtionJson) -> 
 try	
  send(ReceiverSession,AddtionJson)
 after
 exit(normal)
 end.


send(ReceiverSession,Data,SenderUserID)->
  #session{status =Status,appos =AppOS,termialno=TernaimalNO,
		   customcode=CustomCode,appcode = AppCode,lang=Lang }      = ReceiverSession,
  if  AppOS =:=?APPOS_IOS->
       case get_sendapnscontent(Data,Lang) of
		   {0,Content}-> 
			   send00(ReceiverSession,Content,TernaimalNO);
	       _->ok
	   end;
	  true->ok
	end.  
			   
			   
  
send00(ReceiverSession,Data,TernaimalNO)->
 	
  #session{status =Status,appos =AppOS,termialno=TernaimalNO,
		   customcode=CustomCode,appcode = AppCode,lang=Lang }      = ReceiverSession,
	    S1 = unicode:characters_to_list((Data),utf8),
		S0 = string:substr(S1, 1,?APNS_MAXLEN),
		S1Len =  string:len(S1),

		S = if 
		     S1Len>?APNS_MAXLEN -> S0++"...";
			 true->S0
		   end,	
			
		DeviceID = binary_to_list(TernaimalNO),
	
        if S1Len>0 -> 
			   	 Msg = #apns_msg{device_token =  DeviceID,
                                alert = S,
					            sound = "default",
								 badge=1
					},
        if  
		  length(DeviceID)>0->
	         Pool =   getpoolname(AppOS,AppCode,CustomCode),
	          Connection = getConnection(Pool),
	         try		  
		        apns:send_message(Connection,Msg)
	          after
		       disConnection(Pool,Connection) ,
       	     ?INFO_MSG("after send apns 2~n.", [])
	         end;
		       true->ok
		    end,	
	  	 ?INFO_MSG("after send apns 1 ~n.", []);
		 true->ok
 end.


send(ReceiverSession,Data,SenderUserID,Sender101)->
  #session{status =Status,appos =AppOS,termialno=TernaimalNO,
		   customcode=CustomCode,appcode = AppCode} 
      = ReceiverSession,
 
  if 
  	 AppOS =:=?APPOS_IOS; AppOS =:=?APPOS_WINPHONE->
	  case rfc4627:decode(Data) of
	  {ok,Data1,_} -> 
			 case  rfc4627:get_field(Data1, "content") of
				 {ok,Content0} ->Content = binary_to_list(Content0);
				 _->Content=""
			 end, 
			 case  rfc4627:get_field(Data1, "msgtype") of
				 {ok,MsgType0} ->MsgType = MsgType0;
				 _->MsgType=0
			 end;

	      _->
			  Content ="",
              MsgType =0
		end, 
	 
 	?INFO_MSG("send apns Content..... ~p~n.", [Content]),

	 LSender101  = binary_to_list(Sender101),
	  LSender101Len = length(LSender101),
	  LContentLen = length(Content),
	  
	  SData = if
		LSender101Len>0, LContentLen>0 -> 
			LSender101++":"++Content;
		 LSender101Len>0-> LSender101;
	 	 LContentLen>0-> Content;
		true->[]
		end,

	  WSend =if MsgType=:=31;MsgType=:=32;MsgType=:=33;MsgType=:=37;
		        MsgType=:=38;MsgType=:=50;MsgType=:=51;MsgType=:=58;MsgType=:=74;MsgType=:=73
				  ;MsgType=:=79;MsgType=:=77;MsgType=:=78;MsgType=:=80;MsgType>=2000
		  ->0;
		  true ->1		
	  end,	   
	

	    S1 = unicode:characters_to_list(list_to_binary(SData),utf8),
		S0 = string:substr(S1, 1,?APNS_MAXLEN),
		S1Len =  string:len(S1),

		S = if 
		     S1Len>?APNS_MAXLEN -> S0++"...";
			 true->S0
		   end,	
			
		DeviceID = binary_to_list(TernaimalNO),
	
        if S1Len>0 -> 
			   	 Msg = #apns_msg{device_token =  DeviceID,
                                alert = S,
					            sound = "default",
								 badge=1
					},
        if  
		  length(DeviceID)>0,WSend=:=1 ->
	         Pool =   getpoolname(AppOS,AppCode,CustomCode),
	          Connection = getConnection(Pool),
	         try		  
		        apns:send_message(Connection,Msg)
	          after
		       disConnection(Pool,Connection) ,
       	     ?INFO_MSG("after send apns 2~n.", [])
	         end;
		       true->ok
		    end,	
%%		 apns:send_message(Connection, binary_to_list(TernaimalNO), S),
	  	 ?INFO_MSG("after send apns 1 ~n.", []);
		 true->ok
		end;
      true->ok
 end.


send(ReceiverSession,Sender101)->
  #session{status =Status,appos =AppOS,termialno=TernaimalNO,
		   customcode=CustomCode,appcode = AppCode} 
      = ReceiverSession,
   LSender101  = binary_to_list(Sender101),
  if 
  	 AppOS =:=?APPOS_IOS; AppOS =:=?APPOS_WINPHONE->
		?INFO_MSG("send dial apns send1 ~n.", []),
	 BContent = <<"正在呼叫"/utf8>>,
	
	  SData = 
			LSender101++":"++binary_to_list(BContent),

	

	    S1 = unicode:characters_to_list(list_to_binary(SData),utf8),

		S0 = string:substr(S1, 1,?APNS_MAXLEN),

		S1Len =  string:len(S1),

		S = if 
		     S1Len>?APNS_MAXLEN -> S0++"...";
			 true->S0
		   end,	
			
		DeviceID = binary_to_list(TernaimalNO),
		
        if S1Len>0 -> 
			   	 Msg = #apns_msg{device_token =  DeviceID,
                                alert = S,
					            sound = "call_wait.caf",
								 badge=1
					},
        if  
		  length(DeviceID)>0->
	          Pool =   getpoolname(AppOS,AppCode,CustomCode),
	          Connection = getConnection(Pool),
	         try		  
		        apns:send_message(Connection,Msg)
	          after
		       disConnection(Pool,Connection) ,
       	     ?INFO_MSG("after dail send apns 2~n.", [])
	         end;
		       true->ok
		    end,	
%%		 apns:send_message(Connection, binary_to_list(TernaimalNO), S),
	  	 ?INFO_MSG("after dail send apns 1 ~n.", []);
		 true->ok
		end;
      true->ok
 end.

get_sendapnscontent(APNS,Lang)->
  case rfc4627:decode(APNS) of
	  {ok,APNS1,_} -> 
		  {ok,Format} = rfc4627:get_field(APNS1, "format"),
		  {ok,Contents} =rfc4627:get_field(APNS1, "contents"),
		  Content = get_content(Contents,Lang),
		  case Format of
			  0-> 
				  {ok,Content0} =rfc4627:get_field(Content, "content"), 
				  {Format,Content0};	
			  _->cmderror
		  end;	  
      _->cmderror 
	end.
	
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
			 Lang=:=0->Content;%%rfc4627:encode(Content);
			true->
			 get_langcontent(T,Lang)
		 end;
       {ok,Lang} ->Content;%%rfc4627:encode(Content);
	   _-> get_langcontent(T,Lang)
   end.


