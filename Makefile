DIALYZER_APPS = kernel stdlib sasl erts ssl tools os_mon runtime_tools crypto inets \
	public_key mnesia syntax_tools compiler
COMBO_PLT = $(HOME)/.cuttlefish_combo_dialyzer_plt

REBAR := $(CURDIR)/rebar3

.PHONY: all
all: $(REBAR) compile

$(REBAR):
	@curl -k -f -L "https://github.com/emqx/rebar3/releases/download/3.14.3-emqx-6/rebar3" -o ./rebar3
	@chmod +x ./rebar3

.PHONY: deps
deps: $(REBAR)
	$(REBAR) get-deps

.PHONY: distclean
docsclean:
	@rm -rf doc/*.png doc/*.html doc/*.css doc/edoc-info

.PHONY: compile
compile: deps
	$(REBAR) compile

## Environment variable CUTTLEFISH_ESCRIPT is shared with rebar.config
.PHONY: escript
escript: export CUTTLEFISH_ESCRIPT = true
escript: $(REBAR)
	$(REBAR) as escript escriptize

.PHONY: clean
clean: distclean

.PHONY: distclean
distclean:
	@rm -rf _build cuttlefish erl_crash.dump rebar3.crashdump rebar.lock

.PHONY: eunit
eunit: compile
	$(REBAR) eunit verbose=true

cover:
	$(REBAR) cover

.PHONY: dialyzer
dialyzer:
	$(REBAR) dialyzer
