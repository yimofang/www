%% @author hyf
%% @doc @todo Add description to msg_parser.


-module(emipian_parser).
-include("logger.hrl").
-export([parse/2,new/2]).
 

-define(RESERVED, 0).
-define(MAX_LEN, 16#fffffff).
-define(HIGHBIT, 2#10000000).

-record(parse_state,
	{callback_pid = self() :: pid(),parse_process,
         handshakesize = 0              :: non_neg_integer()
         }).

new(CallbackPid, HandShakeSize) ->
    #parse_state{callback_pid = CallbackPid, parse_process=none, handshakesize = HandShakeSize}.


parse(<<>>,  #parse_state{parse_process = none} =  ParseState) ->
	ParseProcess = fun(Bin) -> parse(Bin, ParseState) end,
    ParseState1 = ParseState#parse_state{parse_process = ParseProcess},
    {none, ParseState1};

parse(Data, #parse_state{handshakesize=HandShakeSize,parse_process = none} =  ParseState) 
   when 
	   HandShakeSize>0 ->parse_handshake(Data,ParseState);

parse(Data,   #parse_state{parse_process = none} =  ParseState)  ->
    DataLen = 	byte_size(Data),
   if
	   DataLen<4 -> 	 
		   {more, fun(BinMore) -> parse(<<Data/binary,BinMore/binary>>,none) end};
       true->		
		   <<Len:32/little,Rest/binary>> = Data,
           parse_comand(Rest,Len-4,ParseState)
    end;

parse(Data, #parse_state{parse_process = Cont}) -> Cont(Data).


parse_comand(RestData, Length,
			 #parse_state{ callback_pid = CallbackPid,parse_process = none} =  ParseState) 
     ->
	 DataLen = byte_size(RestData),
	if
	  Length>?MAX_LEN ->
         {error, invalid_emipian_len};
	  DataLen<Length-> 
        

	    ParseProcess = fun(BinMore) -> 
                 RestData0 = binary:copy(RestData),
                 AllRestData = <<RestData0/binary,BinMore/binary>>,
                 parse_comand(AllRestData,Length,ParseState) 
         end,

        ParseState1 = ParseState#parse_state{parse_process = ParseProcess},  
	    {more, ParseState1};	
	  true ->   
	    <<CurData:Length/binary, RestData1/binary>> =RestData,
        CurData1 = binary:copy(CurData), 
        RestData2 = binary:copy(RestData1),
		%% << command acion >>
		catch gen_fsm:send_event(CallbackPid,CurData1),
        ParseState1 = ParseState#parse_state{parse_process = none},  
		{ok,ParseState1,RestData2}
	end.

parse_handshake(Data,
	            #parse_state{handshakesize = Length, callback_pid = CallbackPid,parse_process = none} =  ParseState) ->

	DataLen = byte_size(Data),
	if
	  Length>?MAX_LEN ->
         {error, invalid_emipian_len};
	  DataLen<Length+9-> 
	  
	  ParseProcess = fun(BinMore) -> 
               Data0 = binary:copy(Data),
                AllRestData = <<Data0/binary,BinMore/binary>>,
              parse_handshake(AllRestData,ParseState) end,
      ParseState1 = ParseState#parse_state{parse_process = ParseProcess},  
	    {more, ParseState1};	
	  true ->   
		Len =  Length+9, 
	    <<CurData:Len/binary, RestData1/binary>> =Data,
        CurData1 = binary:copy(CurData), 
        RestData2 = binary:copy(RestData1),
		catch gen_fsm:send_event(CallbackPid,CurData1),
        ParseState1 = ParseState#parse_state{parse_process = none,handshakesize = -1},  
		{ok,ParseState1,RestData2}
 end.


parse_utf(Bin, 0) ->
    {undefined, Bin};
parse_utf(Bin, _) ->
    parse_utf(Bin).

parse_utf(<<Len:16/big, Str:Len/binary, Rest/binary>>) ->
    {binary_to_list(Str), Rest}.

parse_msg(Bin, 0) ->
    {undefined, Bin};
parse_msg(<<Len:16/big, Msg:Len/binary, Rest/binary>>, _) ->
    {Msg, Rest}.

bool(0) -> false;
bool(1) -> true.

%% serialisation


serialise_utf(String) ->
    StringBin = unicode:characters_to_binary(String),
    Len = size(StringBin),
    true = (Len =< 16#ffff),
    <<Len:16/big, StringBin/binary>>.


opt(undefined)            -> ?RESERVED;
opt(false)                -> 0;
opt(true)                 -> 1;
opt(X) when is_integer(X) -> X.


%%  <<Len:32/little>>.



