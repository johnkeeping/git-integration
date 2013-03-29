#!/bin/sh

SHARNESS_TEST_EXTENSION=sh
. ./sharness/sharness.sh

# Add the git-integrate directory to $PATH.
PATH=$(cd ..; pwd):$PATH
export PATH


if ! type git-integration >/dev/null
then
	echo "git-integration doesn't exist.  Have you built it?" >&2
	exit 1
fi


if test -z "$TEST_NO_CREATE_REPO"
then
	git init >/dev/null
fi


GIT_AUTHOR_NAME='A. U. Thor'
GIT_AUTHOR_EMAIL='a.u.thor@example.com'
GIT_COMMITTER_NAME='C. O. Mitter'
GIT_COMMITTER_EMAIL='c.o.mitter@example.net'
export GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL


commit_file () {
	local filename
	filename=$1
	shift
	printf "%s\n" "$*" >"$filename" &&
	git add -f "$filename" &&
	git commit -m "commit $filename"
}

write_script () {
	{
		echo "#!/bin/sh" &&
		cat
	} >"$1" &&
	chmod +x "$1"
}
