#!/bin/sh
#
# Copyright (C) 2013  John Keeping
# Licensed under the GNU GPL version 2.

# If we haven't been called via Git, see if we can tweak $PATH so
# that we can find the git-sh-setup script when we need it later.
GIT_INTEGRATION_VERSION='@@VERSION@@'

if ! type git-sh-setup >/dev/null 2>&1
then
	exec_path=$(git --exec-path) || die 'Git not found!'
	PATH="$exec_path:$PATH"
	export PATH
fi

SUBDIRECTORY_OK=Yes
OPTIONS_KEEPDASHDASH=
OPTIONS_SPEC="\
git integration --create <name> [<base>]
git integration [<action>...] [<branch>]
git integration (--continue | --abort)
--
 Actions:
create!    create a new integration branch
edit!      edit the instruction sheet for a branch
rebuild    rebuild an integration branch
cat!       show the instruction sheet for a branch
status!    show the status of a branch
abort!     abort an in-progress rebuild
continue!  continue an in-progress rebuild
 Inline actions:
add=       appends a 'merge <branch>' line to the instruction sheet
 Options:
autocontinue  continues automatically if rerere resolves all conflicts
prefix=       apply a prefix to each branch name when processing it
version!      print the version of git-integration
"
. git-sh-setup
set_reflog_action integration
require_work_tree_exists
cd_to_toplevel

if test -n "$GIT_INTEGRATION_DEBUG"
then
	set -x
	PS4='+ $(basename "$0"):$LINENO: '
fi

LF='
'
_x40='00000'
_x40="$_x40$_x40$_x40$_x40$_x40$_x40$_x40$_x40"

comment_char=$(git config --get core.commentchar 2>/dev/null | cut -c1)
: ${comment_char:=#}

autocontinue=$(git config --bool integration.autocontinue)
: ${autocontinue:=false}

branch_prefix=$(git config --get integration.prefix 2>/dev/null)

state_dir="$GIT_DIR/integration"
start_file="$state_dir/start-point"
head_file="$state_dir/head-name"
merged_file="$state_dir/merged"
prefix_file="$state_dir/prefix"
insns="$state_dir/git-integration-insn"


print_version () {
	echo "git-integration version $GIT_INTEGRATION_VERSION"
}

integration_ref () {
	local branch
	branch=${1#refs/heads/}
	echo refs/insns/$branch
}

write_insn_sheet () {
	local ref parent insn_blob insn_tree op insn_commit
	ref=$1
	parent=$(git rev-parse --quiet --verify $ref)
	parent_tree=$(git rev-parse --quiet --verify $ref^{tree})

	insn_blob=$(git hash-object -w --stdin) ||
	die "Failed to write instruction sheet blob object"

	insn_tree=$(printf "100644 blob %s\t%s\n" $insn_blob GIT-INTEGRATION-INSN |
		git mktree) ||
	die "Failed to write instruction sheet tree object"

	# If there isn't anything to commit, stop now.
	test "$insn_tree" = "$parent_tree" && return

	op=${parent:+Update}
	: ${op:=Create}
	insn_commit=$(echo "$op integration branch $branch" |
		git commit-tree ${parent:+-p $parent} $insn_tree) ||
	die "Failed to write instruction sheet commit"

	git update-ref $ref $insn_commit ${parent:-$_x40} ||
	die "Failed to update instruction sheet reference"
}

# Helper function to extract the first word in a (potentially shell quoted)
# string.  The normal usage is:
#
#	eval first_word $foo
#
# $1 - argument to be echoed
first_word () {
	echo "$1"
}

# De-indents its argument based on the indentation of its first content line.
# Leading blank lines are stripped.
#
# $1 - message to be de-indented
#
# Prints to stdout the message after removing indentation.
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

# Helper function used in for_each_insn.  This extracts the command,
# arguments and message from the full command block before calling the
# insn_cmd with each of those as a separate argument.
#
# $1 - insn_cmd to be run for each instruction.
# $2 - message to be parsed and split.
#
# Returns the exit code of insn_cmd.
run_insn_command () {
	local IFS
	IFS=" 	$LF"

	local insn_cmd first_line message cmd args
	insn_cmd=$1

	first_line=$(echo "$2" | sed -n -e 1p)
	test -n "$first_line" || return 0

	local message cmd args
	message=$(echo "$2" | sed -e 1d | dedent)
	cmd=${first_line%% *}
	args=${first_line#* }

	$insn_cmd "$cmd" "$args" "$message"
}

# Run a command for each instruction read from stdin.  The input is a
# git-integration instruction sheet which is split into instructions.
#
# insn_cmd is called once for each instruction, with the parameters "cmd",
# "args", "message" where:
#
# - cmd is the command in the instruction sheet
# - args is the remainder of the command line
# - message is the indented message following the command
#
# Processing ends early if insn_cmd returns a non-zero exit code for any
# instruction.
#
# $1 - insn_cmd to run for each instruction.
#
# Returns the exit code of insn_cmd.
for_each_insn () {
	local cmd
	insn_cmd=$1
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
			run_insn_command "$insn_cmd" "$current_insn" || return
			current_insn=
			;;
		esac
		current_insn="$current_insn$line$LF"
	done
	run_insn_command "$insn_cmd" "$current_insn"
}

integration_create () {
	branch=$1
	base=$2

	git update-ref $branch "$branch_prefix$base" $_x40 &&

	echo "base ${base#$branch_prefix}" |
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
 .		The command is ignored.
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
	git update-ref -m "$GIT_REFLOG_ACTION: rebuilt" \
		"$branch" HEAD $(cat "$start_file" 2>/dev/null) &&
	git symbolic-ref -m "$GIT_REFLOG_ACTION: complete" HEAD "$branch" &&
	rm -rf "$state_dir" &&
	git gc --auto &&
	echo "Successfully re-integrated ${branch#refs/heads/}."
}

do_merge () {
	local branch_to_merge merge_msg merge_opts
	branch_to_merge=$1
	shift

	test -n "$branch_to_merge" || break_integration

	branch_to_merge=$branch_prefix$branch_to_merge

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
	if ! git merge "$@" $merge_opts -m "$merge_msg" $branch_to_merge
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
	base=$branch_prefix$1
	test -z "$merged" || {
		echo >&2 "warning: dropping the following branches (resetting to base $base)"
		cat "$merged" | sed -e 's/^/warning: /' >&2
	}
	echo "Resetting to base ${base}..."
	GIT_REFLOG_ACTION="$GIT_REFLOG_ACTION: resetting to base '$base'" \
	git reset --quiet --hard "$base" ||
	break_integration "Failed to reset to base $base"
}

do_dot () {
	: no-op
}

finalize_command () {
	local cmd args message
	cmd=$1
	args=$2
	message=$3
	case "$cmd" in
	base)
		eval "do_base $args"
		;;
	merge)
		eval "do_merge $args"
		;;
	'.')
		eval "do_dot $args"
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
	for_each_insn finalize_command
	finish_integration
}

integration_rebuild () {
	local branch orig_head ref
	branch=$1
	require_clean_work_tree integrate "Please commit or stash them."

	orig_head=$(git rev-parse --quiet --verify "$branch^{commit}") || exit
	GIT_REFLOG_ACTION="$GIT_REFLOG_ACTION: starting rebuild of $branch" \
	git checkout --quiet "$branch^0" || die "could not detach HEAD"
	git update-ref ORIG_HEAD $orig_head

	ref=$(integration_ref $branch)

	git rev-parse --quiet --verify $ref >/dev/null ||
	die "Not an integration branch: ${branch#refs/heads/}"

	mkdir -p "$state_dir" ||
	die "Failed to create state directory"

	echo $branch >"$head_file"
	printf '%s\n' "$branch_prefix" >"$prefix_file"
	git rev-parse --quiet --verify "$branch" >"$start_file"

	git cat-file blob $ref:GIT-INTEGRATION-INSN >"$insns" ||
	die "Failed to read instruction list for branch ${branch#refs/heads/}"

	cat "$insns" | run_integration || die
}

integration_abort () {
	test $# = 0 || usage
	local branch
	branch=$(cat "$head_file" 2>/dev/null) ||
	die "No integration in progress."

	git symbolic-ref -m "$GIT_REFLOG_ACTION: aborted" HEAD $branch &&
	git reset --hard $branch &&
	rm -rf "$state_dir"
}

integration_continue () {
	test $# = 0 || usage

	local branch skip_commit merged
	branch=$(cat "$head_file" 2>/dev/null) ||
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
	branch_prefix=$(cat "$prefix_file")

	cat "$insns" | run_integration "$merged" "$skip_commit"
}

insn_branch_length () {
	local cmd args message
	cmd=$1
	args=$2
	message=$3

	if test "$cmd" = merge
	then
		args="$branch_prefix$(eval "first_word $args")"
		echo ${#args}
	else
		echo 0
	fi
}

# Show the status of a merge command in the instruction sheet.
#
# $1 - branch to be shown
status_merge () {
	local branch_to_merge state verbose_state
	branch_to_merge=$1
	if test -z "$branch_to_merge"
	then
		say >&2 "no branch specified with 'merge' command"
		return
	fi
	branch_to_merge="$branch_prefix$branch_to_merge"
	test -n "$status_base" || status_base=master

	if ! git rev-parse --verify --quiet "$branch_to_merge"^{commit} >/dev/null
	then
		state="$color_changed."
		verbose_state="branch not found"
	elif git merge-base --is-ancestor "$branch_to_merge" "$status_base"
	then
		state="$color_merged+"
		verbose_state="merged to $status_base"
	elif git-merge-base --is-ancestor "$branch_to_merge" "$branch"
	then
		state="$color_uptodate*"
		verbose_state="up-to-date"
	else
		state="$color_changed-"
		verbose_state="branch changed"
	fi

	local color
	test -z "$use_color" || color='--color=always'
	printf '%s %-*s%s(%s)\n' "$state" "$longest_branch" "$branch_to_merge" "$color_reset" "$verbose_state"
	test -n "$message" && echo "$message" | sed -e 's/^./    &/'
	echo
	git --no-pager log --oneline $color --cherry "$status_base...$branch_to_merge" -- 2>/dev/null |
	sed -e 's/^/  /' -e '$ a \
'
}

status_dot () {
	printf '. %s\n' "$*"
	test -n "$message" && echo "$message" | sed -e 's/^./    &/'
}

insn_status () {
	local cmd args message
	cmd=$1
	args=$2
	message=$3

	case "$cmd" in
	base)
		status_base="$branch_prefix$args"
		;;
	merge)
		eval "status_merge $args"
		;;
	'.')
		eval "status_dot $args"
		;;
	*)
		say >&2 "unhandled command: $cmd $args"
		;;
	esac
}

integration_status () {
	local branch ref insn_list
	branch=$1

	ref=$(integration_ref $branch) || die

	insn_list=$(git cat-file blob $ref:GIT-INTEGRATION-INSN) ||
	die "Failed to read instruction list for branch ${branch#refs/heads/}"

	longest_branch=$(
		echo "$insn_list" | for_each_insn insn_branch_length | (
			max=0
			while read -r len
			do
				test "$len" -gt "$max" && max=$len
			done
			echo "$max"
		)
	) || longest_branch=40
	# Add two characters separation.
	longest_branch=$(($longest_branch + 2))

	local use_color color_merged color_uptodate color_changed color_reset
	if git config --get-colorbool color.status
	then
		use_color=true
		color_merged=$(git config --get-color color.integration.merged blue)
		color_uptodate=$(git config --get-color color.integration.uptodate green)
		color_changed=$(git config --get-color color.integration.changed red)
		color_reset=$(git config --get-color '' reset)
	fi

	echo "$insn_list" | for_each_insn insn_status
}

action=
do_create=0
do_edit=0
do_rebuild=auto
do_cat=0
do_status=0
branches_to_add=
need_rebuild=0

total_argc=$#
while test $# != 0
do
	case "$1" in
	--create)
		do_create=1
		need_rebuild=1
		;;
	--edit)
		do_edit=1
		need_rebuild=1
		;;
	--rebuild)
		do_rebuild=1
		;;
	--no-rebuild)
		do_rebuild=0
		;;
	--cat)
		do_cat=1
		;;
	--status)
		do_status=1
		;;
	--abort|--continue)
		test -z "$action" || usage
		test $total_argc -eq 2 || usage
		action=${1##--}
		;;
	--add)
		shift
		branches_to_add="$branches_to_add$1$LF"
		need_rebuild=1
		;;
	--autocontinue)
		autocontinue=true
		;;
	--no-autocontinue)
		autocontinue=false
		;;
	--prefix)
		shift
		branch_prefix=$1
		;;
	--version)
		print_version
		exit
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
	test $do_cat != 1 &&
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

if test -n "$branches_to_add"
then
	ORIG_IFS=$IFS
	IFS=$LF
	for branch in $branches_to_add
	do
		branch="$branch_prefix$branch"
		git rev-parse --quiet --verify "$branch^{commit}" >/dev/null ||
		die "not a valid commit: $branch"
	done
	IFS=$ORIG_IFS
fi

test $do_create = 1 ||
test $do_edit = 1 ||
test $do_rebuild = 1 ||
test $do_cat = 1 ||
test -n "$branches_to_add" || do_status=1

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

	integration_create "$branch" "$base" || exit
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
	integration_edit "$branch" $do_edit "$branches_to_add" || exit
fi

if test $do_cat = 1
then
	git cat-file blob "$(integration_ref "$branch"):GIT-INTEGRATION-INSN" || exit
fi

if test $do_rebuild = auto && test $need_rebuild = 1
then
	test "$(git config --bool --get integration.autorebuild)" = true &&
	do_rebuild=1
fi

if test $do_rebuild = 1
then
	integration_rebuild "$branch" || exit
fi

if test $do_status = 1
then
	integration_status "$branch"
fi
