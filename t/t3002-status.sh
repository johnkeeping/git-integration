#!/bin/sh

test_description='Test the --status option'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file base base &&
	git checkout -b branch1 &&
	commit_file branch1 branch1 &&
	git checkout -b branch2 master &&
	commit_file branch2 branch2
'

test_expect_success 'no branches in integration branch' '
	git checkout master &&
	git integration --create pu &&
	: >expect &&
	git integration --status >actual &&
	test_cmp expect actual
'

test_expect_success 'branch out-of-date' '
	git integration --add branch1 &&
	git integration --status >actual &&
	grep "^- branch1" actual &&
	! grep branch2 actual
'

test_expect_success 'branch up-to-date' '
	git integration --rebuild &&
	git integration --status >actual &&
	grep "^\\* branch1" actual &&
	! grep branch2 actual
'

test_expect_success 'add a second (out-of-date) branch' '
	git integration --add branch2 &&
	git integration --status >actual &&
	grep "^\\* branch1" actual &&
	grep "^- branch2" actual
'

test_expect_success 'two up-to-date branches' '
	git integration --rebuild pu &&
	git integration --status >actual &&
	grep "^\\* branch1" actual &&
	grep "^\\* branch2" actual
'

test_expect_success 'branch merged to base' '
	git checkout master &&
	git merge --no-edit branch1 &&
	git integration --rebuild pu &&
	git integration --status >actual &&
	grep "^+ branch1" actual &&
	grep "^\\* branch2" actual
'

test_expect_success 'branch deleted' '
	git branch -D branch1 &&
	git integration --status >actual &&
	grep "^\\. branch1" actual &&
	grep "^\\* branch2" actual
'

test_expect_success 'empty commit' '
	write_script .git/EDITOR <<-\EOF &&
	cat >"$1" <<EOM
	base master
	empty
	  ### start
	merge branch2
	EOM
	EOF
	GIT_EDITOR=.git/EDITOR git integration --edit &&
	git integration --status >actual &&
	grep "^- <empty>" actual &&
	git integration --rebuild &&
	git integration --status >actual &&
	grep "^\\* <empty>" actual
'

test_done
