%%%----------------------------------------------------------------------
%%% File    : jlib.erl
%%% Author  : Alexey Shchepin <alexey@process-one.net>
%%% Purpose : General XMPP library.
%%% Created : 23 Nov 2002 by Alexey Shchepin <alexey@process-one.net>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2014   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License along
%%% with this program; if not, write to the Free Software Foundation, Inc.,
%%% 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
%%%
%%%----------------------------------------------------------------------

-module(jlib).

-author('alexey@process-one.net').
 
-compile({no_auto_import, [atom_to_binary/2,
                           binary_to_integer/1,
                           integer_to_binary/1]}).

-export([make_jid/3, make_jid/1, string_to_jid/1,
	 jid_to_string/1, is_nodename/1, tolower/1, nodeprep/1,
	 nameprep/1, resourceprep/1, jid_tolower/1,
	 jid_remove_resource/1, jid_replace_resource/2,
	  timestamp_to_iso/1,
	 timestamp_to_iso/2,  now_to_utc_string/1,
	 now_to_local_string/1, datetime_string_to_timestamp/1,
	 term_to_base64/1, base64_to_term/1,
	 decode_base64/1, encode_base64/1, ip_to_list/1,
	 binary_to_integer/1, binary_to_integer/2,
	 integer_to_binary/1, integer_to_binary/2,
	 atom_to_binary/1, binary_to_atom/1, tuple_to_binary/1,
	 l2i/1, i2l/1, i2l/2]).

%% TODO: Remove once XEP-0091 is Obsolete
%% TODO: Remove once XEP-0091 is Obsolete

-include("jlib.hrl").

-export_type([jid/0]).

%send_iq(From, To, ID, SubTags) ->
%    ok.




-spec make_jid(binary(), binary(), binary()) -> jid() | error.

make_jid(User, Server, Resource) ->
    case nodeprep(User) of
      error -> error;
      LUser ->
	  case nameprep(Server) of
	    error -> error;
	    LServer ->
		case resourceprep(Resource) of
		  error -> error;
		  LResource ->
		      #jid{user = User, server = Server, resource = Resource,
			   luser = LUser, lserver = LServer,
			   lresource = LResource}
		end
	  end
    end.

-spec make_jid({binary(), binary(), binary()}) -> jid() | error.

make_jid({User, Server, Resource}) ->
    make_jid(User, Server, Resource).

-spec string_to_jid(binary()) -> jid() | error.

string_to_jid(S) ->
    string_to_jid1(binary_to_list(S), "").

string_to_jid1([$@ | _J], "") -> error;
string_to_jid1([$@ | J], N) ->
    string_to_jid2(J, lists:reverse(N), "");
string_to_jid1([$/ | _J], "") -> error;
string_to_jid1([$/ | J], N) ->
    string_to_jid3(J, "", lists:reverse(N), "");
string_to_jid1([C | J], N) ->
    string_to_jid1(J, [C | N]);
string_to_jid1([], "") -> error;
string_to_jid1([], N) ->
    make_jid(<<"">>, list_to_binary(lists:reverse(N)), <<"">>).

%% Only one "@" is admitted per JID
string_to_jid2([$@ | _J], _N, _S) -> error;
string_to_jid2([$/ | _J], _N, "") -> error;
string_to_jid2([$/ | J], N, S) ->
    string_to_jid3(J, N, lists:reverse(S), "");
string_to_jid2([C | J], N, S) ->
    string_to_jid2(J, N, [C | S]);
string_to_jid2([], _N, "") -> error;
string_to_jid2([], N, S) ->
    make_jid(list_to_binary(N), list_to_binary(lists:reverse(S)), <<"">>).

string_to_jid3([C | J], N, S, R) ->
    string_to_jid3(J, N, S, [C | R]);
string_to_jid3([], N, S, R) ->
    make_jid(list_to_binary(N), list_to_binary(S),
             list_to_binary(lists:reverse(R))).

-spec jid_to_string(jid() | ljid()) -> binary().

jid_to_string(#jid{user = User, server = Server,
		   resource = Resource}) ->
    jid_to_string({User, Server, Resource});
jid_to_string({N, S, R}) ->
    Node = iolist_to_binary(N),
    Server = iolist_to_binary(S),
    Resource = iolist_to_binary(R),
    S1 = case Node of
	   <<"">> -> <<"">>;
	   _ -> <<Node/binary, "@">>
	 end,
    S2 = <<S1/binary, Server/binary>>,
    S3 = case Resource of
	   <<"">> -> S2;
	   _ -> <<S2/binary, "/", Resource/binary>>
	 end,
    S3.

-spec is_nodename(binary()) -> boolean().

is_nodename(Node) ->
    N = nodeprep(Node),
    (N /= error) and (N /= <<>>).

%tolower_c(C) when C >= $A, C =< $Z ->
%    C + 32;
%tolower_c(C) ->
%    C.

-define(LOWER(Char),
	if Char >= $A, Char =< $Z -> Char + 32;
	   true -> Char
	end).

%tolower(S) ->
%    lists:map(fun tolower_c/1, S).

%tolower(S) ->
%    [?LOWER(Char) || Char <- S].

-spec tolower(binary()) -> binary().

tolower(B) ->
    iolist_to_binary(tolower_s(binary_to_list(B))).

tolower_s([C | Cs]) ->
    if C >= $A, C =< $Z -> [C + 32 | tolower_s(Cs)];
       true -> [C | tolower_s(Cs)]
    end;
tolower_s([]) -> [].

%tolower([C | Cs]) when C >= $A, C =< $Z ->
%    [C + 32 | tolower(Cs)];
%tolower([C | Cs]) ->
%    [C | tolower(Cs)];
%tolower([]) ->
%    [].

-spec nodeprep(binary()) -> binary() | error.

nodeprep("") -> <<>>;
nodeprep(S) when byte_size(S) < 1024 ->
    R = stringprep:nodeprep(S),
    if byte_size(R) < 1024 -> R;
       true -> error
    end;
nodeprep(_) -> error.

-spec nameprep(binary()) -> binary() | error.

nameprep(S) when byte_size(S) < 1024 ->
    R = stringprep:nameprep(S),
    if byte_size(R) < 1024 -> R;
       true -> error
    end;
nameprep(_) -> error.

-spec resourceprep(binary()) -> binary() | error.

resourceprep(S) when byte_size(S) < 1024 ->
    R = stringprep:resourceprep(S),
    if byte_size(R) < 1024 -> R;
       true -> error
    end;
resourceprep(_) -> error.

-spec jid_tolower(jid() | ljid()) -> error | ljid().

jid_tolower(#jid{luser = U, lserver = S,
		 lresource = R}) ->
    {U, S, R};
jid_tolower({U, S, R}) ->
    case nodeprep(U) of
      error -> error;
      LUser ->
	  case nameprep(S) of
	    error -> error;
	    LServer ->
		case resourceprep(R) of
		  error -> error;
		  LResource -> {LUser, LServer, LResource}
		end
	  end
    end.

-spec jid_remove_resource(jid()) -> jid();
                         (ljid()) -> ljid().

jid_remove_resource(#jid{} = JID) ->
    JID#jid{resource = <<"">>, lresource = <<"">>};
jid_remove_resource({U, S, _R}) -> {U, S, <<"">>}.

-spec jid_replace_resource(jid(), binary()) -> error | jid().

jid_replace_resource(JID, Resource) ->
    case resourceprep(Resource) of
      error -> error;
      LResource ->
	  JID#jid{resource = Resource, lresource = LResource}
    end.


-spec is_iq_request_type(set | get | result | error) -> boolean().

is_iq_request_type(set) -> true;
is_iq_request_type(get) -> true;
is_iq_request_type(_) -> false.

iq_type_to_string(set) -> <<"set">>;
iq_type_to_string(get) -> <<"get">>;
iq_type_to_string(result) -> <<"result">>;
iq_type_to_string(error) -> <<"error">>.


-type tz() :: {binary(), {integer(), integer()}} | {integer(), integer()} | utc.

%% Timezone = utc | {Sign::string(), {Hours, Minutes}} | {Hours, Minutes}
%% Hours = integer()
%% Minutes = integer()
-spec timestamp_to_iso(calendar:datetime(), tz()) -> {binary(), binary()}.

timestamp_to_iso({{Year, Month, Day},
                  {Hour, Minute, Second}},
                 Timezone) ->
    Timestamp_string =
	lists:flatten(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w",
				    [Year, Month, Day, Hour, Minute, Second])),
    Timezone_string = case Timezone of
			utc -> "Z";
			{Sign, {TZh, TZm}} ->
			    io_lib:format("~s~2..0w:~2..0w", [Sign, TZh, TZm]);
			{TZh, TZm} ->
			    Sign = case TZh >= 0 of
				     true -> "+";
				     false -> "-"
				   end,
			    io_lib:format("~s~2..0w:~2..0w",
					  [Sign, abs(TZh), TZm])
		      end,
    {iolist_to_binary(Timestamp_string), iolist_to_binary(Timezone_string)}.

-spec timestamp_to_iso(calendar:datetime()) -> binary().

timestamp_to_iso({{Year, Month, Day},
                  {Hour, Minute, Second}}) ->
    iolist_to_binary(io_lib:format("~4..0w~2..0w~2..0wT~2..0w:~2..0w:~2..0w",
                                   [Year, Month, Day, Hour, Minute, Second])).


-spec now_to_utc_string(erlang:timestamp()) -> binary().

now_to_utc_string({MegaSecs, Secs, MicroSecs}) ->
    {{Year, Month, Day}, {Hour, Minute, Second}} =
	calendar:now_to_universal_time({MegaSecs, Secs,
					MicroSecs}),
    list_to_binary(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w.~6."
                                 ".0wZ",
                                 [Year, Month, Day, Hour, Minute, Second,
                                  MicroSecs])).

-spec now_to_local_string(erlang:timestamp()) -> binary().

now_to_local_string({MegaSecs, Secs, MicroSecs}) ->
    LocalTime = calendar:now_to_local_time({MegaSecs, Secs,
					    MicroSecs}),
    UTCTime = calendar:now_to_universal_time({MegaSecs,
					      Secs, MicroSecs}),
    Seconds =
	calendar:datetime_to_gregorian_seconds(LocalTime) -
	  calendar:datetime_to_gregorian_seconds(UTCTime),
    {{H, M, _}, Sign} = if Seconds < 0 ->
			       {calendar:seconds_to_time(-Seconds), "-"};
			   true -> {calendar:seconds_to_time(Seconds), "+"}
			end,
    {{Year, Month, Day}, {Hour, Minute, Second}} =
	LocalTime,
    list_to_binary(io_lib:format("~4..0w-~2..0w-~2..0wT~2..0w:~2..0w:~2..0w.~6."
                                 ".0w~s~2..0w:~2..0w",
                                 [Year, Month, Day, Hour, Minute, Second,
                                  MicroSecs, Sign, H, M])).

-spec datetime_string_to_timestamp(binary()) -> undefined | erlang:timestamp().

datetime_string_to_timestamp(TimeStr) ->
    case catch parse_datetime(TimeStr) of
      {'EXIT', _Err} -> undefined;
      TimeStamp -> TimeStamp
    end.

parse_datetime(TimeStr) ->
    [Date, Time] = str:tokens(TimeStr, <<"T">>),
    D = parse_date(Date),
    {T, MS, TZH, TZM} = parse_time(Time),
    S = calendar:datetime_to_gregorian_seconds({D, T}),
    S1 = calendar:datetime_to_gregorian_seconds({{1970, 1,
						  1},
						 {0, 0, 0}}),
    Seconds = S - S1 - TZH * 60 * 60 - TZM * 60,
    {Seconds div 1000000, Seconds rem 1000000, MS}.

% yyyy-mm-dd
parse_date(Date) ->
    [Y, M, D] = str:tokens(Date, <<"-">>),
    Date1 = {binary_to_integer(Y), binary_to_integer(M),
	     binary_to_integer(D)},
    case calendar:valid_date(Date1) of
      true -> Date1;
      _ -> false
    end.

% hh:mm:ss[.sss]TZD
parse_time(Time) ->
    case str:str(Time, <<"Z">>) of
      0 -> parse_time_with_timezone(Time);
      _ ->
	  [T | _] = str:tokens(Time, <<"Z">>),
	  {TT, MS} = parse_time1(T),
	  {TT, MS, 0, 0}
    end.

parse_time_with_timezone(Time) ->
    case str:str(Time, <<"+">>) of
      0 ->
	  case str:str(Time, <<"-">>) of
	    0 -> false;
	    _ -> parse_time_with_timezone(Time, <<"-">>)
	  end;
      _ -> parse_time_with_timezone(Time, <<"+">>)
    end.

parse_time_with_timezone(Time, Delim) ->
    [T, TZ] = str:tokens(Time, Delim),
    {TZH, TZM} = parse_timezone(TZ),
    {TT, MS} = parse_time1(T),
    case Delim of
      <<"-">> -> {TT, MS, -TZH, -TZM};
      <<"+">> -> {TT, MS, TZH, TZM}
    end.

parse_timezone(TZ) ->
    [H, M] = str:tokens(TZ, <<":">>),
    {[H1, M1], true} = check_list([{H, 12}, {M, 60}]),
    {H1, M1}.

parse_time1(Time) ->
    [HMS | T] = str:tokens(Time, <<".">>),
    MS = case T of
	   [] -> 0;
	   [Val] -> binary_to_integer(str:left(Val, 6, $0))
	 end,
    [H, M, S] = str:tokens(HMS, <<":">>),
    {[H1, M1, S1], true} = check_list([{H, 24}, {M, 60},
				       {S, 60}]),
    {{H1, M1, S1}, MS}.

check_list(List) ->
    lists:mapfoldl(fun ({L, N}, B) ->
			   V = binary_to_integer(L),
			   if (V >= 0) and (V =< N) -> {V, B};
			      true -> {false, false}
			   end
		   end,
		   true, List).

%
% Base64 stuff (based on httpd_util.erl)
%

-spec term_to_base64(term()) -> binary().

term_to_base64(Term) ->
    encode_base64(term_to_binary(Term)).

-spec base64_to_term(binary()) -> {term, term()} | error.

base64_to_term(Base64) ->
    case catch binary_to_term(decode_base64(Base64), [safe]) of
      {'EXIT', _} ->
	  error;
      Term ->
	  {term, Term}
    end.

-spec decode_base64(binary()) -> binary().

decode_base64(S) ->
    decode_base64_bin(S, <<>>).

take_without_spaces(Bin, Count) -> 
    take_without_spaces(Bin, Count, <<>>).

take_without_spaces(Bin, 0, Acc) ->
    {Acc, Bin};
take_without_spaces(<<>>, _, Acc) ->
    {Acc, <<>>};
take_without_spaces(<<$\s, Tail/binary>>, Count, Acc) ->
    take_without_spaces(Tail, Count, Acc);
take_without_spaces(<<$\t, Tail/binary>>, Count, Acc) ->
    take_without_spaces(Tail, Count, Acc);
take_without_spaces(<<$\n, Tail/binary>>, Count, Acc) ->
    take_without_spaces(Tail, Count, Acc);
take_without_spaces(<<$\r, Tail/binary>>, Count, Acc) ->
    take_without_spaces(Tail, Count, Acc);
take_without_spaces(<<Char:8, Tail/binary>>, Count, Acc) ->
    take_without_spaces(Tail, Count-1, <<Acc/binary, Char:8>>).

decode_base64_bin(<<>>, Acc) ->
    Acc;
decode_base64_bin(Bin, Acc) ->
    case take_without_spaces(Bin, 4) of
        {<<A, B, $=, $=>>, _} ->
            <<Acc/binary, (d(A)):6, (d(B) bsr 4):2>>;
        {<<A, B, C, $=>>, _} ->
            <<Acc/binary, (d(A)):6, (d(B)):6, (d(C) bsr 2):4>>;
        {<<A, B, C, D>>, Tail} ->
            Acc2 = <<Acc/binary, (d(A)):6, (d(B)):6, (d(C)):6, (d(D)):6>>,
            decode_base64_bin(Tail, Acc2);
        _ ->
            <<"">>
    end.

d(X) when X >= $A, X =< $Z -> X - 65;
d(X) when X >= $a, X =< $z -> X - 71;
d(X) when X >= $0, X =< $9 -> X + 4;
d($+) -> 62;
d($/) -> 63;
d(_) -> 63.


%% Convert Erlang inet IP to list
-spec encode_base64(binary()) -> binary().

encode_base64(Data) ->
    encode_base64_bin(Data, <<>>).

encode_base64_bin(<<A:6, B:6, C:6, D:6, Tail/binary>>, Acc) ->
    encode_base64_bin(Tail, <<Acc/binary, (e(A)):8, (e(B)):8, (e(C)):8, (e(D)):8>>);
encode_base64_bin(<<A:6, B:6, C:4>>, Acc) ->
    <<Acc/binary, (e(A)):8, (e(B)):8, (e(C bsl 2)):8, $=>>;
encode_base64_bin(<<A:6, B:2>>, Acc) ->
    <<Acc/binary, (e(A)):8, (e(B bsl 4)):8, $=, $=>>;
encode_base64_bin(<<>>, Acc) ->
    Acc.

e(X) when X >= 0, X < 26 -> X + 65;
e(X) when X > 25, X < 52 -> X + 71;
e(X) when X > 51, X < 62 -> X - 4;
e(62) -> $+;
e(63) -> $/;
e(X) -> exit({bad_encode_base64_token, X}).

-spec ip_to_list(inet:ip_address() | undefined |
                 {inet:ip_address(), inet:port_number()}) -> binary().

ip_to_list({IP, _Port}) ->
    ip_to_list(IP);
%% This function clause could use inet_parse too:
ip_to_list(undefined) ->
    <<"unknown">>;
ip_to_list(IP) ->
    list_to_binary(inet_parse:ntoa(IP)).

binary_to_atom(Bin) ->
    erlang:binary_to_atom(Bin, utf8).

binary_to_integer(Bin) ->
    list_to_integer(binary_to_list(Bin)).

binary_to_integer(Bin, Base) ->
    list_to_integer(binary_to_list(Bin), Base).

integer_to_binary(I) ->
    list_to_binary(integer_to_list(I)).

integer_to_binary(I, Base) ->
    list_to_binary(erlang:integer_to_list(I, Base)).

tuple_to_binary(T) ->
    iolist_to_binary(tuple_to_list(T)).

atom_to_binary(A) ->
    erlang:atom_to_binary(A, utf8).


l2i(I) when is_integer(I) -> I;
l2i(L) when is_binary(L) -> binary_to_integer(L).

i2l(I) when is_integer(I) -> integer_to_binary(I);
i2l(L) when is_binary(L) -> L.

i2l(I, N) when is_integer(I) -> i2l(i2l(I), N);
i2l(L, N) when is_binary(L) ->
    case str:len(L) of
      N -> L;
      C when C > N -> L;
      _ -> i2l(<<$0, L/binary>>, N)
    end.


