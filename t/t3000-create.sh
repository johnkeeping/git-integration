#!/bin/sh

test_description='Test the --create option'
. ./setup.sh

test_expect_success 'setup branches' '
	commit_file base base &&
	git checkout -b branch1 &&
	commit_file branch1 branch1 &&
	git checkout -b branch2 master &&
	commit_file branch2 branch2 &&
	git tag -m tag1 -a tag1 branch1
'

test_expect_success 'create from non-existent base' '
	test_must_fail git integration --create int-bad i-dont-exist &&
	test_must_fail git rev-parse --verify int-bad
'

test_expect_success 'create integration branch from tag' '
	git integration --create int-tag tag1 &&
	git rev-parse --verify branch1 >expect &&
	git rev-parse --verify HEAD >actual &&
	test_cmp expect actual
'

test_done
