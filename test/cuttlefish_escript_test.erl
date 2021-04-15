-module(cuttlefish_escript_test).
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").
-compile(export_all).

-define(assertPrinted(___Text),
        begin
            ((fun() ->
                     case cuttlefish_test_group_leader:get_output() of
                         {ok, ___Output} ->
                             case re:run(___Output, ___Text) of
                                 {match, _} ->
                                     ok;
                                 nomatch ->
                                     erlang:error({assertPrinted_failed,
                                           [{module, ?MODULE},
                                            {line, ?LINE},
                                            {expected, ___Text},
                                            {actual, unicode:characters_to_list(___Output)}]})
                             end;
                         error ->
                             erlang:error({assertPrinted_failed,
                                           [{module, ?MODULE},
                                            {line, ?LINE},
                                            {expected, ___Text},
                                            {reason, timed_out_on_receive}]})
                     end
              end)())
        end).

-define(capturing(__Forms),
    (fun() ->
        ___OldLeader = group_leader(),
        group_leader(cuttlefish_test_group_leader:new_group_leader(self()), self()),
        try
          __Forms
        after
          cuttlefish_test_group_leader:tidy_up(___OldLeader)
        end
     end)()).

generate_test_() ->
    [
        {"`cuttlefish generate` prints override", fun generate_prints_override/0}
    ].

generate_prints_override() ->
    os:putenv("CUTTLEFISH_ENV_OVERRIDE_PREFIX", "EUNIT_"),
    os:putenv("EUNIT_SYSLOG", "off"),
    ?capturing(begin
                   cuttlefish_escript:main(["-i", tp("override_and_fuzzy.schema"),
                                            "-c", tp("override_and_fuzzy.conf"),
                                            "-d", tp("override_and_fuzzy"),
                                            "-v"]),
                   ?assertPrinted("log.syslog = \"off\"")
               end),
    os:unsetenv("CUTTLEFISH_ENV_OVERRIDE_PREFIX"),
    os:unsetenv("EUNIT_SYSLOG").

describe_test_() ->
     [
      {"`cuttlefish describe` prints documentation", fun describe_prints_docs/0},
      {"`cuttlefish describe` prints datatype's valid values", fun describe_prints_datatype/0},
      {"`cuttlefish describe` prints default", fun describe_prints_default/0},
      {"`cuttlefish describe` prints configured value", fun describe_prints_configured/0},
      {"`cuttlefish describe` prints erlang application key", fun describe_prints_app_key/0},
      {"`cuttlefish describe` prints message when no default exists", fun describe_prints_no_default/0},
      {"`cuttlefish describe` prints message when value not configured", fun describe_prints_not_configured/0}
     ].

describe(Key) ->
    cuttlefish_escript:main(["-i", tp("riak.schema"), "-c", tp("riak.conf"), "describe", Key]).

describe_prints_docs() ->
    ?capturing(begin
                   describe("ring_size"),
                   ?assertPrinted("Documentation for ring_size"),
                   ?assertPrinted("Default ring creation size\\.  Make sure it is a power of 2")
               end).

describe_prints_datatype() ->
    ?capturing(begin
                   describe("storage_backend"),
                   ?assertPrinted("- one of: bitcask, leveldb, memory, multi")
               end).

describe_prints_default() ->
    ?capturing(begin
                   describe("ring_size"),
                   ?assertPrinted("Default Value : 64")
               end).

describe_prints_configured() ->
    ?capturing(begin
                   describe("anti_entropy"),
                   ?assertPrinted("Set Value     : debug")
               end).


describe_prints_app_key() ->
    ?capturing(begin
                   describe("leveldb.bloomfilter"),
                   ?assertPrinted("Internal key  : eleveldb\\.use_bloomfilter")
               end).

describe_prints_no_default() ->
    ?capturing(begin
                   describe("listener.https.foo"),
                   ?assertPrinted("No default set")
               end).

describe_prints_not_configured() ->
    ?capturing(begin
                   describe("ssl.keyfile"),
                   Text = "Value not set in " ++ tp("riak.conf"),
                   ?assertPrinted(Text)
               end).


get_test_() ->
  [
    {"`cuttlefish get` prints value", fun get_prints/0},
    {"`cuttlefish get` prints value from env var", fun get_prints_env/0},
    {"`cuttlefish get` prints nothing for non-existing key", fun get_prints_nothing/0}
  ].

get_(Key) ->
  cuttlefish_escript:main(["-i", tp("riak.schema"), "-c", tp("riak.conf"), "get", Key]).

get_prints() ->
  ?capturing(begin
               get_("ring_size"),
               {ok, Stdout} = cuttlefish_test_group_leader:get_output(),
               ?assertEqual([["32", $\n]], Stdout)
             end),
  ?capturing(begin
               get_("listener.http.internal"),
               {ok, Stdout} = cuttlefish_test_group_leader:get_output(),
               ?assertEqual([["127.0.0.1:8098", $\n]], Stdout)
             end).

get_prints_env() ->
    os:putenv("CUTTLEFISH_ENV_OVERRIDE_PREFIX", "EMQX_"),
    os:putenv("EMQX_RING_SIZE", "16"),
    try
        ?capturing(begin
                       get_("ring_size"),
                       {ok, Stdout} = cuttlefish_test_group_leader:get_output(),
                       ?assertEqual([["16", $\n]], Stdout)
                   end)
    after
        os:unsetenv("CUTTLEFISH_ENV_OVERRIDE_PREFIX"),
        os:unsetenv("EMQX_RING_SIZE")
    end.

get_prints_nothing() ->
  ?capturing(begin
               ?assertThrow(stop_deactivate, get_("ssl.keyfile")),
               {ok, Stdout} = cuttlefish_test_group_leader:get_output(),
               ?assertEqual([], Stdout)
             end).

md_test_() ->
    [
        {"`cuttlefish md` prints markdown", fun md_prints/0}
    ].

md_prints() ->
    ?capturing(begin
                   cuttlefish_escript:main(["-i", tp("riak.schema"), "-t", "configuration for riak", "md"]),
                   ?assertPrinted("## configuration for riak"),
                   ?assertPrinted("### ring_size"),
                   ?assertPrinted("|Type|Default|"),
                   ?assertPrinted("|---|---|"),
                   ?assertPrinted("|integer|64|"),
                   ?assertPrinted("#### description"),
                   ?assertPrinted("Default ring creation size.  Make sure it is a power of 2,"),
                   ?assertPrinted("e.g. 16, 32, 64, 128, 256, 512 etc")
               end).

%% test-path
tp(Name) ->
    filename:join([code:lib_dir(cuttlefish), "test", Name]).

-endif.
