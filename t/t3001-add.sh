#!/bin/sh

test_description='Test the --add option'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file base base &&
	git checkout -b branch1 &&
	commit_file branch1 branch1 &&
	git checkout -b branch2 master &&
	commit_file branch2 branch2
'

test_expect_success 'add one branch to an integration branch' '
	git checkout master &&
	git integration --create pu1 &&
	GIT_EDITOR=false git integration --add branch1 &&
	git integration --cat >INSTRUCTIONS &&
	grep "^merge branch1" INSTRUCTIONS &&
	! grep "^merge branch2" INSTRUCTIONS
'

test_expect_success 'add a branch during create' '
	git checkout master &&
	git integration --add branch2 --create pu2 &&
	git integration --cat >INSTRUCTIONS &&
	! grep "^merge branch1" INSTRUCTIONS &&
	grep "^merge branch2" INSTRUCTIONS
'

test_expect_success 'add two branches and rebuild' '
	git checkout master &&
	git integration --create pu3 &&
	GIT_EDITOR=false git integration --add branch1 --add branch2 --rebuild &&
	git integration --cat >INSTRUCTIONS &&
	grep "^merge branch1" INSTRUCTIONS &&
	grep "^merge branch2" INSTRUCTIONS &&
	git merge-base --is-ancestor branch1 HEAD &&
	git merge-base --is-ancestor branch2 HEAD
'

test_expect_success 'nothing happens if branch is invalid' '
	git checkout master &&
	test_must_fail git integration --create --add=i-dont-exist shouldnt-exist &&
	test_must_fail git rev-parse --verify shouldnt-exist
'

test_done
