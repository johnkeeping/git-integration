#!/bin/sh

test_description='Test configuration variables affecting git-integration'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file base base &&
	git checkout -b branch1 &&
	commit_file branch1 branch1 &&
	git checkout -b branch2 master &&
	commit_file branch2 branch2
'

write_script .git/EDITOR <<\EOF
#!/bin/sh
cat >>"$1" <<EOM
merge branch1

  This merges branch 1.

merge branch2

  This merges branch 2.
EOM
EOF

test_expect_success 'create integration branch with autorebuild' '
	test_config integration.autorebuild true
	GIT_EDITOR=.git/EDITOR git integration --create --edit pu &&
	git merge-base --is-ancestor branch1 HEAD &&
	git merge-base --is-ancestor branch2 HEAD
'

test_expect_success 'create integration branch with --no-rebuild' '
	test_config integration.autorebuild true
	GIT_EDITOR=.git/EDITOR git integration --create --edit --no-rebuild not-built &&
	test_must_fail git merge-base --is-ancestor branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor branch2 HEAD
'

test_done
