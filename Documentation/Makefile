A2X = a2x
ASCIIDOC = asciidoc
INSTALL = install

# Git only looks in one place for HTML files, so the best we can do is pick
# the git in $(prefix) and ask it where that is.
htmldir ?= $(shell $(prefix)/bin/git --html-path)
mandir ?= $(prefix)/share/man
man1dir = $(mandir)/man1

-include ../config.mak

ifeq ($(V),)
QUIET_ASCIIDOC = @echo ' ASCIIDOC $@';
endif

MAN1_TXT = git-integration.txt
MAN_TXT = $(MAN1_TXT)
MAN_HTML = $(patsubst %.txt,%.html,$(MAN_TXT))

DOC_MAN1 = $(patsubst %.txt,%.1,$(MAN1_TXT))

DESTDIR_SQ = $(subst ','\'',$(DESTDIR))
htmldir_SQ = $(subst ','\'',$(htmldir))
man1dir_SQ = $(subst ','\'',$(man1dir))

all:: doc

$(DOC_MAN1): %.1: %.txt
	$(QUIET_ASCIIDOC)$(A2X) -d manpage -f manpage $<

$(MAN_HTML): %.html: %.txt
	$(QUIET_ASCIIDOC)$(ASCIIDOC) -b html5 $<

man: man1
man1: $(DOC_MAN1)

html: $(MAN_HTML)

doc: man html

install: install-man

install-html: html
	$(INSTALL) -d '$(DESTDIR_SQ)$(htmldir_SQ)'
	$(INSTALL) -m 644 $(MAN_HTML) '$(DESTDIR_SQ)$(htmldir_SQ)'

install-man: man
	$(INSTALL) -d '$(DESTDIR_SQ)$(man1dir_SQ)'
	$(INSTALL) -m 644 $(DOC_MAN1) '$(DESTDIR_SQ)$(man1dir_SQ)'

clean:
	$(RM) $(DOC_MAN1) $(MAN_HTML)

.PHONY: all clean install install-html install-man doc man man1 html
