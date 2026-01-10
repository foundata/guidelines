# Ansible style guide (playbooks)

This document defines the style for writing Ansible playbooks, addressing the lack of a consistent and comprehensive code style and usage in both [Red Hat's guidelines](https://github.com/redhat-cop/automation-good-practices/blob/main/coding_style/README.adoc#ansible-guidelines) and the [Ansible documentation](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html).

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

* [YAML files](#yaml-files)
* [Indentation](#indentation)
* [Spacing](#spacing)
* [Quoting](#quoting)
* [Naming](#naming)
* [Booleans](#booleans)
* [Maps (`key: value`)](#maps)
  * [Value retrieval: bracket notation](#value-retrieval)
* [Facts](#facts)
* [Conditionals](#conditionals)
  * [Formatting](#conditionals-formatting)
* [Tasks and play declaration](#tasks-plays)
  * [Handlers](#handlers)
* [External commands](#external-commands)
* [Comments](#comments)
* [Linting](#linting)
* [Miscellaneous](#misc)
* [Linguistic guidelines](#linguistic-guidelines)
* [Author information](#author-information)



## YAML files<a id="yaml-files"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Follow the [YAML 1.2.2 specification](https://yaml.org/spec/1.2.2/).
* Use spaces for [indentation](https://yaml.org/spec/1.2.2/#61-indentation-spaces).
* Use Unix line feed (LF, `\n`) for new lines.
* Use [UTF-8 encoding](https://yaml.org/spec/1.2.2/#52-character-encodings).
* Trim trailing whitespace whenever possible, but ensure files end with a new line.
* Keep line lengths below 160 characters whenever technically possible.
* Use JSON syntax only when it makes sense (e.g., for an automatically generated file) or when it improves readability.


**You SHOULD:**

* Use `.yml` as the extension for new playbooks (or tasks files in roles, and collections).
  * Stay consistent with existing extensions if `.yaml` is already used in a role or collection.
* Start files with comments explaining their purpose, including example usage if reasonable.
* Include blank lines before and after the `---` separator, followed by the rest of the file.
* Check all [`YAML_FILENAME_EXTENSIONS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#yaml-filename-extensions) when searching for files (e.g., `vars_files`, `include_vars`, plugins, or similar functions).
* Keep content around 80 characters in length, and ensure the overall line length, including indentation, stays below 120 characters.
  * Use [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`) as needed to manage long strings.
  * Include a chomping indicator (`-`) behind [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`) when it is important to exclude the trailing newline from the string (e.g., when defining a string variable).
* Refer to [Conditional formatting](#conditionals-formatting) for rules on writing `when`, `changed_when`, and `failed_when` clauses.



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
        - foo is not defined
        - bar is not defined


    # Use parentheses and new lines to group conditions when it helps to understand the
    # logic. In doubt, use parentheses if there are multiple and/or.
    - name: "Shut down CentOS 8 (or newer) and Debian 10 systems"
      ansible.builtin.command:
        cmd: "/sbin/shutdown -t now"
      when:
        - ansible_distribution is defined
        - ansible_distribution_major_version is defined
        - (ansible_distribution == 'CentOS' and ansible_distribution_version is version('8.0.0', '>=')) or
          (ansible_distribution == 'Debian' and ansible_distribution_major_version == '10')
      changed_when:
        - __shutdown_result.rc is defined
        - __shutdown_result.rc == 0
      register: __shutdown_result


    - name: "Include OS vars (with default fallback)"
      ansible.builtin.include_vars:
        dir: "vars"
        files_matching: "^({{ ansible_distribution }}|default)(\\{{ lookup('ansible.builtin.config', 'YAML_FILENAME_EXTENSIONS') | join('|\\\\') }})$"

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
      when: foo is not defined and bar is not defined


    - name: "Include OS vars"
      ansible.builtin.include_vars:
        dir: "vars"
        files_matching: "^mswindows.yml$" # unexpected filename, no fallback, only .yml
```


**Reasoning:**

* YAML 1.2 has been the standard since 2009 and uses only `true` and `false` for booleans, avoiding many potential edge-case issues. Allowing YAML 1.1 is no longer practical.
* The `.yml` extension must be used for consistency. It is predominant in the Ansible ecosystem, even though [yaml.org](https://yaml.org/faq.html) recommends `.yaml`.
* Adding comments at the very beginning of a file allows for quickly identifying the purpose or usage of it, either by opening the file or using the `head` command.
* Ending files with a new line is a common Unix best practice. It prevents terminal prompt misalignment when printing files to [STDOUT](https://en.wikipedia.org/wiki/Standard_streams#Standard_output_(stdout)).
* Long lines are difficult to read. Many projects ask for a line length limit around 120-150 character and [`ansible-lint`](#linting) checks for 160 characters by default ([yaml rule](https://ansible.readthedocs.io/projects/lint/rules/yaml/)).
* Even though JSON is syntactically valid YAML and understood by Ansible, nobody expects it in playbooks.



## Indentation<a id="indentation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Use two spaces to represent sub-maps when indenting.
* Especially indent list contents beyond the list definition.
* Start multi-line maps with a dash (`-`).


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

**You SHOULD:**

* Add at least one blank line between:
  * Two host blocks.
  * Host and include blocks.
* Add at least two blank lines between:
  * Two task blocks.
* Use a single space to separate Jinja2 template markers from variable names or expressions.
* Break up lengthy Jinja templates into multiple templates when they contain distinct logical sections.
* Use Jinja templates for generating text and semi-structured data, not for creating structured data.


**Reasoning:**

Following the spacing rules produces consistent code that is easy to read.


**Good examples:**

```yaml
- name: "Set a variable"
  ansible.builtin.set_fact:
    foo: "{{ bar | default('baz') }}"


- name: "Set another variable"
  ansible.builtin.set_fact:
    bar: "{{ baz | default('foo, barbaz') }}"
```


**Bad examples:**

```yaml
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

* Use [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`) for writing long strings or to simplify complicated quoting.


**You SHOULD:**

* Quote all strings.
* Use double quotes (`"`) for YAML strings.
  * Use single quotes only when they simplify nested expressions, such as Jinja map references with mixed quoting styles.
* Use single quotes (`'`) for Jinja2 strings.


**You MUST NOT:**

* Quote non-string types, such as booleans (`true`, `false`) or numbers (e.g., `1337`).
* Quote references to the local Ansible environment, such as the names of variables being assigned values.


**Good Examples:**

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
  with_items: "{{ nodes }}"


# folded scalar style (useful to prevent complicated quoting or lines longer than 160 chars)
- name: "Node infos"
  ansible.builtin.debug:
    msg: >
      Node {{ item['node_name'] }} is {{ item['status'] }} and in {{ item['az'] }}
      availability zone and belongs to "{{ item['customer'] }}" customer.
  with_items: "{{ nodes }}"


# don't quote booleans and numbers
- name: "Download example homepage"
  ansible.builtin.get_url:
    dest: "/tmp"
    timeout: 60
    url: 'https://example.com'
    validate_certs: true


# variables example 1
- name: "set a variable"
  ansible.builtin.set_fact:
    foo: "bar" # explicitly references the string "bar"


# variables example 2
- name: "Print a variable"
  ansible.builtin.debug:
    # be aware that this option already runs in Jinja2 context and has an implicit
    # {{ }} wrapping, so you should not be using Jinja2 delimiters unless you are
    # looking for double interpolation.
    var: foo
  when:
    - ansible_os_family == 'RedHat'


# variables example 3
- name: "Set another variable"
  ansible.builtin.set_fact:
    baz: "{{ foo }}" # explicitly references the variable foo
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
    baz: another_var  # can cause ambiguity if `another_var` (string or existing variable?)
```


**Reasoning:**

* We have stricter rules than much of the community (cf. [8.2. YAML and Jinja2 Syntax](https://redhat-cop.github.io/automation-good-practices/#_yaml_and_jinja2_syntax)):
  * We believe all strings [should be quoted](https://news.ycombinator.com/item?id=34509789).
  * The number of rules to remember, if you want to use the quotes only when they are really needed, is somewhat excessive for such a simple thing as specifying one of the most common datatypes.
  * However, since laxer rules are so common, we have categorized this as SHOULD instead of MUST.
* Single quotes in YAML behave differently than most programmers expect:
  * Escaping with `\` is **not** possible; instead, `''` (two single quotes) is used.
  * They do **not** prevent variable interpolation.
* Properly escaped strings makes it easier to troubleshoot malformed strings and ensures the desired effect.
* YAML requires you to quote the entire line if it starts with `{{ foo }}` to distinguish between a value and a YAML dictionary.
* Syntax highlighting generally works better when strings are explicitly quoted.
* Refer to the following for more information about edge cases:
  * [Ansible FAQ: "When should I use {{ }}? Also, how to interpolate variables or dynamic variable names"](https://docs.ansible.com/ansible/latest/reference_appendices/faq.html#when-should-i-use-also-how-to-interpolate-variables-or-dynamic-variable-names)
  * [Ansible Lint rule: `risky-octal`](https://ansible.readthedocs.io/projects/lint/rules/risky-octal/)
* Further discussion:
  * [Ansible Lint: add rule to prefer double quotes instead of single (like black) #584](https://github.com/ansible/ansible-lint/discussions/584)
  * [YAML: Do I need quotes for strings in YAML?](https://stackoverflow.com/questions/19109912/yaml-do-i-need-quotes-for-strings-in-yaml)



## Naming<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Use [`snake_case`](https://en.wikipedia.org/wiki/Snake_case) for variables, roles, collections and modules.
* Only use characters from the set `[a-z0-9_]`.
* Start variable names with a letter or underscore.
* Prefix role variables with the collection and/or role name.
* Prefix internal variables (those that are not expected to be set by users) by two underscores.


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
    cmd: |
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

* Ansible uses `snake_case` for module names and parameters. As this convention influences a wide range of playbooks, it is logical to extend it to variable names, even though they are not technically restricted to this format.
* Names of plugins, roles, and most parts of Ansible must follow Python namespace rules, which disallow certain characters, such as hyphens  (`-`) or dots (`.`). See [StackOverflow](https://stackoverflow.com/a/37831973), [Galaxy Issue 775](https://github.com/ansible/galaxy/issues/775), and a [comment from Issue 779](https://github.com/ansible/galaxy/issues/779#issuecomment-401632750) for more information:
  > For that to work, namespaces need to be Python compatible, which means they can’t contain ‘-’.
* Refer to the [Ansible Galaxy documentation on role names](https://galaxy.ansible.com/docs/contributing/creating_role.html#role-names) for additional guidance.
* Role variables, registered variables, and custom facts are not truly local—they persist globally and can pollute the namespace. Prefixing them with the role name reduces conflicts, while two underscores indicate they are internal. This applies to variables set by set_fact and register, as they remain after the role completes. The two underscores for internal variables is [a community convention](https://redhat-cop.github.io/automation-good-practices/#_naming_parameters).



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

* Using `true` / `false` prevents [the Norway problem](https://hitchdev.com/strictyaml/why/implicit-typing-removed/).
* YAML 1.2 only allows `true` / `false` as boolean literals. YAML 1.1 (which is less strict on this) is old and deprecated.



## Maps (`key: value`)<a id="maps"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Use only one space after the colon when specifying a key-value pair.
* Always use the map syntax, regardless of the number of pairs in the map.


**Good examples:**

```yaml
- name: "Start fail2ban"
  ansible.builtin.service:
    name: "fail2ban"
    state: "restarted"
    enabled: true


- name: "Create filter.d directory for easier fail2ban extension"
  ansible.builtin.file:
    group: "fail2ban"
    mode: "0755"
    owner: "fail2ban"
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
  ansible.builtin.file: "path:=/etc/fail2ban/filter.d state=directory group=fail2ban mode=0755 owner=fail2ban"


- name: "Copy sshd.conf to /etc/fail2ban/filter.d/"
  ansible.builtin.copy: "dest=/etc/fail2ban/filter.d/ src=files/filters/sshd.conf"
```


**Reasoning:**

* The map syntax is easier to read and less error-prone.
* Version control diffs are cleaner and more meaningful, as only new or changed parameters are highlighted.



### Value retrieval: bracket notation<a id="value-retrieval"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Use bracket notation for value retrieval.


**You SHOULD:**

* Refactor projects to use bracket notation instead of dot notation, provided the project maintainers agree.


**You MUST NOT:**

* Mix dot and bracket notation within the same project.


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


- name: "Nice Linux distribution? (prints: Fedora)"
  ansible.builtin.debug:
    msg: "{{ platforms[0]['name'] }}"


- name: "Ubuntu version used? (prints: 16.10)"
  ansible.builtin.debug:
    msg: "{{ platforms[1]['versions'][1] }}"

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

* Bracket notation makes it easier to distinguish between keys and attributes or methods of Python dictionaries. It also usually results in better editor highlighting.
* Bracket notation allows for seamless use of variables as keys.
* Dot notation can lead to issues because keys may collide with attributes or methods of Python dictionaries (e.g., `count`, `copy`, `title`, and others). Consistency is crucial, so it's better to stick with bracket notation rather than switching between the two options within a playbook.



## Facts<a id="facts"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Ensure roles and collections are compatible with playbooks using `gather_facts: false`.
* Use the `ansible_facts` dictionary to access facts (e.g., `ansible_facts['distribution']`).


**You MUST NOT:**

* Rely on the [`INJECT_FACTS_AS_VARS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#inject-facts-as-vars) setting being enabled.
* Use `ansible_<factname>` legacy variables (e.g., `ansible_distribution`) to access facts.


**Good examples:**

```yaml
- name: "Init | Gather role-specific facts"
  ansible.builtin.setup:
    gather_subset: "{{ __used_facts }}"
  vars:
    __used_facts:
      # from subset "distribution"
      - "distribution"
      - "distribution_major_version"
      - "distribution_version"
      - "os_family"
      # from subset "virtual"
      - "virtualization_role"
      - "virtualization_type"
  when:
    - not (__used_facts is subset(ansible_facts.keys()))


- name: "Debug | System introduction"
  ansible.builtin.debug:
    msg: >
      Hello 👋
      I am a {{ ansible_facts['distribution'] }} {{ ansible_facts['distribution_version'] }}
      (major {{ ansible_facts['distribution_major_version'] }}) box from the {{ ansible_facts['os_family'] }} family.
      I am running as a {{ ansible_facts['virtualization_role'] | default('bare-metal') }} on
      {{ ansible_facts['virtualization_type'] | default('physical hardware') }}.
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

* Fact gathering is slow and consumes resources. Disabling it globally with `gather_facts: false` is a legitimate optimization for administrators. Your code should not depend on externally defined behavior and should gather only the facts it needs.
* Gathering only specific facts using `ansible.builtin.setup` with `gather_subset` makes roles more robust and faster, as they explicitly declare and load their dependencies.
* The `ansible_<factname>` variables are legacy convenience variables. Using `ansible_facts['<factname>']` is the modern, explicit approach and makes it clear that you are accessing facts rather than regular variables.
* Compatibility with `INJECT_FACTS_AS_VARS = false` ensures playbooks work regardless of the Ansible configuration.
* The conditional `when: not (__used_facts is subset(ansible_facts.keys()))` ensures facts are only gathered if they are not already available, preventing redundant operations if another role or the playbook already gathered them.



## Conditionals<a id="conditionals"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Ensure all conditional expressions (`when`, `changed_when`, `failed_when`, `assert.that`) evaluate to actual boolean values, not truthy/falsy values.
* Use explicit boolean predicates instead of relying on implicit truthiness:
  * `myvar | length > 0` instead of just `myvar`
  * `myvar is defined` for existence checks
  * `myvar is truthy` or `myvar | bool` for explicit truthiness conversion
  * `myvar == 'value'` for string comparisons
* Quote conditional expressions containing `: ` (colon followed by space) to prevent YAML from parsing them as mappings.
* Use parentheses to control Jinja2 order of operations when using operators like `~` (concatenation) with tests.


**You MUST NOT:**

* Rely on implicit truthy evaluation of strings, lists, or dictionaries.
* Accidentally quote sub-expressions within a conditional (the quoted part becomes a literal string and is always truthy).


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


- name: "Check if hostname is set"
  ansible.builtin.assert:
    that:
      - inventory_hostname is defined
      - inventory_hostname | length > 0


- name: "Check message content"
  ansible.builtin.assert:
    that:
      # quote the whole expression to prevent YAML parsing ": " as a mapping
      - "result.msg == 'some_key: some_value'"


- name: "Check hostname contains pattern"
  ansible.builtin.assert:
    that:
      # parentheses ensure concatenation happens before the test
      - inventory_hostname is contains("local" ~ "host")


- name: "Run only if list is not empty"
  ansible.builtin.debug:
    msg: "List has items"
  when:
    - my_list | length > 0
```


**Bad examples:**

```yaml
# BAD: Relies on implicit truthy evaluation of a string
- name: "Check if hostname is set"
  ansible.builtin.assert:
    that:
      - inventory_hostname # this would be only valid if this variable would be a boolean


# BAD: Second part is accidentally quoted, always evaluates to True
- name: "Check if hostname is valid"
  ansible.builtin.assert:
    that:
      - inventory_hostname is defined and 'inventory_hostname | length > 0'


# BAD: Unquoted colon+space is parsed as YAML mapping, always truthy
- name: "Check message content"
  ansible.builtin.assert:
    that:
      - result.msg == "some_key: some_value"


# BAD: Without parentheses, ~ is evaluated after the test, result is "Truehost"
- name: "Check hostname contains pattern"
  ansible.builtin.assert:
    that:
      - inventory_hostname is contains "local" ~ "host"
```


**Reasoning:**

* Python and Jinja2 provide implicit "truthy" evaluation of most non-empty, non-boolean values. While sometimes convenient, this often masks serious logic errors.
* Ansible 12 enforces boolean results for conditionals by default. Non-boolean results now [raise an error (like `Conditional result (<True|False>) was derived from value of type '<Type>'`)]((https://docs.ansible.com/ansible/latest/porting_guides/porting_guide_12.html#broken-conditionals)) instead of being silently evaluated as truthy.
* Writing explicit boolean predicates makes the intent clear and prevents subtle bugs that are hard to diagnose.
* YAML interprets unquoted strings containing `: ` as mappings. Since non-empty mappings are truthy, this silently breaks comparisons. Quoting the entire expression prevents this.



### Formatting<a id="conditionals-formatting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Always use the list format for `when`, `changed_when`, and `failed_when` conditions, even for single conditions.
* Place the pipe operator (`|`) at the beginning of continuation lines for long piped expressions.
* Break lines after unparenthesized `or` operators.
* Avoid chaining unparenthesized `and` operators; use separate list entries instead.


**Good examples:**

```yaml
# Single condition in list format
- name: "Check Ansible version"
  ansible.builtin.assert:
    that:
      - ansible_version['full'] is version(foobar_meta['galaxy_info']['min_ansible_version'], "<")


# Multiple 'or' conditions with line breaks after each 'or'
- name: "Check distribution info"
  ansible.builtin.debug:
    msg: "Distribution info missing or no platforms defined"
  when:
    - ansible_facts['distribution'] is not defined or
      ansible_facts['distribution_version'] is not defined or
      (foobar_meta['galaxy_info']['platforms'] | length) < 1


# Complex piped expressions with '|' at the beginning of continuation lines
- name: "Check platform support"
  ansible.builtin.fail:
    msg: "Platform not supported"
  when:
    - (foobar_meta['galaxy_info']['platforms'] | length) > 0
    - ansible_facts['distribution'] is not defined or
      ansible_facts['distribution_version'] is not defined or
      (foobar_meta['galaxy_info']['platforms'] | length) < 1
    - (foobar_meta['galaxy_info']['platforms']
       | selectattr('name', 'match', '^' ~ ansible_facts['distribution'] ~ '$')
       | map(attribute='versions') | flatten
       | select('match', '^(' ~ ansible_facts['distribution_version'] ~ '|all)$', ignorecase=true)
       | list | length) < 1


# Multiple 'and' conditions as separate list entries
- name: "Run when all conditions are met"
  ansible.builtin.debug:
    msg: "All conditions met"
  when:
    - condition_a
    - condition_b
    - condition_c
```


**Bad examples:**

```yaml
# BAD: Not using list format
- name: "Check Ansible version"
  ansible.builtin.assert:
    that:
      - ansible_version['full'] is version(foobar_meta['galaxy_info']['min_ansible_version'], "<")
  when: ansible_facts['distribution'] is defined


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
    - (foobar_meta['galaxy_info']['platforms'] | selectattr('name', 'match', '^' ~ ansible_facts['distribution'] ~ '$') |
       map(attribute='versions') | flatten | list | length) < 1
```


**Reasoning:**

* Using list format for all conditions ensures cleaner diffs when adding or removing conditions, making changes more readable and easier to review.
* Placing the pipe operator at the beginning of continuation lines improves readability by making the data flow through filters immediately visible.
* Breaking lines after `or` operators and using separate list entries for `and` conditions creates a consistent, scannable structure that reflects the logical grouping.



## Tasks and play declaration<a id="tasks-plays"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

* Use `name:` as the first key for plays, tasks and handlers.
* Begin all names with an uppercase letter.
* Use the `block`, `rescue` and `always` as the last key on tasks.


**You SHOULD:**

* Arrange keys in tasks to follow this general order (omit any keys that are not needed):
  1. Attributes defining what the task is, where to run it and what its parameters are:
     - `name`: Always first, providing a clear description of what the task does.
     - `delegate_to`
     - `become`
     - `module`: The actual action.
       * Place primary, mandatory module parameters (e.g., `name`, `state`, `path`) directly under the module name for clarity.
       * Arrange all other, optional module parameters in alphabetical order, unless doing so negatively impacts readability or logic.
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
  6. `tags`
* Always use a list format for `when`, `changed_when`, and `failed_when`, even if there is only one condition.
* If it is necessary to make task names dynamic, do so by appending `{{ variables }}` at the end of the string.
* The `include_*` and `import_*` statements are not treated differently from other tasks/plays. This clarification is included because many other style guides impose separate rules for these.


**You MUST NOT:**

* Use variables (wrapped in Jinja2 templates) in play names (the `name` attribute of a playbook), as they do not expand properly.
* Use loop variables (e.g., the default `item`) in task names within a loop, as they also do not expand properly.


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


        - name: "Get basic information from 'linux_container' hosts"
          delegate_to: "{{ item }}"
          # ansible.builtin.raw instead of ansible.builtin.command as it works
          # without any existing python on the target
          ansible.builtin.raw: |
            /usr/bin/grep "PRETTY" /etc/os-release; /usr/bin/uname -r;
          args:
            executable: "/bin/bash"
          changed_when: false
          failed_when: false
          loop: "{{ groups['linux_container'] }}"
          loop_control:
            label: "{{ item }}"
          register: __basicinfo_result


        - name: "Show basic information from 'linux_container' hosts"
          ansible.builtin.debug:
            msg: "{{ processed_result.split('\n') }}"
          vars:
            processed_result: |-
              {% for result in __basicinfo_result.results %}
              Host: {{ result.item }} - {{ result.stdout_lines | default(['No output']) | join(', ') }}
              {% endfor %}
          when:
            - __basicinfo_result is defined
            - __basicinfo_result.results is defined
            - __basicinfo_result.results[0].stdout_lines is defined
          run_once: true


    - name: "Install nginx"
      ansible.builtin.apt:
        name: "nginx"
        state: "present"
      when:
        - ansible_os_family == 'RedHat'


    - name: "Create some EC2 Instances"
      amazon.aws.ec2_instance:
        image: "ami-c7d092f7"
        assign_public_ip: true
        key_name: "my_key"
        instance_tags:
          name: "{{ item }}"
      when:
        - ansible_os_family == 'RedHat'
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
        - ansible_os_family == 'RedHat'
      changed_when: false
      failed_when: false
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

* Well-defined parameter rules are helping to create consistent code. Version control diffs are cleaner and more meaningful, as only new or changed parameters are highlighted.
* The proposed ordering creates a logical flow: "what the task is and where to run it" → "when to run it" → "how to process results" → "what to do afterwards". `register:` is placed after loops since the registered variable structure depends on whether loops are used.
* Keep in mind that using variables in task names can make it harder for users to correlate logs with the corresponding code when searching for an actual variable value (e.g., `/dev/foo gets managed as device` instead of `{{ device_name }} gets managed as device`). Placing the variable part at the end of a task name improves log readability and makes it easier to search for the corresponding code.
* The reasoning of the [Ansible Lint rule: `key-order`](https://ansible.readthedocs.io/projects/lint/rules/key-order/#correct-code).
* Further discussion:
  * [Ansible Lint: ansible lint should check order of tasks attributes for when and name #578](https://github.com/ansible/ansible-lint/issues/578). Many people at Red Hat place `when:` immediately after `name:`. This is a subjective choice and we think our approach of grouping it with other control attributes is logical and the `name:` as well as the module describe what is done *together* as a unit.



### Handlers<a id="handlers"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Use `listen` to trigger handlers instead of relying on the handler's `name`.
* Always use list notation for `listen` values.
* Use all lowercase for `listen` values.


**You SHOULD:**

* When refactoring existing code that uses different notation, add the old value as an alias with a comment for backwards compatibility.


**Good examples:**

```yaml
# In handlers/main.yml
- name: "Restart NGINX service"
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  listen:
    - "restart nginx"


- name: "Reload NGINX configuration"
  ansible.builtin.service:
    name: "nginx"
    state: "reloaded"
  listen:
    - "reload nginx"


# Handler with backwards-compatible alias during refactoring
- name: "Restart application service"
  ansible.builtin.service:
    name: "myapp"
    state: "restarted"
  listen:
    - "restart myapp"
    - "Restart MyApp"  # legacy alias, remove after full migration


# In tasks/main.yml - triggering handlers via listen value
- name: "Update NGINX configuration"
  ansible.builtin.template:
    src: "nginx.conf.j2"
    dest: "/etc/nginx/nginx.conf"
  notify:
    - "reload nginx"
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
  listen: "restart nginx"  # should be a list


# BAD: Mixed case in listen value
- name: "Restart NGINX service"
  ansible.builtin.service:
    name: "nginx"
    state: "restarted"
  listen:
    - "Restart Nginx"  # should be all lowercase
```


**Reasoning:**

* Handler names must be unique within a play, while multiple handlers can share the same `listen` value. This allows one notification to trigger multiple handlers.
* Using `listen` decouples the trigger mechanism from the display name, making maintenance easier and allowing names to follow their own readability rules without affecting notification logic.
* List notation signals that multiple trigger aliases are supported and maintains consistency with other list-based attributes.
* Lowercase values prevent case-sensitivity issues and ensure consistent matching across the codebase.



## External commands<a id="external-commands"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This section covers the use of [`ansible.builtin.command`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html) and [`ansible.builtin.shell`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html) modules.


**You MUST:**

* Use dedicated Ansible modules instead of shell commands when available (e.g., `ansible.builtin.apt` instead of `apt-get`, `ansible.builtin.file` instead of `mkdir`).
* Prefer `ansible.builtin.command` over `ansible.builtin.shell` unless shell features (pipes, redirects, globbing, environment variable expansion) are required.
* When using the `cmd` attribute with variables, apply the [`quote` filter](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/quote_filter.html) to prevent command injection: `{{ myvar | ansible.builtin.quote }}`
* Include a comment explaining why `command` or `shell` is necessary instead of a dedicated module (see [Comments](#comments)).


**You SHOULD:**

* Use the `argv` attribute (list) instead of `cmd` for `ansible.builtin.command`:
  * Avoids quoting issues entirely.
  * Allows comments above individual parameters.
  * Easier to build command arguments conditionally from variables.
* Use `creates` or `removes` parameters to achieve idempotency when the command creates or removes files.
* Set `changed_when` and/or `failed_when` to properly reflect command outcomes.


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
  vars:
    __migration_cmd:
      - "/usr/bin/myapp"
      - "migrate"
      - "--database={{ database_name }}"  # argv doesn't need quote filter - no shell parsing involved
  changed_when:
    - __migration_result is success
    - "'No migrations to apply' not in __migration_result['stdout']"
  register: __migration_result


# When shell is necessary (pipes, redirects) - use quote filter for variables
- name: "Find and count log files"
  ansible.builtin.shell:
    cmd: >-
      find /var/log -name '*.log' -mtime +{{ log_retention_days | ansible.builtin.quote }} | wc -l
  changed_when: false
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

* Dedicated Ansible modules are idempotent by design, provide better error handling, and integrate properly with Ansible's change detection and check mode.
* [`ansible.builtin.command`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/command_module.html) executes commands directly without a shell, avoiding shell injection vulnerabilities and unexpected shell interpretation.
* [`ansible.builtin.shell`](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/shell_module.html) spawns a shell process, which is necessary for shell features but introduces security risks if variables are not properly quoted.
* The `argv` attribute passes arguments directly to the executable without shell parsing, eliminating all quoting issues and making the command structure explicit.
* The [`quote` filter](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/quote_filter.html) escapes special characters to prevent command injection when variables contain user-controlled or untrusted data.



## Comments<a id="comments"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Provide explanations for role and collection variables using comments in `/defaults` or `/vars` where they are defined.
* Whenever [`ansible.builtin.command`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/command_module.html) or [`ansible.builtin.shell`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/shell_module.html) modules are used, include a comment with a justification why they are needed to aid future maintenance.


**You SHOULD:**

* Use descriptive enough `name` values to tell what a task does instead of comments whenever possible.
* Keep multi-line comments below 80 characters per line (excluding indentation).


**Reasoning:**

* Good, descriptive `name` values also produce valuable output for the user, as comments are not displayed."
* Variables documented in the `/defaults` or `/vars` directories do not require explanation within the playbooks themselves.



## Linting<a id="linting"></a>

**You MUST:**

* Check your playbooks, collections, roles, and other applicable files with [`ansible-lint --profile production --strict --skip-list use-loop`](https://docs.ansible.com/ansible-lint/).


**Reasoning:**

* Ansible Lint is an official project by the Ansible Core Team and is widely adopted. It can be run offline and provides a command-line tool for linting playbooks, helping to identify areas for potential improvement. Following its recommendations promotes consistent, high-quality code.
* Ansible Lint automatically [runs `ansible-playbook --syntax-check`](https://ansible.readthedocs.io/projects/lint/rules/syntax-check/).
* `with_*` deprecation is still [under discussion](https://github.com/ansible/ansible-lint/issues/2204).



## Miscellaneous<a id="misc"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

* Ensure that all tasks are idempotent.
* Avoid overriding role defaults, variables, or input parameters using `set_fact`. Instead, use a distinct variable name.
* Do not use `meta: end_play`, as it terminates the entire play rather than just the tasks for a specific host (when working with multiple hosts in the inventory). If absolutely necessary, consider using `meta: end_host` instead.
* Limit the use of the [`ansible.builtin.copy`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/copy_module.html) module to scenarios such as copying remote files, static files, or uploading binary blobs. For most file operations, prefer using [`ansible.builtin.template`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html). Even if the file currently does not require templating, this preemptively simplifies future updates, especially when templating functionality needs to be added later.
* When using the [`ansible.builtin.template`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/template_module.html) module, append `.j2` to the template file name for clarity and convention.
* [Use tags with caution](https://redhat-cop.github.io/automation-good-practices/#_use_tags_cautiously_either_for_roles_or_for_complete_purposes).
* [Use the verbosity parameter with debug statements](https://redhat-cop.github.io/automation-good-practices/#_use_the_verbosity_parameter_with_debug_statements).



## Linguistic guidelines<a id="linguistic-guidelines"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

* Follow the official [Ansible Developers Style Guide](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/index.html).
* Follow [Spelling - Word Usage - Common Words and Phrases to Use and Avoid](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/spelling_word_choice.html) recommendations.


Excerpt of the **most important rules**:

* Headers should be written in sentence case. For example, this section's title is `Header case`, not `Header Case` or `HEADER CASE`.
* [Stylistic cheat-sheet](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/index.html#stylistic-cheat-sheet):

  | Rule                  | Good Example            | Bad Example                |
  |-----------------------|-------------------------|----------------------------|
  | Use active voice      | You can run a task by   | A task can be run by       |
  | Use the present tense | This command creates a  | This command will create a |
  | Use standard English  | Return to this page     | Hop back to this page      |
  | Use American English  | The color of the output | The colour of the output   |


**Reasoning:**

The official rules are based on experience of technical writers. As these are also rules for Ansible developers, they are influencing the whole community. It makes sense to apply them in-house to have a consistent user experience.



## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust, readable and consistent code. It was inspired by [Whitecloud Analytics's Ansible styleguide](https://github.com/whitecloud/ansible-styleguide).
