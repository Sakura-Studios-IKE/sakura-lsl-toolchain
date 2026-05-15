# Top-level Makefile for the Sakura LSL Toolchain.
# Delegates to each submodule's own build system.

TOOLS_C     := sakura-lslc sakura-slemu sakura-lsldb
PYTHON_TOOL := sakura-lsltest

PYTHON ?= python3

.PHONY: all clean help test test-lslc test-slemu test-lsldb test-lsltest \
        install install-lsltest install-c plugin

help:
	@echo "Top-level targets:"
	@echo "  make all          build every C tool (lslc, slemu, lsldb)"
	@echo "  make plugin       build the IntelliJ plugin"
	@echo "  make test         run every test suite"
	@echo "  make install      install C binaries to /usr/local/bin"
	@echo "  make install-lsltest   pip install -e sakura-lsltest"
	@echo "  make clean        clean every subproject"

all:
	@for t in $(TOOLS_C); do \
	    echo "==> building $$t"; \
	    $(MAKE) -C $$t || exit $$?; \
	done

clean:
	@for t in $(TOOLS_C); do $(MAKE) -C $$t clean; done

test: test-lslc test-slemu test-lsldb test-lsltest

test-lslc: all
	@echo "═══ sakura-lslc ═══"
	@$(MAKE) -C sakura-lslc test
	@cd sakura-lslc && sh tests/coverage/run_coverage.sh

test-slemu: all
	@echo "═══ sakura-slemu ═══"
	@$(MAKE) -C sakura-slemu e2e
	@cd sakura-slemu && sh tests/coverage/run_coverage.sh

test-lsldb: all
	@echo "═══ sakura-lsldb ═══"
	@$(MAKE) -C sakura-lsldb test

test-lsltest:
	@echo "═══ sakura-lsltest ═══"
	@$(MAKE) -C sakura-lsltest test

install: all install-c install-lsltest

install-c:
	@for t in $(TOOLS_C); do sudo $(MAKE) -C $$t install; done

install-lsltest:
	$(PYTHON) -m pip install -e sakura-lsltest

plugin:
	@cd sakura-intellij-lsl && ./gradlew buildPlugin
	@echo "Plugin zip: sakura-intellij-lsl/build/distributions/sakura-lsl-1.0.0.zip"
