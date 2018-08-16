%% @author hyf
%% @doc @todo Add description to emipian_route.


-module(emipian_route).

-include("session.hrl").
-include("logger.hrl").

-export([
		sendmsg/2,
		route/2
]).

-behaviour(gen_server).

-export([
        start_link/0,
        init/1,
		handle_call/3,
		handle_cast/2,
		handle_info/2,
		terminate/2,
		code_change/3]).

-record(state, {}).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	{ok, #state{}}.

%% ====================================================================
%% Internal functions
%% ====================================================================

sendmsg(Session, Arg) ->
	
   #session{node = Node} = Session,
         ?INFO_MSG("routemsg ,node:~p,node():~p ~n", [Node,node()]),
		case Node == node() of
		    true  -> route(Session, Arg);
		    false -> rpc:call(Node, ?MODULE, route, [Session, Arg])
		end.


route(Session, Arg) ->
    #session{sessionid =SessionID} = Session, 
	LocalSession =  emipian_sm:get_session(SessionID),
    #session{selfpid = Pid}= LocalSession, 
   %%   ?INFO_MSG("route ,selfpid:~p,Arg:~p ~n", [Pid,Arg]),
	  try	 
            Pid!Arg
         catch
			_:_->ok 
      end.
   

handle_call(Req, _From, State) ->
	{stop, {badreq, Req}, State}.

handle_cast(Msg, State) ->
	{stop, {badmsg, Msg}, State}.

handle_info({'DOWN', _MRef, _Type, _Object, _Info}, State) ->
	{noreply, State};
handle_info(Info, State) ->
	{stop, {badinfo, Info}, State}.

terminate(_Reason, _State) ->
	ok.

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.





