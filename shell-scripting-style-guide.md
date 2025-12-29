# Shell scripting style guide

This document defines the style for writing portable [POSIX](https://pubs.opengroup.org/onlinepubs/9799919799/) shell scripts. It aims to produce scripts that work across different shells ([`bash`](https://en.wikipedia.org/wiki/Bash_(Unix_shell)), [`dash`](https://en.wikipedia.org/wiki/Almquist_shell#Dash), [`ash`](https://en.wikipedia.org/wiki/Almquist_shell)) and operating systems while being readable and maintainable.

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [When to use shell](#when-to-use-shell)
- [File format and permission](#file-format-and-permission)
- [Shebang](#shebang)
- [Indentation](#indentation)
- [Line length](#line-length)
- [Quoting](#quoting)
- [Variables](#variables)
- [Functions](#functions)
- [Command substitution](#command-substitution)
- [Conditionals and tests](#conditionals-and-tests)
- [Output and printing](#output-and-printing)
- [Error handling](#error-handling)
- [Comments](#comments)
- [Portability](#portability)
  - [Hints](#hints)
- [Linting and automatic formatting](#linting-and-automatic-formatting)
- [Author information](#author-information)



## When to use shell<a id="when-to-use-shell"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Shell scripting is a *portable* tool when following some rules, but it is not suitable for every task and there are many pitfalls. Use shell scripts where they make sense and delegate to other languages where they struggle.


**Shell is RECOMMENDED for:**

- Short, simple scripts with straightforward logic:
  - System administration tasks like log rotation, backups, and service management.
  - Build scripts, CI/CD pipelines, and deployment automation.
  - Containerfiles
- Task that primarily involves invoking other command-line tools:
  - Top-level wrappers that set up the environment
  - Glue scripts that coordinate the execution of multiple tools.


**Shell is NOT RECOMMENDED for:**

- Data processing beyond simple text manipulation.
- Complex logic with many conditionals and nested structures.
- Tasks requiring robust error handling and recovery.
- Generating or parsing structured data formats (JSON, XML, YAML).
- Cross-platform applications where Python or similar languages would be more portable.


**You SHOULD:**

- Keep shell scripts under 1000 lines including comments. If a script grows larger, consider refactoring or using a different language.
- Prefer calling well-tested command-line tools over reimplementing their functionality in shell.
- Use a layered architecture: shell for the outer wrapper, Python (or another language) for complex logic.


**Reasoning:**

- Shell is good at orchestrating other programs but lacks features for complex programming (proper data structures, exception handling, testing frameworks).
- Shell's quoting rules, word splitting, and glob expansion create numerous pitfalls that grow with script complexity.
- Debugging and testing shell scripts is significantly harder than in languages with proper tooling.
- The same task that takes 20 lines of shell might take 10 lines of Python with better error handling and readability. But Python surely is not as portable because of package dependencies etc., especially if it comes to OCI containers.



## File format and permission<a id="file-format"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use [UTF-8 encoding](https://en.wikipedia.org/wiki/UTF-8) without a [Byte Order Mark (BOM)](https://en.wikipedia.org/wiki/Byte_order_mark).
- Use Unix line endings (LF, `\n`). Do not use Windows (CRLF) or old Mac (CR) line endings.
- End files with a single trailing newline.
- Trim trailing whitespace from lines.
- Never use [SUID or SGID permissions](https://en.wikipedia.org/wiki/Setuid) on shell scripts (security risk). Use `sudo` to provide elevated access if needed.


**Reasoning:**

- Unix shells expect LF line endings. [CRLF can cause subtle bugs or syntax errors](https://www.shellcheck.net/wiki/SC1017#rationale).
- BOMs interfere with the [shebang (`#!`)](#shebang) mechanism and can cause scripts to fail silently.
- [Trailing newlines are a POSIX requirement](https://stackoverflow.com/a/729795) and prevent issues when concatenating files or reading the last line.
- UTF-8 is the universal standard for text encoding and is expected by modern systems.
- SUID/SGID on shell scripts is a security vulnerability: most systems ignore these bits on scripts, and where they work, they create privilege escalation risks through environment manipulation ([`IFS`](https://en.wikipedia.org/wiki/Input_Field_Separators), `PATH`, [`LD_PRELOAD`](https://stackoverflow.com/questions/426230/what-is-the-ld-preload-trick#comment250014_426260)).


**File extensions and permissions:**

| Type | Extension | Executable | Notes |
|------|-----------|------------|-------|
| Executable script | `.sh` or none | Yes (`chmod +x`) | No extension if installed in `PATH` |
| Library/sourced | `.sh` | No (`chmod -x`) | Only sourced, never executed directly |

Library files should not have execute permission to prevent accidental direct execution and to clearly indicate their purpose.



## Shebang<a id="shebang"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Start every script with a [shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)) on the first line.
- Use `#!/usr/bin/env sh` as the default shebang for POSIX-compliant scripts.
- Use `#!/usr/bin/env bash` only when Bash-specific features are required.


**You SHOULD:**

- Document why Bash is required if using the Bash shebang.


**Good examples:**

```sh
#!/usr/bin/env sh
# This is a very cool script

#!/usr/bin/env bash
# Bash required for: associative arrays
#
# This is a very cool script
```


**Bad examples:**

```sh
#!/bin/sh
# Not portable: /bin/sh location varies across systems

#!/bin/bash
# Not portable: bash location varies across systems

#! /usr/bin/env sh
# Space after #! can cause issues on some systems
```


**Reasoning:**

- Using `env` ensures the script finds the interpreter in the user's `PATH`, making it portable across systems where shell locations differ (e.g., `/bin/sh` vs `/usr/bin/sh`).
- The `sh` interpreter provides maximum portability when writing POSIX-compliant scripts.
- Explicitly requiring Bash should be a conscious decision, documented for future maintainers.
- Tangential note (not a shebang issue): some environments bypass or ignore `env(1)` entirely (e.g., [Ansible's `shell` module](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/shell_module.html) with [`args: executable:`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html#parameter-executable)). In such cases, fall back to the most widespread direct paths: `/bin/sh`, `/bin/bash`.




## Indentation<a id="indentation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use 2 (two) spaces for each indentation level. Do not use tabs.
  - Exception: using tabs is for the body of `<<-` tab-indented here-document.
  - Exception: Be consistent and use 4 spaces if an established project of us is using it. Open an dedicated issue for reformatting if so.
- Use consistent indentation throughout the script.
- Indent the bodies of `if`, `for`, `while`, `case`, and function blocks.


**You SHOULD:**

- Place `then`, `do` on the same line as `if`, `for`, `while` (separated by `;` or after a newline for multi-line conditions).
- Indent `case` pattern bodies.


**Good examples:**

```sh
# 2 spaces per indentation level
if [ -f "${config_file}" ]; then
  process_config "${config_file}"
fi

# Multi-line conditions (operator at start of continuation line)
if [ -n "${foo}" ] \
  || [ -n "${bar}" ]; then
  printf '%s\n' 'At least one is set'
fi

# Case statement with indented bodies
case "${option}" in
  start)
    start_service
    ;;
  stop)
    stop_service
    ;;
  *)
    printf '%s\n' 'Unknown option' >&2
    exit 1
    ;;
esac

# Nested blocks
for file in '/file1' '/foo/file2' './file-3'; do
  if [ -r "${file}" ]; then
    process_file "${file}"
  fi
done
```


**Bad examples:**

```sh
# Using tabs
if [ -f "${config_file}" ]; then
»	process_config "${config_file}"  # tab character
fi

# Inconsistent indentation
if [ -f "${config_file}" ]
then
··process_config "${config_file}"  # 2 spaces
····validate_config                # 4 spaces
fi

# No indentation
if [ -f "${config_file}" ]
then
process_config "${config_file}"
fi
```


**Reasoning:**

- Spaces ensure consistent display across all editors and terminals regardless of tab width settings.
- Using two spaces aligns us with the broader shell and container ecosystem (cf. [Google](https://google.github.io/styleguide/shellguide.html#s5.1-indentation), [Kubernetes](https://www.kubernetes.dev/docs/guide/coding-convention/), [Bash Hacker's Wiki](https://web.archive.org/web/20220512181003/https://wiki.bash-hackers.org/scripting/style)) and provides a good enough visual hierarchy as most shell scripts should not have deeply nesting logic.



## Line length<a id="line-length"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Keep lines under 120 characters whenever technically possible.
- Break long pipelines before the pipe character (`|`), with the continuation indented.
- Break long logical expressions before the operator (`&&`, `||`), with the continuation indented.


**You SHOULD:**

- Keep lines under 80 characters when possible.
- Use backslash (`\`) continuation for long commands that are not pipelines.


**Good examples:**

```sh
# Breaking a long command with backslash
curl --silent --location --retry 3 \
  --output "${download_dir}/${filename}" \
  "${download_url}"

# Breaking a pipeline: pipe at start of continuation line
find "${source_dir}" -type f -name '*.txt' \
  | grep -v 'backup' \
  | sort \
  | head -n 10

# Complex pipeline with clear structure
cat "${input_file}" \
  | grep -E '^[0-9]+' \
  | awk '{ sum += $1 } END { print sum }' \
  | tee "${output_file}"

# Breaking logical expressions: operator at start of continuation line
if [ -f "${config_file}" ] \
  && [ -r "${config_file}" ] \
  && [ -s "${config_file}" ]; then
  process_config "${config_file}"
fi

# Multi-line string without unwanted whitespace
printf '%s\n' 'This is a single parameter '\
'because there is no space before the backslash'
```


**Bad examples:**

```sh
# Excessively long line
curl --silent --location --retry 3 --output "${download_dir}/${filename}" --connect-timeout 30 --max-time 300 "${download_url}"

# Operator at end of line
find "${source_dir}" -type f -name '*.txt' |
  grep -v 'backup' |
  sort

# Backslash with space after it (causes syntax error)
curl --silent \·
  --location
```


**Reasoning:**

- Shorter lines are easier to read, especially in side-by-side diffs or on smaller screens.
- Placing operators at the start of continuation lines improves readability by making the logical structure immediately visible when scanning the left edge of the code.



## Quoting<a id="quoting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Quote all variable expansions: `"${variable}"`, not `$variable`.
- Quote all command arguments that could contain spaces or special characters.
- Use double quotes when variable expansion is needed.
- Use single quotes when literal strings are needed (no expansion).
- Correctly escape identical quotes within quotes (use `'\''` and `"\""`, not `\'` or `\"`)


**You SHOULD:**

- Prefer single quotes for static strings to prevent accidental expansion.
- Use double quotes for strings containing variables or command substitutions.
- Mix quotes when it prevents [complicated escaping](https://www.grymoire.com/Unix/Quote.html#uh-8).
- Always quote variables in test expressions: `[ -n "${var}" ]`.
- Quote all command arguments.


**You MUST NOT:**

- Use unquoted variables in command arguments (except in specific contexts like `for item in ${list}`).


**Good examples:**

```sh
# 'Single' quotes indicate that no substitution is desired.
# "Double" quotes indicate that substitution is required/tolerated.

# Variable expansion with double quotes
config_path="/etc/${app_name}.conf"
printf '%s is not supported.\n' "${operating_system}"
result="$(cat "${input_file}")"

# Static strings with single quotes
readonly log_level='info'
rm -f '/tmp/cache.tmp'

# Variables in test expressions
if [ -n "${username}" ]; then
  printf '%s\n' "Hello, ${username}"
fi

# Mixed quoting to prevent complicated escaping
printf '%s\n' "it's working"
```


**Bad examples:**

```sh
# Missing braces around variable names
config_path="/etc/$app_name.conf"    # Ambiguous: is it $app_name or $app?

# Unquoted variables
rm -f $filepath                       # Breaks on spaces, glob expansion
cat $input_file                       # Word splitting issues

# Double quotes for static strings (unnecessary)
readonly log_level="info"             # Single quotes preferred

# Unquoted variable in test
[ -n ${var} ]                         # Breaks if var is empty or unset

# Missing quotes in command substitution argument
result="$(cat ${input_file})"         # Should be "${input_file}"

# Needless escaping single quotes within single-quoted strings
printf '%s\n' 'it'\''s working'

# Does only work in Bash
printf '%s\n' "The word for today is \"Foo\""

# Does not work in any shell
printf '%s\n' 'it\'s working'

# Technically working but complicated escaping. Prevent if possible.
printf '%s\n' 'This "is" correct and it'\''s working' # even breaks some syntax highlighters
printf '%s\n' "This "\""is"\"" correct and it's working"
printf '%s\n' "The word for today is "\"Foo\"   # these are...
printf '%s\n' "The word for today is "\""Foo"\" # ...the same
```


**Reasoning:**

- Quoting prevents word splitting and glob expansion, which are common sources of bugs and security vulnerabilities.
- Braces (`${var}`) around variable names prevent ambiguity in string interpolation.
- Single quotes are safer for static strings as they prevent any form of expansion.
- Proper quoting is essential for handling filenames with spaces and special characters.
- Unquoted variables in test expressions can cause syntax errors or unexpected behavior when empty.
- [Escaping / including identical quotes within quotes in shell](https://www.grymoire.com/Unix/Quote.html#uh-8) is not working as expected for programmers used to other languages.



## Variables<a id="variables"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use lowercase with underscores for local variables: `my_variable`.
- Use UPPERCASE for exported environment variables: `MY_ENV_VAR`.
- Use UPPERCASE for constants (`readonly` / `local -r`): `MY_ENV_VAR`.
- Always wrap variable names in braces: `${variable}`, not `$variable`.
- Quote variable assignments: `foo='bar'` or `bar="${baz}"`.
- Use `set -u` and initialize variables before use.
- Declare and assign separately when assigning a command substitution with an independent return value to avoid masking return values:
  ```sh
  FOO="$(mycmd)"
  export FOO

  local CONFIG_FILE
  CONFIG_FILE='/etc/foobar'
  readonly CONFIG_FILE

  local bar='baz'
  ```


**You SHOULD:**

- Use `readonly` for constants and configuration values.
- Use `local` for function-local variables (note: not POSIX, but widely supported).
- Use meaningful, descriptive variable names.


**You MUST NOT:**

- Use UPPERCASE for local script variables (avoid accidental conflicts with environment variables such as `PATH`, `HOME`, `USER`).


**Good examples:**

```sh
# Local variables: lowercase with underscores
log_level='info'
user_count="${1:-0}"

# Exported variables: UPPERCASE
export MY_APP_DEBUG='true'
export DATABASE_URL="${db_host}:${db_port}"

# Always use braces
message="${greeting}, ${user_name}!"

# Using readonly and UPPERCASE for constants
readonly CFG_WORKINGDIR="/tmp"


# Declare and assign in the same line is OK here because the values are literals
# and not a command substitution with an independent return value.
export FOOBAR='baz'
readonly CONFIG_FILE='/etc/myapp.conf'

# Declare and assign separately when assigning a command substitution
FOO="$(mycmd)"
export FOO
readonly FOO

local bar
bar="$(mycmd)"
readonly bar

# Check if variable is set (compatible with set -u)
if [ -z "${CONFIG_PATH:-}" ]; then
  printf '%s\n' 'CONFIG_PATH is not set' >&2
fi
```


**Bad examples:**

```sh
# UPPERCASE for local variables (risky)
HOME='/custom/path'      # Overwrites system HOME!
USER='admin'             # Overwrites current user variable

# Missing braces
message="$greeting, $user_name!"  # Ambiguous

# Unquoted assignment
foo=bar                  # Works, but inconsistent with other assignments

# Missing braces causes wrong interpolation
file="$name_backup.txt"  # Tries to expand $name_backup, not $name

# Return value of mycmd is ignored, export/local will always return true.
# This may prevent conditionals and traps from working correctly.
export FOO="$(mycmd)"
local bar="$(mycmd)"
```


**Reasoning:**

- The lowercase/UPPERCASE convention is a well-established practice that prevents accidental overwriting of important environment variables.
- Braces eliminate ambiguity when concatenating variables with other text.
- Quoting assignments is technically optional in most cases, but consistent quoting prevents edge-case bugs and improves readability.
- Using `${var:-}` allows checking for unset variables even with `set -u` enabled.
- Since `local` is widely supported (`bash`, `dash`, `ash`, `zsh`, FreeBSD `sh`) and `ksh` compatibility is rarely required, using `local` is acceptable for most use cases. Document the limitation if `ksh` support is needed.
- Combining declaration and assignment (`export foo="$(cmd)"` or `local foo="$(cmd)"`) masks the command's return value because `export`/`local` always return true, breaking error handling via conditionals, `set -e`, and traps (cf. [SC2155](https://www.shellcheck.net/wiki/SC2155)).



## Functions<a id="functions"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use lowercase with underscores for function names: `my_function`.
- Define functions *without* the `function` keyword (it is a non-portable Bashism).
- Use parentheses without spaces after the function name: `my_function() { ... }`.
- Separate libraries with `::`: `my_library::my_function() { ... }`.

**You SHOULD:**

- Group `local` variable declarations at the beginning of functions.
- Return explicit exit codes from functions.
- Use a `main` function for scripts with multiple functions, called as `main "$@"` at the end of the file.


**Good examples:**

```sh
###
# Process a configuration file and validate its contents.
# Arguments:
#   $1 - Path to the configuration file.
#   $2 - Expected configuration version (optional, default: "1.0").
# Returns:
#   0 if successful, 1 if file not found, 2 if validation fails.
process_config() {
  local config_path="${1}"
  local expected_version="${2:-1.0}"

  if [ ! -f "${config_path}" ]; then
    printf '%s\n' "Error: Config file not found: ${config_path}" >&2
    return 1
  fi

  # Validate configuration
  if ! validate_config "${config_path}" "${expected_version}"; then
    return 2
  fi

  return 0
}


###
# Print a formatted error message to STDERR.
# Arguments:
#   $1 - The error message to display.
# Outputs:
#   Writes error message to STDERR.
print_error() {
  printf '%s: %s\n' "Error" "${1}" >&2
  return 0
}


###
# Main entry point.
# Arguments:
#   $@ - Command-line arguments.
main() {
  if [ "$#" -lt 1 ]; then
    print_error "Missing required argument"
    exit 2
  fi

  process_config "${1}"
}

# Call main at the end of the script
main "$@"
```

The `main` pattern keeps execution flow clear, allows functions to be defined in logical order, and enables sourcing the script without executing it (for testing or library use):

```sh
# Source without executing (main is not called when sourced)
(return 0 2>/dev/null) && sourced='1' || sourced='0'
if [ "${sourced}" -eq 0 ]; then
  main "$@"
fi
```


**Bad examples:**

```sh
# Using function keyword (Bashism)
function process_config() {
  printf '%s\n' 'Processing...'
}

# Missing documentation
process_config() {
  local config_path="${1}"
  # What does this function do? What are the parameters?
}

# No space before brace, inconsistent style
process_config(){
printf '%s\n' 'Processing...'
}
```

**Reasoning:**

- The `function` keyword is a Bash extension not available in POSIX shells like dash.
- Explicit return codes make error handling predictable and testable.
- The `local` keyword is not POSIX but is widely supported (bash, dash, ash, zsh). For maximum portability with ksh, group variable declarations visibly so they can be easily converted.



## Command substitution<a id="command-substitution"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `$(command)` syntax for command substitution.
- Never use backticks (`` `command` ``) for command substitution.


**You SHOULD:**

- Quote command substitutions when assigning to variables: `var="$(command)"`.
- Nest command substitutions when needed (easy with `$()` syntax).


**Good examples:**

```sh
# Modern command substitution syntax
current_date="$(date '+%Y-%m-%d')"
file_count="$(find "${dir}" -type f | wc -l)"

# Nested command substitution
backup_name="$(basename "$(dirname "${path}")")"

# Command substitution in conditionals
if [ "$(id -u)" -ne 0 ]; then
  printf '%s\n' 'This script requires root privileges.' >&2
  exit 1
fi
```


**Bad examples:**

```sh
# Backticks (deprecated, hard to nest, hard to read)
current_date=`date '+%Y-%m-%d'`
file_count=`find "${dir}" -type f | wc -l`

# Nested backticks (very confusing)
backup_name=`basename \`dirname "${path}"\``
```


**Reasoning:**

- The `$()` syntax is POSIX-compliant and supported by all modern shells.
- The `$()` syntax is more readable and easier to nest.
- Backticks are a legacy syntax from the Bourne shell era and require complex escaping for nesting.



## Conditionals and tests<a id="conditionals"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `[ ]` (single brackets) for test expressions, not `[[ ]]` (double brackets are a Bashism).
- Use `=` for string equality, not `==` (the latter is a Bashism in `[ ]`).
- Quote all variables in test expressions.


**You SHOULD:**

- Use `-z` to test for empty strings and `-n` for non-empty strings.
- Use `&&` and `||` outside the brackets for compound conditions.
- Use `grep` for pattern matching instead of `[[ =~ ]]`.


**Good examples:**

```sh
# String comparisons
if [ "${answer}" = 'yes' ]; then
  printf '%s\n' 'Confirmed'
fi

# Testing for empty/non-empty strings
if [ -z "${username}" ]; then
  printf '%s\n' 'Username is required' >&2
  exit 1
fi

if [ -n "${verbose}" ]; then
  printf '%s\n' 'Verbose mode enabled'
fi

# File tests
if [ -f "${config_file}" ] && [ -r "${config_file}" ]; then
  . "${config_file}"
fi

# Numeric comparisons
if [ "${count}" -gt 10 ]; then
  printf '%s\n' 'Count exceeds limit'
fi

# Pattern matching with grep (POSIX-compliant)
if printf '%s' "${input}" | grep -E -q '^[0-9]+$'; then
  printf '%s\n' 'Input is a number'
fi

# Substring check with grep
if printf '%s' "${haystack}" | grep -F -q 'needle'; then
  printf '%s\n' 'Found needle in haystack'
fi
```


**Bad examples:**

```sh
# Double brackets (Bashism)
if [[ "${answer}" == 'yes' ]]; then
  printf '%s\n' 'Confirmed'
fi

# Using == in single brackets (Bashism in test)
if [ "${answer}" == 'yes' ]; then
  printf '%s\n' 'Confirmed'
fi

# Regex in double brackets (Bashism)
if [[ "${input}" =~ ^[0-9]+$ ]]; then
  printf '%s\n' 'Input is a number'
fi

# Unquoted variable in test (dangerous)
if [ -n ${var} ]; then    # Breaks if var is empty
  printf '%s\n' 'var is set'
fi

# Comparing against empty string (prefer -z)
if [ "${var}" = '' ]; then
  printf '%s\n' 'var is empty'
fi
```


**Common test operators:**

| Operator | Description |
|----------|-------------|
| `-z STRING` | True if string is empty (zero length) |
| `-n STRING` | True if string is not empty (non-zero length) |
| `STR1 = STR2` | True if strings are equal |
| `STR1 != STR2` | True if strings are not equal |
| `-f FILE` | True if file exists and is a regular file |
| `-d FILE` | True if file exists and is a directory |
| `-r FILE` | True if file exists and is readable |
| `-w FILE` | True if file exists and is writable |
| `-x FILE` | True if file exists and is executable |
| `-s FILE` | True if file exists and has size > 0 |
| `-L FILE` | True if file exists and is a symbolic link |
| `INT1 -eq INT2` | True if integers are equal |
| `INT1 -ne INT2` | True if integers are not equal |
| `INT1 -lt INT2` | True if INT1 < INT2 |
| `INT1 -le INT2` | True if INT1 <= INT2 |
| `INT1 -gt INT2` | True if INT1 > INT2 |
| `INT1 -ge INT2` | True if INT1 >= INT2 |


**POSIX character classes for `grep`, `sed`, `tr`:**

| Class | Equivalent | Description |
|-------|------------|-------------|
| `[:alnum:]` | `[A-Za-z0-9]` | Letters and digits |
| `[:alpha:]` | `[A-Za-z]` | Letters |
| `[:lower:]` | `[a-z]` | Lowercase letters |
| `[:upper:]` | `[A-Z]` | Uppercase letters |
| `[:digit:]` | `[0-9]` | Digits |
| `[:xdigit:]` | `[A-Fa-f0-9]` | Hexadecimal digits |
| `[:space:]` | `[ \t\r\n\v\f]` | Whitespace characters |
| `[:blank:]` | `[ \t]` | Space and tab only |


**Reasoning:**

- The `[[ ]]` syntax is a Bash/Zsh extension not available in POSIX shells.
- Double equals (`==`) is not part of the POSIX test specification.
- Using `grep` for pattern matching is portable and often clearer than regex operators.
- Proper quoting in tests prevents word splitting and syntax errors.



## Output and printing<a id="output"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `printf` instead of `echo` for output.
- Never put variables directly in the format string: use `printf '%s\n' "${var}"`, not `printf "${var}"`.
- Write error messages to `STDERR` using `>&2`.


**You SHOULD:**

- Include a trailing newline in output: `printf 'message %s\n' 'whatever'`.
- Use format specifiers appropriately: `%s` for strings, `%d` for integers.


**Good examples:**

```sh
# Basic output with printf
printf '%s\n' 'Starting process...'

# Output with variables (safe)
printf '%s\n' "${message}"
printf 'User: %s, ID: %d\n' "${username}" "${user_id}"

# Error output to STDERR
printf '%s: %s\n' 'Error' 'File not found' >&2

# Multi-line output
printf '%s\n' 'Line 1' 'Line 2' 'Line 3'

# Formatted output
printf '%-20s %10d\n' 'Total files:' "${file_count}"
```


**Bad examples:**

```sh
# Using echo (behavior varies across implementations)
echo 'Starting process...'
echo -e 'Tab:\there'       # -e not portable
echo -n 'No newline'       # -n not portable

# Variable in format string (format string vulnerability)
printf "${user_input}"     # DANGEROUS: user can inject format specifiers

# Missing error redirection
printf '%s\n' 'Error: something failed'  # Should go to STDERR
```


**Reasoning:**

- The behavior of `echo` varies significantly across implementations (handling of `-e`, `-n`, backslash escapes). POSIX does not define the behavior when the first argument starts with `-` or contains backslashes.
- `printf` is consistent and well-defined across all POSIX shells.
- Putting variables in the format string creates a format string vulnerability where special characters like `%s` or `%n` in the input could cause unexpected behavior or crashes.
- Error messages should go to STDERR so they can be handled separately from normal output.



## Error handling<a id="error-handling"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `set -u` to treat unset variables as errors.
- Use exit code 2 for command-line syntax errors (following Unix convention).
- Write error messages to `STDERR` using `>&2`.


**You SHOULD:**
- Check command exit status explicitly for important operations.
- Provide meaningful error messages that include the script name.
- Use `trap` for cleanup operations.


**You SHOULD NOT:**

- Use `set -e` (it has many edge cases and can cause unexpected behavior).
- Use `set -a` (allexport) globally; if needed, use it locally and reset immediately.


**Error logging function:**

For long-running scripts or daemons, include a timestamp in error messages:

```sh
###
# Print a timestamped error message to STDERR.
# Arguments:
#   $@ - The error message components.
# Outputs:
#   Writes timestamped error message to STDERR.
err() {
  printf '[%s]: %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$*" >&2
}

# Usage
err "Failed to connect to database"
# Output: [2024-01-15T14:30:22+0100]: Failed to connect to database
```


**Good examples:**

```sh
#!/usr/bin/env sh
set -u  # Error on unset variables

# Explicit error handling
if ! mkdir -p "${output_dir}"; then
  printf '%s: Failed to create directory: %s\n' "$(basename "${0}")" "${output_dir}" >&2
  exit 1
fi

# Check command success with meaningful message
if ! curl --silent --fail --output "${output_file}" "${url}"; then
  printf '%s: Download failed: %s\n' "$(basename "${0}")" "${url}" >&2
  exit 1
fi

# Using exit code 2 for usage errors
if [ "$#" -lt 1 ]; then
  printf 'Usage: %s <input_file>\n' "$(basename "${0}")" >&2
  exit 2
fi

# Cleanup on exit using trap
cleanup() {
  rm -f "${temp_file:-}"
}
trap cleanup EXIT

# Handle pipeline failures explicitly (POSIX-compliant way)
if ! grep 'pattern' file.txt | sort > output.txt; then
  # Note: This only checks if 'sort' succeeded
  # For the grep exit status, use a temporary variable or file
  :
fi

# More reliable pipeline error handling
grep 'pattern' file.txt > temp.txt
grep_status="$?"
if [ "${grep_status}" -gt 1 ]; then
  # grep returns 1 for "no matches", 2+ for errors
  printf '%s\n' 'grep failed' >&2
  exit 1
fi
sort temp.txt > output.txt || exit 1
```


**Reasoning:**

- `set -u` catches typos in variable names and prevents silent failures from unset variables.
- Exit code 2 is the Unix convention for syntax errors (used by shell builtins and most utilities).
- Trap handlers ensure cleanup happens even when the script is interrupted.
- `set -e` has [numerous gotchas](http://mywiki.wooledge.org/BashFAQ/105):
  - Does not trigger in command substitutions: `var=$(false); echo "still runs"`.
  - Does not trigger in pipelines (only checks last command): `false | true` succeeds.
  - Disabled in `if`, `while`, `until` conditions, and `&&`/`||` lists.
  - Behavior varies between shells and shell versions.
  - If you still want to use `set -e`, be aware of these limitations and combine it with explicit error handling for critical operations. When Bash is required and you choose to use `set -e` (for whatever reason), these additional options help:
    ```bash
    #!/usr/bin/env bash
    set -e           # Exit on error
    set -u           # Error on unset variables
    set -o pipefail  # Pipeline fails if any command fails (Bash-specific)
    shopt -s inherit_errexit  # Preserve set -e in command substitutions (Bash 4.4+)
    ```
    Note: `pipefail` and `inherit_errexit` are Bash-specific and not POSIX-compliant.
- `set -a` exports all subsequently defined variables to the environment, which can pollute child processes and cause unexpected behavior.



## Comments<a id="comments"></a>

**You MUST:**

- Start each file with a description of its contents.
- Write comments and documentation in US English.
- Document functions with a comment block (omit sections that don't apply):
  1. Short and simple description of the function.
  2. Globals: List of global variables used and/or modified.
  3. Arguments: Arguments taken (use None if no args).
  4. Outputs: Describing output to STDOUT and/or STDERR.
  5. Returns: Returned values other than the default exit status of the last command run.



**You SHOULD:**

- Use sentence case for comments (capitalize the first word only, unless proper nouns are involved).
- Write comments that explain "why", not "what" (the code shows what).


**Good examples:**

```sh
#!/usr/bin/env sh
#
# Perform a full backup of the Zammad ticketing system database.

###
# Remove temporary files from the build directory.
# Globals:
#   BUILD_DIR
#   VERBOSE
# Arguments:
#   None
cleanup_build() {
  rm -rf "${BUILD_DIR}/tmp"
}

###
# Remove a file with validation.
# Arguments:
#   $1 - Path to the file to delete.
# Returns:
#   0 if file was deleted, 1 if file does not exist, 2 on permission error.
remove_file() {
  local file_path="${1}"

  if [ ! -e "${file_path}" ]; then
    return 1
  fi

  rm "${file_path}" || return 2
}

###
# Retrieve the application configuration directory path.
# Globals:
#   APP_HOME
# Arguments:
#   None
# Outputs:
#   Writes directory path to STDOUT.
get_config_dir() {
  printf '%s\n' "${APP_HOME}/config"
}
```


**Style recommendations:**

| Rule | Good Example | Bad Example |
|------|--------------|-------------|
| Use active voice | The script creates a backup | A backup is created by the script |
| Use present tense | This function returns | This function will return |
| Use American English | The color of the output | The colour of the output |


**Reasoning:**

- English is the lingua franca of software development.
- Consistent style makes documentation easier to read and maintain.
- Comments explaining "why" remain valuable even when code changes.
- Documentation blocks help maintainers understand the code without reading the implementation. The format follows [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html).



## Portability<a id="portability"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Target POSIX-compliant shells (`sh`, `dash`, `bash`, `ash`).
- Check for command availability before using non-standard utilities.
- Use `./*` instead of bare `*` when passing glob results to commands that interpret leading dashes as options.


**You SHOULD:**

- Use only POSIX-defined utilities and their POSIX-defined options when possible.
- Set `LC_ALL` to get predictable behavior:
  ```sh
  LC_ALL='en_US.UTF-8'
  ```
  Do so until your script explicitly has to follow a system's localization.
- Test scripts with `dash` during development (it is stricter about POSIX compliance).
- Avoid GNU-specific options (long options like `--verbose` are often not portable even if they are improving readability).
- Document any required non-POSIX features or tools.


**Reasoning:**

- `dash` is a minimal POSIX shell that catches many Bashisms during development.
- POSIX compliance ensures scripts work across Linux distributions (`bash`, `dash`, `ash`), macOS (usually a very old Bash 3.2 or `zsh`), and BSDs (`ash`-based `sh` or `ksh`).
- GNU long options (`--option`) are convenient but not available on BSD systems (including macOS) without GNU coreutils.
- Using `command -v` is the POSIX-compliant way to check for command availability (preferred over `which`, `hash`, or `type`).
- Safe glob expansion is needed as filenames can start with a hyphen (e.g., `-rf`), which commands may interpret as options. Using `./*` prevents this:
  ```sh
  # Bad - fails if a file is named "-rf" or "--help"
  rm *
  cat *

  # Good - ./ prefix prevents interpretation as options
  rm ./*
  cat ./*

  # Also works with loops
  for file in ./*; do
      process_file "${file}"
  done
  ```
- Setting `LC_ALL` ensures predictable sorting, character classification, and text processing. Without explicit [locale](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/locale.html) settings, script behavior may vary between systems. `LC_ALL` overrides all other locale variables (`LANG` and individual `LC_*` settings), so it alone is sufficient.



### Hints

**Checking for required commands:**

```sh
# Check if required command is available
if ! command -v 'jq' > /dev/null 2>&1; then
  printf '%s: %s\n' 'Error' 'jq is required but not installed' >&2
  exit 1
fi

# Check multiple commands
for cmd in 'curl' 'jq' 'openssl'; do
  if ! command -v "${cmd}" > /dev/null 2>&1; then
    printf '%s: "%s" is required but not installed.\n' 'Error' "${cmd}" >&2
    exit 1
  fi
done

# Check using our boilerplate (FIXME see ...)
## FIXME
```


**Basic local testing with alternate shells:**

```sh
sudo dnf install dash busybox oksh

# Test script.sh syntax with multiple shells
for shell in dash sh bash oksh; do
  if command -v "${shell}" >/dev/null 2>&1; then
    printf 'Syntax check with %s: ' "${shell}"
    if "${shell}" -n ./script.sh 2>&1; then
      printf 'OK\n'
    else
      printf 'FAILED\n'
    fi
  fi
done
```

**POSIX-compliant utilities:**

Common POSIX utilities that can be relied upon (see [Open Group Base Specifications, IEEE Std 1003.1-2017: Shell & Utilities](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html): [4. Utilities](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap04.html)): `awk`, `basename`, `cat`, `chmod`, `chown`, `compress`, `cp`, `cut`, `date`, `dirname`, `env`, `expr`, `find`, `grep`, `head`, `id`, `kill`, `ln`, `ls`, `mkdir`, `mkfifo`, `mv`, `od`, `paste`, `printf`, `pwd`, `read`, `rm`, `rmdir`, `sed`, `sleep`, `sort`, `tail`, `tee`, `test`, `touch`, `tr`, `true`, `false`, `umask`, `uname`, `uncompress`, `uniq`, `wc`, `xargs`, `zcat`.



## Linting and automatic formatting<a id="linting-formatting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- On **POSIX** scripts (shebang `#!/usr/bin/env sh`):
  - Run [`shfmt`](https://github.com/mvdan/sh):
    ```sh
    shfmt --language-dialect posix --indent 2 --case-indent --binary-next-line --simplify --diff script.sh
    shfmt --language-dialect posix --indent 2 --case-indent --binary-next-line --simplify --write script.sh
    ```
  - Run [`shellcheck`](https://www.shellcheck.net/):
    ```sh
    shellcheck --shell=sh --severity=style --exclude=SC3043 script.sh
    ```
  - Run [`checkbashisms`](https://tracker.debian.org/pkg/devscripts):
    ```sh
    checkbashisms script.sh
    ```
- On **Bash** scripts (shebang `#!/usr/bin/env bash`):
  - Run [`shfmt`](https://github.com/mvdan/sh):
    ```sh
    shfmt --language-dialect bash --indent 2 --case-indent --binary-next-line --simplify --diff script.sh
    shfmt --language-dialect bash --indent 2 --case-indent --binary-next-line --simplify --write script.sh
    ```
  - Run [`shellcheck`](https://www.shellcheck.net/):
    ```sh
    shellcheck --shell=bash --severity=style script.sh
    ```
- Fix all errors and warnings. If a warning must be silenced, add a comment explaining why:
  ```sh
  # shellcheck disable=SC2034  # Variable is exported for use by sourcing script
  unused_but_exported_var='value'
  ```


**Reasoning:**

- `shfmt` eliminates style debates by providing a single, deterministic format.
- Automated tools catch errors that humans miss and enforce consistency without manual effort:
  - `shellcheck` identifies bugs, security issues, and portability problems. See the [ShellCheck Wiki](https://www.shellcheck.net/wiki/) for a complete list of checks.
  - `checkbashisms` catches many (not all) bash-specific constructs that break POSIX compatibility (note: it has some false positives and does not catch all issues).



## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust, readable, and portable shell scripts. It incorporates lessons learned from real-world cross-platform shell scripting, as well as insights drawn from several authoritative resources that served as references and sources of inspiration:

- [Google: Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [The Open Group (POSIX): Shell & Utilities — Detailed Table of Contents](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/contents.html)
- [Greg's Wiki: Bash Frequently Asked Questions](https://mywiki.wooledge.org/BashFAQ)
- [Greg's Wiki: Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
