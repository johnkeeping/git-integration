#!/bin/sh
#
# Copyright (C) 2013  John Keeping
# Licensed under the GNU GPL version 2.

SUBDIRECTORY_OK=Yes
OPTIONS_KEEPDASHDASH=
OPTIONS_SPEC="\
git integration --create <name> [<base>]
git integration --edit [--create] [<branch>]
git integration --rebuild [<branch>]
git integration --continue | --abort
--
 Actions:
create!    create a new integration branch
edit!      edit the instruction sheet for a branch
rebuild    rebuild an integration branch
abort!     abort an in-progress rebuild
continue!  continue an in-progress rebuild
 Inline actions:
add=       appends a 'merge <branch>' line to the instruction sheet
 Options:
autocontinue  continues automatically if rerere resolves all conflicts
"
. git-sh-setup
set_reflog_action integration
require_work_tree_exists
cd_to_toplevel

test -n "$GIT_INTEGRATION_DEBUG" && set -x

LF='
'
_x40='00000'
_x40="$_x40$_x40$_x40$_x40$_x40$_x40$_x40$_x40"

comment_char=$(git config --get core.commentchar 2>/dev/null | cut -c1)
: ${comment_char:=#}

autocontinue=$(git config --bool integration.autocontinue)
: ${autocontinue:=false}

state_dir="$GIT_DIR/integration"
start_file="$state_dir/start-point"
head_file="$state_dir/head-name"
merged_file="$state_dir/merged"
insns="$state_dir/git-integration-insn"


integration_ref () {
	local branch
	branch=${1#refs/heads/}
	echo refs/insns/$branch
}

write_insn_sheet () {
	local ref parent insn_blob insn_tree op insn_commit
	ref=$1
	parent=$(git rev-parse --quiet --verify $ref)

	insn_blob=$(git hash-object -w --stdin) ||
	die "Failed to write instruction sheet blob object"

	insn_tree=$(printf "100644 blob %s\t%s\n" $insn_blob GIT-INTEGRATION-INSN |
		git mktree) ||
	die "Failed to write instruction sheet tree object"

	op=${parent:+Update}
	: ${op:=Create}
	insn_commit=$(echo "$op integration branch $branch" |
		git commit-tree ${parent:+-p $parent} $insn_tree) ||
	die "Failed to write instruction sheet commit"

	git update-ref $ref $insn_commit ${parent:-$_x40} ||
	die "Failed to update instruction sheet reference"
}

integration_create () {
	branch=$1
	base=$2

	git update-ref $branch $base $_x40 &&

	echo "base $base" |
	write_insn_sheet $(integration_ref $branch) &&
	git checkout ${branch#refs/heads/} &&

	echo "Integration branch $branch created."
}

integration_edit () {
	branch=$1
	manual_edit=${2=1}
	append_branches=$3

	ref=$(integration_ref $branch)

	edit_file="$GIT_DIR/GIT-INTEGRATION-INSN"

	git rev-parse --quiet --verify $ref >/dev/null ||
	die "Not an integration branch: ${branch#refs/heads/}"

	{
		git cat-file blob $ref:GIT-INTEGRATION-INSN &&
		if test -n "$append_branches"
		then
			echo "$append_branches" |
			sed -e '/^$/d' -e 's/^/\nmerge /'
		fi
		echo &&
		git stripspace --comment-lines <<EOF 

Format:
 command: args

    Indented lines form a comment for certain commands.
    For other commands these are ignored.

Lines beginning with $comment_char are stripped.

Commands:
 base		Resets the branch to the specified state.  Every integration
		instruction list should begin with a "base" command.
 merge		Merges the specified branch.  Extended comment lines are
		added to the commit message for the merge.
EOF
	} >"$edit_file"

	if test "$manual_edit" != 0
	then
		git_editor "$edit_file" || die
	fi

	cat "$edit_file" |
	git stripspace --strip-comments |
	write_insn_sheet $ref
}

break_integration () {
	printf '%s\n%s\n' "$current_insn" "$line" >"$insns".new
	cat >>"$insns".new

	mv "$insns".new "$insns"
	echo "$merged" >"$merged_file"

	test $# = 0 || printf '%s\n' "$1" >&2
	cat >&2 <<EOF

Once you have resolved this, run:

	git integration --continue

NOTE: Any changes to the instruction sheet will not be saved.
EOF
	exit 1
}

finish_integration () {
	git update-ref "$branch" HEAD $(cat "$start_file" 2>/dev/null) &&
	git symbolic-ref HEAD "$branch" &&
	rm -rf "$state_dir" &&
	git gc --auto &&
	echo "Successfully re-integrated ${branch#refs/heads/}."
}

do_merge () {
	local brance_to_merge merge_msg merge_opts
	branch_to_merge=$1
	test -n "$branch_to_merge" || break_integration

	if test "$skip_commit" = "$(git rev-parse --quiet $branch_to_merge)"
	then
		echo "Merged branch ${branch_to_merge}."
		merged="$merged$branch_to_merge$LF"
		return
	fi

	merge_msg=$(
		printf '%s\t\tbranch %s' \
			$(git rev-parse --quiet --verify $branch_to_merge) \
			$branch_to_merge |
		git fmt-merge-msg --log --message \
			"Merge branch '$branch_to_merge' into ${branch#refs/heads/}" |
		git stripspace --strip-comments &&
		printf '\n%s\n' "$message"
	) || die "failed to create message for merge commit"

	merge_opts="--quiet --no-log --no-ff"
	if test "$autocontinue" = "true"
	then
		merge_opts="$merge_opts --rerere-autoupdate"
	fi

	echo "Merging branch ${branch_to_merge}..."
	if ! git merge $merge_opts -m "$merge_msg" $branch_to_merge
	then
		if test "$autocontinue" = "true" &&
		   test -z "$(git ls-files --unmerged)"
		then
			git commit --no-edit --no-verify || break_integration
		else
			break_integration
		fi
	fi
	merged="$merged$branch_to_merge$LF"
}

do_base () {
	local base
	base=$1
	test -z "$merged" || {
		echo >&2 "warning: dropping the following branches (resetting to base $base)"
		cat "$merged" | sed -e 's/^/warning: /' >&2
	}
	echo "Resetting to base ${base}..."
	git reset --quiet --hard "$base" ||
	break_integration "Failed to reset to base $base"
}

dedent () {
	local message indent
	# Strip leading blank lines.
	message=$(IFS=
		while read -r line
		do
			test -z "$line" && continue
			printf '%s\n' "$line"
			break
		done
		cat
	)
	indent=$(echo "$message" | sed -n -e '1 {
		s/^\([ 	]*\).*$/\1/
		p
		q
	}')
	echo "$message" | sed -e "s/^$indent//"
}

finalize_command () {
	local IFS
	IFS=" 	$LF"
	local first_line
	first_line=$(echo "$1" | sed -n -e 1p)
	test -n "$first_line" || return 0

	local message cmd args
	message=$(echo "$1" | sed -e 1d | dedent)
	cmd=${first_line%% *}
	args=${first_line#* }
	case "$cmd" in
	base)
		eval "do_base $args"
		;;
	merge)
		eval "do_merge $args"
		;;
	*)
		break_integration "Unknown command: $cmd"
		;;
	esac
}

run_integration () {
	local IFS merged skip_commit
	merged=$1
	skip_commit=$2
	current_insn=
	IFS=
	while read -r line
	do
		case "$line" in
		''|' '*|'	'*)
			: # Blank or indented line.
			;;
		*)
			# New command, finish the previous one.
			finalize_command "$current_insn"
			current_insn=
			;;
		esac
		current_insn="$current_insn$line$LF"
	done
	finalize_command "$current_insn"
	finish_integration
}

integration_rebuild () {
	local branch orig_head ref
	branch=$1
	require_clean_work_tree integrate "Please commit or stash them."

	orig_head=$(git rev-parse --quiet --verify "$branch^{commit}") || exit
	git checkout --quiet "$branch^0" || die "could not detach HEAD"
	git update-ref ORIG_HEAD $orig_head

	ref=$(integration_ref $branch)

	git rev-parse --quiet --verify $ref >/dev/null ||
	die "Not an integration branch: ${branch#refs/heads/}"

	mkdir -p "$state_dir" ||
	die "Failed to create state directory"

	echo $branch >"$head_file"
	git rev-parse --quiet --verify "$branch" >"$start_file"

	git cat-file blob $ref:GIT-INTEGRATION-INSN >"$insns" ||
	die "Failed to read instruction list for branch ${branch#refs/heads/}"

	cat "$insns" | run_integration
}

integration_abort () {
	test $# = 0 || usage
	local branch
	branch=$(cat "$head_file") ||
	die "No integration in progress."

	git reset --hard $branch &&
	git symbolic-ref HEAD $branch &&
	rm -rf "$state_dir"
}

integration_continue () {
	test $# = 0 || usage

	local branch skip_commit merged
	branch=$(cat "$head_file") ||
	die "No integration in progress."

	if test -f "$GIT_DIR/MERGE_HEAD"
	then
		# We are being called to continue an existing operation,
		# without the user having manually committed the result of
		# resolving conflicts.
		git update-index --ignore-submodules --refresh &&
		git diff-files --quiet --ignore-submodules ||
		die "You must edit all merge conflicts and then mark them as resolved using git add"

		skip_commit=$(cat "$GIT_DIR/MERGE_HEAD")

		git commit --no-edit || die
	fi

	merged=$(cat "$merged_file")

	cat "$insns" | run_integration "$merged" "$skip_commit"
}

action=
do_create=0
do_edit=0
do_rebuild=auto
branches_to_add=

total_argc=$#
while test $# != 0
do
	case "$1" in
	--create)
		do_create=1
		;;
	--edit)
		do_edit=1
		;;
	--rebuild)
		do_rebuild=1
		;;
	--no-rebuild)
		do_rebuild=0
		;;
	--abort|--continue)
		test -z "$action" || usage
		test $total_argc -eq 2 || usage
		action=${1##--}
		;;
	--add)
		shift
		git rev-parse --quiet --verify "$1^{commit}" >/dev/null ||
		die "not a valid commit: $1"
		branches_to_add="$branches_to_add$1$LF"
		;;
	--autocontinue)
		autocontinue=true
		;;
	--no-autocontinue)
		autocontinue=false
		;;
	--)
		shift
		break
		;;
	*)
		usage
		;;
	esac
	shift
done

if test -n "$action"
then
	test $do_create != 1 &&
	test $do_edit != 1 &&
	test $do_rebuild != 1 &&
	test -z "$branches_to_add" || usage
fi

case $action in
	continue)
		integration_continue
		exit
		;;
	abort)
		integration_abort
		exit
		;;
	*)
		test -f "$insns" &&
		die "Integration already in progress."
		;;
esac

test $do_create = 1 ||
test $do_edit = 1 ||
test $do_rebuild = 1 ||
test -n "$branches_to_add" || usage

branch=
if test $do_create = 1
then
	test $# != 0 || usage

	branch=$(git check-ref-format --normalize "refs/heads/$1") ||
	die "invalid branch name: $1"
	shift
	if test $# = 0
	then
		base=master
	else
		base=$1
		shift
		git rev-parse --quiet --verify "$base^{commit}" >/dev/null ||
		die "no such branch: $base"
	fi

	test $# = 0 || usage

	integration_create "$branch" "$base"
else
	if test $# = 0
	then
		branch=$(git symbolic-ref HEAD 2>/dev/null) ||
		die "HEAD is detached, could not figure out which integration branch to use"
	else
		branch=$(git check-ref-format --normalize "refs/heads/${1#refs/heads/}") &&
		git rev-parse --quiet --verify "$branch^{commit}" >/dev/null ||
		die "no such branch: $1"

		shift
	fi

	git rev-parse --quiet --verify "$(integration_ref "$branch")" >/dev/null ||
	die "Not an integration branch: ${branch#refs/heads/}"
fi

test $# = 0 || usage

if test $do_edit = 1 || test -n "$branches_to_add"
then
	integration_edit "$branch" $do_edit "$branches_to_add"
fi

if test $do_rebuild = auto
then
	test "$(git config --bool --get integration.autorebuild)" = true &&
	do_rebuild=1
fi

if test $do_rebuild = 1
then
	integration_rebuild "$branch"
fi
