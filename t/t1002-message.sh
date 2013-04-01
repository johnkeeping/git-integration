#!/bin/sh

test_description='Test integration branches with no conflicts'
. ./setup.sh

write_script .git/EDITOR <<\EOF
#!/bin/sh
cat >>"$1" <<EOM
merge branch1

  This merges branch 1.

merge branch2

  This merges branch 2.
EOM
EOF

test_expect_success 'setup branches' '
	commit_file base base &&
	git checkout -b branch1 &&
	commit_file branch1 branch1 &&
	git checkout -b branch2 master &&
	commit_file branch2 branch2 &&
	GIT_EDITOR=.git/EDITOR git integration --create --edit --rebuild pu
'

test_expect_success 'check branches merged' '
	git symbolic-ref HEAD >actual &&
	echo refs/heads/pu >expect &&
	test_cmp expect actual &&
	git merge-base --is-ancestor branch1 HEAD &&
	git merge-base --is-ancestor branch2 HEAD
'

test_expect_success 'check branch2 merge message' '
	git cat-file commit HEAD | sed -e "1,/^\$/ d" >message &&
	grep "branch .branch2. into pu" message &&
	grep "^This merges branch 2" message
'

test_expect_success 'check branch1 merge message' '
	git cat-file commit HEAD^ | sed -e "1,/^\$/ d" >message &&
	grep "branch .branch1. into pu" message &&
	grep "^This merges branch 1" message
'

test_done
