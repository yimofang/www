%% @author hyf
%% @doc @todo Add description to emipian_pools.


-module(emipian_pools).
-include("mongo_protocol.hrl").
-include("apns.hrl").
-include("logger.hrl").

%% ====================================================================
%% API functions
%% ====================================================================
-export([start_link/0,init/1,startmysqls/0,startpools/0]).


start_link() ->
    supervisor:start_link({local, emipian_poolses}, ?MODULE, []).
init(_) ->
    {ok, {{one_for_one, 10, 1}, []}}.


startpools()->
 %%  ets:new(tcp_pools, [named_table, public]),
   startmysqls(),
   mongo_app:start(1, 1)
  , startmongopool()
   ,apns:start()
   ,startapnspool()
   .

startmysqls()
  ->
    case emipian_config:get_option(mysqlpools, fun validate_cfg/1) of
	undefined ->
	    ignore;
	Ls ->
	    Ls2 = lists:map(
	        fun({Name,Opts}) ->
		        case startmysqlpool({Name,Opts}) of
			    {ok, _Pid} = R -> R;
			    {error, Error} ->
				throw(Error)
			end
		end, Ls),
	    {ok, {{one_for_one, 10, 1}, Ls2}}
    end.

startmysqlpool({Name,Opts}) ->

    {Host,Port,Database,Username,Password,Size,Max_Overflow,TimeOut} 
    = getdatabalseparam(Opts),
    WorkArg =[binary_to_list(Host), Port, binary_to_list(Username),
			   binary_to_list(Password), binary_to_list(Database), fun mysqllog/3],

	 PoolArg = [{name,{local, Name}},
                        {worker_module, mysql},
                        {size, Size}, {max_overflow, Max_Overflow},{checklink,fun checkmysql/1}],
	ChildSpec = poolboy:child_spec(Name, PoolArg, WorkArg),
%%	Name0 = gen_action_mod:get_module_proc(<<"mysql">>, Name) , 
%%	gen_mod:get_module_proc(<<"sup">>, Module),
%%	ChildSpec = {Name,
%%		 {poolboy, start_link, [PoolArg, WorkArg]},
%%		 permanent,
	%%	 brutal_kill,
%%         5000,
%%		 worker,
%%		 [poolboy]},
    supervisor:start_child(emipian_poolses, ChildSpec).

%%	poolboy:start_link([{name,{local, Name}},
%%                        {worker_module, mysql},
%%                        {size, Size}, {max_overflow, Max_Overflow},{checklink,fun checkmysql/1}],WorkArg).

getdatabalseparam(Opts)
  ->
   	   Host =      case lists:keysearch(hostname, 1, Opts) of
				    {value, {_, Value1}} -> Value1;
				    _ -> <<"127.0.0.1">>
		            end,					
		Port =      case lists:keysearch(port, 1, Opts) of
				    {value, {_, Value2}} -> Value2;
				    _ -> 3306
		            end,					
		Database =  case lists:keysearch(database, 1, Opts) of
				    {value, {_, Value6}} -> Value6;
				    _ -> <<"MPe">>
		            end,					
		Username =  case lists:keysearch(username, 1, Opts) of
				    {value, {_, Value4}} -> Value4;
				 	    _ -> <<"root">>
		            end,					
		
		Password =  case lists:keysearch(password, 1, Opts) of
				    {value, {_, Value5}} -> Value5;
				 	    _ -> <<"123456">>
		            end,
		Size =  case lists:keysearch(size, 1, Opts) of
				    {value, {_, Value8}} -> Value8;
				 	    _ -> 2
		            end,
		Max_Overflow =  case lists:keysearch(max_overflow, 1, Opts) of
				    {value, {_, Value7}} -> Value7;
				 	    _ -> 10
             end,
	   TimeOut =  case lists:keysearch(timeout, 1, Opts) of
				    {value, {_, Value9}} -> Value9;
				 	    _ -> 12000
		            end,
	   {Host,Port,Database,
		Username,Password,Size,Max_Overflow,TimeOut}.

%%	   {binary_to_list(Host),Port,binary_to_list(Database),
%%		binary_to_list(Username),binary_to_list(Password),Size,Max_Overflow,TimeOut}.
	
validate_cfg(L) ->L.


startmongopool() ->
    case emipian_config:get_option(mongopools, fun validate_cfg/1) of
	undefined ->
	    ignore;
	Ls ->
	    Ls2 = lists:map(
	        fun({Name,Opts}) ->
		        case startmongopool({Name,Opts}) of
			    {ok, _Pid} = R -> R;
			    {error, Error} ->
				throw(Error)
			end
		end, Ls),
    ok
	%%    {ok, {{one_for_one, 10, 1}, Ls2}}
    end.

startmongopool({Name,Opts}) ->

    {Host,Port,Database,Username,Password,Size,Max_Overflow,TimeOut} 
    = getdatabalseparam(Opts),
    WorkOpts =[{username,Username},{password,Password},{timeout,TimeOut}],
    ConnStats = #conn_state{database = Database, write_mode = safe, read_mode = master},
    WorkArg =[{binary_to_list(Host),Port,ConnStats},WorkOpts],
    PoolArg = [{name,{local, Name}},
                        {worker_module, mc_worker},
                        {size, Size}, {max_overflow, Max_Overflow},{checklink,fun checkmongo/1}],
	%%	Name0 = gen_action_mod:get_module_proc(<<"mongodb">>, Name) , 
	ChildSpec = poolboy:child_spec(Name, PoolArg, WorkArg),

%% {Name,
%%		 {poolboy, start_link, [PoolArg, WorkArg]},
		%% transient,
		%% brutal_kill,
%%           permanent,
%%		   5000,
%%		 worker,
%%		 [poolboy]},
    supervisor:start_child(emipian_poolses, ChildSpec).

%%	poolboy:start_link([{name,{local, Name}},
%%                        {worker_module, mc_worker},
%%                        {size, Size}, {max_overflow, Max_Overflow},{checklink,fun checkmongo/1}],WorkArg).



startapnspool() ->
    case emipian_config:get_option(apnspools, fun validate_cfg/1) of
	undefined ->
	    ignore;
	Ls ->
	    Ls2 = lists:map(
	        fun({Name,Opts}) ->
		        case startapnspool({Name,Opts}) of
			    {ok, _Pid} = R -> R;
			    {error, Error} ->
				throw(Error)
			end
		end, Ls),
    ok
	%%    {ok, {{one_for_one, 10, 1}, Ls2}}
    end.


log_error(MsgId, Status) ->
  ?ERROR_MSG("Error on msg ~p: ~p~n", [MsgId, Status]).

log_feedback(Token) ->
  ?WARNING_MSG("Device with token ~p removed the app~n", [Token]).

 mysqllog(Level, Format, Arguments) ->
	
	lager:log(Level, self(), Format, Arguments).


startapnspool({Name,Opts}) ->

   	   Release =      case lists:keysearch(release, 1, Opts) of
				    {value, {_, Value0}} -> Value0;
				    _ -> 0
		            end,					
       if 
		   Release=:=1 -> Host = "gateway.push.apple.com",
						  FPHost ="feedback.push.apple.com",
						  Port =2195, 	
						  FBPort =2196;
		   true->
			               Host =  "gateway.sandbox.push.apple.com",
						   FPHost ="feedback.sandbox.push.apple.com",
						   Port =2195, 	
						   FBPort =2196
	      end,	   

	   CertFile =  case lists:keysearch(cert_file, 1, Opts) of
				    {value, {_, Value6}} -> binary_to_list(Value6);
				    _ -> ""
		            end,					
		
		KeyPass =  case lists:keysearch(password, 1, Opts) of
				    {value, {_, Value5}} -> binary_to_list(Value5);
				 	    _ -> "123456"
		            end,

	   Size =  case lists:keysearch(size, 1, Opts) of
				    {value, {_, Value8}} -> Value8;
				 	    _ -> 2
		            end,
		Max_Overflow =  case lists:keysearch(max_overflow, 1, Opts) of
				    {value, {_, Value7}} -> Value7;
				 	    _ -> 10
             end,
	   TimeOut =  case lists:keysearch(timeout, 1, Opts) of
				    {value, {_, Value9}} -> Value9;
				 	    _ -> 12000
		            end,
	   
    WorkArg = #apns_connection{
                          error_fun    = fun log_error/2,
                          feedback_fun = fun log_feedback/1,							   
						  apple_host        = Host,
                          apple_port        = Port,
                          cert_file         = CertFile,
                          cert_password     = KeyPass,
                          timeout           = TimeOut,
                          feedback_host     = FPHost,
                          feedback_port     = FBPort  ,
                          feedback_timeout  = 30*60*1000
                          },

   PoolArg = [{name,{local, Name}},
                        {worker_module, apns_connection},
                        {size, Size}, {max_overflow, Max_Overflow},{checklink,fun checkiosapns/1}],
%%   Name0 = gen_action_mod:get_module_proc(<<"apns">>, Name) , 
	ChildSpec = poolboy:child_spec(Name, PoolArg, WorkArg),
%%   ChildSpec = {Name,
%%		 {poolboy, start_link, [PoolArg, WorkArg]},
%%				permanent,
%%				5000,
	%%	 transient,
	%%	 brutal_kill,
%%		 worker,
%%		 [poolboy]},
    supervisor:start_child(emipian_poolses, ChildSpec).
%%	poolboy:start_link([{name,{local, Name}},
%%                        {worker_module, apns_connection},
%%                        {size, Size}, {max_overflow, Max_Overflow},{checklink,fun checkiosapns/1}],WorkArg).


checkmysql(Connection) ->
  	S="SELECT fnType FROM tblsysconf LIMIT 1",
	try
	  ResultSet = mysql:fetch(Connection,S),
	  ?INFO_MSG("checkmysql : ~p~n.", [ResultSet]),
	 case ResultSet of
		 {error,_} ->false;
	      _->true
	 end
	catch
		_:_->
	  ?INFO_MSG("checkmysql : false~p~n.", [Connection]),
	false	
    end. 
checkmongo(Connection) ->
  try
	 mongo:find_one(Connection,  <<"tbltestpool">>, {}),
	 true
	catch
	  _:_->false	
    end. 
checkiosapns(Connection) -> 
	apns_connection:checkapns(Connection)
	.
%% ====================================================================
%% Internal functions
%% ====================================================================


