#!/bin/sh

test_description='Test integration branches with no conflicts'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file base base &&
	git checkout -b branch1 &&
	commit_file branch1 branch1 &&
	git checkout -b branch2 master &&
	commit_file branch2 branch2
'

test_expect_success 'create integration branch' '
	git checkout master &&
	git integration --create pu &&
	git cat-file blob refs/insns/pu:GIT-INTEGRATION-INSN >actual &&
	echo "base master" >expect &&
	test_cmp expect actual &&
	git symbolic-ref HEAD >actual &&
	echo refs/heads/pu >expect &&
	test_cmp expect actual
'

write_script .git/EDITOR <<\EOF
#!/bin/sh
cat >>"$1" <<EOM
merge branch1

  This merges branch 1.

merge branch2

  This merges branch 2.

. branch3

  "branch3" is ignored for now.
EOM
EOF

test_expect_success 'add branches to integration branch' '
	GIT_EDITOR=.git/EDITOR git integration --edit &&
	git integration --rebuild &&
	git merge-base --is-ancestor branch1 HEAD &&
	git merge-base --is-ancestor branch2 HEAD &&
	test_must_fail git merge-base --is-ancestor branch3 HEAD &&
	git log --merges --oneline | wc -l | tr -d " " >actual &&
	echo 2 >expect &&
	test_cmp expect actual
'

write_script .git/EDITOR <<\EOF
#!/bin/sh
cat >>"$1" <<EOM
merge branch3

  This merges branch 3.
EOM
EOF

test_expect_success 'add another branch and rebuild' '
	git checkout -b branch3 master &&
	commit_file branch3 branch3 &&
	GIT_EDITOR=.git/EDITOR git integration --edit pu &&
	git integration --rebuild pu &&
	git merge-base --is-ancestor branch1 HEAD &&
	git merge-base --is-ancestor branch2 HEAD &&
	git merge-base --is-ancestor branch3 HEAD &&
	git log --merges --oneline | wc -l | tr -d " " >actual &&
	echo 3 >expect &&
	test_cmp expect actual
'

test_expect_success 'do not create empty commits' '
	git rev-parse --verify refs/insns/pu >expect &&
	GIT_EDITOR=true git integration --edit &&
	git rev-parse --verify refs/insns/pu >actual &&
	test_cmp expect actual
'

test_done
