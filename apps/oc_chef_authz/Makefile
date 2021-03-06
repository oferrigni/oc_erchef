DEPS = $(CURDIR)/deps

DIALYZER_OPTS = -Wunderspecs
ITEST_DEPS = $(CURDIR)/itest/common/deps
# List dependencies that should be included in a cached dialyzer PLT file.
DIALYZER_DEPS = deps/jiffy/ebin \
                deps/ibrowse/ebin \
                deps/opscoderl_httpc/ebin \
                deps/stats_hero/ebin \
                deps/envy/ebin \
                deps/sqerl/ebin \
                deps/darklaunch/ebin \
                deps/ej/ebin \
                deps/chef_objects/ebin

DEPS_PLT = oc_chef_authz.plt

ERLANG_DIALYZER_APPS = asn1 \
                       compiler \
                       crypto \
                       edoc \
                       erts \
                       eunit \
                       gs \
                       hipe \
                       inets \
                       kernel \
                       mnesia \
                       observer \
                       public_key \
                       runtime_tools \
                       ssl \
                       stdlib \
                       syntax_tools \
                       tools \
                       webtool \
                       xmerl

all: compile eunit itest dialyzer

# Clean ebin and .eunit of this project
clean:
	@rebar clean skip_deps=true

# Clean this project and all deps
allclean:
	@rebar clean
	@rm -rf itest/ct_logs

compile: $(DEPS)
	@rebar compile

$(DEPS):
	@rebar get-deps

# Full clean and removal of all deps. Remove deps first to avoid
# wasted effort of cleaning deps before nuking them.
distclean:
	@rm -rf deps $(DEPS_PLT) itest/ct_logs
	@rebar clean

eunit:
	@rebar skip_deps=true eunit

test: eunit

# Only include local PLT if we have deps that we are going to analyze
ifeq ($(strip $(DIALYZER_DEPS)),)
dialyzer: ~/.dialyzer_plt
	@dialyzer $(DIALYZER_OPTS) -r ebin
else
dialyzer: ~/.dialyzer_plt $(DEPS_PLT)
	@dialyzer $(DIALYZER_OPTS) --plts ~/.dialyzer_plt $(DEPS_PLT) -r ebin

$(DEPS_PLT):
	@dialyzer --build_plt $(DIALYZER_DEPS) --output_plt $(DEPS_PLT)
endif

~/.dialyzer_plt:
	@echo "ERROR: Missing ~/.dialyzer_plt. Please wait while a new PLT is compiled."
	dialyzer --build_plt --apps $(ERLANG_DIALYZER_APPS)
	@echo "now try your build again"

doc:
	@rebar doc skip_deps=true

$(ITEST_DEPS):
	mkdir -p $(ITEST_DEPS)

$(ITEST_DEPS)/enterprise-chef-server-schema: $(ITEST_DEPS)
	cd $(ITEST_DEPS); git clone git@github.com:opscode/enterprise-chef-server-schema.git; cd enterprise-chef-server-schema; git checkout $(EC_SCHEMA_VERSION); $(MAKE) install


itest_deps: $(ITEST_DEPS)/enterprise-chef-server-schema

itest: clean itest_deps
        # recompile, setting TEST define so we can play with
        # unexported functions.
	@echo "Recompiling with -DTEST ..."
	@rebar compile -DTEST
	@mkdir -p itest/ct_logs
	@ct_run -spec itest/spec.spec -pa deps/*/ebin -pa ebin
	@echo "Review results with: open itest/ct_logs/index.html"

.PHONY: all compile eunit test dialyzer clean allclean distclean doc ct
