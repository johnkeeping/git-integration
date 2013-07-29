SHELL_PATH ?= $(SHELL)
PROVE ?= prove

-include ../config.mak

SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))

T = $(sort $(wildcard t[0-9][0-9][0-9][0-9]-*.sh))

all: $(T)

prove:
	prove --exec '$(SHELL_PATH_SQ)' $(PROVE_OPTS) $(T)

$(T):
	@'$(SHELL_PATH_SQ)' $@

.PHONY: all prove $(T)
