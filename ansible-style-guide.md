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
* [Tasks and play declaration](#tasks-plays)
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
* If a `when:` condition contains only `and` expressions, break it into a list of conditions for better readability.
* Keep content around 80 characters in length, and ensure the overall line length, including indentation, stays below 120 characters.
  * Use [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`) as needed to manage long strings.
  * Include a chomping indicator (`-`) behind [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`) when it is important to exclude the trailing newline from the string (e.g., when defining a string variable).
* Use parentheses and new lines to group conditions when it helps to clarify the logic. When in doubt, use parentheses if there are multiple `and` or `or` operators.



**Good examples:**

```yaml
# Connect to the host and checks for an Python installation. Show demo tasks.
#
# Example usage:
#   ansible-playbook -e ping_data_return="pong" playbook.yml
#   ansible-playbook -e ping_data_return="crash" playbook.yml

---

- name: "Example playbook"
  hosts: localhost
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
      register: shutdown_result
      when:
        - ansible_distribution is defined
        - ansible_distribution_major_version is defined
        - (ansible_distribution == 'CentOS' and ansible_distribution_version is version('8.0.0', '>=')) or
          (ansible_distribution == 'Debian' and ansible_distribution_major_version == '10')
      changed_when:
        - shutdown_result.rc is defined
        - shutdown_result.rc == 0


    - name: "Include OS vars (with default fallback)"
      ansible.builtin.include_vars:
        dir: "vars"
        files_matching: "^({{ ansible_distribution }}|default)(\\{{ lookup('ansible.builtin.config', 'YAML_FILENAME_EXTENSIONS') | join('|\\\\') }})$"

# newline (Unix line feed, \n) at end of file

```


**Bad examples:**

```yaml
---
- hosts: localhost
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
* Add at least two blank line between:
  * Two task blocks.
* Use a single space to separate Jinja2 template markers from variable names or expressions.
* Break up lengthy Jinja templates into multiple templates when they contain distinct logical sections.
* Avoid Jinja templates for generating text and semi-structured data, not for creating structured data.


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
  ansible.builtin.service:
    name: "{{ item['node_name'] }}"
    state: "started"
    enabled: true
  with_items: "{{ nodes }}"
  become: true


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
  when: ansible_os_family == 'Fedora'


# variables example 3
- name: "Set another variable"
  ansible.builtin.set_fact:
    baz: "{{ foo }}" # explicitly references the variable foo
```


**Bad examples:**

```yaml
- name: Start node named Horton
  ansible.builtin.service:
    name: horton
    state: 'started'
    enabled: true
  become: true


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
  * [Ansible Lint: add rule to prefer double quotes intead of single (like black) #584](https://github.com/ansible/ansible-lint/discussions/584)
  * [YAML: Do I need quotes for strings in YAML?](https://stackoverflow.com/questions/19109912/yaml-do-i-need-quotes-for-strings-in-yaml)



## Naming<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

* Use [`snake_case`](https://en.wikipedia.org/wiki/Snake_case) for variables, roles, collections and modules.
* Only use characters from the set `[a-z0-9_]`.
* Start variable names with a letter.


**Good examples:**

```yaml
- name: "set some facts"
  ansible.builtin.set_fact:
    node_is_online: true
    node_age: 20
    node_name: "test"
    one_and_only: false
```


**Bad examples:**

```yaml
- name: "Set some facts"
  ansible.builtin.set_fact:
    nodeIsOnline: true
    nodeage: 20
    NODE_NAME: "test"
    1andOnly: False
```


**Reasoning:**

* Ansible uses `snake_case` for module names and parameters. As this convention influences a wide range of playbooks, it is logical to extend it to variable names, even though they are not technically restricted to this format.
* Names of plugins, roles, and most parts of Ansible must follow Python namespace rules, which disallow certain characters, such as hyphens  (`-`) or dots (`.`). See [StackOverflow](https://stackoverflow.com/a/37831973), [Galaxy Issue 775](https://github.com/ansible/galaxy/issues/775), and a [comment from Issue 779](https://github.com/ansible/galaxy/issues/779#issuecomment-401632750) for more information:
  > For that to work, namespaces need to be Python compatible, which means they can’t contain ‘-’.
*  Refer to the [Ansible Galaxy documentation on role names](https://galaxy.ansible.com/docs/contributing/creating_role.html#role-names) for additional guidance.



## Booleans<a id="booleans"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:** use `true` and `false` only (all lowercase without quotes).


**Good examples:**

```yaml
- name: "Start fail2ban"
  ansible.builtin.service:
    name: "fail2ban"
    state: "restarted"
    enabled: true
  become: true
```


**Bad examples:**

```yaml
- name: "Start fail2ban"
  ansible.builtin.service:
    name: "fail2ban"
    state: "restarted"
    enabled: 1
  become: 'yes'
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
  become: true


- name: "Create filter.d directory for easier fail2ban extension"
  ansible.builtin.file:
    group: "fail2ban"
    mode: "0755"
    owner: "fail2ban"
    path: "/etc/fail2ban/filter.d"
    state: "directory"
  become: true


- name: "Copy sshd.conf to /etc/fail2ban/filter.d/"
  ansible.builtin.copy:
    dest: "/etc/fail2ban/filter.d/"
    src: "files/filters/sshd.conf"
  become: true
```


**Bad examples:**

```yaml
- name: "Start fail2ban"
  ansible.builtin.service:
    name    : "fail2ban"
    state   : "restarted"
    enabled : true
  become : true


- name: "Create filter.d directory for easier fail2ban extension"
  ansible.builtin.file: "path:=/etc/fail2ban/filter.d state=directory group=fail2ban mode=0755 owner=fail2ban"
  become: true


- name: "Copy sshd.conf to /etc/fail2ban/filter.d/"
  ansible.builtin.copy: "dest=/etc/fail2ban/filter.d/ src=files/filters/sshd.conf"
  become: true
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
* Dot notation can lead to issues because keys may collide with attributes or methods of Python dictionaries (e.g., `count`, `copy`, `title`, and others). Consistency is crucial, so it’s better to stick with bracket notation rather than switching between the two options within a playbook.



## Tasks and play declaration<a id="tasks-plays"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

* Use `name:` as the first key for plays, tasks and handlers.
* Use the module name (for example `ansible.builtin.debug`) as the second parameter of a task.
* Use the `block`, `rescue` and `always` as the last key on tasks.


**You SHOULD:**

* Begin all names with an uppercase letter.
* Make task names dynamic, if necessary, by appending `{{ variables }}` at the end of the string.
* Arrange keys in tasks to follow this general order (omit any keys that are not needed):
  1. `name`
  2. `module`
     * Place primary, mandatory module parameters (e.g., `name`, `state`, `path`) directly under the module name for clarity.
     * Arrange all other, optional module parameters in alphabetical order, unless doing so negatively impacts readability or logic.
  3. Loop operators (e.g., `loop`, `with_items`, or `with_fileglob`).
  4. `register`
  5. Other common keys (e.g., `become`), arranged in alphabetical order.
  6. Control attributes:
     - `when`, `changed_when`, `failed_when`, and `ignore_errors` (in this specific order).
     - Use a list format for `when`, `changed_when`, and `failed_when`, even if there is only one condition.
  7. `tags`
     - Use a list format, even if there is only one tag.

The `include_*` and `import_*` statements are not treated differently from other tasks/plays. This clarification is included because many other style guides impose separate rules for these.


**You MUST NOT:**

* Use variables (wrapped in Jinja2 templates) in play names (the `name` attribute of a playbook), as they do not expand properly.
* Use loop variables (e.g., the default `item`) in task names within a loop, as they also do not expand properly.


**Good examples:**

```yaml
---
- name: "A cool playbook"
  hosts: localhost
  tasks:
    - name: "A block"
      when: true
      block: # last key, even after "when:" to prevent indentation errors
        - name: "Display a message"
          ansible.builtin.debug:
            msg: "Hello world!"


    - name: "Install Nginx"
      ansible.builtin.apt:
        name: "nginx"
        state: "present"
      when:
        - ansible_os_family == 'Fedora'


    - name: "Create some EC2 Instances"
      amazon.aws.ec2_instance:
        image: "ami-c7d092f7"
        assign_public_ip: true
        key_name: "my_key"
        instance_tags:
          name: "{{ item }}"
      with_items: "{{ instance_names }}"
      ignore_errors: true
      register: ec2_output
      when:
        - ansible_os_family == 'Fedora'
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
        - ansible_os_family == 'Fedora'
      changed_when: false
      failed_when: false

```


**Bad examples:**

```yaml

---

- hosts: localhost
  name: "A cool playbook" # should be the first one
  tasks:
    - name: "A block"
      block:
        - name: "Display a message"
          ansible.builtin.debug:
            msg: "Hello world!"
      when: true # when key should be before block


  - name: "Create some EC2 Instances"
    when: ansible_os_family == 'Fedora'
    tags: "ec2"
    amazon.aws.ec2_instance: "image=ami-c7d092f7 assign_public_ip=true"
    register: ec2_output
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
* Keep in mind that using variables in task names can make it harder for users to correlate logs with the corresponding code when searching for an actual variable value (e.g., `/dev/foo gets managed as device` instead of `{{ device_name }} gets managed as device`). Placing the variable part at the end of a task name improves log readability and makes it easier to search for the corresponding code.
* The reasoning of the [Ansible Lint rule: `key-order`](https://ansible.readthedocs.io/projects/lint/rules/key-order/#correct-code).
* Further discussion:
  * [Ansible Lint: ansible lint should check order of tasks attributes for when and name #578](https://github.com/ansible/ansible-lint/issues/578)



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

  | Rule                  | Good Exmaple            | Bad Example                |
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
