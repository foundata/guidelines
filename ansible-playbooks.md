# Ansible playbook guidelines

This document defines the style for writing Ansible playbooks, addressing the
lack of a consistent and comprehensive code style and usage in both
[Red Hat's guidelines](https://github.com/redhat-cop/automation-good-practices/blob/main/coding_style/README.adoc#ansible-guidelines)
and the
[Ansible documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html).

Collection boundaries and role argument specifications follow the
[Ansible roles and collections guide](./ansible-roles-collections.md).
Ansible modules and plugins written in Python follow the
[Ansible module development guide](./ansible-modules.md).

The terms MUST, SHOULD, and other key words are used as defined in
[RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [YAML files](#yaml-files)
- [Indentation](#indentation)
- [Spacing](#spacing)
- [Quoting](#quoting)
- [Naming](#naming)
- [Booleans](#booleans)
- [Maps (`key: value`)](#maps)
  - [Value retrieval: bracket notation](#value-retrieval)
- [Facts](#facts)
- [Conditionals](#conditionals)
  - [Formatting](#conditionals-formatting)
- [Loops](#loops)
  - [Loop variables in role task files](#role-loop-variables)
- [Tasks and play declaration](#tasks-plays)
  - [Handlers](#handlers)
  - [Templates](#templates)
- [External commands](#external-commands)
  - [Scripts](#scripts)
- [Comments](#comments)
- [Linting](#linting)
- [Miscellaneous](#misc)
- [Linguistic guidelines](#linguistic-guidelines)
- [Author information](#author-information)


## YAML files<a id="yaml-files"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use [YAML 1.2.2](https://yaml.org/spec/1.2.2/)-compatible syntax that the
  project's supported Ansible versions interpret consistently.
- Use spaces for
  [indentation](https://yaml.org/spec/1.2.2/#61-indentation-spaces).
- Use Unix line feed (LF, `\n`) for new lines.
- Use [UTF-8 encoding](https://yaml.org/spec/1.2.2/#52-character-encodings).
- Trim trailing whitespace whenever possible, but ensure files end with a new
  line.
- Keep line lengths below 160 characters whenever technically possible.
- Use JSON syntax only when it makes sense (e.g., for an automatically generated
  file) or when it improves readability.

**You SHOULD:**

- Use `.yml` as the extension for new playbooks (or tasks files in roles, and
  collections).
  - Stay consistent with existing extensions if `.yaml` is already used in a
    role or collection.
- Start files with comments explaining their purpose, including example usage if
  reasonable.
- Start YAML documents with `---`. Let `ansible-lint --fix` determine spacing
  around the separator.
- Check all
  [`YAML_FILENAME_EXTENSIONS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#yaml-filename-extensions)
  when searching for files (e.g., `vars_files`, `include_vars`, plugins, or
  similar functions).
- Keep content around 80 characters in length, and ensure the overall line
  length, including indentation, stays below 120 characters.
  - Use [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and
    `|`) as needed to manage long strings.
  - Include a chomping indicator (`-`) behind
    [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`)
    when it is important to exclude the trailing newline from the string (e.g.,
    when defining a string variable).
- Refer to [Conditional formatting](#conditionals-formatting) for rules on
  writing `when`, `changed_when`, and `failed_when` clauses.

**Good examples:**

```yaml
# Connect to the host and check for a Python installation. Show demo tasks.
#
# Example usage:
#   ansible-playbook -e ping_data_return="pong" playbook.yml
#   ansible-playbook -e ping_data_return="crash" playbook.yml

---
- name: "Example playbook"
  hosts: "localhost"
  tasks:
    - name: "Connect to host, verify a Python installation."
      ansible.builtin.ping:
        data: "{{ ping_data_return }}"

    - name: "Print a very long line"
      ansible.builtin.debug:
        verbosity: 1
        msg: >
          Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod
          tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At
          vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren,
          no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit
          amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut
          labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam
          et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata
          sanctus est Lorem ipsum dolor sit amet.
      when:
        # when clause is a raw Jinja2 expression without double curly braces or quoting
        - foo is not ansible.builtin.defined
        - bar is not ansible.builtin.defined

    # Use parentheses and new lines to group conditions when it helps to understand the
    # logic. In doubt, use parentheses if there are multiple and/or.
    - name: "Shut down CentOS 8 (or newer) and Debian 10 systems"
      ansible.builtin.command:
        cmd: "/sbin/shutdown -t now"
      when:
        - ansible_facts['distribution'] is ansible.builtin.defined
        - ansible_facts['distribution_major_version'] is ansible.builtin.defined
        - >-
          ((ansible_facts['distribution'] | ansible.builtin.lower) == 'centos' and
          ansible_facts['distribution_version'] is ansible.builtin.version('8.0.0', '>=')) or
          ((ansible_facts['distribution'] | ansible.builtin.lower) == 'debian' and
          ansible_facts['distribution_major_version'] == '10')
      changed_when:
        - __shutdown_result is ansible.builtin.success
      register: __shutdown_result

    - name: "Include OS vars (with default fallback)"
      ansible.builtin.include_vars:
        dir: "vars"
        files_matching: "^({{ ansible_facts['distribution'] }}|default)(\\{{ lookup('ansible.builtin.config', 'YAML_FILENAME_EXTENSIONS') | join('|\\\\') }})$"

# newline (Unix line feed, \n) at end of file
```

**Bad examples:**

```yaml
---
- hosts: "localhost"
  tasks:
    - name: "Connect to host, verify a Python installation."
      ansible.builtin.ping:
        data: "{{ ping_data_return }}"

    - name: "Print a very long line"
      ansible.builtin.debug:
        msg: "Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet."
      when: foo is not ansible.builtin.defined and bar is not ansible.builtin.defined

    - name: "Include OS vars"
      ansible.builtin.include_vars:
        dir: "vars"
        files_matching: "^mswindows.yml$" # unexpected filename, no fallback, only .yml
```

**Reasoning:**

- This guide uses YAML 1.2-oriented conventions, but Ansible's runtime parser
  retains
  [YAML 1.1 behavior](https://docs.ansible.com/projects/ansible/latest/reference_appendices/YAMLSyntax.html).
  Linter settings do not replace that parser. Use lowercase `true` and `false`
  for booleans and quote ambiguous strings, such as `"yes"`, `"no"`, and version
  numbers, so linting and execution agree on their types.
- The `.yml` extension must be used for consistency. It is predominant in the
  Ansible ecosystem, even though [yaml.org](https://yaml.org/faq.html)
  recommends `.yaml`.
- Adding comments at the very beginning of a file allows for quickly identifying
  the purpose or usage of it, either by opening the file or using the `head`
  command.
- Ending files with a new line is a common Unix best practice. It prevents
  terminal prompt misalignment when printing files to
  [STDOUT](https://en.wikipedia.org/wiki/Standard_streams#Standard_output_(stdout)).
- Long lines are difficult to read. Many projects ask for a line length limit
  around 120-150 character and [`ansible-lint`](#linting) checks for 160
  characters by default
  ([yaml rule](https://ansible.readthedocs.io/projects/lint/rules/yaml/)).
- Even though JSON is syntactically valid YAML and understood by Ansible, nobody
  expects it in playbooks.


## Indentation<a id="indentation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use two spaces to represent sub-maps when indenting.
- Especially indent list contents beyond the list definition.

**Reasoning:**

Following the indentation rules produces consistent code that is easy to read.

**Good examples:**

```yaml
---
- name: "Print some dummy messages."
  ansible.builtin.debug:
    msg:
      - "Dummy 1"
      - "Dummy 2"
      - "Dummy 3"
    verbosity: 1
```

**Bad examples:**

```yaml
- name: "Print some dummy messages."
  ansible.builtin.debug:
    msg:
    - "Dummy 1"
    - "Dummy 2"
    - "Dummy 3"
```


## Spacing<a id="spacing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Let `ansible-lint --fix` determine mechanical YAML layout. Do not restore
  spacing that the formatter removes.
- End files with a newline. Do not require an additional empty line at EOF.

**You SHOULD:**

- Separate adjacent tasks with one blank line. Accept the formatter's placement
  around multiline values, comments and nested blocks; do not add blank lines
  immediately after `pre_tasks:`, `tasks:`, `post_tasks:`, or `block:`.
- Use a single space to separate Jinja2 template markers from variable names or
  expressions.
- Break up lengthy Jinja templates into multiple templates when they contain
  distinct logical sections.

**Reasoning:**

Following the formatter produces consistent code without competing formatting
passes. `ansible-lint --fix` usually collapses multiple blank lines between
tasks and removes structural blank lines and extra empty lines at EOF, but can
retain two blank lines after multiline values or comments. Use a yamllint
maximum of two, not one, to accept that output. A maximum cannot require a
separator between tasks.

**Good examples:**

```yaml
---
- name: "Molecule | Prepare"
  hosts: "molecule"
  gather_facts: false
  pre_tasks:
    - name: "Molecule | Prepare | Basic self-checks for the testing infrastructure"
      block:
        - name: "Molecule | Prepare | Fail if MOLECULE_SCENARIO_DIRECTORY is not set or empty"
          ansible.builtin.fail:
            msg: "MOLECULE_SCENARIO_DIRECTORY env var is not set or empty"
          when:
            - (lookup('ansible.builtin.env', 'MOLECULE_SCENARIO_DIRECTORY') | ansible.builtin.trim) | ansible.builtin.length == 0

  tasks:
    - name: "Set a variable"
      ansible.builtin.set_fact:
        foo: "{{ bar | ansible.builtin.default('baz') }}"

    - name: "Set another variable"
      ansible.builtin.set_fact:
        bar: "{{ baz | ansible.builtin.default('foo, barbaz') }}"
```

**Bad examples:**

```yaml
---
- name: "Molecule | Prepare"
  hosts: "molecule"
  gather_facts: false

  pre_tasks:
    - name: "Molecule | Prepare | Basic self-checks for the testing infrastructure"
      run_once: true # noqa: run-once[task]
      block:
        - name: "Molecule | Prepare | Fail if MOLECULE_SCENARIO_DIRECTORY is not set or empty"
          ansible.builtin.fail:
            msg: "MOLECULE_SCENARIO_DIRECTORY env var is not set or empty"
          when:
            - (lookup('env', 'MOLECULE_SCENARIO_DIRECTORY') | ansible.builtin.trim) | ansible.builtin.length == 0
  tasks:
    - name: "Set a variable"
        ansible.builtin.set_fact:
            foo: "{{bar|default('baz')}}"
    - name: "Set another variable"
        ansible.builtin.set_fact:
            bar: "{{baz|default('foo,barbaz')}}"
```


## Quoting<a id="quoting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`)
  for writing long strings or to simplify complicated quoting.

**You SHOULD:**

- Quote ordinary string values, including strings that resemble booleans or
  numbers.
- Leave structural keys and simple identifiers plain, such as variable names
  in `register`, `loop_control.loop_var` and `set_fact` keys.
- Leave implicit Jinja2 expressions plain where YAML permits, including
  conditions and `ansible.builtin.debug`'s `var` parameter. Use outer YAML
  quotes when required by YAML syntax, such as expressions containing `: `.
  Do not add `{{ }}` delimiters in these expression contexts.
- Use double quotes (`"`) for quoted YAML strings. Single quotes are permitted
  when the string contains double quotes. Use block scalars where quoting
  becomes cumbersome.
- Use single quotes (`'`) for Jinja2 strings.

**You MUST NOT:**

- Quote non-string types, such as booleans (`true`, `false`) or numbers (e.g.,
  `1337`).

**Good examples:**

```yaml
- name: "Connect to host, verify a usable python"
  ansible.builtin.ping:
    data: "{{ ping_return }}"

# double quotes with nested single quotes for Jinja2
- name: "Start all nodes"
  become: true
  ansible.builtin.service:
    name: "{{ item['node_name'] }}"
    state: "started"
    enabled: true
  loop: "{{ nodes }}"

# folded scalar style (useful to prevent complicated quoting or lines longer than 160 chars)
- name: "Node infos"
  ansible.builtin.debug:
    verbosity: 1
    msg: >
      Node {{ item['node_name'] }} is {{ item['status'] }} and in {{ item['az'] }}
      availability zone and belongs to "{{ item['customer'] }}" customer.
  loop: "{{ nodes }}"

# don't quote booleans and numbers
- name: "Download example homepage"
  ansible.builtin.get_url:
    dest: "/tmp"
    timeout: 60
    url: "https://example.com"
    validate_certs: true

# variables example 1
- name: "Set a variable"
  ansible.builtin.set_fact:
    foo: "bar" # explicitly references the string "bar"

# variables example 2
- name: "Print a variable"
  ansible.builtin.debug:
    # var is an implicit Jinja2 expression; omit {{ }} delimiters.
    var: foo
    verbosity: 1
  when:
    - (ansible_facts['os_family'] | ansible.builtin.lower) == 'redhat'

# variables example 3
- name: "Set another variable"
  ansible.builtin.set_fact:
    baz: "{{ foo }}" # explicitly references the variable foo
```

These tasks expect an `app_config` mapping with a string `label` field:

```yaml
- name: "Show application configuration"
  ansible.builtin.debug:
    var: app_config
    verbosity: 1
  when:
    - app_config is ansible.builtin.defined
  register: __app_config_result

- name: "Show active application configuration"
  ansible.builtin.debug:
    var: app_config
    verbosity: 1
  when:
    - "app_config['label'] == 'mode: active'"
```

**Bad examples:**

```yaml
- name: Start node named Horton
  become: true
  ansible.builtin.service:
    name: horton
    state: 'started'
    enabled: true

- name: "Assign a value without quoting"
  ansible.builtin.set_fact:
    baz: another_var # literal string, not a variable lookup; quote for style
```

**Reasoning:**

- We have stricter rules than much of the community (cf.
  [8.2. YAML and Jinja2 Syntax](https://redhat-cop.github.io/automation-good-practices/#_yaml_and_jinja2_syntax)):
  - We believe ordinary string values
    [should be quoted](https://news.ycombinator.com/item?id=34509789).
  - The number of rules to remember, if you want to use the quotes only when
    they are really needed, is somewhat excessive for such a simple thing as
    specifying one of the most common datatypes.
  - However, since laxer rules are so common, we have categorized this as SHOULD
    instead of MUST.
- Single quotes in YAML behave differently than most programmers expect:
  - Escaping with `\` is **not** possible; instead, `''` (two single quotes) is
    used.
  - They do **not** prevent variable interpolation.
- Properly escaped strings make it easier to troubleshoot malformed strings and
  ensure the desired effect.
- YAML requires you to quote the entire scalar if it starts with `{{ foo }}` to
  distinguish between a value and a YAML dictionary.
- Outer YAML quotes preserve an expression as a string for Ansible to evaluate;
  they do not turn the expression's result into a Jinja2 string literal.
  The `debug.var` parameter already uses
  [implicit Jinja2 evaluation](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/debug_module.html#parameter-var).
  Ordinary module string parameters need `{{ }}` for variable substitution.
- Syntax highlighting generally works better when strings are explicitly quoted.
- Refer to the following for more information about edge cases:
  - [Ansible FAQ: "When should I use {{ }}? Also, how to interpolate variables or dynamic variable names"](https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#when-should-i-use-also-how-to-interpolate-variables-or-dynamic-variable-names)
  - [Ansible Lint rule: `risky-octal`](https://ansible.readthedocs.io/projects/lint/rules/risky-octal/)
- Further discussion:
  - [Ansible Lint: add rule to prefer double quotes instead of single (like black) #584](https://github.com/ansible/ansible-lint/discussions/584)
  - [YAML: Do I need quotes for strings in YAML?](https://stackoverflow.com/questions/19109912/yaml-do-i-need-quotes-for-strings-in-yaml)


## Naming<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use Fully Qualified Collection Names (FQCN) for all modules, plugins, tests,
  filters, and lookups (e.g., `ansible.builtin.copy` instead of `copy`).
  This includes literal plugin names passed to `lookup`, `query`, `q`, `map`,
  `select`, `reject`, `selectattr` and `rejectattr`. Jinja globals such as
  `range()` and `namespace()`, language keywords, and comparison-operator test
  aliases such as `==` are not collection plugin names.
- Use [`snake_case`](https://en.wikipedia.org/wiki/Snake_case) for variables,
  roles, collections and modules.
- Only use characters from the set `[a-z0-9_]`.
- Start variable names with a letter or underscore.
- Prefix role variables with the collection and/or role name.
- Prefix internal variables (those that are not expected to be set by users) by
  two underscores.

**Good examples:**

```yaml
- name: "Set some facts"
  ansible.builtin.set_fact:
    node_is_online: true
    node_age: 20
    node_name: "test"
    one_and_only: false

- name: "Determine version of foo"
  ansible.builtin.shell:
    executable: "/bin/bash"
    cmd: |
      set -u
      set -o pipefail
      __foo_installed=""
      if command -v 'foo' > /dev/null 2>&1
      then
        __foo_installed="$(foo --version | tail -1 | sed -e 's/^v//g')"
        if ! printf '%s' "${__foo_installed}" | grep -E -q -e '^[[:digit:]\.]*$'
        then
          __foo_installed=''
        fi
      fi
      printf '%s' "${__foo_installed}"
  changed_when:
    - false
  register: __foo_installed_result
```

**Bad examples:**

```yaml
- name: "Set some facts"
  ansible.builtin.set_fact:
    nodeIsOnline: true
    nodeage: 20
    NODE_NAME: "test"
    1andOnly: False

- name: "determine version of foo"
  ansible.builtin.shell:
    cmd: |
      installed=""
      if command -v 'foo' > /dev/null 2>&1
      then
        installed="$(foo --version | tail -1 | sed -e 's/^v//g')"
        if ! printf '%s' "${installed}" | grep -E -q -e '^[[:digit:]\.]*$'
        then
          installed=''
        fi
      fi
      printf '%s' "${installed}"
  register: installed_result
```

**Reasoning:**

- Using FQCN prevents ambiguity when multiple collections provide modules with
  the same name, ensures consistent behavior across different Ansible
  configurations, and makes dependencies explicit. Ansible recommends FQCN as a
  best practice.
- Ansible uses `snake_case` for module names and parameters. As this convention
  influences a wide range of playbooks, it is logical to extend it to variable
  names, even though they are not technically restricted to this format.
- Names of plugins, roles, and most parts of Ansible must follow Python
  namespace rules, which disallow certain characters, such as hyphens (`-`) or
  dots (`.`). See [StackOverflow](https://stackoverflow.com/a/37831973),
  [Galaxy Issue 775](https://github.com/ansible/galaxy/issues/775), and a
  [comment from Issue 779](https://github.com/ansible/galaxy/issues/779#issuecomment-401632750)
  for more information:
  > For that to work, namespaces need to be Python compatible, which means they
  > can't contain '-'.
- Refer to the
  [Ansible Galaxy documentation on role names](https://galaxy.ansible.com/docs/contributing/creating_role.html#role-names)
  for additional guidance.
- Role variables, registered variables, and custom facts are not truly local.
  They persist globally and can pollute the namespace. Prefixing them with the
  role name reduces conflicts, while two underscores indicate they are internal.
  This applies to variables set by `set_fact` and `register`, as they remain
  after the role completes. The two underscores for internal variables are
  [a community convention](https://redhat-cop.github.io/automation-good-practices/#_naming_parameters).



## Booleans<a id="booleans"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:** use `true` and `false` only (all lowercase without quotes).

**Good examples:**

```yaml
- name: "Start fail2ban"
  become: true
  ansible.builtin.service:
    name: "fail2ban"
    state: "restarted"
    enabled: true
```

**Bad examples:**

```yaml
- name: "Start fail2ban"
  become: 'yes'
  ansible.builtin.service:
    name: "fail2ban"
    state: "restarted"
    enabled: 1
```

**Reasoning:**

- Lowercase `true` and `false` are unambiguous across YAML 1.1 and 1.2 parsers.
  YAML accepts additional spellings; this guide requires lowercase for
  consistency.
- Quote strings that a YAML 1.1 parser could interpret as booleans, such as
  `"no"`, to avoid
  [the Norway problem](https://hitchdev.com/strictyaml/why/implicit-typing-removed/).


## Maps (`key: value`)<a id="maps"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use only one space after the colon when specifying a key-value pair.
- Always use the map syntax, regardless of the number of pairs in the map.

**Good examples:**

```yaml
- name: "Start fail2ban"
  ansible.builtin.service:
    name: "fail2ban"
    state: "restarted"
    enabled: true

- name: "Create filter.d directory for easier fail2ban extension"
  ansible.builtin.file:
    owner: "fail2ban"
    group: "fail2ban"
    mode: "u=rwx,g=rx,o=rx" # 0755
    path: "/etc/fail2ban/filter.d"
    state: "directory"

- name: "Copy sshd.conf to /etc/fail2ban/filter.d/"
  ansible.builtin.copy:
    dest: "/etc/fail2ban/filter.d/"
    src: "files/filters/sshd.conf"
```

**Bad examples:**

```yaml
- name: "Start fail2ban"
  ansible.builtin.service:
    name    : "fail2ban"
    state   : "restarted"
    enabled : true

- name: "Create filter.d directory for easier fail2ban extension"
  ansible.builtin.file: "path:=/etc/fail2ban/filter.d state=directory owner=fail2ban group=fail2ban mode=0755"

- name: "Copy sshd.conf to /etc/fail2ban/filter.d/"
  ansible.builtin.copy: "dest=/etc/fail2ban/filter.d/ src=files/filters/sshd.conf"
```

**Reasoning:**

- The map syntax is easier to read and less error-prone.
- Version control diffs are cleaner and more meaningful, as only new or changed
  parameters are highlighted.


### Value retrieval: bracket notation<a id="value-retrieval"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use bracket notation for dictionary-key and sequence-item value retrieval.
  Method calls such as `mapping.keys()` are outside this rule.

**You SHOULD:**

- Refactor projects to use bracket notation instead of dot notation, provided
  the project maintainers agree.

**You MUST NOT:**

- Mix dot and bracket notation for value retrieval within the same project.

**Good examples:**

```yaml
- name: "Define some variables"
  ansible.builtin.set_fact:
    foo:
      field1: "one"
      field2: "two"
    platforms:
      - name: "Fedora"
        versions:
          - "all"
      - name: "Ubuntu"
        versions:
          - "16.04"
          - "16.10"

- name: "Show field1 (prints: one)"
  ansible.builtin.debug:
    msg: "{{ foo['field1'] }}"
    verbosity: 1

- name: "Nice Linux distribution? (prints: Fedora)"
  ansible.builtin.debug:
    msg: "{{ platforms[0]['name'] }}"
    verbosity: 1

- name: "Ubuntu version used? (prints: 16.10)"
  ansible.builtin.debug:
    msg: "{{ platforms[1]['versions'][1] }}"
    verbosity: 1
```

**Bad examples:**

```yaml
- name: "Define some variables"
  ansible.builtin.set_fact:
    foo:
      field1: "one"
      field2: "two"
    platforms:
      - name: "Fedora"
        versions:
          - "all"
      - name: "Ubuntu"
        versions:
          - "16.04"
          - "16.10"

- name: "Show field1 (prints: one)"
  ansible.builtin.debug:
    msg: "{{ foo.field1 }}"

- name: "Nice Linux distribution? (prints: Fedora)"
  ansible.builtin.debug:
    msg: "{{ platforms.0.name }}"

- name: "Ubuntu version used? (prints: 16.10)"
  ansible.builtin.debug:
    msg: "{{ platforms.1.versions[1] }}"
```

**Reasoning:**

- Bracket notation makes it easier to distinguish between keys and attributes or
  methods of Python dictionaries. It also usually results in better editor
  highlighting.
- Bracket notation supports variables as keys.
- Dot notation can fail when keys collide with attributes or methods of Python
  dictionaries, such as `count`, `copy`, or `title`. Use bracket notation
  consistently within a playbook.


## Facts<a id="facts"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Ensure roles and collections are compatible with playbooks using
  `gather_facts: false`.
- Use the `ansible_facts` dictionary to access facts (e.g.,
  `ansible_facts['distribution']`).
- Distinguish the fact keys the role needs from the `gather_subset` selectors
  used to collect them. A mapping from selectors to required keys is also
  suitable; use its keys for collection and its values for presence checks.
- Include `!all` and `!min` when restricting collection to explicitly selected
  subsets, then list the required selectors.
- Document whether cached values are acceptable. A presence check does not
  establish freshness; refresh affected facts before using them when current
  values are required or earlier changes have invalidated them.

**You SHOULD:**

- Test with `gather_facts: false` and fact injection disabled, including missing
  facts and stale values that the role must refresh.

**You MUST NOT:**

- Rely on the
  [`INJECT_FACTS_AS_VARS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#inject-facts-as-vars)
  setting being enabled.
- Use `ansible_<factname>` legacy variables (e.g., `ansible_distribution`) to
  access facts.

This restriction applies to injected fact aliases, not every `ansible_*` name.
Magic variables such as `ansible_version` and connection variables such as
`ansible_host` remain valid. See
[Ansible's special variables](https://docs.ansible.com/projects/ansible/latest/reference_appendices/special_variables.html).

**Good examples:**

```yaml
# This role accepts cached platform facts; refresh them after platform changes.
- name: "Init | Gather role-specific facts"
  ansible.builtin.setup:
    gather_subset:
      - "!all"
      - "!min"
      - "distribution"
      - "virtual"
  vars:
    __required_fact_keys:
      # from subset "distribution"
      - "distribution"
      - "distribution_major_version"
      - "distribution_version"
      - "os_family"
      # from subset "virtual"
      - "virtualization_role"
      - "virtualization_type"
  when:
    - not (__required_fact_keys is ansible.builtin.subset(ansible_facts.keys()))

- name: "Debug | System introduction"
  ansible.builtin.debug:
    verbosity: 1
    msg: >
      Hello 👋
      I am a {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
      (major {{ ansible_facts['distribution_major_version'] }}) box from the {{ ansible_facts['os_family'] }} family.
      I am running as a {{ ansible_facts['virtualization_role'] | ansible.builtin.default('bare-metal') }} on
      {{ ansible_facts['virtualization_type'] | ansible.builtin.default('physical hardware') }}.
```

**Bad examples:**

```yaml
# BAD: Assumes gather_facts: true was run, uses legacy variable names
- name: "Debug | System introduction"
  ansible.builtin.debug:
    msg: >
      I am a {{ ansible_distribution }} {{ ansible_distribution_version }}
      (major {{ ansible_distribution_major_version }}) box from the {{ ansible_os_family }} family.
```

**Reasoning:**

- Fact gathering is slow and consumes resources. Disabling it globally with
  `gather_facts: false` is a legitimate optimization for administrators. Your
  code should not depend on externally defined behavior and should gather only
  the facts it needs.
- `gather_subset` selects collectors; the presence check lists required output
  keys. Some fact names are also supported selectors, but a collector can
  return several related facts and require other collectors. The returned
  mapping is not limited to the keys the role needs.
- `!all` alone retains the default minimum set. Add `!min` to exclude it before
  selecting the required subsets. See the
  [`setup` parameters](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/setup_module.html#parameters).
- The `ansible_<factname>` variables are legacy convenience variables. Using
  `ansible_facts['<factname>']` is the modern, explicit approach and makes it
  clear that you are accessing facts rather than regular variables.
- Compatibility with `INJECT_FACTS_AS_VARS = false` ensures playbooks work
  regardless of the Ansible configuration.
- The example skips collection when all required keys exist. This avoids
  redundant work when cached platform facts are acceptable. It does not check
  their age or whether the underlying state has changed. For example, gather
  network facts again after changing network configuration if later tasks
  depend on the new state.


## Conditionals<a id="conditionals"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Ensure all conditional expressions (`when`, `changed_when`, `failed_when`,
  `until`, `assert.that`) evaluate to actual boolean values, not truthy/falsy
  values.
- Use validated boolean variables directly. For other values, use explicit
  predicates or supported boolean conversion:
  - `myvar | ansible.builtin.length > 0` instead of just `myvar`
  - `myvar is ansible.builtin.defined` for existence checks
  - `myvar | ansible.builtin.bool` for supported boolean representations, such
    as the strings `"true"` and `"false"`
  - `myvar == 'value'` for string comparisons
- Use `ansible.builtin.truthy` only when Python truthiness is the intended
  meaning. It treats a nonempty string such as `"false"` as true. Do not use
  `ansible.builtin.bool` to test arbitrary strings, lists, or mappings.
- Quote conditional expressions containing `:` (colon followed by space) to
  prevent YAML from parsing them as mappings.
- Use parentheses to control Jinja2 order of operations when using operators
  like `~` (concatenation) with tests.

**You MUST NOT:**

- Rely on implicit truthy evaluation of strings, lists, or dictionaries.
- Accidentally quote sub-expressions within a conditional (the quoted part
  becomes a string instead of a boolean expression).

**You SHOULD:**

- Use the
  [`ansible.builtin.success`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/success_test.html)
  and
  [`ansible.builtin.failed`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/failed_test.html)
  tests when evaluating Ansible task status. Compare `rc` when interpreting
  command-specific exit codes; task status and process exit status are not
  interchangeable.
- Normalize categorical string facts (such as `os_family` or `distribution`) to
  lowercase at comparison time with
  [`ansible.builtin.lower`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/lower_filter.html),
  and use lowercase comparison values, unless letter case is semantically
  significant.

**Good examples:**

```yaml
- name: "Using real booleans (no truthiness conversion involved)"
  ansible.builtin.assert:
    that:
      - foo
      - not bar
  vars:
    foo: true
    bar: false

- name: "Distinguish boolean conversion from string truthiness"
  ansible.builtin.assert:
    that:
      - not ('false' | ansible.builtin.bool)
      - "'false' is ansible.builtin.truthy"

- name: "Check if hostname is set"
  ansible.builtin.assert:
    that:
      - inventory_hostname is ansible.builtin.defined
      - inventory_hostname | ansible.builtin.length > 0

- name: "Check message content"
  ansible.builtin.assert:
    that:
      # quote the whole expression to prevent YAML parsing ": " as a mapping
      - "result['msg'] == 'some_key: some_value'"

- name: "Check hostname contains pattern"
  ansible.builtin.assert:
    that:
      # parentheses ensure concatenation happens before the test
      - inventory_hostname is ansible.builtin.contains('local' ~ 'host')

- name: "Run only if list is not empty"
  ansible.builtin.debug:
    msg: "List has items"
    verbosity: 1
  when:
    - my_list | ansible.builtin.length > 0

- name: "Handle SUSE systems"
  ansible.builtin.debug:
    msg: "The operating-system family is SUSE"
    verbosity: 1
  when:
    - (ansible_facts['os_family'] | ansible.builtin.lower) == 'suse'

- name: "Handle supported operating-system families"
  ansible.builtin.debug:
    msg: "The operating-system family is supported"
    verbosity: 1
  when:
    - (ansible_facts['os_family'] | ansible.builtin.lower) in ['redhat', 'suse']

# Using success/failed tests to handle a command's task status
- name: "Run a command and check result"
  ansible.builtin.command:
    argv:
      - "/usr/bin/myapp"
      - "--check"
  changed_when:
    - false
  ignore_errors: true # Preserve the failed status for the handling task below.
  register: __myapp_check_result

- name: "Handle command result"
  ansible.builtin.debug:
    msg: "Command succeeded"
    verbosity: 1
  when:
    - __myapp_check_result is ansible.builtin.success

- name: "Handle command failure"
  ansible.builtin.fail:
    msg: "Command failed: {{ __myapp_check_result['stderr'] }}"
  when:
    - __myapp_check_result is ansible.builtin.failed
```

This diagnostic requires `diff` and two configuration files. Exit code 1 means
the files differ; it is an expected result, not a task failure:

```yaml
- name: "Compare application configurations"
  ansible.builtin.command:
    argv:
      - "diff"
      - "--"
      - "/etc/myapp/config.conf"
      - "/etc/myapp/config.expected"
  changed_when:
    - false
  failed_when:
    - __config_diff_result['rc'] not in [0, 1]
  register: __config_diff_result

- name: "Report configuration differences"
  ansible.builtin.debug:
    msg: "Configurations differ"
    verbosity: 1
  when:
    - __config_diff_result['rc'] == 1
```

**Bad examples:**

```yaml
# BAD: Relies on implicit truthy evaluation of a string
- name: "Check if hostname is set"
  ansible.builtin.assert:
    that:
      - inventory_hostname # this would be only valid if this variable would be a boolean

# BAD: The quoted sub-expression is a string, not a boolean predicate
- name: "Check if hostname is valid"
  ansible.builtin.assert:
    that:
      - inventory_hostname is ansible.builtin.defined and 'inventory_hostname | ansible.builtin.length > 0'

# BAD: Unquoted colon+space is parsed as a YAML mapping, not a boolean expression
- name: "Check message content"
  ansible.builtin.assert:
    that:
      - result.msg == "some_key: some_value"

# BAD: Without parentheses, ~ is evaluated after the test, result is "Truehost"
- name: "Check hostname contains pattern"
  ansible.builtin.assert:
    that:
      - inventory_hostname is contains "local" ~ "host"

# BAD: Couples the comparison to the capitalization supplied by the fact source
- name: "Handle SUSE systems"
  ansible.builtin.debug:
    msg: "The operating-system family is SUSE"
  when:
    - ansible_facts['os_family'] == 'Suse'

# BAD: Mixes externally supplied capitalization into the comparison interface
- name: "Handle supported operating-system families"
  ansible.builtin.debug:
    msg: "The operating-system family is supported"
  when:
    - ansible_facts['os_family'] in ['RedHat', 'Suse']

# BAD: Using process exit status as a substitute for Ansible task status
- name: "Handle command result"
  ansible.builtin.debug:
    msg: "Command succeeded"
  when:
    - __myapp_check_result['rc'] == 0  # use "is ansible.builtin.success" instead

- name: "Handle command failure"
  ansible.builtin.fail:
    msg: "Command failed"
  when:
    - __myapp_check_result['rc'] != 0  # use "is ansible.builtin.failed" instead
```

**Reasoning:**

- Python and Jinja2 provide implicit "truthy" evaluation of most non-empty,
  non-boolean values. While sometimes convenient, this often masks serious logic
  errors.
- Ansible 12 enforces boolean results for conditionals by default. Non-boolean
  results now
  [raise an error (like `Conditional result (<True|False>) was derived from value of type '<Type>'`)](https://docs.ansible.com/ansible/latest/porting_guides/porting_guide_12.html#broken-conditionals)
  instead of being silently evaluated as truthy.
- Writing explicit boolean predicates makes the intent clear and prevents subtle
  bugs that are hard to diagnose.
- The
  [`bool` filter](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/bool_filter.html)
  parses a limited set of boolean representations. The
  [`truthy` test](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/truthy_test.html)
  checks Python truthiness by default. They answer different questions for
  strings such as `"false"`; prefer a specific comparison when testing content.
- YAML can interpret unquoted expressions containing `:` followed by a space
  as mappings. Quoting the entire expression prevents a type error or, on older
  Ansible versions, an unintended truthy result.
- The `success` and `failed` tests inspect the task's failure status and work
  across modules, including those without return codes. `failed_when: false`
  overrides this status, so a nonzero return code can still test as successful.
  When a later task handles a registered failure, `ignore_errors: true`
  continues execution without clearing that status. Otherwise, let the task
  fail normally.
- Facts are external inputs. Normalizing categorical values only at the
  comparison boundary gives conditional logic a canonical interface and prevents
  capitalization differences from changing control flow, while preserving the
  original fact value for display, file names, or other case-sensitive uses.


### Formatting<a id="conditionals-formatting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Always use the list format for `when`, `changed_when`, `failed_when`, and
  `until` conditions, even for single conditions.
- Use separate list entries for independent, top-level `and` clauses. Keep
  `or` alternatives in one list entry and preserve grouping in mixed
  expressions; do not split nested clauses into separate entries.

Separate list entries are joined with `and`: all must be true. This also means
`failed_when` only marks failure, and `changed_when` only reports change, when
all their entries are true. For alternatives, use one entry containing `or`.
See
[Ansible's failure conditions](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_error_handling.html#defining-failure).

**You SHOULD:**

- Use a folded scalar (`>-`) for a long conditional expression when deliberate
  line breaks improve readability. The formatter can reflow plain multiline
  scalars, but preserves folded-scalar layout.
- In folded expressions, break after `or` operators and place filter pipes (`|`)
  at the beginning of continuation lines. Do not force short expressions onto
  multiple lines merely because they contain `or`.

**Good examples:**

```yaml
# Retry until a boolean test succeeds, using list format for one condition
- name: "Wait for application readiness"
  ansible.builtin.uri:
    url: "http://127.0.0.1:8080/health"
    status_code: 200
  until:
    - __health_result is ansible.builtin.success
  retries: 5
  delay: 2
  register: __health_result

# This application can report an error in stdout even with exit code 0
- name: "Check application exit status and error output"
  ansible.builtin.command:
    argv:
      - "/usr/bin/myapp"
      - "--check"
  changed_when:
    - false
  failed_when:
    - >-
      __myapp_check_result['rc'] != 0 or
      'ERROR' in __myapp_check_result['stdout']
  register: __myapp_check_result

# Single condition in list format
- name: "Check Ansible version"
  ansible.builtin.assert:
    that:
      - ansible_version['full'] is ansible.builtin.version(foobar_meta['galaxy_info']['min_ansible_version'], '<')

# Multiple 'or' conditions with line breaks after each 'or'
- name: "Check distribution info"
  ansible.builtin.debug:
    msg: "Distribution info missing or no platforms defined"
    verbosity: 1
  when:
    - >-
      ansible_facts['distribution'] is not ansible.builtin.defined or
      ansible_facts['distribution_version'] is not ansible.builtin.defined or
      (foobar_meta['galaxy_info']['platforms'] | ansible.builtin.length) < 1

# Complex piped expressions with '|' at the beginning of continuation lines
- name: "Check platform support"
  ansible.builtin.fail:
    msg: "Platform not supported"
  when:
    - (foobar_meta['galaxy_info']['platforms'] | ansible.builtin.length) > 0
    - >-
      ansible_facts['distribution'] is not ansible.builtin.defined or
      ansible_facts['distribution_version'] is not ansible.builtin.defined or
      (foobar_meta['galaxy_info']['platforms'] | ansible.builtin.length) < 1
    - >-
      (foobar_meta['galaxy_info']['platforms']
      | ansible.builtin.selectattr('name', 'ansible.builtin.match', '^' ~ ansible_facts['distribution'] ~ '$')
      | ansible.builtin.map(attribute='versions') | ansible.builtin.flatten
      | ansible.builtin.select('ansible.builtin.match', '^(' ~ ansible_facts['distribution_version'] ~ '|all)$', ignorecase=true)
      | ansible.builtin.list | ansible.builtin.length) < 1

# Multiple 'and' conditions as separate list entries
- name: "Run when all conditions are met"
  ansible.builtin.debug:
    msg: "All conditions met"
    verbosity: 1
  when:
    - condition_a
    - condition_b
    - condition_c
```

**Bad examples:**

```yaml
# BAD: Fails only when both are true, hiding either failure on its own
- name: "Check application exit status and error output"
  ansible.builtin.command:
    argv:
      - "/usr/bin/myapp"
      - "--check"
  changed_when:
    - false
  failed_when:
    - __myapp_check_result['rc'] != 0
    - "'ERROR' in __myapp_check_result['stdout']"
  register: __myapp_check_result

# BAD: Not using list format
- name: "Check Ansible version"
  ansible.builtin.assert:
    that:
      - ansible_version['full'] is version(foobar_meta['galaxy_info']['min_ansible_version'], "<")
  when: ansible_facts['distribution'] is ansible.builtin.defined

# BAD: Chaining 'and' in a single line instead of separate list entries
- name: "Run when all conditions are met"
  ansible.builtin.debug:
    msg: "All conditions met"
  when: condition_a and condition_b and condition_c

# BAD: Pipe at end of line instead of beginning of continuation line, missing line breaks
- name: "Check platform support"
  ansible.builtin.fail:
    msg: "Platform not supported"
  when:
    - (foobar_meta['galaxy_info']['platforms'] | ansible.builtin.selectattr('name', 'match', '^' ~ ansible_facts['distribution'] ~ '$') |
       map(attribute='versions') | ansible.builtin.flatten | ansible.builtin.list | ansible.builtin.length) < 1
```

**Reasoning:**

- Using list format for all conditions ensures cleaner diffs when adding or
  removing conditions, making changes more readable and easier to review.
- `until` retries the task until all its conditions are true or retries are
  exhausted. List format is a guideline convention; Ansible also accepts a
  scalar expression. The health-check example assumes an HTTP endpoint where
  status 200 means ready.
- Placing the pipe operator at the beginning of continuation lines improves
  readability by making the data flow through filters immediately visible.
- Breaking lines after `or` operators and using separate list entries for `and`
  conditions creates a consistent, scannable structure that reflects the logical
  grouping.


## Loops<a id="loops"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `loop` for iterating over simple lists and variables.
- Migrate `with_*` constructs to loop if listed at
  "[Migrating from with_X to loop](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_loops.html#migrating-from-with-x-to-loop)",
  especially `with_items` and `with_list`.

**You SHOULD NOT:**

- Convert `with_*` to `loop` statements that requires using `lookup()` within a
  `loop` to use the loop keyword.

**Good examples:**

```yaml
# Simple list - use loop
- name: "Install packages"
  ansible.builtin.apt:
    name: "{{ item }}"
    state: "present"
  loop:
    - "nginx"
    - "curl"

# Lookup-based - keep with_fileglob if there is no additional filtering needed
- name: "Include cleanup tasks"
  ansible.builtin.include_tasks:
    file: "{{ item }}"
  with_fileglob:
    - "../tasks/cleanup/*.yml"

# Lookup-based, but no with_fileglob as alphabetical order has to be guaranteed
- name: "Include additional tasks from foo/ in alphabetical order"
  ansible.builtin.include_tasks:
    file: "{{ loop_item }}"
  when:
    - loop_item is ansible.builtin.file
  loop: "{{ lookup('ansible.builtin.fileglob', 'foo/*.yml', wantlist=true) | ansible.builtin.sort }}"
  loop_control:
    loop_var: "loop_item"
```

**Bad examples:**

```yaml
# BAD: Unnecessarily complex if file order does not matter - keep with_fileglob instead
- name: "Include cleanup tasks"
  ansible.builtin.include_tasks:
    file: "{{ item }}"
  loop: "{{ lookup('fileglob', '../tasks/cleanup/*.yml', wantlist=True) }}"
```

**Reasoning:**

- [Ansible documentation: Comparing loops](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_loops.html#comparing-loops)
- The Ansible team has not deprecated `with_<lookup>` in general. The syntax
  remains valid despite
  [earlier](https://github.com/ansible/ansible/issues/51153#issuecomment-456219258)
  [discussions](https://github.com/ansible/ansible-lint/issues/2204#issue-1266269947).


### Loop variables in role task files<a id="role-loop-variables"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Set `loop_control.loop_var` explicitly for every `loop` or `with_*` in a
  role's task files.
- Use a private name built from the role's public variable prefix and the loop's
  purpose: `__<public-variable-prefix><purpose>_item`. The public variable
  prefix includes its trailing underscore. For example, use
  `__role_collection_package_item` for a package loop in a role whose public
  variables start with `role_collection_`. A generic dispatch loop in
  `tasks/main.yml` can use `__role_collection_loop_item`.
- Use different purpose names for nested loops, including loops in task files
  called by a looping `include_tasks` task.

**Good examples:**

```yaml
# collection/roles/example/tasks/packages.yml
- name: "Install packages"
  ansible.builtin.package:
    name: "{{ __role_collection_package_item }}"
    state: "present"
  loop: "{{ role_collection_packages }}"
  loop_control:
    loop_var: "__role_collection_package_item"
```

**Bad examples:**

```yaml
# collection/roles/example/tasks/packages.yml
- name: "Install packages"
  ansible.builtin.package:
    name: "{{ item }}"
    state: "present"
  loop: "{{ role_collection_packages }}"
```

**Reasoning:**

- Consumers can run `include_role` in a loop and pass role parameters templated
  from that loop's `item`. Ansible evaluates these parameters when the role
  accesses them. A role task that also loops over `item` replaces the consumer's
  value while the parameter is evaluated.
- This collision can silently produce an empty or incorrect value when the
  parameter uses `default(...)`. The role may then change or remove the wrong
  data. An explicit, namespaced loop variable prevents the role from rebinding
  `item`.
- Purpose-specific names also prevent collisions between
  [nested loops](https://docs.ansible.com/projects/ansible/latest/playbook_guide/playbooks_loops.html#nested-loops).


## Tasks and play declaration<a id="tasks-plays"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `name:` as the first key for plays, tasks and handlers.
- Begin all names with an uppercase letter.
- Place `block`, `rescue` and `always` after all other task keys, in that
  order when present. These boundaries follow stock
  [`key-order`](https://docs.ansible.com/projects/lint/rules/key-order/).
- Put any dynamic part of a task name at the end, as required by stock
  [`name[template]`](https://docs.ansible.com/projects/lint/rules/name/).

**You SHOULD:**

- Extend stock `key-order` by arranging the keys between `name` and the final
  `block`/`rescue`/`always` group in this order (omit unused keys):
  1. Attributes defining what the task is, where to run it and what its
     parameters are:
     - `delegate_to`
     - `become`
     - `module`: The actual action.
       - Place primary, mandatory module parameters (e.g., `name`, `state`,
         `path`) directly under the module name for clarity.
       - Place `owner`, `group` and `mode` together (in this order).
       - Arrange all other, optional module parameters in alphabetical order,
         unless doing so negatively impacts readability or logic.
         This is advisory and applies only to module parameters, not application
         data in `vars`, `set_fact` assignments or nested module payloads.
     - `args`: If using the args syntax for complex module parameters.
     - `vars`: If using additional or inline variables to the module.
     - `environment`: If setting environment variables for an action.
  2. Attributes defining when to run or fail, control attributes:
     - `when`
     - `changed_when`
     - `failed_when`
     - `ignore_errors`
     - `run_once`
  3. Loop controls:
     - `loop`
     - `loop_control`
     - `with_*`
  4. Attributes defining how to process results:
     - `register`
     - `no_log`
  5. Attributes defining what to do afterwards or to get triggered by:
     - `notify`
     - `listen`
  6. `tags`, before any `block`, `rescue` or `always` key.
- Leave keys not listed above in their relative slots within the middle group;
  they must not precede `name` or follow block-related keys. Do not apply this
  extension to play keys or arbitrary nested data mappings.
- The `include_*` and `import_*` statements are not treated differently from
  other tasks/plays. This clarification is included because many other style
  guides impose separate rules for these.

**You MUST NOT:**

- Use variables (wrapped in Jinja2 templates) in play names (the `name`
  attribute of a playbook), as they do not expand properly.
- Use loop variables (e.g., the default `item`) in task names within a loop, as
  they also do not expand properly.

Keep stock `key-order` enabled. The foundata extension reports only additional
ordering constraints; it must not reverse stock's ordering or duplicate its
findings. Extended ordering is currently diagnostic-only: stock's cached autofix
can overwrite another ordering transform. Apply the suggested middle-key order
manually rather than relying on two competing autofixes.

The list requirement for `when`, `changed_when`, and `failed_when` is defined in
[Conditional formatting](#conditionals-formatting), including single conditions.

**Good examples:**

```yaml
---
- name: "A cool playbook"
  hosts: "localhost"
  tasks:
    - name: "A block"
      when:
        - false
      block: # last key, even after "when:" to prevent indentation errors
        - name: "Display a message"
          ansible.builtin.debug:
            msg: "Hello world!"
            verbosity: 1

        - name: "Get basic information from 'linux_container' hosts"
          delegate_to: "{{ item }}"
          # ansible.builtin.raw instead of ansible.builtin.command as it works
          # without any existing python on the target
          ansible.builtin.raw: |
            /usr/bin/grep "PRETTY" /etc/os-release; /usr/bin/uname -r;
          args:
            executable: "/bin/bash"
          changed_when:
            - false
          failed_when:
            - false
          loop: "{{ groups['linux_container'] }}"
          loop_control:
            label: "{{ item }}"
          register: __basicinfo_result

        - name: "Show basic information from 'linux_container' hosts"
          ansible.builtin.debug:
            msg: "{{ processed_result.split('\n') }}"
            verbosity: 1
          vars:
            processed_result: |-
              {% for result in __basicinfo_result['results'] %}
              Host: {{ result['item'] }} - {{ result['stdout_lines'] | ansible.builtin.default(['No output']) | ansible.builtin.join(', ') }}
              {% endfor %}
          when:
            - __basicinfo_result is ansible.builtin.defined
            - __basicinfo_result['results'] is ansible.builtin.defined
            - __basicinfo_result['results'][0]['stdout_lines'] is ansible.builtin.defined
          run_once: true

    - name: "Install nginx"
      ansible.builtin.apt:
        name: "nginx"
        state: "present"
      when:
        - (ansible_facts['os_family'] | ansible.builtin.lower) == 'redhat'

    - name: "Create some EC2 Instances"
      amazon.aws.ec2_instance:
        image: "ami-c7d092f7"
        assign_public_ip: true
        key_name: "my_key"
        instance_tags:
          name: "{{ item }}"
      when:
        - (ansible_facts['os_family'] | ansible.builtin.lower) == 'redhat'
      ignore_errors: true
      loop: "{{ instance_names }}"
      register: __ec2_output
      tags:
        - "ec2"

    - name: "Include tasks to cleanup"
      ansible.builtin.include_tasks:
        file: "cleanup.yml"
      tags:
        - "always"
        - "cleanup"

    - name: "Manage device {{ device_name }}"
      foo.module:
        device: "{{ device_name }}"
      when:
        - (ansible_facts['os_family'] | ansible.builtin.lower) == 'redhat'
      changed_when:
        - false
      failed_when:
        - false
```

**Bad examples:**

```yaml
---
- hosts: "localhost"
  name: "A cool playbook" # should be the first one
  tasks:
    - name: "A block"
      block:
        - name: "Display a message"
          ansible.builtin.debug:
            msg: "Hello world!"
      when: true # when key should be before block

  - name: "Create some EC2 Instances"
    when: ansible_os_family == 'RedHat'
    tags: "ec2"
    amazon.aws.ec2_instance: "image=ami-c7d092f7 assign_public_ip=true"
    register: __ec2_output
    with_items: "{{ instance_names }}"
    ignore_errors: true

  - ansible.builtin.include_tasks: "setup.yml"
    tags: "setup"
  - ansible.builtin.include_tasks: "config.yml"
  - ansible.builtin.include_tasks: "cleanup.yml" tags=always

  - name: "{{ device_name }} gets managed as device"
    changed_when: false
    failed_when: false
    foo.module:
      device: "{{ device_name }}"
```

**Reasoning:**

- Well-defined parameter rules are helping to create consistent code. Version
  control diffs are cleaner and more meaningful, as only new or changed
  parameters are highlighted.
- The proposed ordering creates a logical flow: "what the task is and where to
  run it" → "when to run it" → "how to process results" → "what to do
  afterwards". `register:` is placed after loops since the registered variable
  structure depends on whether loops are used.
- Keep in mind that using variables in task names can make it harder for users
  to correlate logs with the corresponding code when searching for an actual
  variable value (e.g., `/dev/foo gets managed as device` instead of
  `{{ device_name }} gets managed as device`). Placing the variable part at the
  end of a task name improves log readability and makes it easier to search for
  the corresponding code.
- The reasoning of the
  [Ansible Lint rule: `key-order`](https://ansible.readthedocs.io/projects/lint/rules/key-order/#correct-code).
- Further discussion:
  - [Ansible Lint: ansible lint should check order of tasks attributes for when and name #578](https://github.com/ansible/ansible-lint/issues/578).
    Many people at Red Hat place `when:` immediately after `name:`. This is a
    subjective choice and we think our approach of grouping it with other
    control attributes is logical and the `name:` as well as the module describe
    what is done *together* as a unit.


### Handlers<a id="handlers"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `listen` to trigger handlers instead of relying on the handler's `name`.
- Always use list notation for `listen` values.
- Use lowercase for `listen` values except documented migration aliases.
- Name new role-specific topics `<public-variable-prefix><action>_<object>`.
  The role's public variable prefix, including its trailing underscore,
  identifies the owning role and collection. The action states what happens;
  the object identifies the affected service, component, or resource. For a
  role with prefix `nginx_web_`, use `nginx_web_restart_nginx`, not
  `nginx_web_restart`. Keep the object explicit even when it repeats part of
  the prefix.

These requirements apply to notifiable handlers, not static `import_tasks`
directives. Check the imported handlers instead. A dynamic `include_tasks`
handler needs its own `listen` topics; its included tasks are not individually
notifiable handlers.

**You SHOULD:**

- Update `notify` references together with renamed `listen` topics. Document
  consumer-facing topic changes in release notes.

**You MAY:**

- Use shared broadcast topics without an individual role's prefix when several
  roles intentionally respond to one notification. Keep the action and object
  explicit, use lowercase, and document the purpose and intended listeners.
- Retain already-published topics as temporary migration aliases, including
  unprefixed or mixed-case values. Mark each alias with an adjacent comment
  and document its removal version. Add the new canonical topic, use it for
  new callers, and remove each alias at the documented version. This exception
  does not permit new nonconforming topics or indefinite aliases.

`foundata-handler-listen` recognizes adjacent `Migration alias; remove in
3.0.0.` comments and `Shared broadcast` comments. Review their purpose and
removal deadline; the check does not establish whether an exception is
justified.

**Good examples:**

```yaml
# In handlers/main.yml of the nginx role in the web collection
- name: "Restart NGINX service"
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  listen:
    - "nginx_web_restart_nginx"

- name: "Reload NGINX configuration"
  ansible.builtin.service:
    name: "nginx"
    state: "reloaded"
  listen:
    - "nginx_web_reload_nginx"

# In handlers/main.yml of the myapp role in the web collection
- name: "Restart application service"
  ansible.builtin.service:
    name: "myapp"
    state: "restarted"
  listen:
    - "myapp_web_restart_myapp"
    # Shared broadcast for all application-service handlers in the web stack.
    - "web_restart_application_services"

# In tasks/main.yml - triggering handlers via listen value
- name: "Update NGINX configuration"
  ansible.builtin.template:
    src: "nginx.conf.j2"
    dest: "/etc/nginx/nginx.conf"
    mode: "u=rw,g=r,o=r" # 0644
  notify:
    - "nginx_web_reload_nginx"
```

```yaml
# Preserve the published topic while callers migrate; remove it in 3.0.0.
- name: "Restart NGINX service" # noqa: foundata-handler-listen
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  listen:
    - "nginx_web_restart_nginx"
    - "Restart Nginx" # Migration alias; remove in 3.0.0.
```

**Bad examples:**

```yaml
# BAD: Triggering handler by name instead of listen value
- name: "Restart NGINX service"
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  # no listen defined, relies on name matching

# In tasks - triggering by handler name (fragile)
- name: "Update NGINX configuration"
  ansible.builtin.template:
    src: "nginx.conf.j2"
    dest: "/etc/nginx/nginx.conf"
  notify:
    - "Restart nginx service"  # coupled to handler's name

# BAD: Non-list notation for listen
- name: "Restart NGINX service"
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  listen: "nginx_web_restart_nginx"  # should be a list

# BAD: New mixed-case topic without a documented migration exception
- name: "Restart NGINX service"
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  listen:
    - "Nginx_Web_Restart_Nginx"  # should be all lowercase

# BAD: The prefix identifies the owner but the affected object is missing
- name: "Restart NGINX service"
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  listen:
    - "nginx_web_restart"
```

**Reasoning:**

- Handler names must be unique within a play, while multiple handlers can share
  the same `listen` value. This allows one notification to trigger multiple
  handlers.
- Topics share the play's scope. Role prefixes prevent accidental broadcasts;
  explicit action/object names identify the operation without relying on the
  role name to imply its target.
- Using `listen` decouples the trigger mechanism from the display name, making
  maintenance easier and allowing names to follow their own readability rules
  without affecting notification logic.
- List notation signals that multiple trigger aliases are supported and
  maintains consistency with other list-based attributes.
- Lowercase values prevent case-sensitivity issues and ensure consistent
  matching across the codebase.
- Published topics are interfaces used by callers outside the role. Temporary
  aliases preserve those callers during migration; a removal version keeps the
  exception bounded.


### Templates<a id="templates"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Pass all external data a template needs through `tpl_*` variables defined in
  the task's `vars:`, including values such as `ansible_managed`. This covers
  dependencies in included, imported and inherited templates. Renderer-provided
  metadata has no general exemption.
- Document any template-local values a fragment expects from its caller.
- Refactor existing templates to `tpl_*` inputs when you touch them.

**You SHOULD:**

- Import reusable macro libraries without context and pass their data as macro
  arguments. Imports using `with context` must follow the same external-input
  requirements.

**You MUST NOT:**

- Read task loop variables, registered results, facts, or other ambient Ansible
  variables directly inside a template.

Variables defined inside the template, its own loop variables and macro
parameters are local to the template and do not need the `tpl_*` prefix. Jinja
built-in facilities such as `loop` and `namespace()` remain available.

Includes inherit the caller's context by default; imports do not. An included
fragment may use documented caller-local values, but must not read ambient
Ansible variables. See
[Jinja's context behavior](https://jinja.palletsprojects.com/en/stable/templates/#import-context-behavior).
Alternative delimiters, whether configured in the task or a `#jinja2:` header,
do not change these input requirements.

**Good examples:**

```yaml
- name: "Config | Default | Create or update vhost config files"
  ansible.builtin.template:
    src: "vhost.conf.j2"
    dest: "{{ __run_example_vhosts_dir_path }}/{{ __run_example_vhost_item['name'] }}.conf"
    owner: "root"
    group: "root"
    mode: "u=rw,g=r,o=r" # 0644
  vars:
    # Pass (and/or adjust) variables needed for the template
    tpl_marker: "{{ __run_example_config_file_marker }}"
    tpl_managed: "{{ ansible_managed }}"
    tpl_content: "{{ __run_example_vhost_item['content'] }}"
  loop: "{{ run_example_vhosts_config }}"
  loop_control:
    loop_var: "__run_example_vhost_item"
```

```jinja
{# templates/vhost.conf.j2 #}
{{ tpl_marker }}
# {{ tpl_managed }}

{{ tpl_content }}
```

Reusable macros receive their inputs as arguments:

```yaml
- name: "Config | Default | Create or update vhost server name"
  ansible.builtin.template:
    src: "server-name.conf.j2"
    dest: "/etc/nginx/conf.d/server-name.conf"
    owner: "root"
    group: "root"
    mode: "u=rw,g=r,o=r" # 0644
  vars:
    tpl_server_name: "{{ nginx_web_server_name }}"
```

```jinja
{# templates/server-name.conf.j2 #}
{% import "macros.j2" as config without context %}
{{ config.server_name(tpl_server_name) }}
```

```jinja
{# templates/macros.j2 #}
{% macro server_name(name) -%}
server_name {{ name }};
{%- endmacro %}
```

**Bad examples:**

```jinja
{# BAD: Template reads the loop variable and role internals directly #}
{{ __run_example_config_file_marker }}
# {{ ansible_managed }}

{{ __run_example_vhost_item['content'] }}
```

**Reasoning:**

- The `vars:` block lists the template's external inputs, so a reader sees
  them in the task without opening the template.
- A template that takes its external data through `tpl_*` variables can be
  rendered from another task, loop, or role without editing the file. The
  example above works for a second task that builds the same file from a
  different source.
- Defaults, filters, and merges stay in the task where they are visible. The
  template remains a plain rendering of its inputs.
- Splitting a template across files must not hide external dependencies.
  Explicit macro arguments keep reusable helpers independent of their caller's
  context.



## External commands<a id="external-commands"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This section covers the use of
[`ansible.builtin.command`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html)
and
[`ansible.builtin.shell`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html)
modules.

**You MUST:**

- Use dedicated Ansible modules instead of shell commands when available (e.g.,
  `ansible.builtin.apt` instead of `apt-get`, `ansible.builtin.file` instead of
  `mkdir`).
- Prefer `ansible.builtin.command` over `ansible.builtin.shell` unless shell
  features such as pipes, redirects, or globbing are required.
- When interpolating variable arguments into `cmd`, apply the
  [`quote` filter](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/quote_filter.html)
  to each argument: `{{ myvar | ansible.builtin.quote }}`. This preserves
  argument boundaries and prevents shell interpretation of the value.
- Pass `argv` elements without shell quoting or the `quote` filter. Set
  `expand_argument_vars: false` when argument values must reach the command
  literally, including dollar signs. This option requires ansible-core 2.16 or
  later.
- Explain non-obvious reasons why a dedicated module is unsuitable, or why
  particular shell features or execution behavior are required (see
  [Comments](#comments)). A nearby explanation may cover related tasks. Do not
  add generic boilerplate or repeat what the task already makes clear.

**You SHOULD:**

- Use the `argv` attribute (list) instead of `cmd` for
  `ansible.builtin.command`:
  - Keeps each argument in its own list element, including values with spaces.
  - Allows comments above individual parameters.
  - Easier to build command arguments conditionally from variables.
- Use `creates` or `removes` parameters to achieve idempotency when the command
  creates or removes files.
- Set `changed_when` and/or `failed_when` to properly reflect command outcomes.

**Good examples:**

```yaml
# Using argv with list - preferred for ansible.builtin.command:
# Easy to comment on parameter. Easy to define as dedicated variable if needed
- name: "Create a backup archive"
  ansible.builtin.command:
    argv:
      - "tar"
      - "-czf"
      # destination archive
      - "/backup/data.tar.gz"
      # source directory
      - "/var/lib/myapp/data"
    creates: "/backup/data.tar.gz"

# Building argv from variable - easy to modify conditionally (e.g. as fact)
- name: "Run database migration"
  ansible.builtin.command:
    argv: "{{ __migration_cmd }}"
    expand_argument_vars: false
  vars:
    __migration_cmd:
      - "/usr/bin/myapp"
      - "migrate"
      - "--database={{ database_name }}"  # Pass the database name literally, including any dollar signs.
  changed_when:
    - __migration_result is ansible.builtin.success
    - "'No migrations to apply' not in __migration_result['stdout']"
  register: __migration_result

# When shell is necessary (pipes, redirects) - use quote filter for variables
- name: "Find and count log files"
  ansible.builtin.shell:
    executable: "/bin/bash"
    cmd: |-
      set -u
      set -o pipefail
      if ! find /var/log -name '*.log' -mtime +{{ log_retention_days | ansible.builtin.quote }} | wc -l; then
        printf '%s\n' 'Failed to count log files' >&2
        exit 1
      fi
  changed_when:
    - false
  register: __log_count_result

# Using creates for idempotency
- name: "Initialize application database"
  ansible.builtin.command:
    argv:
      - "/usr/bin/myapp"
      - "db"
      - "init"
    creates: "/var/lib/myapp/.db_initialized"
```

**Bad examples:**

```yaml
# BAD: Using shell command instead of dedicated module
- name: "Install nginx"
  ansible.builtin.command:
    cmd: "apt-get install -y nginx"  # use ansible.builtin.apt instead

# BAD: Using shell without necessity
- name: "Apply sysctl settings"
  ansible.builtin.shell:
    cmd: "sysctl --system"  # no shell features needed, use command

# BAD: Using cmd string instead of argv list, missing quote filter for variables in cmd
- name: "Run command with complex arguments"
  ansible.builtin.command:
    cmd: "myapp --config '/path/with spaces/config.yml' --name '{{ app_name }}'"  # injection risk!
    # quoting is error-prone, use argv instead
```

**Reasoning:**

- Dedicated state-management modules usually handle change detection and
  idempotency for their supported operations. Check the module's documented
  behavior and check-mode support; using a module does not by itself guarantee
  idempotency.
- [`ansible.builtin.command`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html)
  executes commands directly without a shell, avoiding shell injection
  vulnerabilities and unexpected shell interpretation.
- [`ansible.builtin.shell`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/shell_module.html)
  spawns a shell process, which is necessary for shell features but introduces
  security risks if variables are not properly quoted.
- The `argv` attribute avoids splitting a command string. Shell quotes added to
  its elements become part of the argument value. Ansible can still expand
  environment variables: `command` expands values such as `$HOME` by default
  since ansible-core 2.16. Environment expansion alone does not require `shell`.
- Neither `argv` nor the `quote` filter prevents the executable from treating a
  value as an option or interpreting its own expression language. Validate
  inputs for that command and use an end-of-options marker (`--`) where it is
  supported and appropriate.


### Scripts<a id="scripts"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This subsection covers shell scripts used with Ansible, including inline scripts
embedded in `ansible.builtin.shell` tasks and standalone scripts executed via
`ansible.builtin.script`.

**You MUST:**

- Keep script bodies POSIX-compatible for reuse. The shell options below are
  explicit exceptions with their own runtime requirements.
- Use `executable: "/bin/bash"` with `ansible.builtin.shell`. Document Bash at
  this path as a prerequisite on the execution host, including delegated hosts,
  and ensure it is available before the task runs. Ansible otherwise uses
  `/bin/sh`; an inline shebang does not select the shell.
- Use block scalar style (`|`) for multi-line scripts and the chomping indicator
  (`|-`) when trailing newlines matter.
- Follow applicable parts of the
  [Shell scripting style guide](./shell-scripting.md).
- Use `changed_when` and/or `failed_when` to properly reflect script outcomes.
- Check critical command and assignment statuses explicitly. Handle expected
  nonzero statuses narrowly; do not hide other failures with `|| true`.
- Test important failure paths, including pipeline stages, command
  substitutions and functions used as conditions, on supported shell versions.
- Enable `set -o pipefail` for inline shell pipelines, in accordance with stock
  [`risky-shell-pipe`](https://docs.ansible.com/projects/lint/rules/risky-shell-pipe/).
  Handle expected nonzero statuses explicitly. If a pipeline intentionally
  requires different failure semantics, document them and use a task-local
  suppression; do not disable the stock rule globally.
- Start *inline* scripts with:

  ```sh
  set -u # no uninitialized vars
  ```

**You SHOULD:**

- Keep inline scripts short (roughly 50 lines maximum).
- Use `set -e` only for simple, linear scripts where any failed command should
  stop execution, following the
  [shell guide's exception](./shell-scripting.md#error-handling). Explain why
  it is used and require Bash 4.4 or newer for this setup:

  ```bash
  set -u
  set -e
  set -o pipefail
  shopt -s inherit_errexit
  ```

  `inherit_errexit` preserves `-e` inside command substitutions, but does not
  remove its conditional-context exceptions. Use explicit error handling for
  branches, important pipeline statuses and substitutions used in logic. The
  mandatory `set -u` and inline-pipeline `pipefail` requirements apply whether
  or not `set -e` is used.
- For complex logic, use the
  [`ansible.builtin.script`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/script_module.html)
  module, which allows maintaining the script as a standalone file that can be
  linted, tested, and version-controlled separately.
- Use ShellCheck for shell syntax and dialect checks, and shfmt for formatting,
  before embedding scripts in Ansible tasks. Check representative rendered
  variants of scripts containing Jinja expressions; ShellCheck does not parse
  Jinja or replace runtime tests.
- Prefer
  [`ansible.builtin.raw`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/raw_module.html)
  over `ansible.builtin.shell` when no Python is available on the target (e.g.,
  during bootstrapping).

**Good examples:**

```yaml
# Capture systemctl's active-state text for a report; an inactive service is allowed.
- name: "Check and report service status"
  ansible.builtin.shell:
    executable: "/bin/bash"
    cmd: |
      set -u
      if service_status="$(systemctl is-active myservice)"; then
        :
      else
        status="$?"
        if [ "${status}" -ne 3 ] || [ "${service_status}" != 'inactive' ]; then
          printf '%s\n' 'Failed to query myservice or found an unexpected state' >&2
          exit "${status}"
        fi
      fi
      printf '%s\n' "${service_status}"
  changed_when:
    - false
  register: __service_result

# Using ansible.builtin.script for complex logic - script can be linted/tested standalone
- name: "Run complex data migration"
  ansible.builtin.script:
    cmd: "files/scripts/migrate_data.sh {{ source_dir | ansible.builtin.quote }} {{ dest_dir | ansible.builtin.quote }}"
    executable: "/bin/bash"
  changed_when:
    - __migration_result is ansible.builtin.success
    - "'Changes applied' in __migration_result['stdout']"
  register: __migration_result
```

Standalone script outline; the migration commands are omitted:

```sh
#!/usr/bin/env sh
#
# files/scripts/migrate_data.sh - standalone file, can be linted with shellcheck

export PATH="${PATH:-'/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'}"
export LC_ALL='en_US.UTF-8'
set -u                                                      # no uninitialized vars
# Keep explicit pipeline-status handling for older shells.
if set -o 2>/dev/null | grep -Fq 'pipefail'; then
    set +o pipefail
fi

source_dir="${1}"
dest_dir="${2}"

# Complex logic with proper error handling, functions, etc.
if [ ! -d "${source_dir}" ]; then
    printf 'Error: Source directory does not exist: %s\n' "${source_dir}" >&2
    exit 1
fi

# ... more logic ...
printf 'Changes applied\n'
```

**Bad examples:**

```yaml
# BAD: Missing executable, using Bashisms
- name: "Process files"
  ansible.builtin.shell:
    cmd: "for f in /tmp/*.txt; do [[ -f $f ]] && cat $f; done"  # Bashism: [[ ]]
  # no executable defined, no error handling

# BAD: Complex script that should be in a separate file
- name: "Complex inline script"
  ansible.builtin.shell:
    executable: "/bin/bash"
    cmd: |
      set -u
      # 150+ lines of complex logic... his should use ansible.builtin.script instead
      function process_data() { # function keyword is a Bashism
        # ...
      }
      # ... many more lines ...
```

**Reasoning:**

- It is generally preferable to write Ansible modules rather than using scripts.
  Modules provide better integration with Ansible's features (check mode, diff
  mode, proper return values, documentation). However, scripting is an
  acceptable approach when you are not yet capable of writing modules (yet). It
  is better to implement needed functionality via high-quality scripts than to
  not implement it at all.
- A well-parameterized, linted standalone script (used with
  `ansible.builtin.script`) is a better intermediate step towards a
  fully-featured Ansible module than inline scripting. It encourages proper
  structure, parameters, testability, and can later be converted to a module.
- POSIX-compliant scripts maximize portability across different systems and
  shells. Even when executing with Bash, avoiding Bashisms ensures scripts can
  be reused (partially) in other contexts.
- Bash execution and portable script syntax are separate requirements.
  `pipefail` is specified by POSIX.1-2024, but older shells may lack it;
  `inherit_errexit` is Bash-specific. Keep the standalone shell guide's broader
  compatibility policy separate from inline tasks that explicitly require Bash.
- `set -e` depends on shell context. Testing a function in `if` or an `&&`/`||`
  list can disable its effect inside the function. Combining `export` or
  `local` with an assignment can hide a failed substitution; assign and check
  the status separately (see
  [ShellCheck SC2155](https://www.shellcheck.net/wiki/SC2155)).
- The `ansible.builtin.script` module transfers a local script to the remote
  host, executes it, and removes it afterward. This allows complex scripts to be
  maintained as proper files with syntax highlighting, linting (shellcheck),
  testing, and version control benefits.
- Block scalar style (`|`) preserves line breaks and makes scripts readable
  within YAML.


## Comments<a id="comments"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Provide explanations for role and collection variables using comments in
  `/defaults` or `/vars` where they are defined.
- When using `ansible.builtin.command` or `ansible.builtin.shell`, explain
  non-obvious reasons why a dedicated module is unsuitable, or why particular
  shell features or execution behavior are required. A nearby explanation may
  cover related tasks. Do not add generic boilerplate or repeat what the task
  already makes clear.

**You SHOULD:**

- Use descriptive enough `name` values to tell what a task does instead of
  comments whenever possible.
- Keep comments concise: explain only non-obvious intent, constraints, or
  workarounds; do not narrate or repeat what the task, module arguments, or
  surrounding code already show. When both a problem and its workaround require
  explanation, use at most one short paragraph for each.
- Keep multi-line comments below 80 characters per line (excluding indentation).

**Reasoning:**

- Descriptive `name` values appear in Ansible's output; comments do not.
- Variables documented in the `/defaults` or `/vars` directories do not require
  explanation within the playbooks themselves.
- Concise comments preserve context that the code cannot express. Narrating
  visible behavior adds noise and is more likely to become outdated when the
  implementation changes.

**Good example:**

```yaml
# The application's validator checks cross-file references that file checks cannot.
- name: "Validate application configuration"
  ansible.builtin.command:
    argv:
      - "/usr/local/bin/myapp"
      - "config"
      - "validate"
  changed_when:
    - false
```


## Linting<a id="linting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Keep an `.ansible-lint` file in the root of every project with Ansible
  content. It selects the `production` profile, sets `strict: true`, skips
  `use-loop` and links to this section.
- Treat stock rules and their formatter as the compatibility baseline. Foundata
  rules MAY add stricter checks, but MUST NOT require output rejected by an
  enabled stock rule or undo its formatting. Resolve an actual conflict by
  adapting this guide, not by silently disabling stock checks. A documented,
  narrowly scoped exception remains possible where the underlying operation
  requires it.
- Check playbooks, collections, roles and other applicable files with
  [`ansible-lint --strict`](https://docs.ansible.com/projects/lint/), which
  reads that file.
- Lint test content such as Molecule scenarios as well. Install the collections
  it uses instead of excluding it.
- Exclude generator-owned `changelogs/changelog.yaml` from Ansible Lint,
  including autofix. Validate it separately with
  `antsibull-changelog lint-changelog-yaml changelogs/changelog.yaml`, and check
  changelog fragments with `antsibull-changelog lint`. Do not exclude the entire
  changelog directory merely to exempt generated output.
- Document which SHOULD-level recommendations the project enforces as lint
  errors. An enabled rule can be stricter than this guide's minimum obligations.
- Keep suppressions specific to the affected rule and the smallest applicable
  scope. Explain the reason next to the suppression. Use them for documented
  exceptions or false positives; existing nonconforming code is a finding to
  fix, not an exception.
- When CI requires `ansible-lint-foundata`, install the tested package version
  or reviewed local build in the same environment as Ansible Lint, enable the
  selected rule IDs, and verify that all expected IDs appear in
  `ansible-lint --list-rules --format brief` using the project's configuration.
  Fail the check if any are missing. Also run known-invalid, isolated fixtures
  and require each adopted rule's diagnostic: listing proves discovery, not
  execution, because `--list-rules` bypasses profile filtering. A successful
  stock-only run does not prove that the project's custom rules ran.

Local use without the extension MAY fall back to stock Ansible Lint. The
extension is optional unless the project adopts it; required CI coverage must
not silently fall back. Record adopted rules and their remaining review
requirements in the project's contributor documentation.

**Good examples:**

```yaml
# ansible-lint config implementing foundata's guidelines. Details, reasoning:
# https://foundata.com/en/guidelines/ansible-playbooks/#linting

---
profile: "production"
strict: true

skip_list:
  - "use-loop"

exclude_paths:
  - ".cache/"
  - "changelogs/changelog.yaml"
```

**Reasoning:**

- Ansible Lint is an official project by the Ansible Core Team and is widely
  adopted. Following its recommendations promotes consistent code.
- Ansible Lint automatically
  [runs `ansible-playbook --syntax-check`](https://ansible.readthedocs.io/projects/lint/rules/syntax-check/).
  A collection that is not installed fails that check, which is why test
  content needs its collections.
- Every run of ansible-lint reads the configuration file, including editor
  integrations and a `antsibull-nox` session of a collection (if any).
  Command-line options apply only where someone types them.
- A custom `exclude_paths` list replaces the default, so keep `.cache/` in it.
  Full exclusion preserves generator-owned formatting; dedicated changelog
  validation retains syntax and changelog-format checks. Skipping individual
  YAML style rules alone does not stop `--fix` from reformatting a file.
- The `with_<lookup>` syntax is not deprecated and remains valid. See the
  [Loops](#loops) section for when to use `with_*` vs `loop`. As of 2026-Q4,
  ansible-lint lists `use-loop` in its `production` profile as a
  [planned rule](https://github.com/ansible/ansible-lint/issues/2204). The
  skip keeps `with_*` loops valid once it ships.


## Miscellaneous<a id="misc"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Configuration automation MUST converge without reporting repeated changes
  when inputs and managed state remain unchanged. Intentionally repeatable
  operations, such as backups or maintenance jobs, MUST have an explicit trigger
  or a documented purpose. Change reporting MUST reflect the operation's actual
  behavior. Setting `changed_when: false` on a mutating command does not make it
  idempotent.
- Avoid overriding role defaults, variables, or input parameters using
  `set_fact`. Instead, use a distinct variable name.
- Reusable roles MUST NOT use `ansible.builtin.meta: end_play` or
  `ansible.builtin.meta: end_host` unless terminating their caller is an
  explicit, documented part of the role's contract. `end_play` stops the play
  for all hosts; `end_host` stops the remaining play for the current host,
  including unrelated roles and tasks. Neither merely exits the current role.
- Prefer role-local conditions or `ansible.builtin.meta: end_role` to skip
  remaining role tasks. `end_role` requires ansible-core 2.18 or later; use
  conditions when supporting older versions. It leaves later play tasks and
  other roles running and does not cancel notified handlers. Do not call it
  outside a role or from a handler. See the
  [meta module documentation](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/meta_module.html).
- Orchestration playbooks MAY deliberately use `end_play` or `end_host` when
  that termination scope is required. Explain the purpose and affected scope
  in an adjacent comment. `foundata-no-end-play` checks for that comment in
  direct orchestration tasks. Reusable roles and task files with unknown caller
  scope require task-local `# noqa: foundata-no-end-play` for a documented
  exception. Review the contract and affected scope; never substitute `end_host`
  just to avoid a finding.
- Limit the use of the
  [`ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html)
  module to scenarios such as copying remote files, static files, or uploading
  binary blobs. For most file operations, prefer using
  [`ansible.builtin.template`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html).
  Even if a file does not yet need templating, starting with a template avoids
  changing its source location and deployment task when templating is added.
  This follows
  [Red Hat CoP's Automation Good Practices](https://github.com/redhat-cop/automation-good-practices/blob/main/coding_style/README.adoc#ansible-guidelines).
- When using the
  [`ansible.builtin.template`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html)
  module, append `.j2` to the template file name for clarity and convention.
- [Use tags with caution](https://redhat-cop.github.io/automation-good-practices/#_use_tags_cautiously_either_for_roles_or_for_complete_purposes).
- Debug tasks MUST set `verbosity` explicitly. Diagnostic output SHOULD use
  `verbosity: 1` or higher. Output deliberately intended for normal runs MAY
  use `verbosity: 0`. See
  [Use the verbosity parameter with debug statements](https://redhat-cop.github.io/automation-good-practices/#_use_the_verbosity_parameter_with_debug_statements).
- Build structured data using native mappings and lists. Jinja expressions and
  filters MAY transform those values. When JSON or YAML text is needed,
  serialize the complete value using `ansible.builtin.to_json`,
  `ansible.builtin.to_nice_json`, `ansible.builtin.to_yaml`, or
  `ansible.builtin.to_nice_yaml`. Do not manually assemble document structure or
  escaping through text interpolation. A `.j2` template containing
  `{{ tpl_config | ansible.builtin.to_nice_json }}` follows this rule.
- Specify file permissions using complete, absolute symbolic assignments, with
  the matching octal equivalent as a trailing comment. Example:
  `mode: "u=rw,g=r,o=r" # 0644`. Set permissions for all of `u`, `g`, and `o`
  explicitly using `=` (or an equivalent explicit `a=` assignment). Do not use
  relative `+` or `-` operations, incomplete assignments, conditional `X`, or
  copies of existing permission bits. The result must not depend on the previous
  mode, file type, or umask. Explicit special bits remain permitted. This shows
  both representations without making the result dependent on existing state.
- When a mode comes from a variable, put the octal comment at its literal
  definition. Do not repeat it at every use. The resolved value must still meet
  the permission rule; review dynamic values and definitions, which the current
  `foundata-file-mode` rule does not check.
- Artifact-staging copies that must retain source-file permissions MAY use
  `ansible.builtin.copy` with `mode: "preserve"`. Explain why those permissions
  must be retained and add a task-local `# noqa: foundata-file-mode`. This
  exception does not apply to ordinary configuration deployment or to relative
  symbolic modes.

**Good examples:**

```yaml
# roles/nginx/tasks/main.yml (requires ansible-core >= 2.18)
- name: "Skip disabled NGINX role"
  ansible.builtin.meta: "end_role"
  when:
    - not (nginx_web_enabled | ansible.builtin.bool)
```

```yaml
# In an orchestration playbook; deployment_plan_only is a play-wide switch.
# After planning, deliberately skip deployment for all hosts in this play.
- name: "Finish deployment planning" # noqa: foundata-no-end-play
  ansible.builtin.meta: "end_play"
  when:
    - deployment_plan_only | ansible.builtin.bool
```

```yaml
# vars/main.yml
example_config_mode: "u=rw,g=r,o=" # 0640
```

```yaml
- name: "Set configuration permissions"
  ansible.builtin.file:
    path: "/etc/example.conf"
    mode: "{{ example_config_mode }}"

# The staging tree must retain the release artifact's executable bits for packaging.
- name: "Stage release artifact" # noqa: foundata-file-mode
  ansible.builtin.copy:
    src: "release/"
    dest: "/srv/build/staging/"
    mode: "preserve"

- name: "Report the published artifact location"
  ansible.builtin.debug:
    msg: "Artifact published to {{ artifact_url }}"
    verbosity: 0
```


## Linguistic guidelines<a id="linguistic-guidelines"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

- Follow the official
  [Ansible Developers Style Guide](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/index.html).
- Follow
  [Spelling - Word Usage - Common Words and Phrases to Use and Avoid](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/spelling_word_choice.html)
  recommendations.


Excerpt of the **most important rules**:

- Headers should be written in sentence case. For example, this section's title
  is `Header case`, not `Header Case` or `HEADER CASE`.
- [Stylistic cheat-sheet](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/index.html#stylistic-cheat-sheet):

  |         Rule          |      Good Example       | Bad Example |
  | --------------------- | ----------------------- | ----------- |
  | Use active voice      | You can run a task by   | A task can be run by |
  | Use the present tense | This command creates a  | This command will create a |
  | Use standard English  | Return to this page     | Hop back to this page |
  | Use American English  | The color of the output | The colour of the output |

**Reasoning:**

The official rules are based on experience of technical writers. As these are
also rules for Ansible developers, they are influencing the whole community. It
makes sense to apply them in-house to have a consistent user experience.


## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust,
readable and consistent code. It was inspired by
[Whitecloud Analytics's Ansible styleguide](https://github.com/whitecloud/ansible-styleguide).
