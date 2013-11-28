#!/bin/sh

test_description='Test applying a prefix to refs in the instruction sheet'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file base base &&
	git branch -M sub/master &&
	git checkout -b sub/branch1 &&
	commit_file base sub/branch1 &&
	git checkout -b sub/branch2 sub/master &&
	commit_file base sub/branch2 &&
	git checkout -b sub/branch3 sub/master &&
	commit_file base sub/branch3
'

write_script .git/EDITOR <<\EOF
#!/bin/sh
cat >"$1" <<EOM
base master
merge branch1
merge branch2
EOM
EOF

test_expect_success 'create integration branch' '
	git checkout sub/master &&
	GIT_EDITOR=.git/EDITOR git integration --create --prefix=sub/ --edit pu &&
	git symbolic-ref HEAD >actual &&
	echo refs/heads/pu >expect &&
	test_cmp expect actual
'

test_expect_success 'prefix preserved over pause and continue' '
	# Continue mode should ignore the configured prefix and use whatever
	# was given when the command started
	test_config integration.prefix invalid/ &&
	test_must_fail git integration --rebuild --prefix sub/ &&
	git merge-base --is-ancestor sub/branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor sub/branch2 HEAD &&
	echo resolved >base &&
	git add base &&
	git integration --continue >output &&
	git merge-base --is-ancestor sub/branch2 HEAD &&
	grep branch2 output
'

test_expect_success 'status with prefix' '
	git integration --status >output &&
	grep "^\\. branch1" output &&
	grep "^\\. branch2" output &&
	git integration --status --prefix=sub/ >output &&
	grep "^\\* sub/branch1" output &&
	grep "^\\* sub/branch2" output &&
	test_config integration.prefix sub/ &&
	git integration --status >actual &&
	test_cmp output actual
'

test_expect_success 'add respects prefix' '
	test_must_fail git integration --add=branch3 2>output &&
	grep branch3 output &&
	git integration --add=branch3 --prefix=sub/ &&
	git integration --cat >output &&
	! grep sub/ output
'

test_done
