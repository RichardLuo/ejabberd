%%%----------------------------------------------------------------------
%%% File    : ejabberd_app.erl
%%% Author  : Alexey Shchepin <alexey@sevcom.net>
%%% Purpose : 
%%% Created : 31 Jan 2003 by Alexey Shchepin <alexey@sevcom.net>
%%% Id      : $Id$
%%%----------------------------------------------------------------------

-module(ejabberd_app).
-author('alexey@sevcom.net').
-vsn('$Revision$ ').

-behaviour(application).

-export([start/2, stop/1, init/0]).

-include("ejabberd.hrl").

start(normal, Args) ->
    randoms:start(),
    db_init(),
    sha:start(),
    catch ssl:start(),
    translate:start(),
    acl:start(),
    gen_mod:start(),
    ejabberd_config:start(),
    ejabberd_auth:start(),
    cyrsasl:start(),
    Sup = ejabberd_sup:start_link(),
    start(),
    load_modules(),
    Sup;
start(_, _) ->
    {error, badarg}.

stop(StartArgs) ->
    ok.

start() ->
    spawn(?MODULE, init, []).

init() ->
    register(ejabberd, self()),
    % Profiling
    %eprof:start(),
    %eprof:profile([self()]),
    %erlang:system_flag(fullsweep_after, 0),
    error_logger:logfile({open, ?ERROR_LOG_PATH}),
    ok = erl_ddll:load_driver(".", expat_erl),
    Port = open_port({spawn, expat_erl}, [binary]),

    loop(Port).


loop(Port) ->
    receive
	_ ->
	    loop(Port)
    end.

db_init() ->
    case mnesia:system_info(extra_db_nodes) of
	[] ->
	    mnesia:create_schema([node()]);
	_ ->
	    ok
    end,
    mnesia:start(),
    mnesia:wait_for_tables(mnesia:system_info(local_tables), infinity).

load_modules() ->
    case ejabberd_config:get_local_option(modules) of
	undefined ->
	    ok;
	Modules ->
	    lists:foreach(fun({Module, Args}) ->
				  gen_mod:start_module(Module, Args)
			  end, Modules)
    end.
