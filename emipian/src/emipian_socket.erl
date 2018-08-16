%% @author hyf
%% @doc @todo Add description to emipian_socket.

 
-module(emipian_socket).
%% API
-export([start/4,
	 connect/3,
	 connect/4,
	 starttls/2,
	 starttls/3,
	 compress/1,
	 compress/2,
	 reset_stream/1,
 	 send/2, 
	 change_shaper/2,
	 monitor/1,
	 get_sockmod/1,
	 get_peer_certificate/1,
	 get_verify_result/1,
	 close/1,
	 sockname/1, peername/1]).
 
-include("emipian.hrl").
-include("logger.hrl").
-include("jlib.hrl").

-type sockmod() :: emipian_http_poll |
                   emipian_http_bind |
                   gen_tcp | p1_tls | ezlib.
-type receiver() :: pid () | atom().
-type socket() :: pid() | inet:socket() |
                  p1_tls:tls_socket() |
                  ezlib:zlib_socket() |
                  emipian_http_bind:bind_socket() |
                  emipian_http_poll:poll_socket().

-record(socket_state, {sockmod = gen_tcp :: sockmod(),
                       socket = self() :: socket(),
                       receiver = self() :: receiver()}).

-type socket_state() :: #socket_state{}.

-export_type([socket_state/0, sockmod/0]).

-spec start(atom(), sockmod(), socket(), [{atom(), any()}]) -> any().

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function:
%% Description:
%%--------------------------------------------------------------------
start(Module, SockMod, Socket, Opts) ->
   %%  HandShakeSize = case lists:keysearch(handshakesize, 1,
    case Module:socket_type() of
      bin_stream ->
       {ReceiverMod, Receiver, RecRef} = case catch
						   SockMod:custom_receiver(Socket)
						of
					      {receiver, RecMod, RecPid} ->
						  {RecMod, RecPid, RecMod};
					      _ ->
						  RecPid =
						      emipian_receiver:start(Socket,
									      SockMod,
									      none,
									      Opts),
						  {emipian_receiver, RecPid,
						   RecPid}
					    end,
	  SocketData = #socket_state{sockmod = SockMod,
				     socket = Socket, receiver = RecRef},
	   case Module:start({?MODULE, SocketData}, Opts) of
	    {ok, Pid} ->
		case SockMod:controlling_process(Socket, Receiver) of
		  ok -> ok;
		  {error, _Reason} -> SockMod:close(Socket)
		end,
		ReceiverMod:become_controller(Receiver, Pid);
	    {error, _Reason} ->
		SockMod:close(Socket),
		case ReceiverMod of
		  emipian_receiver -> ReceiverMod:close(Receiver);
		  _ -> ok
		end
	  end;
      independent -> ok;
      raw ->
	  case Module:start({SockMod, Socket}, Opts) of
	    {ok, Pid} ->
		case SockMod:controlling_process(Socket, Pid) of
		  ok -> ok;
		  {error, _Reason} -> SockMod:close(Socket)
		end;
	    {error, _Reason} -> SockMod:close(Socket)
	  end
    end.

connect(Addr, Port, Opts) ->
    connect(Addr, Port, Opts, infinity).

connect(Addr, Port, Opts, Timeout) ->
    case gen_tcp:connect(Addr, Port, Opts, Timeout) of
      {ok, Socket} ->
	  Receiver = emipian_receiver:start(Socket, gen_tcp,
					     none),
	  SocketData = #socket_state{sockmod = gen_tcp,
				     socket = Socket, receiver = Receiver},
	  Pid = self(),
	  case gen_tcp:controlling_process(Socket, Receiver) of
	    ok ->
		emipian_receiver:become_controller(Receiver, Pid),
		{ok, SocketData};
	    {error, _Reason} = Error -> gen_tcp:close(Socket), Error
	  end;
      {error, _Reason} = Error -> Error
    end.

starttls(SocketData, TLSOpts) ->
    {ok, TLSSocket} = p1_tls:tcp_to_tls(SocketData#socket_state.socket, TLSOpts),
    emipian_receiver:starttls(SocketData#socket_state.receiver, TLSSocket),
    SocketData#socket_state{socket = TLSSocket, sockmod = p1_tls}.

starttls(SocketData, TLSOpts, Data) ->
    {ok, TLSSocket} = p1_tls:tcp_to_tls(SocketData#socket_state.socket, TLSOpts),
    emipian_receiver:starttls(SocketData#socket_state.receiver, TLSSocket),
    send(SocketData, Data),
    SocketData#socket_state{socket = TLSSocket, sockmod = p1_tls}.

compress(SocketData) -> compress(SocketData, undefined).

compress(SocketData, Data) ->
    {ok, ZlibSocket} =
	emipian_receiver:compress(SocketData#socket_state.receiver,
				   Data),
    SocketData#socket_state{socket = ZlibSocket,
			    sockmod = ezlib}.

reset_stream(SocketData)
    when is_pid(SocketData#socket_state.receiver) ->
    emipian_receiver:reset_stream(SocketData#socket_state.receiver);
reset_stream(SocketData)
    when is_atom(SocketData#socket_state.receiver) ->
    (SocketData#socket_state.receiver):reset_stream(SocketData#socket_state.socket).

-spec send(socket_state(), iodata()) -> ok.

send(SocketData, Data) ->
    case catch (SocketData#socket_state.sockmod):send(
	     SocketData#socket_state.socket, Data) of
        ok -> ok;
	{error, timeout} ->
	    ?INFO_MSG("Timeout on ~p:send",[SocketData#socket_state.sockmod]),
	    exit(normal);
        Error ->
	    ?DEBUG("Error in ~p:send: ~p",[SocketData#socket_state.sockmod, Error]),
	    exit(normal)
    end.

%% Can only be called when in c2s StateData#state.xml_socket is true
%% This function is used for HTTP bind
%% sockmod=emipian_http_poll|emipian_http_bind or any custom module


change_shaper(SocketData, Shaper)
    when is_pid(SocketData#socket_state.receiver) ->
    emipian_receiver:change_shaper(SocketData#socket_state.receiver,
				    Shaper);
change_shaper(SocketData, Shaper)
    when is_atom(SocketData#socket_state.receiver) ->
    (SocketData#socket_state.receiver):change_shaper(SocketData#socket_state.socket,
						     Shaper).

monitor(SocketData)
    when is_pid(SocketData#socket_state.receiver) ->
    erlang:monitor(process,
		   SocketData#socket_state.receiver);
monitor(SocketData)
    when is_atom(SocketData#socket_state.receiver) ->
    (SocketData#socket_state.receiver):monitor(SocketData#socket_state.socket).

get_sockmod(SocketData) ->
    SocketData#socket_state.sockmod.

get_peer_certificate(SocketData) ->
    p1_tls:get_peer_certificate(SocketData#socket_state.socket).

get_verify_result(SocketData) ->
    p1_tls:get_verify_result(SocketData#socket_state.socket).

close(SocketData) ->
    emipian_receiver:close(SocketData#socket_state.receiver).

sockname(#socket_state{sockmod = SockMod,
		       socket = Socket}) ->
    case SockMod of
      gen_tcp -> inet:sockname(Socket);
      _ -> SockMod:sockname(Socket)
    end.

peername(#socket_state{sockmod = SockMod,
		       socket = Socket}) ->
    case SockMod of
      gen_tcp -> inet:peername(Socket);
      _ -> SockMod:peername(Socket)
    end.


