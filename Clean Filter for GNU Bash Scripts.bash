#!/usr/bin/env bash
#shellcheck disable=SC2034
# Comments prefixed by BASHDOC: are hints to specific GNU Bash Manual's section:
# https://www.gnu.org/software/bash/manual/

## Makes debuggers' life easier - Unofficial Bash Strict Mode
## http://redsymbol.net/articles/unofficial-bash-strict-mode/
## BASHDOC: Shell Builtin Commands - Modifying Shell Behavior - The Set Builtin
### Exit prematurely if a command's return value is not 0(with some exceptions), triggers ERR trap if available.
set -o errexit

### Trap on `ERR' is inherited by shell functions, command substitutions, and subshell environment as well
set -o errtrace

### Exit prematurely if an unset variable is expanded, causing parameter expansion failure.
set -o nounset

### Let the return value of a pipeline be the value of the last (rightmost) command to exit with a non-zero status
set -o pipefail

## Non-overridable Primitive Variables
##
## BashFAQ/How do I determine the location of my script? I want to read some config files from the same place. - Greg's Wiki
## http://mywiki.wooledge.org/BashFAQ/028
RUNTIME_SCRIPT_FILENAME="$(basename "${BASH_SOURCE[0]}")"
declare -r RUNTIME_SCRIPT_FILENAME
declare -r RUNTIME_SCRIPT_NAME="${RUNTIME_SCRIPT_FILENAME%.*}"
RUNTIME_SCRIPT_DIRECTORY="$(dirname "$(realpath --strip "${0}")")"
declare -r RUNTIME_SCRIPT_DIRECTORY
declare -r RUNTIME_SCRIPT_PATH_ABSOLUTE="${RUNTIME_SCRIPT_DIRECTORY}/${RUNTIME_SCRIPT_FILENAME}"
declare -r RUNTIME_SCRIPT_PATH_RELATIVE="${0}"
declare -r RUNTIME_COMMAND_BASE="${RUNTIME_COMMAND_BASE:-${0}}"

trap_errexit(){
	printf 'An error occurred and the script is prematurely aborted\n' 1>&2
	return 0
}; declare -fr trap_errexit; trap trap_errexit ERR

trap_exit(){
	printf 'DEBUG: %s is leaving\n' "${RUNTIME_SCRIPT_NAME}" 1>&2
	if ! rm "${temp_file}"; then
		printf '%s: %s: Error: Unable to remove temporary file\n' "${RUNTIME_SCRIPT_NAME}" "${FUNCNAME[0]}" 1>&2
		exit 1
	fi
	return 0
}; declare -fr trap_exit; trap trap_exit EXIT

check_runtime_dependencies(){
	for a_command in sed python; do
		if ! command -v "${a_command}" &>/dev/null; then
			printf 'ERROR: %s command not found.\n' "${a_command}" 1>&2
			return 1
		fi
	done
	return 0
}; declare -fr check_runtime_dependencies

## init function: program entrypoint
init(){
	printf 'DEBUG: %s called\n' "${RUNTIME_SCRIPT_NAME}" 1>&2
	if ! check_runtime_dependencies; then
		exit 1
	fi

	declare -g temp_file
	temp_file="$(mktemp --tmpdir "${RUNTIME_SCRIPT_NAME}.tmp.XXXXXX")"

	# dump current stdin to temp_file
	cat >"${temp_file}"

	# undo version injection
	# sed --in-place 's//@@VERSION@@"/' "${temp_file}"

	# enforce coding style
	SHC_PREFIX_DIR="${RUNTIME_SCRIPT_DIRECTORY}"
	# Scope of "Flexible Software Installation Specification" project
	# shellcheck disable=SC1090
	if ! source "${SHC_PREFIX_DIR}"/SOFTWARE_DIRECTORY_CONFIGURATION.source 2>/dev/null\
		|| [ ! -v SDC_CODE_FORMATTERS_DIR ]; then
		printf -- '%s: Error: Unable to acquire code formatters directory\n' "${RUNTIME_SCRIPT_NAME}" 1>&2
		exit 1
	fi

	# Scope of "Flexible Software Installation Specification" project
	# shellcheck disable=SC1090
	if ! source "${SDC_CODE_FORMATTERS_DIR}"/SOFTWARE_DIRECTORY_CONFIGURATION.source 2>/dev/null\
		|| [ ! -v SDC_BASHBEAUTIFY_DIR ]; then
		printf -- '%s: Error: Unable to acquire Bashbeautify directory\n' "${RUNTIME_SCRIPT_NAME}" 1>&2
		exit 1
	fi

	"${SDC_BASHBEAUTIFY_DIR}"/bashbeautify.py \
		--tab-str '	' \
		--tab-size 1 \
		--no-backup \
		"${temp_file}"

	# dump temp_file to stdout
	cat "${temp_file}"

	printf 'DEBUG: %s is done\n' "${RUNTIME_SCRIPT_NAME}" 1>&2
	exit 0
}; declare -fr init
init "${@}"