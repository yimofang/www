

-module(emipian_acceptor).
-include("logger.hrl").

-export([start_link/3, start_link/4, init/4]).

-define(EMFILE_SLEEP_MSEC, 100).
-define(ACCEPT_TIMEOUT, 60000).
-define(SSL_TIMEOUT, 20000).
-define(SSL_HANDSHAKE_TIMEOUT, 60000).

start_link(Server, Listen, Module) ->
    start_link(Server, Listen, Module, []).

start_link(Server, Listen, Module, Opts) ->
    proc_lib:spawn_link(?MODULE, init, [Server, Listen, Module, Opts]).

do_accept(Server, Listen) ->
    T1 = os:timestamp(),
    case transport_accept(Listen) of
        {ok, Socket} ->
            gen_server:cast(Server, {accepted, self(), timer:now_diff(os:timestamp(), T1)}),
            Finish = finish_accept(Socket),
			Finish;
        Other ->
			Other
    end.

init(Server, Listen, Module, Opts) ->
    case catch do_accept(Server, Listen) of
        {ok, Socket} ->
            call_loop(Socket,Module, Opts);
        {error, Err} when Err =:= closed orelse
                          Err =:= esslaccept orelse
                          Err =:= timeout ->
            exit(normal);
        Other ->
            %% Mitigate out of file descriptor scenario by sleeping for a
            %% short time to slow error rate
            case Other of
                {error, emfile} ->
                    receive
                    after ?EMFILE_SLEEP_MSEC ->
                            ok
                    end;
                _ ->
                    ok
            end,
            exit({error, accept_failed})
    end.


transport_accept({ssl, ListenSocket}) ->
		
    case ssl:transport_accept(ListenSocket) of
        {ok, Socket} ->

            {ok, {ssl, Socket}};
        {error, _} = Err ->
            Err
    end;
transport_accept(ListenSocket) ->
	NewSocket = gen_tcp:accept(ListenSocket,?ACCEPT_TIMEOUT),
   case NewSocket of
	{ok, Socket} ->
	    case {inet:sockname(Socket), inet:peername(Socket)} of
		{{ok, {Addr, Port}}, {ok, {PAddr, PPort}}} ->
		    ?INFO_MSG("(~w) Accepted connection ~s:~p -> ~s:~p",
			      [Socket, inet_parse:ntoa(PAddr), PPort,
			       inet_parse:ntoa(Addr), Port]);
		_ ->
          ?INFO_MSG(" transport_accept  not sockname  (~w) ~n",
				       [Socket]),	

			ok
	    end;
     {error, timeout} ->
	    ok;   
     {error, Reason} ->
	    ?ERROR_MSG("(~w) Failed TCP accept: ~w",
                       [ListenSocket, Reason])
      end,
 NewSocket.

finish_accept({ssl, Socket}) ->
	
   ?INFO_MSG(" finish_accept SSL (~w) ~n",  [Socket]),	
    
	SocketName =case {ssl:sockname(Socket), ssl:peername(Socket)} of
			{{ok, {Addr0, Port0}}, {ok, {PAddr0, PPort0}}} ->
                Addr = Addr0,
                PAddr = PAddr0,
                Port = Port0,
                PPort = PPort0,
                ok;
			_ ->
               Addr = 0,
                PAddr = 0,
                Port = 0,
                PPort = 0,
			    error
     end,
	

    case ssl:ssl_accept(Socket, ?SSL_HANDSHAKE_TIMEOUT) of
        ok ->
		   ?INFO_MSG(" sslaccept ssl_accept2 (~w) ~n",
				       [Socket]),	
		    case SocketName  of
			ok ->
			    ?INFO_MSG("(~w), Accepted SSL ~s:~p -> ~s:~p",
				       [Socket,inet_parse:ntoa(PAddr), PPort,
				       inet_parse:ntoa(Addr), Port]);
			_ ->
			    ok
		    end,
            {ok, {ssl, Socket}};
        {error, Reason} = Err ->
		    case SocketName of
			ok->
			?ERROR_MSG(" Failed SSL TCP accept: ~s:~p, ~w",
             [  inet_parse:ntoa(PAddr), PPort,Reason]);
			_ ->
			 ?ERROR_MSG(" Failed SSL TCP accept not SockName:  ~w",
             [ Reason])

		    end,

            Err
    end;
finish_accept(Socket) ->
	   ?INFO_MSG(" finish_accept  (~w) ~n",
				       [Socket]),	
    {ok, Socket}.

call_loop({ssl, Socket},Module,Opts) ->
	emipian_socket:start((Module), ssl, Socket, Opts);
call_loop(Socket,Module,Opts) ->
	 emipian_socket:start((Module), gen_tcp, Socket, Opts).
