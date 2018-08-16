%% @author hyf
%% @doc @todo Add description to emipian_util.


-module(emipian_util).
-define(int16(X), [((X) bsr 8) band 16#ff, (X) band 16#ff]).
%% ====================================================================
%% API functions
%% ====================================================================
-export([get_curtimestamp/0,get_mstime/1,binary_to_str/1,str_to_binayid/1,ip_to_str/1,
		 compareIPs/2,ip_islocal/1,
		 utc_timestamp/0
		,lookuprecordvalue/2,to_xml/1,list_to_xml/1,
		 json_to_xmlforgroupreceiver/1,get_uuid/0,
		 str_to_binayid36/1
		  ,str_to_binayid/2	
		,list_to_hex/1
		,get_erlangtime/1
		,addtime/2
		,subtracttime/2
		,recordtojson/1
		]).



%% ====================================================================
%% Internal functions
%% ====================================================================

get_uuid()->
	list_to_binary(string:to_upper(uuid:to_string(uuid:uuid4()))).
get_curtimestamp()->
 {M,S,_} = os:timestamp(),
 M*1000000000+S*1000.

get_mstime({M,S,_} )->
 M*1000000000+S*1000.

get_erlangtime(TMS) ->
    M = TMS div 1000000000,
	TMS1 = TMS rem 1000000000,
    S = TMS1 div 1000,
	{M,S,0}.


addtime(ErlangTime,Addtime)
  ->
	MsTime = get_mstime(ErlangTime),
	MsTime1 = MsTime+Addtime,
	get_erlangtime(MsTime1).

subtracttime(ErlangTime,Addtime)
  ->
	MsTime = get_mstime(ErlangTime),
	MsTime1 = MsTime-Addtime,
	get_erlangtime(MsTime1).
	
binary_to_str(Data) when is_binary(Data)->
  H = binary:split(Data,[<<0>>]),
  case H of
   [D,_] ->D;
   [D1]-> D1 
  end;
binary_to_str(Data) ->{}.
  
str_to_binayid(Data) when is_binary(Data)->
  Reverse = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,	
  Len = 40-byte_size(Data),
  if Len>0 ->
  <<Data/binary,Reverse:Len/binary>> ; 
   true-> <<Data/binary>> 
  end;
str_to_binayid(Data) ->
  Reverse = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,	
	
	<<Reverse:40/binary>>.

str_to_binayid36(Data) when is_binary(Data)->
  Reverse = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,	
  Len = 36-byte_size(Data),
  if Len>0 ->
  <<Data/binary,Reverse:Len/binary>> ; 
   true->  <<Data/binary>> 
  end;
str_to_binayid36(Data)->
	  Reverse = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,	
	
	<<Reverse:36/binary>>.


str_to_binayid(Data,Size) when is_binary(Data)->
  Reverse = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,	
  Len = Size-byte_size(Data),
  if Len>0 ->
  <<Data/binary,Reverse:Len/binary>> ; 
   true->  <<Data/binary>> 
  end;
str_to_binayid(Data,Size)->
	  Reverse = <<0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>,	
	
	<<Reverse:Size/binary>>.

ip_to_str(IP)->
	{Addr,_} =IP,
   ip_to_str(<<>>,ip_to_bytes(Addr)).

ip_to_str(Pre,[])
  ->Pre;

ip_to_str(<<>>,[H|T])->
   Cur = list_to_binary(integer_to_list(H,10)),
   ip_to_str(Cur,T);

ip_to_str(Pre,[H|T])->
    Cur = list_to_binary(integer_to_list(H,10)),
	Cur1 = <<Pre/binary,<<".">>/binary,Cur/binary>>,
   ip_to_str(Cur1,T).

ip_to_bytes(IP) when tuple_size(IP) =:= 4 -> ip4_to_bytes(IP);
ip_to_bytes(IP) when tuple_size(IP) =:= 8 -> ip6_to_bytes(IP).

ip4_to_bytes({A,B,C,D}) ->
    [A band 16#ff, B band 16#ff, C band 16#ff, D band 16#ff].

ip6_to_bytes({A,B,C,D,E,F,G,H}) ->
    [?int16(A), ?int16(B), ?int16(C), ?int16(D),
     ?int16(E), ?int16(F), ?int16(G), ?int16(H)].


ip4_islocal({A,B,C,D}) ->
	if (A=:=127) and (B=:=0) and (C =:=0) and (D=:=1)
        ->yes;
        true->no
	end.
ip6_islocal({A,B,C,D,E,F,G,H}) ->
	if (A=:=0) and (B=:=0) and (C =:=0) and (D=:=0)and (E=:=0)and (F=:=0)and (G=:=0)
		 and (H=:=1) 
        ->yes;
        true->no
	end.

ip_islocal(IP) when tuple_size(IP) =:= 4 -> ip4_islocal(IP);
ip_islocal(IP) when tuple_size(IP) =:= 8 -> ip6_islocal(IP).


compareIP (IPSrc,IPDest,Mask) ->
 	  
  IP1Len = tuple_size(IPSrc), 
  IP2Len = tuple_size(IPDest),
  if IP1Len=/=IP2Len ->no;
     true-> 
		 compareIP0(IPSrc,IPDest,Mask) 
  end.

compareIP0 (IP1,IP2,Mask) when tuple_size(IP1) =:= 4 -> compareIP4(IP1,IP2,Mask);
compareIP0 (IP1,IP2,Mask) when tuple_size(IP1) =:= 8 -> compareIP6(IP1,IP2,Mask).

compareIP4({A1,B1,C1,D1},{A2,B2,C2,D2},{M1,M2,M3,M4})->
  case ip4_islocal({A2,B2,C2,D2}) of
	yes->yes;
	_->  
     if ((A1 band M1)=:=(A2 band M1)) and((B1 band M2)=:=(B2 band M2))
       and ((C1 band M3)=:=(C2 band M3)) and((D1 band M4)=:=(D2 band M4))
     ->yes;
      true->no
    end
  end.

compareIP6({A1,B1,C1,D1,E1,F1,G1,H1},{A2,B2,C2,D2,E2,F2,G2,H2},PreLen)->
	case ip6_islocal({A2,B2,C2,D2,E2,F2,G2,H2}) of
		 yes->yes;
	     _->
			 
			 yes
	 end.



compareIPs ([],_) ->no;
compareIPs ([H1|IPAndMask],IPDest) ->
  {IP,Mask} =H1,	
  case	compareIP (IP,IPDest,Mask) of   
	  yes->yes;
	  _->compareIPs(IPAndMask,IPDest)
  end.


randomonestr() ->
 Base =[48,49,50,51,52,53,54,55,56,57],
 Size = length(Base),
 Rnd =  erlang:trunc(random:uniform()*100) rem Size+1,
 lists:nth(Rnd, Base).
 
randomonestr(Count)->
  Random = randomonestr(Count,<<>>),
  lists:list_to_bin(Random).
  
randomonestr(Count,ARandom)
 when Count=:=0->ARandom;
randomonestr(Count,ARandom)->
   E = randomonestr(),
   Random = ARandom,
   randomonestr(Count-1,Random),
	Random.


utc_timestamp() ->
    TS = {_,_,Micro} = os:timestamp(),
    {{Year,Month,Day},{Hour,Minute,Second}} = 
	calendar:now_to_universal_time(TS),
    S = io_lib:format("~4w-~w-~wT~w:~w:~w.~wZ",
		  [Year,Month,Day,Hour,Minute,Second,Micro]),
     S. 

recordtojson(N) ->
 recordtotuple(N,0,tuple_size(N) div 2,[])	.
  
recordtotuple(N,High,High,R) ->R;
recordtotuple(N,Index,High,R) ->
	Key  = element (2*Index+1, N),
	Value  = element (2*Index+ 2, N),
	R1 = R++[{Key,Value}],
	recordtotuple(N,Index+1,High,R1).
  
 lookuprecordvalue (Key, Fields) -> case find (Key, Fields) of
	{Index} -> element (Index * 2 + 2, Fields);
	{} -> not_found end.


find (Key,Fields) -> findN (Key,Fields, 0, tuple_size(Fields) div 2).
findN (_Key, Fields, High, High) -> {};
findN (Key, Fields, Low, High) -> case element (Low * 2 + 1, Fields) of
	Key -> {Low};
	_ -> findN (Key, Fields, Low + 1, High) end. 
  
%% Data  binary|list
%% return list
to_xml(Data) when is_binary(Data)->
  Data1 = binary:replace(Data,<<"&">>, <<"&amp;">>,[global]),
  Data2 = binary:replace(Data1,<<"<">>, <<"&lt;">>,[global]),
  Data3 = binary:replace(Data2,<<">">>, <<"&gt;">>,[global]),
  binary_to_list(Data3);

to_xml(Data) when is_list(Data)->
  Data0 = list_to_binary(Data),
  to_xml(Data0).

list_to_xml([],PreData) ->PreData;

list_to_xml([H|T],PreData) ->
	X = "<A>"++to_xml(H)++"</A>",
    list_to_xml(T,PreData++X). 

list_to_xml(T)  ->
 list_to_xml(T,[]).


json_to_xmlforgroupreceiver(T)->
json_to_xmlforgroupreceiver(T,[]).

json_to_xmlforgroupreceiver([],PreData)->
  PreData;
json_to_xmlforgroupreceiver([H|T],PreData)->
   {ok,Id1} =  rfc4627:get_field(H, "id"),
   Id = binary_to_list(Id1),
   {ok,Type} = rfc4627:get_field(H, "type"),
   Type1 = integer_to_list(Type,10),
   X = "<A><id>"++Id++"</id>"++"<type>"++Type1++"</type></A>",
   json_to_xmlforgroupreceiver(T,PreData++X).

list_to_hex(L) ->
	lists:flatten(lists:map(fun(X) -> int_to_hex(X) end, L)).

int_to_hex(N) when N < 256 ->
[hex(N div 16), hex(N rem 16)].

hex(N) when N < 10 ->
$0+N;
hex(N) when N >= 10, N < 16 ->
$a + (N-10).
