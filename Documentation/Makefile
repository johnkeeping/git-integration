A2X = a2x
ASCIIDOC = asciidoc
INSTALL = install

mandir = $(prefix)/share/man
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

install: man
	$(INSTALL) -d '$(DESTDIR_SQ)$(man1dir_SQ)'
	$(INSTALL) -m 644 $(DOC_MAN1) '$(DESTDIR)$(man1dir_SQ)'

.PHONY: all install-doc doc man man1 html
