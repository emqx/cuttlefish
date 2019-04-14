DIALYZER_APPS = kernel stdlib sasl erts ssl tools os_mon runtime_tools crypto inets \
	public_key mnesia syntax_tools compiler
COMBO_PLT = $(HOME)/.cuttlefish_combo_dialyzer_plt

REBAR := rebar3

.PHONY: all deps

all: compile

deps:
	$(REBAR) get-deps

docsclean:
	@rm -rf doc/*.png doc/*.html doc/*.css doc/edoc-info

compile: deps
	$(REBAR) compile

escript:
	$(REBAR) as escript escriptize

clean:
	@rm -rf _build rebar.lock cuttlefish erl_crash.dump rebar3.crashdump

eunit: compile
	$(REBAR) eunit verbose=true

dialyzer:
	$(REBAR) dialyzer
