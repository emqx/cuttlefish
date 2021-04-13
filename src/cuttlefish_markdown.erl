%%--------------------------------------------------------------------
%% Copyright (c) 2021 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

-module(cuttlefish_markdown).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).
-endif.

-export([md/1, files/2]).

files(Files, Out) ->
    {_, Mappings, _} = cuttlefish_schema:files(Files),
    file:write_file(Out, md(Mappings)).

md(Mappings) ->
    io_lib:fwrite("~ts\n", [lists:concat([do_md(M) || M <- Mappings])]).

do_md(M) ->
    md_title(M) ++ md_type_info(M) ++ md_description(M) ++ "\n".

md_title(M) ->
    h3(string:join(cuttlefish_mapping:variable(M), ".")).

md_type_info(M) ->
    th(["Type", "Default"]) ++ td([datatype_to_string(cuttlefish_mapping:datatype(M)), maybe_default(M)]).

md_description(M) ->
    h4("description") ++ string:join(cuttlefish_mapping:doc(M), "\n").

datatype_to_string([T]) ->
    lists:flatten(io_lib:format("~p", [T]));
datatype_to_string(T) ->
    lists:flatten(io_lib:format("~p", [T])).

maybe_default(M) ->
    case cuttlefish_mapping:default(M) of
        undefined ->
            "---";
        V ->
            StringifyAttempts = [cuttlefish_datatypes:to_string(V, T) || T <- cuttlefish_mapping:datatype(M)],
            hd(lists:filter(fun ({error, _}) -> false; (_) -> true end, StringifyAttempts))
    end.

h3(Str) when is_list(Str) ->
    "### " ++ Str ++ "\n".

h4(Str) when is_list(Str) ->
    "#### " ++ Str ++ "\n".

td(List) when is_list(List) ->
    "|" ++ string:join(List, "|") ++ "|" ++ "\n".

th(List) when is_list(List) ->
    td(List) ++ "|" ++ string:join(lists:duplicate(length(List), "---"), "|") ++ "|" ++ "\n".


-ifdef(TEST).

md_basic_test() ->
    String =
    "%% @doc this is some doc\n
    {mapping, \"a.b\", \"internal.key\", [
        {datatype, integer},
        {default, 64}
    ]}.\n",
    {_, Mappings, _} = cuttlefish_schema:strings([String]),
    ?assertEqual(["### a.b\n" ++
                  "|Type|Default|\n" ++
                  "|---|---|\n" ++
                  "|integer|64|\n" ++
                  "#### description\n" ++
                  "this is some doc\n", $\n], md(Mappings)).

md_no_default_test() ->
    String =
        "%% @doc this is some doc\n
        {mapping, \"a.b\", \"internal.key\", [
            {datatype, integer}
        ]}.\n",
    {_, Mappings, _} = cuttlefish_schema:strings([String]),
    ?assertEqual(["### a.b\n" ++
        "|Type|Default|\n" ++
        "|---|---|\n" ++
        "|integer|---|\n" ++
        "#### description\n" ++
        "this is some doc\n", $\n], md(Mappings)).

md_string_multiple_datatype_stringify_test() ->
    String =
        "%% @doc this is some doc\n
        {mapping, \"listener.tcp.$name\", \"emqx.listeners\", [
            {default, {\"127.0.0.1\",5000}},
            {datatype, [integer, ip]}
        ]}.\n",
    {_, Mappings, _} = cuttlefish_schema:strings([String]),
    ?assertEqual(["### listener.tcp.$name\n" ++
                  "|Type|Default|\n" ++
                  "|---|---|\n" ++
                  "|[integer,ip]|127.0.0.1:5000|\n" ++
                  "#### description\n" ++
                  "this is some doc\n", $\n], md(Mappings)).

-endif.
