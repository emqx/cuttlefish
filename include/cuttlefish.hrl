-ifndef(CUTTLEFISH_HRL).
-define(CUTTLEFISH_HRL, ture).

-ifdef(EUNIT).
-define(logger, cuttlefish_test_logger).
-else.
-define(logger, logger).
-endif.

-endif.
