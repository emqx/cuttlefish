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

-export([md/1, files/2, h2/1]).

files(Files, Out) ->
    Schema = cuttlefish_schema:files(Files),
    file:write_file(Out, md(Schema)).

md({_, Mappings, Validators}) ->
    io_lib:fwrite("~ts\n", [lists:concat([do_md(M, Validators) || M <- Mappings])]).

do_md(M, Validators) ->
    md_title(M) ++ md_type_info(M, Validators) ++ md_description(M) ++ "\n".

md_title(M) ->
    h3(string:join(cuttlefish_mapping:variable(M), ".")).

md_type_info(M, Validators) ->
    Vs = case md_validators(M, Validators) of
        [] ->
            undefined;
        Vs0 ->
            Vs0
        end,
    th_td(["Type", "Default", "Constraint"],
          [datatype_to_string(cuttlefish_mapping:datatype(M)), maybe_default(M), Vs]).

md_validators(M, Validators) ->
    MatchedValidators = cuttlefish_mapping:validators(M, Validators),
    string:join([code(cuttlefish_validator:description(V)) || V <- MatchedValidators], "<br>").

md_description(M) ->
    h4("description") ++ string:join(cuttlefish_mapping:doc(M), "\n").

datatype_to_string([T]) ->
    lists:flatten(io_lib:format("~p", [T]));
datatype_to_string(T) ->
    lists:flatten(io_lib:format("~p", [T])).

maybe_default(M) ->
    case cuttlefish_mapping:default(M) of
        undefined ->
            undefined;
        V ->
            StringifyAttempts = [cuttlefish_datatypes:to_string(V, T) || T <- cuttlefish_mapping:datatype(M)],
            hd(lists:filter(fun ({error, _}) -> false; (_) -> true end, StringifyAttempts))
    end.

h2(Str) when is_list(Str) ->
    "## " ++ Str ++ "\n".

h3(Str) when is_list(Str) ->
    "### " ++ Str ++ "\n".

h4(Str) when is_list(Str) ->
    "#### " ++ Str ++ "\n".

td(List) when is_list(List) ->
    "|" ++ string:join(List, "|") ++ "|" ++ "\n".

th(List) when is_list(List) ->
    td(List) ++ "|" ++ string:join(lists:duplicate(length(List), "---"), "|") ++ "|" ++ "\n".

% deletes column if td element is undefined
th_td(Th, Td) when is_list(Th) andalso is_list(Td) ->
    {Th0, Td0} = delete_undefined(Th, Td, [], []),
    th(Th0) ++ td(Td0).

delete_undefined([], [], ThAcc, TdAcc) ->
    {lists:reverse(ThAcc), lists:reverse(TdAcc)};
delete_undefined([_|MoreTh], [undefined|MoreTd], ThAcc, TdAcc) ->
    delete_undefined(MoreTh, MoreTd, ThAcc, TdAcc);
delete_undefined([Th|MoreTh], [Td|MoreTd], ThAcc, TdAcc) ->
    delete_undefined(MoreTh, MoreTd, [Th|ThAcc], [Td|TdAcc]).

code(Str) when is_list(Str) ->
    "`" ++ Str ++ "`".

-ifdef(TEST).

md_basic_test() ->
    String =
    "%% @doc this is some doc\n
    {mapping, \"a.b\", \"internal.key\", [
        {datatype, integer},
        {default, 64}
    ]}.\n",
    Schema = cuttlefish_schema:strings([String]),
    ?assertEqual(["### a.b\n" ++
                  "|Type|Default|\n" ++
                  "|---|---|\n" ++
                  "|integer|64|\n" ++
                  "#### description\n" ++
                  "this is some doc\n", $\n], md(Schema)).

md_no_default_test() ->
    String =
        "%% @doc this is some doc\n
        {mapping, \"a.b\", \"internal.key\", [
            {datatype, integer}
        ]}.\n",
    Schema = cuttlefish_schema:strings([String]),
    ?assertEqual(["### a.b\n" ++
        "|Type|\n" ++
        "|---|\n" ++
        "|integer|\n" ++
        "#### description\n" ++
        "this is some doc\n", $\n], md(Schema)).

md_string_multiple_datatype_stringify_test() ->
    String =
        "%% @doc this is some doc\n
        {mapping, \"listener.tcp.$name\", \"emqx.listeners\", [
            {default, {\"127.0.0.1\",5000}},
            {datatype, [integer, ip]}
        ]}.\n",
    Schema = cuttlefish_schema:strings([String]),
    ?assertEqual(["### listener.tcp.$name\n" ++
                  "|Type|Default|\n" ++
                  "|---|---|\n" ++
                  "|[integer,ip]|127.0.0.1:5000|\n" ++
                  "#### description\n" ++
                  "this is some doc\n", $\n], md(Schema)).

md_constraint_test() ->
    String =
        "%% @doc this is from emqx.schema
         {mapping, \"node.fullsweep_after\", \"vm_args.-env ERL_FULLSWEEP_AFTER\", [
         {default, 1000},
         {datatype, integer},
         {validators, [\"positive_integer\"]}
         ]}.\n
         {validator, \"positive_integer\", \"must be a positive integer\",
         fun(X) -> X >= 0 end}.",

    Schema = cuttlefish_schema:strings([String]),
    ?assertEqual(["### node.fullsweep_after\n" ++
                  "|Type|Default|Constraint|\n" ++
                  "|---|---|---|\n" ++
                  "|integer|1000|`must be a positive integer`|\n" ++
                  "#### description\n" ++
                  "this is from emqx.schema\n", $\n], md(Schema)).

md_multiple_constraint_test() ->
    String =
        "{mapping, \"a.b\", \"internal.key\", [
         {datatype, integer},
         {validators, [\"positive_integer\", \"less_than_5\"]}
         ]}.\n
         {validator, \"positive_integer\", \"must be a positive integer\",
         fun(X) -> X >= 0 end}.\n
         {validator, \"less_than_5\", \"must be less than 5\",
         fun(X) -> X < 5 end}.",

    Schema = cuttlefish_schema:strings([String]),
    ?assertEqual(["### a.b\n" ++
                  "|Type|Constraint|\n" ++
                  "|---|---|\n" ++
                  "|integer|`must be a positive integer`<br>`must be less than 5`|\n" ++
                  "#### description\n" ++
                  "\n", $\n], md(Schema)).

-endif.
