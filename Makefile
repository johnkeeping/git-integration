all::

prefix = $(HOME)
bindir = $(prefix)/bin
mandir = $(prefix)/share/man
man1dir = $(mandir)/man1

INSTALL = install

-include config.mak

ifeq ($(V),)
QUIET_GEN =      @echo '      GEN $@';
QUIET_ASCIIDOC = @echo ' ASCIIDOC $@';

export QUIET_GEN
endif

MAN1_TXT = git-integration.txt
MAN_TXT = $(MAN1_TXT)
MAN_HTML = $(patsubst %.txt,%.html,$(MAN_TXT))

DOC_MAN1 = $(patsubst %.txt,%.1,$(MAN1_TXT))

DESTDIR_SQ = $(subst ','\'',$(DESTDIR))
bindir_SQ = $(subst ','\'',$(bindir))
man1dir_SQ = $(subst ','\'',$(man1dir))

git-integration: git-integration.sh
	$(QUIET_GEN)cp $^ $@

$(DOC_MAN1): %.1: %.txt
	$(QUIET_ASCIIDOC)a2x -d manpage -f manpage $<

$(MAN_HTML): %.html: %.txt
	$(QUIET_ASCIIDOC)a2x -d manpage -f xhtml $<

man: man1
man1: $(DOC_MAN1)

html: $(MAN_HTML)

doc: man html

all:: git-integration

test: all
	$(MAKE) -C t

install: all
	$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$(bindir_SQ)'
	$(INSTALL) -m 755 git-integration '$(DESTDIR_SQ)$(bindir_SQ)'

install-doc: man
	$(INSTALL) -d '$(DESTDIR_SQ)$(man1dir_SQ)'
	$(INSTALL) -m 644 $(DOC_MAN1) '$(DESTDIR)$(man1dir_SQ)'

.PHONY: all test install install-doc doc man man1 html
