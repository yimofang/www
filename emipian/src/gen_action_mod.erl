%%%----------------------------------------------------------------------
%%% File    : gen_mod.erl
%%% Author  : Alexey Shchepin <alexey@process-one.net>
%%% Purpose : 
%%% Purpose :
%%% Created : 24 Jan 2003 by Alexey Shchepin <alexey@process-one.net>
%%%
%%%
%%% emipian, Copyright (C) 2002-2014   ProcessOne
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

-module(gen_action_mod).
-include("errorcode.hrl").
-include("action.hrl").
-author('heyonhfu').
  
-export([start/0, start_module/2, start_module/3, stop_module/2,
	 stop_module_keep_config/2, get_opt/3, get_opt/4,
	 get_opt_host/3, db_type/1, db_type/2, get_module_opt/5,
	 get_module_opt_host/3, loaded_modules/1,
	 loaded_modules_with_opts/1, get_hosts/2,
	 get_module_proc/2, is_loaded/2,get_actionmod/1,
	 	 process_action/4,get_sendfields_fromparam/2,get_sendparam_fromfields/5

		,sendmsg_to_terminal/11
		,get_msgstamptime/2]).

%%-export([behaviour_info/1]).

-include( "emipian.hrl").
-include("logger.hrl").

-record(emipian_action_module,
        {module_host = {undefined, <<"">>} :: {atom(), binary()},
         opts = [] :: opts() | '_' | '$2',
		 action::integer()
          }).

-type opts() :: [{atom(), any()}].

-callback start(binary(), opts()) -> any().
-callback stop(binary()) -> any().

-export_type([opts/0]).

%%behaviour_info(callbacks) -> [{start, 2}, {stop, 1}];
%%behaviour_info(_Other) -> undefined.

start() ->
    ets:new(emipian_action_modules,
	    [named_table, public,
	     {keypos, #emipian_action_module.module_host}]),
    
	
	
	ok.

-spec start_module(binary(), atom()) -> any().

start_module(Host, Module) ->
    Modules = emipian_config:get_option(
		{modules, Host},
		fun(L) when is_list(L) -> L end, []),
    case lists:keyfind(Module, 1, Modules) of
	{_, Opts} ->
	    start_module(Host, Module, Opts);
	false ->
	    {error, not_found_in_config}
    end.

-spec start_module(binary(), atom(), opts()) -> any().

start_module(Host, Module, Opts) ->
    ets:insert(emipian_action_modules,
	       #emipian_action_module{module_host = {Module, Host},
				opts = Opts}),
    try Module:start(Host, Opts) catch
      Class:Reason ->
	  ets:delete(emipian_action_modules, {Module, Host}),
	  ErrorText =
	      io_lib:format("Problem starting the module ~p for host "
			    "~p ~n options: ~p~n ~p: ~p~n~p",
			    [Module, Host, Opts, Class, Reason,
			     erlang:get_stacktrace()]),
	  ?CRITICAL_MSG(ErrorText, []),
	  case is_app_running(emipian) of
	    true ->
		erlang:raise(Class, Reason, erlang:get_stacktrace());
	    false ->
		?CRITICAL_MSG("emipian initialization was aborted "
			      "because a module start failed.",
			      []),
		timer:sleep(3000),
		erlang:halt(string:substr(lists:flatten(ErrorText), 1, 199))
	  end
    end.

is_app_running(AppName) ->
    Timeout = 15000,
    lists:keymember(AppName, 1,
		    application:which_applications(Timeout)).

-spec stop_module(binary(), atom()) -> error | {aborted, any()} | {atomic, any()}.

%% @doc Stop the module in a host, and forget its configuration.
stop_module(Host, Module) ->
    case stop_module_keep_config(Host, Module) of
      error -> error;
      ok -> ok
    end.












%% @doc Stop the module in a host, but keep its configuration.
%% As the module configuration is kept in the Mnesia local_config table,
%% when emipian is restarted the module will be started again.
%% This function is useful when emipian is being stopped
%% and it stops all modules.
-spec stop_module_keep_config(binary(), atom()) -> error | ok.

stop_module_keep_config(Host, Module) ->
    case catch Module:stop(Host) of
      {'EXIT', Reason} -> ?ERROR_MSG("~p", [Reason]), error;
      {wait, ProcList} when is_list(ProcList) ->
	  lists:foreach(fun wait_for_process/1, ProcList),
	  ets:delete(emipian_action_modules, {Module, Host}),
	  ok;
      {wait, Process} ->
	  wait_for_process(Process),
	  ets:delete(emipian_action_modules, {Module, Host}),
	  ok;
      _ -> ets:delete(emipian_action_modules, {Module, Host}), ok
    end.

wait_for_process(Process) ->
    MonitorReference = erlang:monitor(process, Process),
    wait_for_stop(Process, MonitorReference).

wait_for_stop(Process, MonitorReference) ->
    receive
      {'DOWN', MonitorReference, _Type, _Object, _Info} -> ok
      after 5000 ->
		catch exit(whereis(Process), kill),
		wait_for_stop1(MonitorReference)
    end.

wait_for_stop1(MonitorReference) ->
    receive
      {'DOWN', MonitorReference, _Type, _Object, _Info} -> ok
      after 5000 -> ok
    end.

-type check_fun() :: fun((any()) -> any()) | {module(), atom()}.

-spec get_opt(atom(), opts(), check_fun()) -> any().

get_opt(Opt, Opts, F) ->
    get_opt(Opt, Opts, F, undefined).

-spec get_opt(atom(), opts(), check_fun(), any()) -> any().

get_opt(Opt, Opts, F, Default) ->
    case lists:keysearch(Opt, 1, Opts) of
        false ->
            Default;
        {value, {_, Val}} ->
            emipian_config:prepare_opt_val(Opt, Val, F, Default)
    end.

-spec get_module_opt(global | binary(), atom(), atom(), check_fun(), any()) -> any().

get_module_opt(global, Module, Opt, F, Default) ->
    Hosts = (?MYHOSTS),
    [Value | Values] = lists:map(fun (Host) ->
					 get_module_opt(Host, Module, Opt,
							F, Default)
				 end,
				 Hosts),
    Same_all = lists:all(fun (Other_value) ->
				 Other_value == Value
			 end,
			 Values),
    case Same_all of
      true -> Value;
      false -> Default
    end;
get_module_opt(Host, Module, Opt, F, Default) ->
    OptsList = ets:lookup(emipian_action_modules, {Module, Host}),
    case OptsList of
      [] -> Default;
      [#emipian_action_module{opts = Opts} | _] ->
	  get_opt(Opt, Opts, F, Default)
    end.

-spec get_module_opt_host(global | binary(), atom(), binary()) -> binary().

get_module_opt_host(Host, Module, Default) ->
    Val = get_module_opt(Host, Module, host,
                         fun iolist_to_binary/1,
                         Default),
    emipian_regexp:greplace(Val, <<"@HOST@">>, Host).

-spec get_opt_host(binary(), opts(), binary()) -> binary().

get_opt_host(Host, Opts, Default) ->
    Val = get_opt(host, Opts, fun iolist_to_binary/1, Default),
    emipian_regexp:greplace(Val, <<"@HOST@">>, Host).

-spec db_type(opts()) -> odbc | mnesia | riak.

db_type(Opts) ->
    get_opt(db_type, Opts,
            fun(odbc) -> odbc;
               (internal) -> mnesia;
               (mnesia) -> mnesia;
               (riak) -> riak
            end,
            mnesia).

-spec db_type(binary(), atom()) -> odbc | mnesia | riak.

db_type(Host, Module) ->
    get_module_opt(Host, Module, db_type,
                   fun(odbc) -> odbc;
                      (internal) -> mnesia;
                      (mnesia) -> mnesia;
                      (riak) -> riak
                   end,
                   mnesia).

-spec loaded_modules(binary()) -> [atom()].

loaded_modules(Host) ->
    ets:select(emipian_action_modules,
	       [{#emipian_action_module{_ = '_', module_host = {'$1', Host}},
		 [], ['$1']}]).

-spec loaded_modules_with_opts(binary()) -> [{atom(), opts()}].

loaded_modules_with_opts(Host) ->
    ets:select(emipian_action_modules,
	       [{#emipian_action_module{_ = '_', module_host = {'$1', Host},
				  opts = '$2'},
		 [], [{{'$1', '$2'}}]}]).

-spec get_hosts(opts(), binary()) -> [binary()].

get_hosts(Opts, Prefix) ->
    case get_opt(hosts, Opts,
                 fun(Hs) -> [iolist_to_binary(H) || H <- Hs] end) of
        undefined ->
            case get_opt(host, Opts,
                         fun iolist_to_binary/1) of
                undefined ->
                    [<<Prefix/binary, Host/binary>> || Host <- ?MYHOSTS];
                Host ->
                    [Host]
            end;
        Hosts ->
            Hosts
    end.

-spec get_module_proc(binary(), {frontend, atom()} | atom()) -> atom().

get_module_proc(Host, {frontend, Base}) ->
    get_module_proc(<<"frontend_", Host/binary>>, Base);
get_module_proc(Host, Base) ->
    binary_to_atom(
      <<(erlang:atom_to_binary(Base, latin1))/binary, "_", Host/binary>>,
      latin1).

-spec is_loaded(binary(), atom()) -> boolean().

is_loaded(Host, Module) ->
    ets:member(emipian_action_modules, {Module, Host}).


%% ====================================================================
%% 根据Action得到要使用的模块
%%
%% return
%% noaction | Mod_Action
%% 
%% 
%% ====================================================================

get_actionmod(Action)->
   case Action of
	  ?AC_CS_BEAT -> mod_action_beat; 
      _->
	    case emipian_config:get_option(action_mods,fun validate_cfg/1) of
	 	  undefined ->
		    noaction;
		   Ls ->
			 case lists:keysearch(Action, 1, Ls) of
				false->

                noaction;

				{value,{_,Mod}}->

               Mod
		      end
		  end
        end.


%% ====================================================================
%% Must implement API or action
%% return
%% {ok/terminate/resume/error,Data}
%% Data ={Code,Action,Param,Addition}
%% Addition ={}
%%
%%
%% ====================================================================

%% ==================================================================
%% 执行指令
%% MOD:process_action must return
%% 需返回以下值
%%  1){ok/terminate/resume,Data}  需回应客户
%%  或
%%  2) {noresp,ok/terminate}   不需要
%%  ??{noaction}
%% Data ={Code,Action,Param,Addition}
%% Addition ={}
%%   1)
%% ok:Success,continue
%% terminate: halt connection and send 
%%  resume: error and continue
%%  error: Param of command error,halt connection 
%% ====================================================================
process_action(MsgID,Session,Action,Param)->
  case get_actionmod(Action) of 
	noaction->
		{resume,{?EC_CMDERROR,Action,<<>>,{<<>>}}};
     Mod->Mod:process_action(MsgID,Session,Action,Param)  
   end.

get_sendmessage(Session,Action,Param)->
	
ok.



get_sendfields_fromparam(Action,Param)->
 case get_actionmod(Action) of 
	noaction-> cmderror;
	%%	{resume,{?EC_CMDERROR,Action,<<>>,{<<>>}}};
    Mod->Mod:get_sendfields_fromparam(Action,Param)  
   end.

get_msgstamptime(Action,Param)->
 case get_actionmod(Action) of 
	noaction->cmderror;
%%		{resume,{?EC_CMDERROR,Action,<<>>,{<<>>}}};
     Mod->Mod:get_msgstamptime(Param)  
   end.
  
get_sendparam_fromfields(Action,StampTime,MsgID,SendTime,Result)->
  case get_actionmod(Action) of 
	noaction->cmderror;
 %%	 {resume,{?EC_CMDERROR,Action,<<>>,{<<>>}}};
      Mod->Mod:get_sendparam_fromfields(Action,StampTime,MsgID,SendTime,Result)  
   end.

sendmsg_to_terminal(Action,MsgID,SynNo,Param,Session,SenderUserID,MsgTime,ChatObj,Mode,AddtionInfo,Retry)->
 case get_actionmod(Action) of 
	noaction->cmderror;
%%		{resume,{?EC_CMDERROR,Action,<<>>,{<<>>}}};
    Mod->
       CanSend = 
		 if
			Mode =:=0 -> 
			   case  emipian_msg_log:save_terminalreceiver(MsgID, SynNo, Session,Retry) of
			   duplicate->
				  if Retry=:=yes 
					   ->yes;
					true ->no
				   end;
			   _->yes
			  end;
			 true->yes  
	    end,		   
      if CanSend=:=yes ->
        Mod:sendmsg_to_terminal(Action,MsgID,SynNo,Param,Session,
							   SenderUserID,MsgTime,ChatObj,AddtionInfo);
	    true->ok
      end
  end.	
	
validate_cfg(L) ->L.