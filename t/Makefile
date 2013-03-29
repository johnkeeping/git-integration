SHELL_PATH ?= /bin/sh

-include ../config.mak

SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))

T = $(sort $(wildcard t[0-9][0-9][0-9][0-9]-*.sh))

all: $(T)

$(T):
	@'$(SHELL_PATH_SQ)' $@

.PHONY: $(T)
