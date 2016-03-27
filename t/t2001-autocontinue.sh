#!/bin/sh

test_description='Test autocontinue'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file file base &&
	git checkout -b branch1 &&
	commit_file file branch1 &&
	git checkout -b branch2 master &&
	commit_file file branch2 &&
	git checkout -b branch3 master &&
	commit_file file branch3
'

test_expect_success 'create integration branch' '
	test_config rerere.enabled true &&
	test_must_fail git integration --create --add branch1 --add branch2 --add branch3 --rebuild pu &&
	echo merged >file &&
	git add file &&
	test_must_fail git integration --continue &&
	echo merged-again >file &&
	git add file &&
	git integration --continue
'

test_expect_success 'rebuild with --autocontinue' '
	test_config rerere.enabled true &&
	git integration --rebuild --autocontinue &&
	git merge-base --is-ancestor branch1 HEAD &&
	git merge-base --is-ancestor branch2 HEAD &&
	git merge-base --is-ancestor branch3 HEAD
'

test_expect_success 'rebuild with autocontinue in config' '
	test_config rerere.enabled true &&
	test_config integration.autocontinue true &&
	git integration --rebuild &&
	git merge-base --is-ancestor branch1 HEAD &&
	git merge-base --is-ancestor branch2 HEAD &&
	git merge-base --is-ancestor branch3 HEAD
'

test_expect_success 'rebuild with autocontinue in config and --no-autocontinue' '
	test_config rerere.enabled true &&
	test_config integration.autocontinue true &&
	test_when_finished git integration --abort &&
	test_must_fail git integration --rebuild --no-autocontinue &&
	git add file &&
	test_must_fail git integration --continue
'

test_done
