A2X = a2x
ASCIIDOC = asciidoc
INSTALL = install

MAKEINFO = makeinfo
DOCBOOK2X_TEXI = docbook2x-texi
INSTALL_INFO = install-info

# Git only looks in one place for HTML files, so the best we can do is pick
# the git in $(prefix) and ask it where that is.
htmldir ?= $(shell $(prefix)/bin/git --html-path)
infodir ?= $(prefix)/share/info
mandir ?= $(prefix)/share/man
man1dir = $(mandir)/man1

-include ../config.mak

ifeq ($(V),)
QUIET_ASCIIDOC = @echo ' ASCIIDOC $@';
QUIET_DB2TEXI  = @echo '  DB2TEXI $@';
QUIET_MAKEINFO = @echo ' MAKEINFO $@';
endif

MAN1_TXT = git-integration.txt
MAN_TXT = $(MAN1_TXT)
MAN_HTML = $(patsubst %.txt,%.html,$(MAN_TXT))
MAN_INFO = $(patsubst %.txt,%.info,$(MAN_TXT))
MAN_XML = $(patsubst %.txt,%.xml,$(MAN_TXT))

DOC_MAN1 = $(patsubst %.txt,%.1,$(MAN1_TXT))

DESTDIR_SQ = $(subst ','\'',$(DESTDIR))
htmldir_SQ = $(subst ','\'',$(htmldir))
infodir_SQ = $(subst ','\'',$(infodir))
man1dir_SQ = $(subst ','\'',$(man1dir))

all:: doc

$(DOC_MAN1): %.1: %.txt
	$(QUIET_ASCIIDOC)$(A2X) -d manpage -f manpage $<

$(MAN_HTML): %.html: %.txt
	$(QUIET_ASCIIDOC)$(ASCIIDOC) -b html5 $<

$(MAN_XML): %.xml: %.txt
	$(QUIET_ASCIIDOC)$(ASCIIDOC) -b docbook -d manpage -o $@+ $< && \
	mv $@+ $@

git-integration.texi: $(MAN_XML) make-texi.sh
	$(QUIET_DB2TEXI)$(DOCBOOK2X_TEXI) --encoding=UTF-8 \
		--to-stdout $< >$@++ && \
	./make-texi.sh <$@++ >$@+ && \
	rm $@++ && \
	mv $@+ $@

$(MAN_INFO): %.info: %.texi
	$(QUIET_MAKEINFO)$(MAKEINFO) --no-split --no-validate -o $@ $<

man: man1
man1: $(DOC_MAN1)

html: $(MAN_HTML)

info: $(MAN_INFO)

doc: man html info

install: install-man

install-html: html
	$(INSTALL) -d '$(DESTDIR_SQ)$(htmldir_SQ)'
	$(INSTALL) -m 644 $(MAN_HTML) '$(DESTDIR_SQ)$(htmldir_SQ)'

install-info: info
	$(INSTALL) -d '$(DESTDIR_SQ)$(infodir_SQ)'
	$(INSTALL) -m 644 $(MAN_INFO) '$(DESTDIR_SQ)$(infodir_SQ)'
	if test -r '$(DESTDIR)$(infodir_SQ)/dir'; then \
		$(INSTALL_INFO) --info-dir='$(DESTDIR_SQ)$(infodir_SQ)' $(MAN_INFO); \
	else \
		echo >&2 "No directory found in $(DESTDIR)$(infodir)"; \
	fi

install-man: man
	$(INSTALL) -d '$(DESTDIR_SQ)$(man1dir_SQ)'
	$(INSTALL) -m 644 $(DOC_MAN1) '$(DESTDIR_SQ)$(man1dir_SQ)'

clean:
	$(RM) $(DOC_MAN1) $(MAN_HTML)

.PHONY: all clean install install-html install-man doc man man1 html
