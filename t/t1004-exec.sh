#!/bin/sh

test_description='Test the exec instruction'
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
cat >"$1" <<EOM
base master
merge branch1
exec echo one >new-file && git add new-file && git commit -m new-file
merge branch2
EOM
EOF

test_expect_success 'exec enabled by integration.allowExec' '
	git checkout master &&
	GIT_EDITOR=.git/EDITOR git integration --create --edit pu &&
	test_must_fail git integration --rebuild pu 2>actual &&
	grep "command is not enabled" actual &&
	test_config integration.allowExec true &&
	git integration --continue &&
	git cat-file blob HEAD:new-file >actual &&
	echo one >expect &&
	test_cmp expect actual
'

test_expect_success 'exec enabled by branch.<name>.integrationAllowExec' '
	test_config branch.pu.integrationAllowExec true &&
	git integration --rebuild pu
'

write_script .git/EDITOR <<\EOF
#!/bin/sh
cat >"$1" <<EOM
base master
merge branch1
exec false
merge branch2
exec echo one >new-file && git add new-file && git commit -m new-file
EOM
EOF

test_expect_success 'handle failure in exec' '
	test_config integration.allowExec true &&
	GIT_EDITOR=.git/EDITOR git integration --edit pu &&
	test_must_fail git integration --rebuild pu &&
	! test -f new-file &&
	git integration --continue &&
	test -f new-file
'

test_done
