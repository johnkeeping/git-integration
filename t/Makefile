-include ../config.mak

T = $(sort $(wildcard t[0-9][0-9][0-9][0-9]-*.sh))

all: $(T)

$(T):
	@./$@

.PHONY: $(T)
