#!/usr/bin/env sh
#
# FIXME Script for reasons
#
# SPDX-FileCopyrightText: 2026, foundata GmbH (https://foundata.com)
# SPDX-License-Identifier: GPL-3.0-or-later

# --- BOILERPLATE START v1.0.0 ---
# Consistent environment for predictable tool and shell behavior
export PATH="${PATH:-'/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'}"
export LC_ALL='en_US.UTF-8'
set -u                                                      # no uninitialized vars
set -o 2>/dev/null | grep -Fq 'pipefail' && set +o pipefail # disable, non-POSIX

# Config msg() messages (override via environment or inline where needed)
: "${DEBUG:=0}"          # 0: No debug messages. 1: Print debug messages.
: "${MSG_TIMESTAMP:=0}"  # 0: No timestamp (TS) prefix 1: Unix TS. 2: ISO TS
: "${MSG_SCRIPTNAME:=0}" # 0: No scriptname prefix. 1: Enable scriptname prefix

# Formatting codes (ANSI if STDOUT is TTY and NO_COLOR empty; empty otherwise)
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  x1b=$(printf '\033') # escape byte (0x1b) (shown as ^[ in most editors)
  # terminfo|termcap comments for reference; alternative for ancient systems:
  # FMT_FOO="$(tput terminfo_foo 2>/dev/null || tput termcap_foo 2>/dev/null)"
  FMT_RESET="${x1b}(B${x1b}[m" # sgr0|me (G0 charset/US-ASCII, attributes reset)
  FMT_BOLD="${x1b}[1m"         # bold|md
  FMT_UL="${x1b}[4m"           # smul|us
  FMT_SO="${x1b}[7m"           # smso|so (standout, reverse video)
  FMT_RED="${x1b}[31m"         # setaf N|AF N (1=red)
  FMT_GREEN="${x1b}[32m"       # setaf N|AF N (2=green)
  FMT_YELLOW="${x1b}[33m"      # setaf N|AF N (3=yellow)
  FMT_BLUE="${x1b}[34m"        # setaf N|AF N (4=blue)
  unset x1b
else
  FMT_RESET='' FMT_BOLD='' FMT_UL='' FMT_SO='' FMT_RED='' FMT_GREEN='' FMT_YELLOW='' FMT_BLUE=''
fi
# shellcheck disable=SC2034
readonly FMT_RESET FMT_BOLD FMT_UL FMT_SO FMT_RED FMT_GREEN FMT_YELLOW FMT_BLUE

###
# Print formatted messages to STDOUT or STDERR.
# Options:
#   -e, --error     Print error message (bold red) to STDERR.
#   -w, --warning   Print warning message (bold yellow) to STDERR.
#   -s, --success   Print success message (bold green) to STDOUT.
#   -i, --info      Print info message (bold blue) to STDOUT.
#   -d, --debug     Print debug message (standout) to STDOUT (only if DEBUG=1).
# Globals:
#   DEBUG          - If 0, suppresses -d/--debug messages.
#   MSG_TIMESTAMP  - 1: Enable unix timestamp as prefix.
#                    2: Enable ISO timestamp as prefix.
#   MSG_SCRIPTNAME - 1: Enable script name as prefix.
# Arguments:
#   $1 - Optional flag (see "Options").
#   $@ - Message to print.
# Outputs:
#   Formatted message to STDOUT or STDERR depending on flag.
msg() {
  local _msg_fd='1' _msg_color='' _msg_prefix='' _msg_fmt=''
  case "${1:-}" in
    '-e' | '--error')
      _msg_fd='2'
      _msg_color="${FMT_BOLD}${FMT_RED}"
      ;;
    '-w' | '--warning')
      _msg_fd='2'
      _msg_color="${FMT_BOLD}${FMT_YELLOW}"
      ;;
    '-s' | '--success')
      _msg_fd='1'
      _msg_color="${FMT_BOLD}${FMT_GREEN}"
      ;;
    '-i' | '--info')
      _msg_fd='1'
      _msg_color="${FMT_BOLD}${FMT_BLUE}"
      ;;
    '-d' | '--dbg' | '--debug')
      [ "${DEBUG:-0}" = 0 ] && return 0
      _msg_fd='1'
      _msg_color="${FMT_SO}"
      ;;
    *) false ;;
  esac && shift
  case "${MSG_TIMESTAMP:-0}" in
    '1') _msg_prefix="[$(date '+%s')] " ;;                  # non-POSIX but widely available: %s
    '2') _msg_prefix="[$(date '+%Y-%m-%dT%H:%M:%S%z')] " ;; # non-POSIX but widely available: z
    *) ;;
  esac
  case "${MSG_SCRIPTNAME:-0}" in
    '1') _msg_prefix="[${0##*/}] ${_msg_prefix}" ;;
    *) ;;
  esac
  _msg_fmt="${_msg_color}${_msg_prefix}$*${FMT_RESET}"
  [ "${_msg_fd}" = '2' ] && printf '%s\n' "${_msg_fmt}" >&2 || printf '%s\n' "${_msg_fmt}"
}

###
# Manage cleanup commands on exit/interrupt (LIFO order).
# Globals:
#   _TRAP_STACK - Newline-separated list of commands (newest first).
#                 Modified by push/pop/run operations.
# Arguments:
#   $1      - Action: push (add to stack), pop (remove last (no execute)),
#             or run (execute all & clear).
#   $2      - Command to register (required for push).
# Returns:
#   0 on success, 1 on invalid usage.
# Example:
#   trap_stack push 'rm -rf "/tmp/mydir"'
#   trap_stack pop
#   trap_stack run
_TRAP_STACK=''
trap_stack() {
  case "${1:-}" in
    'push')
      # linebreak is needed (stack delimiter)
      _TRAP_STACK="${2:?Command required}${_TRAP_STACK:+
${_TRAP_STACK}}"
      trap 'trap_stack run' EXIT
      trap 'trap_stack run; exit 130' INT
      trap 'trap_stack run; exit 143' TERM
      ;;
    'pop')
      _TRAP_STACK="$(printf '%s\n' "${_TRAP_STACK}" | tail -n +2)"
      [ -z "${_TRAP_STACK}" ] && trap - EXIT INT TERM
      ;;
    'run')
      while [ -n "${_TRAP_STACK}" ]; do
        eval "$(printf '%s\n' "${_TRAP_STACK}" | head -n 1)" || true
        _TRAP_STACK="$(printf '%s\n' "${_TRAP_STACK}" | tail -n +2)"
      done
      trap - EXIT INT TERM
      ;;
    *)
      printf 'Usage: trap_stack push|pop|run [cmd]\n' >&2
      return 1
      ;;
  esac
}

###
# Check if commands are available.
# Options:
#   -r  Required mode: exit with error if any command is missing.
# Arguments:
#   $@ - Command names to check.
# Returns:
#   0 if all commands exist.
#   1 if any missing (or exit 1 if -r is set)
check_cmd() {
  local required=0
  [ "${1}" = "-r" ] && required=1 && shift
  for cmd; do
    command -v "${cmd}" >/dev/null 2>&1 && continue
    [ "${required}" = 1 ] || return 1
    msg -e "Required command not found: ${cmd}"
    exit 1
  done
}

###
# Run a command that should never fail. If the command fails, print an error
# and exit immediately.
# Arguments:
#   $@ - Command and arguments to execute.
# Outputs:
#   Error message to STDERR on failure.
# Returns:
#   0 on success.
#   >0 (the original exitcode of the command) on failure.
ensure() {
  local exit_code
  "$@"
  exit_code="$?"
  if [ "${exit_code}" -ne 0 ]; then
    msg -e "Command failed (exit code ${exit_code}): $*"
    exit "${exit_code}"
  fi
  return 0
}

# Convenience wrappers (see the used functions for documentation)
require_cmd() { check_cmd -r "$@"; }
# --- BOILERPLATE END v1.0.0 ---

###### FIXME additional /optional but often useful boilerplate follow

###
# Parse command line arguments.
# Globals:
#   opt_bar - Set to 1 if -b is given.
#   opt_foo - Set to value of -f argument.
# Arguments:
#   $@ - Command line arguments.
# Returns:
#   0 on success, 2 on usage error.
parse_args() {
  opt_bar='0'
  opt_foo=''

  # getopts format string: '^:' silence STDERR, 'x:' needs value, 'x' is a flag
  OPTIND='1' OPTARG='' OPT=''
  while getopts ':bf:h' OPT; do
    case "${OPT}" in
      # FIXME short desc of the flag
      'b')
        opt_bar='1'
        ;;

      # FIXME short desc of the parameter
      'f')
        opt_foo="${OPTARG}"
        if ! printf '%s' "${opt_foo}" | grep -E -q -e '^[[:digit:]]*$'; then
          opt_foo=''
          msg -w "Invalid value for '-${OPT}', ignoring it."
        fi
        ;;

      # show help
      'h')
        filename="${0##*/}"
        # <<- allows tab-indentation (stripped by the shell; no spaces). The
        # text is left unindented to avoid formatter/linter issues with mixed
        # tabs and spaces as content uses spaces for mandoc/groff formatting.
        mantext="$(
          cat <<-DELIM
.TH ${filename} 1
.SH NAME
${filename} - FIXME make things for reasons.

.SH SYNOPSIS
.B ${filename}
.PP
.BI "[-f " "foo" "]"
.B [-h]

.SH DESCRIPTION
Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren,
no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit
amet, consetetur.

.SH OPTIONS
.TP
.B -b
FIXME Long desc of the flag "-b".
.TP
.B -f foo
FIXME Long desc of parameter "-f".
.TP
.B -h
Print this help.

.SH ENVIRONMENT VARIABLES
This program uses the following environment variables:
.TP
.B FIXME
Allows the specification of a default value for FIXME.

.SH EXIT STATUS
This program returns an exit status of zero if it succeeds. Non zero
is returned in case of failure. 2 will be returned for command line
syntax errors (e.g. usage of an unknown option).

.SH AUTHOR
John "FIXME" Doe <john@example.com>
DELIM
        )"
        if check_cmd 'mandoc'; then
          printf '%s' "${mantext}" | mandoc -Tascii -man | more
        elif check_cmd 'groff'; then
          printf '%s' "${mantext}" | groff -Tascii -man | more
        else
          msg -e "Neither 'mandoc' nor 'groff' is available, cannot display help"
          exit 1
        fi
        unset filename mantext
        exit 0
        ;;

      *)
        msg -e "Unknown option '${OPTARG}' (or missing option value). Use '-h' to get usage instructions."
        exit 2
        ;;
    esac
  done
  unset opt OPTARG
  shift $((OPTIND - 1)) && OPTIND='1' # delete processed options, reset index
}

###
# Main entry point.
# Arguments:
#   $@ - Command line arguments.
main() {
  trap_stack 'push' "rm -f '${tmp_file:-}'"

  parse_args "$@"

  # FIXME Main script logic goes here
  msg "opt_bar=${opt_bar}"
  msg "opt_foo=${opt_foo}"
  msg -s 'Script executed successfully.'
}

main "$@"
