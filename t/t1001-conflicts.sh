#!/bin/sh

test_description='Test integration branches with no conflicts'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file base base &&
	git checkout -b branch1 &&
	commit_file base branch1 &&
	git checkout -b branch2 master &&
	commit_file base branch2 &&
	git checkout -b branch3 master &&
	commit_file newfile newfile
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
	git checkout master &&
	GIT_EDITOR=.git/EDITOR git integration --create --edit pu &&
	git symbolic-ref HEAD >actual &&
	echo refs/heads/pu >expect &&
	test_cmp expect actual
'

test_expect_success 'conflict in last branch resolved' '
	test_must_fail git integration --rebuild &&
	git merge-base --is-ancestor branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor branch2 HEAD &&
	echo resolved >base &&
	git add base &&
	git integration --continue >output &&
	git merge-base --is-ancestor branch2 HEAD &&
	grep branch2 output
'

test_expect_success 'conflict in last branch try continue when unresolved' '
	test_must_fail git integration --rebuild &&
	git merge-base --is-ancestor branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor branch2 HEAD &&
	test_must_fail git integration --continue &&
	echo resolved >base &&
	git add base &&
	git integration --continue >output &&
	git merge-base --is-ancestor branch2 HEAD &&
	grep branch2 output
'

test_expect_success 'conflict in last branch skipped' '
	test_must_fail git integration --rebuild &&
	git merge-base --is-ancestor branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor branch2 HEAD &&
	git integration --skip &&
	! git merge-base --is-ancestor branch2 HEAD
'

test_expect_success 'conflict in last branch and abort' '
	git checkout pu &&
	git reset --hard master &&
	test_must_fail git integration --rebuild &&
	git merge-base --is-ancestor branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor branch2 HEAD &&
	git integration --abort &&
	git rev-parse --verify master >expect &&
	git rev-parse --verify pu >actual &&
	test_cmp expect actual &&
	echo refs/heads/pu >expect &&
	git symbolic-ref HEAD >actual &&
	test_cmp expect actual &&
	test_must_fail git merge-base --is-ancestor branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor branch2 HEAD
'

test_expect_success 'abort does not move other branches' '
	git checkout pu &&
	git reset --hard master &&
	git rev-parse --verify branch1 >expect &&
	test_must_fail git integration --rebuild &&
	git checkout --force branch1 &&
	git integration --abort &&
	git rev-parse --verify branch1 >actual &&
	test_cmp expect actual
'

write_script .git/EDITOR <<\EOF
#!/bin/sh
cat >>"$1" <<EOM
merge branch3
EOM
EOF

test_expect_success 'conflict in middle branch' '
	GIT_EDITOR=.git/EDITOR git integration --edit &&
	test_must_fail git integration --rebuild &&
	git merge-base --is-ancestor branch1 HEAD &&
	test_must_fail git merge-base --is-ancestor branch2 HEAD &&
	echo resolved >base &&
	git add base &&
	git integration --continue >output &&
	git merge-base --is-ancestor branch2 HEAD &&
	git merge-base --is-ancestor branch3 HEAD &&
	grep branch2 output &&
	grep branch3 output
'

test_done
