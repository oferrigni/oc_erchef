%% -*- erlang-indent-level: 4;indent-tabs-mode: nil; fill-column: 92 -*-
%% ex: ts=4 sw=4 et
%% @author Stephen Delano <stephen@opscode.com>
%% Copyright 2013 Opscode, Inc. All Rights Reserved.

-module(oc_chef_authz_app).

-behaviour(application).

-export([
         start/2,
         stop/1
        ]).

start(_StartType, _StartArgs) ->
    {ok, self()}.

stop(_State) ->
    ok.
