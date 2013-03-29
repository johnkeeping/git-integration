all::

prefix = $(HOME)
bindir = $(prefix)/bin
mandir = $(prefix)/share/man
man1dir = $(mandir)/man1

INSTALL = install

-include config.mak

ifeq ($(V),)
QUIET_GEN =      @echo '      GEN $@';

export QUIET_GEN
endif

export mandir man1dir

DESTDIR_SQ = $(subst ','\'',$(DESTDIR))
bindir_SQ = $(subst ','\'',$(bindir))

git-integration: git-integration.sh
	$(QUIET_GEN)cp $^ $@

all:: git-integration

test: all
	$(MAKE) -C t

install: all
	$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$(bindir_SQ)'
	$(INSTALL) -m 755 git-integration '$(DESTDIR_SQ)$(bindir_SQ)'

doc man html:
	$(MAKE) -C Documentation/ $@

install-doc:
	$(MAKE) -C Documentation/ install

.PHONY: all test install install-doc doc man html
