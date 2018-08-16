%% @author hyf
%% @doc @todo Add description to mysql0.


-module(mysql).

-behaviour(gen_server).

%%--------------------------------------------------------------------
%% External exports
%%--------------------------------------------------------------------
-export([
	 fetch/2,
	 fetch/3,
     start_link/1,
	 get_result_field_info/1,
	 get_result_rows/1,
	 get_result_affected_rows/1,
	 get_result_reason/1,

	 quote/1,
	 asciz_binary/2


%%	 stop/0,

  %%   gc_each/1
	]).

%%--------------------------------------------------------------------
%% Internal exports - just for mysql_* modules
%%--------------------------------------------------------------------
-export([log/3,
	 log/4
	]).

%%--------------------------------------------------------------------
%% Internal exports - gen_server callbacks
%%--------------------------------------------------------------------
-export([init/1,
	 handle_call/3,
	 handle_cast/2,
	 handle_info/2,
	 terminate/2,
	 code_change/3
	]).

%%--------------------------------------------------------------------
%% Records
%%--------------------------------------------------------------------
-include("mysql.hrl").
-record(state, {
	  log_fun,	%% undefined | function for logging,
      conn_id,  
      gc_tref   %% undefined | timer:TRef
	 }).


%%--------------------------------------------------------------------
%% Macros
%%--------------------------------------------------------------------
%% -define(SERVER, mysql_dispatcher).
-define(CONNECT_TIMEOUT, 5000).
-define(LOCAL_FILES, 128).

-define(PORT, 3306).


%%====================================================================
%% External functions
%%====================================================================

%% stop() ->
%%    gen_server:call(?SERVER, stop).

%% gc_each(Millisec) ->
%5    gen_server:call(?SERVER, {gc_each, Millisec}).

%%--------------------------------------------------------------------
%% Function: fetch(Id, Query)
%%           fetch(Id, Query, Timeout)
%%           Id      = term(), connection-group Id
%%           Query   = string(), MySQL query in verbatim
%%           Timeout = integer() | infinity, gen_server timeout value
%% Descrip.: Send a query and wait for the result.
%% Returns : {data, MySQLRes}    |
%%           {updated, MySQLRes} |
%%           {error, MySQLRes}
%%           MySQLRes = term()
%%--------------------------------------------------------------------
%%--------------------------------------------------------------------
%% Function: fetch(Id, Query)
%%           fetch(Id, Query, Timeout)
%%           Id      = term(), connection-group Id
%%           Query   = string(), MySQL query in verbatim
%%           Timeout = integer() | infinity, gen_server timeout value
%% Descrip.: Send a query and wait for the result.
%% Returns : {data, MySQLRes}    |
%%           {updated, MySQLRes} |
%%           {error, MySQLRes}
%%           MySQLRes = term()
%%--------------------------------------------------------------------
fetch(Id, Query) when is_list(Query) ->
    gen_server:call(Id, {fetch, Id, Query}).
fetch(Id, Query, Timeout) when is_list(Query) ->
    gen_server:call(Id, {fetch, Id, Query}, Timeout).


%%--------------------------------------------------------------------
%% Function: get_result_field_info(MySQLRes)
%%           MySQLRes = term(), result of fetch function on "data"
%% Descrip.: Extract the FieldInfo from MySQL Result on data received
%% Returns : FieldInfo
%%           FieldInfo = list() of {Table, Field, Length, Name}
%%--------------------------------------------------------------------
get_result_field_info(#mysql_result{fieldinfo = FieldInfo}) ->
    FieldInfo.

%%--------------------------------------------------------------------
%% Function: get_result_rows(MySQLRes)
%%           MySQLRes = term(), result of fetch function on "data"
%% Descrip.: Extract the Rows from MySQL Result on data received
%% Returns : Rows
%%           Rows = list() of list() representing records
%%--------------------------------------------------------------------
get_result_rows(#mysql_result{rows=AllRows}) ->
    AllRows.

%%--------------------------------------------------------------------
%% Function: get_result_affected_rows(MySQLRes)
%%           MySQLRes = term(), result of fetch function on "updated"
%% Descrip.: Extract the Rows from MySQL Result on update
%% Returns : AffectedRows
%%           AffectedRows = integer()
%%--------------------------------------------------------------------
get_result_affected_rows(#mysql_result{affectedrows=AffectedRows}) ->
    AffectedRows.

%%--------------------------------------------------------------------
%% Function: get_result_reason(MySQLRes)
%%           MySQLRes = term(), result of fetch function on "error"
%% Descrip.: Extract the error Reason from MySQL Result on error
%% Returns : Reason
%%           Reason    = string()
%%--------------------------------------------------------------------
get_result_reason(#mysql_result{error=Reason}) ->
    Reason.

%%--------------------------------------------------------------------
%% Function: quote(String)
%%           String = string()
%% Descrip.: Quote a string so that it can be included safely in a
%%           MySQL query.
%% Returns : Quoted = string()
%%--------------------------------------------------------------------
quote(String) when is_list(String) ->
    [34 | lists:reverse([34 | quote(String, [])])].	%% 34 is $"

quote([], Acc) ->
    Acc;
quote([0 | Rest], Acc) ->
    quote(Rest, [$0, $\\ | Acc]);
quote([10 | Rest], Acc) ->
    quote(Rest, [$n, $\\ | Acc]);
quote([13 | Rest], Acc) ->
    quote(Rest, [$r, $\\ | Acc]);
quote([$\\ | Rest], Acc) ->
    quote(Rest, [$\\ , $\\ | Acc]);
quote([39 | Rest], Acc) ->		%% 39 is $'
    quote(Rest, [39, $\\ | Acc]);	%% 39 is $'
quote([34 | Rest], Acc) ->		%% 34 is $"
    quote(Rest, [34, $\\ | Acc]);	%% 34 is $"
quote([26 | Rest], Acc) ->
    quote(Rest, [$Z, $\\ | Acc]);
quote([C | Rest], Acc) ->
    quote(Rest, [C | Acc]).

%%--------------------------------------------------------------------
%% Function: asciz_binary(Data, Acc)
%%           Data = binary()
%%           Acc  = list(), input accumulator
%% Descrip.: Find the first zero-byte in Data and add everything
%%           before it to Acc, as a string.
%% Returns : {NewList, Rest}
%%           NewList = list(), Acc plus what we extracted from Data
%%           Rest    = binary(), whatever was left of Data, not
%%                     including the zero-byte
%%--------------------------------------------------------------------
asciz_binary(<<>>, Acc) ->
    {lists:reverse(Acc), <<>>};
asciz_binary(<<0:8, Rest/binary>>, Acc) ->
    {lists:reverse(Acc), Rest};
asciz_binary(<<C:8, Rest/binary>>, Acc) ->
    asciz_binary(Rest, [C | Acc]).

%%--------------------------------------------------------------------
%% Function: log(LogFun, Level, Format)
%%           log(LogFun, Level, Format, Arguments)
%%           LogFun    = undefined | function() with arity 3
%%           Level     = debug | normal | error
%%           Format    = string()
%%           Arguments = list() of term()
%% Descrip.: Either call the function LogFun with the Level, Format
%%           and Arguments as parameters or log it to the console if
%%           LogFun is undefined.
%% Returns : void()
%%
%% Note    : Exported only for use by the mysql_* modules.
%%
%%--------------------------------------------------------------------
log(LogFun, Level, Format) ->
    log(LogFun, Level, Format, []).

log(LogFun, Level, Format, Arguments) when is_function(LogFun) ->
	Level1 =
         if Level =:= normal ->info;
			true ->Level
		 end,	
		
    LogFun(Level1, Format, Arguments);
log(undefined, _Level, Format, Arguments) ->
    %% default is to log to console
    io:format(Format, Arguments),
    io:format("~n", []).


%%====================================================================
%% gen_server callbacks
%%====================================================================
start_link([Host, Port, User, Password, Database, LogFun]) when is_list(Host), is_integer(Port), is_list(User),
								  is_list(Password), is_list(Database) ->

    crypto:start(),
    Pid = gen_server:start_link(?MODULE, [Host, Port, User, Password, Database, LogFun], []),
%%	log(LogFun, error, "mysql start_link ~p~n",[Pid]),
	Pid.

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%%           Args = [Id, Host, Port, User, Password, Database, LogFun]
%%             Id       = term(), connection-group Id
%%             Host     = string()
%%             Port     = integer()
%%             User     = string()
%%             Password = string()
%%             Database = string()
%%             LogFun   = undefined | function() with arity 3
%% Descrip.: Initiates the gen_server (MySQL dispatcher).
%%--------------------------------------------------------------------
init([Host, Port, User, Password, Database, LogFun]) ->
%%	 crypto:start(),
	process_flag(trap_exit, true),
    case mysql_conn:start(Host, Port, User, Password, Database, LogFun) of
	{ok, ConnPid} ->
		   {ok, #state{log_fun    = LogFun,
					   conn_id = ConnPid,
                gc_tref = undefined
			       }};
	{error, Reason} ->
	    log(LogFun, error, "mysql: Failed starting first MySQL connection handler, exiting"),
	    {stop, {error, Reason}}
    end.


%%--------------------------------------------------------------------
%% Function: handle_call({fetch, Id, Query}, From, State)
%%           Id    = term(), connection-group id
%%           Query = string(), MySQL query
%% Descrip.: Make a MySQL query. Use the first connection matching Id
%%           in our connection-list. Don't block the mysql_dispatcher
%%           by returning {noreply, ...} here and let the mysql_conn
%%           do gen_server:reply(...) when it has an answer.
%% Returns : {noreply, NewState}             |
%%           {reply, {error, Reason}, State}
%%           NewState = state record()
%%           Reason   = atom() | string()
%%--------------------------------------------------------------------
handle_call({fetch, Id, Query}, From, State) ->
       log(State#state.log_fun, debug, "mysql: fetch ~p (id ~p)", [Query, Id]),
	    mysql_conn:fetch(State#state.conn_id, Query, From),
	    {noreply, State};



%%--------------------------------------------------------------------
%% Function: handle_call(get_logfun, From, State)
%% Descrip.: Fetch our logfun.
%% Returns : {reply, {ok, LogFun}, State}
%%           LogFun = undefined | function() with arity 3
%%--------------------------------------------------------------------
handle_call(get_logfun, _From, State) ->
    {reply, {ok, State#state.log_fun}, State};

handle_call(stop, _From, State) ->
    {stop, normal, State};

handle_call(Unknown, _From, State) ->
    log(State#state.log_fun, error, "mysql: Received unknown gen_server call : ~p", [Unknown]),
    {reply, {error, "unknown gen_server call in mysql client"}, State}.


%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State)
%% Descrip.: Handling cast messages
%% Returns : {noreply, State}          |
%%           {noreply, State, Timeout} |
%%           {stop, Reason, State}            (terminate/2 is called)
%%--------------------------------------------------------------------
handle_cast(Unknown, State) ->
    log(State#state.log_fun, error, "mysql: Received unknown gen_server cast : ~p", [Unknown]),
    {noreply, State}.


%%--------------------------------------------------------------------
%% Function: handle_info(Msg, State)
%% Descrip.: Handling all non call/cast messages
%% Returns : {noreply, State}          |
%%           {noreply, State, Timeout} |
%%           {stop, Reason, State}            (terminate/2 is called)
%%--------------------------------------------------------------------



handle_info(gc, State) ->
    erlang:garbage_collect(self()),
    {noreply, State};


handle_info(Info, State) ->
    log(State#state.log_fun, error, "mysql: Received unknown signal : ~p", [Info]),
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State)
%% Descrip.: Shutdown the server
%% Returns : Reason
%%--------------------------------------------------------------------
terminate(Reason, State) ->
    LogFun = State#state.log_fun,
 
%%	log(LogFun, error, "mysql terminate:  ~p-~p~n", [State#state.conn_id,Reason]),
	mysql_conn:stop(State#state.conn_id),
    LogLevel = case Reason of
		   normal -> debug;
		   _ -> error
	       end,
    log(LogFun, LogLevel, "mysql: Terminating with reason : ~p", [Reason]),
    Reason.

%%--------------------------------------------------------------------
%% Function: code_change(_OldVsn, State, _Extra)
%% Descrip.: Convert process state when code is changed
%% Returns : {ok, State}
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.




