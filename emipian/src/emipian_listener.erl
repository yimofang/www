
%% @author hyf
%% @doc @todo Add description to emipian_listener.

  
-module(emipian_listener).
-export([start_link/0, init/1, 
	 start_listeners/0,
	 start_listener/3,
	 stop_listeners/0,
	 stop_listener/2,
	 parse_listener_portip/2,
	 add_listener/3,
	 delete_listener/2,
         transform_options/1,
         validate_cfg/1
	]).

-include("emipian.hrl").
-include("logger.hrl").

%% We do not block on send anymore.
-define(TCP_SEND_TIMEOUT, 15000).

start_link() ->
    supervisor:start_link({local, emipian_listeners}, ?MODULE, []).


init(_) ->
    ets:new(listen_sockets, [named_table, public]),
 %%   bind_tcp_ports(),
    {ok, {{one_for_one, 10, 1}, []}}.



 
start_listeners() ->

%%    case emipian_config:get_local_option(listen) of

    case emipian_config:get_option(listen, fun validate_cfg/1) of
	undefined ->
	    ignore;
	Ls ->
	    Ls2 = lists:map(
	        fun({Port, Module, Opts}) ->
		        case start_listener(Port, Module, Opts) of
			    {ok, _Pid} = R -> R;
	 		    {error, Error} ->
				throw(Error)
			end
		end, Ls),
	    report_duplicated_portips(Ls),
	    {ok, {{one_for_one, 10, 1}, Ls2}}
    end.
  
report_duplicated_portips(L) ->
    LKeys = [Port || {Port, _, _} <- L],
    LNoDupsKeys = proplists:get_keys(L),
    case LKeys -- LNoDupsKeys of
	[] -> ok;
	Dups ->
	    ?CRITICAL_MSG("In the ejabberd configuration there are duplicated "
			  "Port number + IP address:~n  ~p",
			  [Dups])
  end.





%% @spec (PortIP, Opts) -> {Port, IPT, IPS, IPV, OptsClean}
%% where
%%      PortIP = Port | {Port, IPT | IPS}
%%      Port = integer()
%%      IPT = tuple()
%%      IPS = string()
%%      IPV = inet | inet6
%%      Opts = [IPV | {ip, IPT} | atom() | tuple()]
%%      OptsClean = [atom() | tuple()]
%% @doc Parse any kind of ejabberd listener specification.
%% The parsed options are returned in several formats.
%% OptsClean does not include inet/inet6 or ip options.
%% Opts can include the options inet6 and {ip, Tuple},
%% but they are only used when no IP address was specified in the PortIP.
%% The IP version (either IPv4 or IPv6) is inferred from the IP address type,
%% so the option inet/inet6 is only used when no IP is specified at all.

parse_listener_portip(PortIP, Opts) ->
    {IPOpt, Opts2} = strip_ip_option(Opts),
    {IPVOpt, OptsClean} = case lists:member(inet6, Opts2) of
			      true -> {inetstart6, Opts2 -- [inet6]};
			      false -> {inet, Opts2}
			  end,
    {Port, IPT, IPS, Proto} =
	case add_proto(PortIP, Opts) of
	    {P, Prot} ->
		T = get_ip_tuple(IPOpt, IPVOpt),
		S = jlib:ip_to_list(T),
		{P, T, S, Prot};
	    {P, T, Prot} when is_integer(P) and is_tuple(T) ->
		S = jlib:ip_to_list(T),
		{P, T, S, Prot};
	    {P, S, Prot} when is_integer(P) and is_binary(S) ->
		[S | _] = str:tokens(S, <<"/">>),
		{ok, T} = inet_parse:address(binary_to_list(S)),
		{P, T, S, Prot}
	end,
    IPV = case tuple_size(IPT) of
	      4 -> inet;
	      8 -> inet6
	  end,
    {Port, IPT, IPS, IPV, Proto, OptsClean}.

prepare_opts(IPT, IPV, OptsClean) ->
    %% The first inet|inet6 and the last {ip, _} work,
    %% so overriding those in Opts
    Opts = [IPV | OptsClean] ++ [{ip, IPT}],
    SockOpts = lists:filter(fun({ip, _}) -> true;
			       (inet6) -> true;
			       (inet) -> true;
			       ({backlog, _}) -> true;
			       (_) -> false
			    end, Opts),
    {Opts, SockOpts}.

add_proto(Port, Opts) when is_integer(Port) ->
    {Port, get_proto(Opts)};
add_proto({Port, Proto}, _Opts) when is_atom(Proto) ->
    {Port, normalize_proto(Proto)};
add_proto({Port, Addr}, Opts) ->
    {Port, Addr, get_proto(Opts)};
add_proto({Port, Addr, Proto}, _Opts) ->
    {Port, Addr, normalize_proto(Proto)}.

strip_ip_option(Opts) ->
    {IPL, OptsNoIP} = lists:partition(
			fun({ip, _}) -> true;
			   (_) -> false
			end,
			Opts),
    case IPL of
	%% Only the first ip option is considered
	[{ip, T1} | _] ->
	    {T1, OptsNoIP};
	[] ->
	    {no_ip_option, OptsNoIP}
    end.

get_ip_tuple(no_ip_option, inet) ->
    {0, 0, 0, 0};
get_ip_tuple(no_ip_option, inet6) ->
    {0, 0, 0, 0, 0, 0, 0, 0};
get_ip_tuple(IPOpt, _IPVOpt) ->
    IPOpt.



%% @spec (Port, Module, Opts) -> {ok, Pid} | {error, Error}
start_listener(Port, Module, Opts) ->
    case start_listener2(Port, Module, Opts) of
	{ok, _Pid} = R -> R;
	{error, {{'EXIT', {undef, [{M, _F, _A}|_]}}, _} = Error} ->
	    ?ERROR_MSG("Error starting the ejabberd listener: ~p.~n"
		       "It could not be loaded or is not an ejabberd listener.~n"
		       "Error: ~p~n", [Module, Error]),
	    {error, {module_not_available, M}};
	{error, {already_started, Pid}} ->
	    {ok, Pid};
	{error, Error} ->
	    {error, Error}
    end.

%% @spec (Port, Module, Opts) -> {ok, Pid} | {error, Error}
start_listener2(Port, Module, Opts) ->
    %% It is only required to start the supervisor in some cases.
    %% But it doesn't hurt to attempt to start it for any listener.
    %% So, it's normal (and harmless) that in most cases this call returns: {error, {already_started, pid()}}
  %%  maybe_start_sip(Module),
    start_module_sup(Port, Module),
    start_listener_sup(Port, Module, Opts).

start_module_sup(_Port, Module) ->
    Proc1 = gen_mod:get_module_proc(<<"sup">>, Module),
    ChildSpec1 =
	{Proc1,
	 {emipian_tmp_sup, start_link, [Proc1, strip_frontend(Module)]},
	 permanent,
	 infinity,
	 supervisor,
	 [emipian_tmp_sup]},
    supervisor:start_child(emipian_sup, ChildSpec1).

start_listener_sup(PortIP, Module, RawOpts) ->

  try check_listener_options(RawOpts) of
	ok ->
	    {Port, IPT, IPS, IPV, Proto, OptsClean} = parse_listener_portip(PortIP, RawOpts),
	    {Opts, SockOpts} = prepare_opts(IPT, IPV, OptsClean),
	    case Proto of
		udp -> ok;
		_ ->
		    emipian_socket_server:start(PortIP, Module, SockOpts, Port, IPS,Opts)
	    end
    catch
	throw:{error, Error} ->
	    ?ERROR_MSG(Error, [])
    end.


stop_listeners() ->
    Ports = emipian_config:get_option(listen, fun validate_cfg/1),
    lists:foreach(
      fun({PortIpNetp, Module, _Opts}) ->
	      delete_listener(PortIpNetp, Module)
      end,
      Ports).

%% @spec (PortIP, Module) -> ok
%% where
%%      PortIP = {Port, IPT | IPS}
%%      Port = integer()
%%      IPT = tuple()
%%      IPS = string()
%%      Module = atom()
stop_listener(PortIP, _Module) ->
    supervisor:terminate_child(emipian_listeners, PortIP),
    supervisor:delete_child(emipian_listeners, PortIP).

%% @spec (PortIP, Module, Opts) -> {ok, Pid} | {error, Error}
%% where
%%      PortIP = {Port, IPT | IPS}
%%      Port = integer()
%%      IPT = tuple()
%%      IPS = string()
%%      IPV = inet | inet6
%%      Module = atom()
%%      Opts = [IPV | {ip, IPT} | atom() | tuple()]
%% @doc Add a listener and store in config if success
add_listener(PortIP, Module, Opts) ->
    {Port, IPT, _, _, Proto, _} = parse_listener_portip(PortIP, Opts),
    PortIP1 = {Port, IPT, Proto},
    case start_listener(PortIP1, Module, Opts) of
	{ok, _Pid} ->
	    Ports = case emipian_config:get_option(
                           listen, fun validate_cfg/1) of
			undefined ->
			    [];
			Ls ->
			    Ls
		    end,
	    Ports1 = lists:keydelete(PortIP1, 1, Ports),
	    Ports2 = [{PortIP1, Module, Opts} | Ports1],
            Ports3 = lists:map(fun transform_option/1, Ports2),
	    emipian_config:add_option(listen, Ports3),
	    ok;
	{error, {already_started, _Pid}} ->
	    {error, {already_started, PortIP}};
	{error, Error} ->
	    {error, Error}
    end.

delete_listener(PortIP, Module) ->
    delete_listener(PortIP, Module, []).

%% @spec (PortIP, Module, Opts) -> ok
%% where
%%      PortIP = {Port, IPT | IPS}
%%      Port = integer()
%%      IPT = tuple()
%%      IPS = string()
%%      Module = atom()
%%      Opts = [term()]
delete_listener(PortIP, Module, Opts) ->
    {Port, IPT, _, _, Proto, _} = parse_listener_portip(PortIP, Opts),
    PortIP1 = {Port, IPT, Proto},
    Ports = case emipian_config:get_option(
                   listen, fun validate_cfg/1) of
		undefined ->
		    [];
		Ls ->
		    Ls
	    end,
    Ports1 = lists:keydelete(PortIP1, 1, Ports),
    Ports2 = lists:map(fun transform_option/1, Ports1),
    emipian_config:add_option(listen, Ports2),
    stop_listener(PortIP1, Module).


-spec is_frontend({frontend, module} | module()) -> boolean().

is_frontend({frontend, _Module}) -> true;
is_frontend(_) -> false.

%% @doc(FrontMod) -> atom()
%% where FrontMod = atom() | {frontend, atom()}
-spec strip_frontend({frontend, module()} | module()) -> module().

strip_frontend({frontend, Module}) -> Module;
strip_frontend(Module) when is_atom(Module) -> Module.

maybe_start_sip(esip_socket) ->
    ejabberd:start_app(esip);
maybe_start_sip(_) ->
    ok.

%%%
%%% Check options
%%%

check_listener_options(Opts) ->
  %%  case includes_deprecated_ssl_option(Opts) of
%%	false -> ok;
%%	true ->
%%	    Error = "There is a problem with your ejabberd configuration file: "
%%		"the option 'ssl' for listening sockets is no longer available."
%%		" To get SSL encryption use the option 'tls'.",%%
%%	    throw({error, Error})
 %%   end,
    case certfile_readable(Opts) of
	true -> ok;
	{false, Path} ->
            ErrorText = "There is a problem in the configuration: "
		"the specified file is not readable: ",
	    throw({error, ErrorText ++ Path})
    end,
    ok.

%% Parse the options of the socket,
%% and return if the deprecated option 'ssl' is included
%% @spec (Opts) -> true | false
includes_deprecated_ssl_option(Opts) ->
    case lists:keysearch(ssl, 1, Opts) of
	{value, {ssl, _SSLOpts}} ->
	    true;
	_ ->
	    lists:member(ssl, Opts)
    end.

%% @spec (Opts) -> true | {false, Path::string()}
certfile_readable(Opts) ->
    case proplists:lookup(certfile, Opts) of
	none -> true;
	{certfile, Path} ->
            PathS = binary_to_list(Path),
	    case emipian_config:is_file_readable(PathS) of
		true -> true;
		false -> {false, PathS}
	    end
    end.

get_proto(Opts) ->
    case proplists:get_value(proto, Opts) of
	undefined ->
	    tcp;
	Proto ->
	    normalize_proto(Proto)
    end.

normalize_proto(tcp) -> tcp;
normalize_proto(udp) -> udp;
normalize_proto(UnknownProto) ->
    ?WARNING_MSG("There is a problem in the configuration: "
		 "~p is an unknown IP protocol. Using tcp as fallback",
		 [UnknownProto]),
    tcp.

socket_error(Reason, PortIP, Module, SockOpts, Port, IPS) ->
    ReasonT = case Reason of
		  eaddrnotavail ->
		      "IP address not available: " ++ IPS;
		  eaddrinuse ->
		      "IP address and port number already used: "
			  ++binary_to_list(IPS)++" "++integer_to_list(Port);
		  _ ->
		      format_error(Reason)
	      end,
    ?ERROR_MSG("Failed to open socket:~n  ~p~nReason: ~s",
	       [{Port, Module, SockOpts}, ReasonT]),
    throw({Reason, PortIP}).

format_error(Reason) ->
    case inet:format_error(Reason) of
	"unknown POSIX error" ->
	    atom_to_list(Reason);
	ReasonStr ->
	    ReasonStr
    end.

-define(IS_CHAR(C), (is_integer(C) and (C >= 0) and (C =< 255))).
-define(IS_UINT(U), (is_integer(U) and (U >= 0) and (U =< 65535))).
-define(IS_PORT(P), (is_integer(P) and (P > 0) and (P =< 65535))).
-define(IS_TRANSPORT(T), ((T == tcp) or (T == udp))).

transform_option({{Port, IP, Transport}, Mod, Opts}) ->
    IPStr = if is_tuple(IP) ->
                    list_to_binary(inet_parse:ntoa(IP));
               true ->
                    IP
            end,
    Opts1 = lists:map(
              fun({ip, IPT}) when is_tuple(IPT) ->
                      {ip, list_to_binary(inet_parse:ntoa(IP))};
                 (tls) -> {tls, true};
                 (ssl) -> {tls, true};
                 (zlib) -> {zlib, true};
                 (starttls) -> {starttls, true};
                 (starttls_required) -> {starttls_required, true};
                 (Opt) -> Opt
              end, Opts),
    Opts2 = lists:foldl(
              fun(Opt, Acc) ->
                      try
                          Mod:transform_listen_option(Opt, Acc)
                      catch error:undef ->
                              [Opt|Acc]
                      end
              end, [], Opts1),
    TransportOpt = if Transport == tcp -> [];
                      true -> [{transport, Transport}]
                   end,
    IPOpt = if IPStr == <<"0.0.0.0">> -> [];
               true -> [{ip, IPStr}]
            end,
    IPOpt ++ TransportOpt ++ [{port, Port}, {module, Mod} | Opts2];
transform_option({{Port, Transport}, Mod, Opts})
  when ?IS_TRANSPORT(Transport) ->
    transform_option({{Port, {0,0,0,0}, Transport}, Mod, Opts});
transform_option({{Port, IP}, Mod, Opts}) ->
    transform_option({{Port, IP, tcp}, Mod, Opts});
transform_option({Port, Mod, Opts}) ->
    transform_option({{Port, {0,0,0,0}, tcp}, Mod, Opts});
transform_option(Opt) ->
    Opt.

transform_options(Opts) ->
    lists:foldl(fun transform_options/2, [], Opts).

transform_options({listen, LOpts}, Opts) ->
    [{listen, lists:map(fun transform_option/1, LOpts)} | Opts];
transform_options(Opt, Opts) ->
    [Opt|Opts].

-type transport() :: udp | tcp.
-type port_ip_transport() :: inet:port_number() |
                             {inet:port_number(), transport()} |
                             {inet:port_number(), inet:ip_address()} |
                             {inet:port_number(), inet:ip_address(),
                              transport()}.
-spec validate_cfg(list()) -> [{port_ip_transport(), module(), list()}].

validate_cfg(L) ->
    lists:map(
      fun(LOpts) ->
              lists:foldl(
                fun({port, Port}, {{_, IP, T}, Mod, Opts}) ->
                        true = ?IS_PORT(Port),
                        {{Port, IP, T}, Mod, Opts};
                   ({ip, IP}, {{Port, _, T}, Mod, Opts}) ->
                        {{Port, prepare_ip(IP), T}, Mod, Opts};
                   ({transport, T}, {{Port, IP, _}, Mod, Opts}) ->
                        true = ?IS_TRANSPORT(T),
                        {{Port, IP, T}, Mod, Opts};
                   ({module, Mod}, {Port, _, Opts}) ->
                        {Port, prepare_mod(Mod), Opts};
                   (Opt, {Port, Mod, Opts}) ->
                        {Port, Mod, [Opt|Opts]}
                end, {{5222, {0,0,0,0}, tcp}, emipian_c2s, []}, LOpts)
      end, L).



prepare_ip({A, B, C, D} = IP)
  when ?IS_CHAR(A) and ?IS_CHAR(B) and ?IS_CHAR(C) and ?IS_CHAR(D) ->
    IP;
prepare_ip({A, B, C, D, E, F, G, H} = IP)
  when ?IS_UINT(A) and ?IS_UINT(B) and ?IS_UINT(C) and ?IS_UINT(D)
       and ?IS_UINT(E) and ?IS_UINT(F) and ?IS_UINT(G) and ?IS_UINT(H) ->
    IP;
prepare_ip(IP) when is_list(IP) ->
    {ok, Addr} = inet_parse:address(IP),
    Addr;
prepare_ip(IP) when is_binary(IP) ->
    prepare_ip(binary_to_list(IP)).

prepare_mod(emipian_sip) ->
    prepare_mod(sip);
prepare_mod(sip) ->
    esip_socket;
prepare_mod(Mod) when is_atom(Mod) ->
    Mod.
