REL_VERSION = v0.2

# The default target is...
all::

prefix = $(HOME)
bindir = $(prefix)/bin
mandir = $(prefix)/share/man
man1dir = $(mandir)/man1
bashcompletiondir = $(prefix)/share/bash-completion

ASCIIDOC = asciidoc
INSTALL = install

ifndef SHELL_PATH
	SHELL_PATH = /bin/sh
endif

GIT-INTEGRATION-VERSION: FORCE
	@VN=$$(git describe --match 'v[0-9]*' --dirty 2>/dev/null) || \
	VN=$(REL_VERSION); \
	VN=$${VN#v}; \
	OLD=$$(sed -e 's/^GIT_INTEGRATION_VERSION = //' 2>/dev/null <$@); \
	test x"$$VN" = x"$$OLD" || { \
		echo >&2 "GIT_INTEGRATION_VERSION = $$VN"; \
		echo "GIT_INTEGRATION_VERSION = $$VN" >$@; \
	}
-include GIT-INTEGRATION-VERSION

-include config.mak

ifeq ($(V),)
QUIET_GEN =      @echo '      GEN $@';

export QUIET_GEN
endif

export SHELL_PATH
export mandir man1dir

DESTDIR_SQ = $(subst ','\'',$(DESTDIR))
bindir_SQ = $(subst ','\'',$(bindir))
bashcompletiondir_SQ = $(subst ','\'',$(bashcompletiondir))

SHELL_PATH_SQ = $(subst ','\'',$(SHELL_PATH))
GIT_INTEGRATION_VERSION_SQ = $(subst ','\'',$(GIT_INTEGRATION_VERSION))

SHELL = $(SHELL_PATH)

# Values in the BUILD-VARS file are double-sq-escaped so that the file can be
# sourced into the script used when running tests.
BUILD-VARS: FORCE
	@echo SHELL_PATH=\''$(subst ','\'',$(SHELL_PATH_SQ))'\' >$@+ && \
	if cmp $@ $@+ >/dev/null 2>&1; then \
		rm -f $@+; \
	else \
		echo >&2 ' * build variables changed' && \
		mv $@+ $@; \
	fi

git-integration: git-integration.sh BUILD-VARS GIT-INTEGRATION-VERSION
	$(QUIET_GEN)sed -e '1s|#!.*/sh|#!$(SHELL_PATH_SQ)|' \
			-e 's|@@VERSION@@|$(GIT_INTEGRATION_VERSION_SQ)|' $< >$@+ && \
	chmod +x $@+ && \
	mv $@+ $@

all:: git-integration

test: all
	@$(MAKE) --no-print-directory -C t

install: all
	$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$(bindir_SQ)'
	$(INSTALL) -m 755 git-integration '$(DESTDIR_SQ)$(bindir_SQ)'

doc man html:
	$(MAKE) -C Documentation/ $@

install-doc:
	$(MAKE) -C Documentation/ install

install-html:
	$(MAKE) -C Documentation/ install-html

install-man:
	$(MAKE) -C Documentation/ install-man

.PHONY: doc man html install-doc install-html install-man

install-completion:
	$(INSTALL) -d -m 755 '$(DESTDIR_SQ)$(bashcompletiondir_SQ)'
	$(INSTALL) -m 644 git-integration.bashcomplete \
		'$(DESTDIR_SQ)$(bashcompletiondir_SQ)/git-integration'

clean:
	$(RM) git-integration
	$(RM) BUILD-VARS GIT-INTEGRATION-VERSION
	$(MAKE) -C Documentation/ clean
	$(MAKE) -C t/ clean

.PHONY: FORCE all clean test install install-completion


gh-pages:
	$(QUIET_GEN)rm -rf gh-pages && \
	GIT_INDEX_FILE=.git/gh-pages.index && \
	export GIT_INDEX_FILE && \
	git read-tree gh-pages && \
	git checkout-index --prefix=gh-pages/ --all && \
	$(ASCIIDOC) --conf Documentation/site.asciidoc.conf -b html5 \
		--out-file=gh-pages/index.html Documentation/index.txt && \
	$(ASCIIDOC) --conf Documentation/site.asciidoc.conf -b html5 -d manpage \
		--out-file=gh-pages/git-integration.html Documentation/git-integration.txt

commit-gh-pages: gh-pages
	GIT_INDEX_FILE=.git/gh-pages.index && \
	export GIT_INDEX_FILE && \
	git read-tree gh-pages && \
	blob=$$(git hash-object -w gh-pages/index.html) && \
	git update-index --add --cacheinfo 100644 $$blob index.html && \
	blob=$$(git hash-object -w gh-pages/git-integration.html) && \
	git update-index --add --cacheinfo 100644 $$blob git-integration.html && \
	oldtree=$$(git rev-parse --verify gh-pages^{tree}) && \
	tree=$$(git write-tree) && \
	( \
		test $$oldtree = $$tree || { \
		commit=$$(git commit-tree $$tree -p gh-pages \
			-m "Autogenerated site for $$(git describe --always HEAD)") && \
		git update-ref refs/heads/gh-pages $$commit; } \
	)

.PHONY: commit-gh-pages gh-pages
