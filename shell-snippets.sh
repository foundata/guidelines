#!/usr/bin/env sh
#
# Shell snippets: often needed / common actions ready for copy & paste.
#
# Please note:
# - All simple command snippets should be POSIX compatible (beside calling
#   external non-POSIX-commands like curl/wget)
# - Functions may rely on other functions from shell-boilerplate.sh
#
# SPDX-FileCopyrightText: 2026, foundata GmbH (https://foundata.com)
# SPDX-License-Identifier: GPL-3.0-or-later

################################################################################
# Variables and string handling
################################################################################

# Case conversion
foo="$(printf '%s' "${foo}" | tr '[:upper:]' '[:lower:]')"                   # to lower case
foo="$(printf '%s' "${foo}" | tr '[:lower:]' '[:upper:]')"                   # to upper case
foo="$(printf '%s' "${foo}" | tr '[:upper:][:lower:]' '[:lower:][:upper:]')" # swap case

# Trim leading and trailing whitespace
foo="$(printf '%s' "${foo}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

# Remove duplicate lines (if not empty or #comment)
awk '/^[[:space:]]*$/ || /^[[:space:]]*#/ || !seen[$0]++' '/etc/hosts'

# Remove duplicate lines (if not empty or #comment), squeeze multiple blank lines into one
awk '/^[[:space:]]*$/{if(!b)print;b=1;next}{b=0}/^[[:space:]]*#/{print;next}!seen[$0]++' '/etc/hosts'

# Length of string: ${#var}
foo='acb123üäß'
printf 'the string "%s" is %d chars long.\n' "${foo}" "${#foo}"

# Count list items (NF=number of fields, includes edge cases like one or zero correctly)
foo_list='bar,baz'
foo_itemcount="$(printf '%s\n' "${foo_list}" | awk -F',' '{print NF}')"
printf 'foo_list contains %d items.\n' "${foo_itemcount}"

# Strip NUL bytes
foo="$(printf '%s' "${foo}" | tr -d '\000')"

# Strip NUL bytes + shell-dangerous chars
foo="$(printf '%s' "${foo}" | tr -d '\000\\[]!#&()|;<>^`{}$"'"'")"

# Read user input (preserves whitespace and backslashes)
IFS= read -r foo

# Search and replace (static values)
foo="$(printf '%s' "${foo}" | sed 's/search/replace/g')"

# Search and replace with variables (awk avoids security pitfalls and regex escaping hell)
search='needle'
replace='blabla'
foo="$(printf '%s' "${foo}" | awk -v s="${search}" -v r="${replace}" '{gsub(s,r)}1')"

################################################################################
# Environment
################################################################################

###
# Get the effective (current) user's home directory. ${HOME} is not reliable or
# unset in many environments (e.g. Amazon Linux).
# Arguments:
#   -l - Get login (original) user's home instead of effective user's.
# Outputs:
#   Home directory path to STDOUT.
# Returns:
#   0 if found, 1 if not.
get_home() {
  local _username=''
  if [ "${1:-}" = '-l' ]; then
    # original (logname and who are reading utmp data)
    _username="$(logname 2>/dev/null)" || _username="$(who -m 2>/dev/null | awk '{print $1}')"
  else
    # effective
    _username="${_username:-$(id -un)}" || return 1
  fi

  # get home
  if command -v getent >/dev/null 2>&1; then # works with LDAP/NIS/SSSD
    getent passwd "${_username}" 2>/dev/null | cut -d: -f6 && return 0
  fi
  awk -F: -v u="${_username}" '$1 == u { print $6; exit }' '/etc/passwd'

  # Last resort trust ${HOME}
  [ -n "${HOME:-}" ] && printf '%s\n' "${HOME}"
}

################################################################################
# Process controll
################################################################################

###
# Ensure single instance of this script.
# Arguments:
#   $1 - Must be '--' (sentinel to ensure proper invocation).
#   $@ - Original script arguments after '--'.
# Returns:
#   Exits 97 if called incorrectly (e.g. missing sentinel).
#   Exits 98 if locking mechanism failed.
#   Exits 99 if another instance is running.
ensure_single() {
  # Require '--' sentinel to ensure caller passes "${@}"
  if [ "${1:-}" != '--' ]; then
    # shellcheck disable=SC2016 # needed as literal example without expansion
    msg -e 'must be called as: ensure_single_instance -- "${@}"'
    exit 97
  fi
  shift # remove sentinel
  # flock (preferred) (using file descriptor 9)
  if check_cmd 'flock'; then
    local _lockfile="${TMPDIR:-/tmp}/${0##*/}.lock"
    exec 9>"${_lockfile}" || {
      MSG_SCRIPTNAME='1' msg -e 'Cannot create lockfile'
      exit 98
    }
    flock -n 9 || {
      MSG_SCRIPTNAME='1' msg -e "Another instance is running."
      exit 99
    }
  # lsof fallback (imperfect: false positives if editor/less has script open)
  elif check_cmd 'lsof' 'wc'; then
    # shellcheck disable=SC2312 # best effort, usage of '| true' complicated
    if [ "$(lsof -t "${0}" 2>/dev/null | wc -l)" -gt 1 ]; then
      MSG_SCRIPTNAME='1' msg -e "Another instance is running (lsof fallback; consider installing flock)"
      exit 99
    fi
  else
    MSG_SCRIPTNAME='1' msg -e 'No locking mechanism available (need flock or lsof).'
    exit 98
  fi
}

# example precaution regarding stale processes (here: clamscan): 'timeout' sends
# SIGTERM after 600m and SIGKILL after an additional 1m if needed.
timeout --kill-after='1m' '600m' clamscan

################################################################################
# User interaction
################################################################################

# read user input into the var ${foo}.
# Attention: sanitize input if needed, e.g. nullbytes
IFS= read -r foo

# prompt with default
printf 'Enter name [default]: '
IFS= read -r foo
foo="${foo:-default}"

###
# Prompt user for yes/no confirmation.
# Arguments:
#   $1 - Prompt message (optional, default: "Continue?").
# Returns:
#   0 if yes, 1 if no/other.
confirm() {
  local _prompt="${1:-Continue?}"
  local _yesexpr='^[yY].*'
  local _noexpr='^[nN].*'
  local _yeschar='y'
  local _nochar='n'
  local _answer=''
  # Get localized expressions
  if check_cmd 'locale'; then
    _yesexpr="$(locale yesexpr 2>/dev/null)" || _yesexpr='^[yY].*'
    _noexpr="$(locale noexpr 2>/dev/null)" || _noexpr='^[nN].*'
    # Extract first letter from bracket expression: ^[+1yY].* → y
    _yc="$(printf '%s' "${_yesexpr}" | sed 's/.*\[[^a-zA-Z]*\([a-zA-Z]\).*/\1/' | tr '[:upper:]' '[:lower:]')"
    _nc="$(printf '%s' "${_noexpr}" | sed 's/.*\[[^a-zA-Z]*\([a-zA-Z]\).*/\1/' | tr '[:upper:]' '[:lower:]')"
    # Only use if extraction succeeded (single char)
    [ "${#_yc}" -eq 1 ] && _yeschar="${_yc}"
    [ "${#_nc}" -eq 1 ] && _nochar="${_nc}"
  fi
  printf '%s' "${_prompt} [${_yeschar}/${_nochar}]: "
  IFS= read -r _answer
  printf '%s' "${_answer}" | grep -E -q -e "${_yesexpr}"
}

# Usage
if confirm 'Continue?'; then
  printf 'Going on...\n'
else
  printf 'Exiting...\n'
  exit 0
fi

# Ask user for a path, check if user entered usable and portable data
printf 'Please enter the target path:\n> '
require_cmd 'pathchk'
while IFS= read -r data_path; do
  if [ -n "${data_path}" ] && pathchk -p "${data_path}" 2>/dev/null; then
    break # path was valid
  fi
  printf 'Invalid, please try again:\n> '
done

################################################################################
# Files
################################################################################

# Copy a dir with rsync (not POSIX but widely available).
# --archive equals -rlptgoD (recursive, symlinks, permissions, times, group,
# owner, devices).
rsync \
  --archive \
  --verbose \
  --human-readable \
  --progress \
  --exclude='.git/' \
  --exclude='/file' \
  --exclude='dir/' \
  "/tmp/source/" "/tmp/dest/"

###
# Download a file with curl/wget fallback.
# Arguments:
#   $1 - URL to download.
#   $2 - Destination directory.
#   $3 - Filename (optional, derived from URL if omitted).
# Returns:
#   0 on success, 1 on failure.
download_file() {
  local _dl_url="${1:?download_file()\: URL required}"
  local _dl_dir="${2:?download_file()\: Destination directory required}"
  local _dl_name="${3:-$(basename "${_dl_url}" | sed 's/[^[:alnum:]_.-]/-/g')}"
  local _dl_tmpdir=''
  local _dl_dest=''

  # Create temporary directory
  _dl_tmpdir="$(mktemp -d)" || {
    'Cannot create temp directory'
    return 1
  }
  trap_stack 'push' "rm -rf '${_dl_tmpdir}'"

  # Download with curl or wget
  msg "Downloading: ${_dl_url}"
  if check_cmd 'curl'; then
    ensure curl --fail --silent --show-error --location --retry 3 --max-time 300 \
      --output "${_dl_tmpdir}/${_dl_name}" "${_dl_url}"
  elif check_cmd 'wget'; then
    ensure wget --quiet --tries=3 --timeout=60 \
      --output-document="${_dl_tmpdir}/${_dl_name}" "${_dl_url}"
  else
    MSG_SCRIPTNAME=1 msg -e 'Neither curl nor wget available'
    return 1
  fi

  # Move to destination (avoid collision)
  mkdir -p "${_dl_dir}" || {
    msg -e "Cannot create ${_dl_dir}"
    return 1
  }
  _dl_dest="${_dl_dir}/${_dl_name}"
  if [ -e "${_dl_dest}" ]; then
    _dl_base="${_dl_name%.*}"
    _dl_ext="${_dl_name##*.}"
    [ "${_dl_base}" = "${_dl_ext}" ] && _dl_ext='' # no extension
    _dl_dest="${_dl_dir}/${_dl_base}-$$.${_dl_ext:-}"
    _dl_dest="${_dl_dest%.}" # remove trailing dot if no extension
  fi

  mv "${_dl_tmpdir}/${_dl_name}" "${_dl_dest}" || {
    msg -e "Cannot move to ${_dl_dest}" >&2
    return 1
  }
  msg -s "Download stored at: ${_dl_dest}"
  rm -rf "${_dl_tmpdir}"
  trap_stack 'pop' # remove trap (cleanup done)
  return 0
}
