%% @author hyf
%% @doc @todo Add description to emipian_tmp_sup.


-module(emipian_tmp_sup).

-export([start_link/2, init/1]).

start_link(Name, Module) ->
    supervisor:start_link({local, Name}, ?MODULE, Module).

init(Module) ->
    {ok,
     {{simple_one_for_one, 10, 1},
      [{undefined, {Module, start_link, []}, temporary,
	brutal_kill, worker, [Module]}]}}.

