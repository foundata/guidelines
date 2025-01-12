# Ansible style guide (playbooks)

This document defines the style to follow when writing Ansible playbooks. Refer to [`ansible-style-guide-example.yml`](ansible-style-guide-example.yml) for rules illustrated in code and for further clarification.

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

* [YAML files](#yaml-files)
* [Indentation](#indentation)
* [Spacing](#spacing)
* [Quoting](#quoting)
* [Naming of variables, roles, plugins and modules](#naming)
* [Booleans](#booleans)
* [Maps (`key: value`)](#maps)
  * [Value retrieval: bracket notation](#value-retrieval)
* [Hosts declaration](#hosts)
* [Tasks and play declaration](#tasks-plays)
* [Ansible lint](#linting)
* [Linguistic guidelines](#linguistic-guidelines)
* [Reasoning](#reasoning)
* [Author information](#author-information)



## YAML files<a id="yaml-files"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST**

* Follow the [YAML 1.2.2 specification](https://yaml.org/spec/1.2.2/).
* Use spaces for [indentation](https://yaml.org/spec/1.2.2/#61-indentation-spaces).
* Use Unix line feed (LF, `\n`) for new lines.
* Use [UTF-8 encoding](https://yaml.org/spec/1.2.2/#52-character-encodings).
* Trim trailing whitespace whenever possible, but end your files with a new line.
* Keep the line length below 160 characters whenever technically possible.
* Use JSON syntax only when it makes sense (e.g., for an automatically generated file) or when it improves readability.

**You SHOULD**

* Use `.yml` as the extension for new roles and collections.
  * Stay consistent with existing extensions if `.yaml` is already used in a role.
* Start scripts with comments explaining their purpose, including example usage if necessary.
* Include blank lines around the `---` separator, followed by the rest of the file.
* Check all [`YAML_FILENAME_EXTENSIONS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#yaml-filename-extensions) when searching for files (e.g., `vars_files`, `include_vars`, plugins, or similar functions).
* Keep the line length below 120 characters.
  * Use [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`) as needed to manage long strings.
  * Include a chomping indicator (`>-`) when it is important to exclude the trailing newline from the string (e.g., when defining a string variable).
  * If a `when:` condition results in a long line and contains an and expression, break it into a list of conditions for better readability.


**Good examples:**

```yaml
# The playbook connects to the host and checks for an existing, usable Python installation.
#
# Example usage:
#   ansible-playbook -e ping_data_return="pong" playbook.yml
#   ansible-playbook -e ping_data_return="crash" playbook.yml

---

- hosts: localhost
  tasks:

    - name: "Connect to host, verify a Python installation."
      ansible.builtin.ping:
        data: "{{ ping_data_return }}"

    - name: "Print a very long line"
      ansible.builtin.debug:
        msg: >
          Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et
          dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet
          clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet,
          consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat,
          sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no
          sea takimata sanctus est Lorem ipsum dolor sit amet.
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
```


**Reasoning:**

* YAML 1.2 has been the standard since 2009 and uses only `true` and `false` for booleans, avoiding many potential edge-case issues. Allowing YAML 1.1 is no longer practical.
* The `.yml` extension must be used for consistency. It is predominant in the Ansible ecosystem, even though [yaml.org](https://yaml.org/faq.html) recommends `.yaml`.
* Adding comments at the very beginning of a file allows for quickly identifying the purpose or usage of a script, either by opening the file or using the `head` command.
* Ending files with a new line is a common Unix best practice. It prevents terminal prompt misalignment when printing files to, for example, STDOUT.
* Long lines are difficult to read. Many projects ask for a line length limit around 120-150 character and [`ansible-lint`](#linting) checks for 160 characters by default ([yaml rule](https://ansible.readthedocs.io/projects/lint/rules/yaml/)).
* Even though JSON is syntactically valid YAML and understood by Ansible, nobody expects it in playbooks.



## Indentation<a id="indentation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST**

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

**You SHOULD**

* Add blank lines between:
  * Two host blocks.
  * Two task blocks.
  * Host and include blocks.
* Use a single space to separate Jinja2 template markers from variable names or expressions.
* Break up lengthy Jinja templates into multiple templates when they contain distinct logical sections.
* Avoid Jinja templates for generating text and semi-structured data, not for creating structured data.

Refer to [`ansible-style-guide-example.yml`](ansible-style-guide-example.yml) for a more detailed example of proper spacing and other best practices.


**Reasoning:**

Following the spacing rules produces consistent code that is easy to read.


**Good examples:**

```yaml
---
- hosts: localhost
  tasks:

  - name: "Set a variable"
    ansible.builtin.set_fact:
      foo: "{{ bar | default('baz') }}"

  - name: "Set another variable"
    ansible.builtin.set_fact:
      bar: "{{ baz | default('foo, barbaz') }}"
```


**Bad examples:**

```yaml
---
- hosts: localhost
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


**You MUST**

* Quote all strings.
* Use [block scalars](https://yaml-multiline.info/#block-scalars) (`>` and `|`) for writing long strings or to simplify complicated quoting.
* Quote an entire value if it starts with `{{`.


**You SHOULD**

* Prefer double quotes (`"`) over single quotes (`'`). Use single quotes only when they simplify nested expressions, such as Jinja map references with mixed quoting styles.


**You MUST NOT**

* Quote non-string types, such as booleans (`true`, `false`) or numbers (e.g., `1337`).
* Quote references to the local Ansible environment, such as the names of variables being assigned values.

Refer to [`ansible-style-guide-example.yml`](ansible-style-guide-example.yml) for a detailed example of proper quoting and other best practices.


**Good Examples:**

```yaml

# good
- name: "Connect to host, verify a usable python"
  ansible.builtin.ping:
    data: "{{ ping_return }}"


# double quotes with nested single quotes
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
  with_items: nodes


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
    foo: "bar"


# variables example 2
- name: "Print a variable"
  ansible.builtin.debug:
    var: foo
  when: ansible_os_family == "Fedora"


# variables example 3
- name: "set another variable"
  ansible.builtin.set_fact:
    baz: "{{ foo }}"
```


**Bad examples:**

```yaml
- name: Start node named Horton
  ansible.builtin.service:
    name: horton
    state: 'started'
    enabled: true
  become: true
```


**Reasoning:**

* Single quotes in YAML behave differently than most programmers expect:
  * Escaping with `\` is **not** possible; instead, `''` (two single quotes) is used.
  * They do **not** prevent variable interpolation.
* Properly escaping strings makes it easier to troubleshoot malformed strings and ensures the desired effect.
* YAML requires you to quote the entire line if it starts with `{{ foo }}` to distinguish between a value and a YAML dictionary.
*-* Syntax highlighting generally works better when strings are explicitly quoted.



## Naming of variables, roles, plugins and modules<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST**

* Use [`snake_case`](https://en.wikipedia.org/wiki/Snake_case).
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

* Ansible uses `snake_case` for module names and parameters. Since this convention influences a wide range of playbooks, it makes sense to extend it to variable names, even though they are not technically restricted to this format.
* Names of plugins and roles and most parts of Ansible  must follow the rules of the Python namespace, which does not allow certain characters, such as hyphens (`-`) or dots (`.`). See [StackOverflow](https://stackoverflow.com/a/37831973), [Galaxy Issue 775](https://github.com/ansible/galaxy/issues/775), and a [comment from Issue 779](https://github.com/ansible/galaxy/issues/779#issuecomment-401632750) for more information:
  > For that to work, namespaces need to be Python compatible, which means they can’t contain ‘-’.
*  Refer to the [Ansible Galaxy documentation on role names](https://galaxy.ansible.com/docs/contributing/creating_role.html#role-names) for additional guidance.



## Booleans<a id="booleans"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST** use `true` and `false` only (all lowercase without quotes).


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

* Using only `true`/`false` prevents [the Norway problem](https://hitchdev.com/strictyaml/why/implicit-typing-removed/).
* YAML 1.2 only allows `true`/`false` as boolean literals. YAML 1.1 (which is less strict on this) is old and deprecated.



## Maps (`key: value`)<a id="maps"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST**

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

**You MUST**

* Use bracket notation for value retrieval.


**You SHOULD**

* Refactor projects to use bracket notation instead of dot notation, provided the project maintainers agree.


**You MUST NOT**

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



## Hosts declaration<a id="hosts"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A `hosts` section declaration **SHOULD follow** this general order:

1. `hosts`
2. options in alphabetical order
3. `pre_tasks`
4. `roles`
5. `tasks`


**Good examples:**

```yaml
- hosts: "webnodes"
  remote_user: "nginx"
  vars:
    nginx_state: "started"
  pre_tasks:
    - name: "Set the timezone to Europe/Berlin"
      ansible.builtin.lineinfile:
        dest: "/etc/environment"
        line: "TZ=Europe/Berlin"
        state: "present"
      become: true
  roles:
    - { role: "nginx", tags: [ "nginx", "webserver" ] }
  tasks:
    - name: "start the NGINX service"
      ansible.builtin.service:
        name: "nginx"
        state: "{{ nginx_state }}"
```


**Reasoning:**

Well-defined parameter rules are helping to create consistent code.



## Tasks and play declaration<a id="tasks-plays"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


A task/play declaration **SHOULD follow** this general order:

1. `name`
2. `module` (for example `service`)
3. module parameters in map declaration, alphabetical order
4. loop operator (for example `with_items` or `with_fileglob`)
5. task options in alphabetical order (for example `become`, `ignore_errors`, `register`) except `when` and `tags`
5. `when`
6. `tags`

Just omit points which do not apply.

Please note that `include_*` or `import_*`  do not differ from others tasks/plays (just to mention as many style guides out there are having separate rules for them).

If needed, task names can be made dynamic by using variables wrapped in Jinja2 templates *at the end* of the string.


**You MUST NOT**

* Use variables (wrapped in Jinja2 templates) in play names, as they do not expand properly.
* Use loop variables (e.g., the default `item`) in task names within a loop, as they also do not expand properly.


**Good examples:**

```yaml
- name: "Create some EC2 Instances"
  amazon.aws.ec2_instance:
    assign_public_ip: true
    image: "ami-c7d092f7"
    instance_tags:
      name: "{{ item }}"
    key_name: "my_key"
  with_items: "{{ instance_names }}"
  ignore_errors: true
  register: ec2_output
  when: ansible_os_family == "Fedora"
  tags: "ec2"


- name: "Include tasks to setup the managed software"
  ansible.builtin.include_tasks: "setup.yml"
  tags: "setup"


- name: "Include tasks to configure the managed software"
  ansible.builtin.include_tasks: "config.yml"

- name: "Include tasks to cleanup"
  ansible.builtin.include_tasks: "cleanup.yml"
  tags: [ "always", "cleanup" ]

- name: "Manage device {{ device_name }}"
  foo.module:
    device: "{{ device_name }}"
```


**Bad examples:**

```yaml
- name: "Create some EC2 Instances"
  when: ansible_os_family == "Fedora"
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
  foo.module:
    device: "{{ device_name }}"
```


**Reasoning:**

* Well-defined parameter rules are helping to create consistent code. Version control diffs are cleaner and more meaningful, as only new or changed parameters are highlighted.
* Keep in mind that using variables in task names can make it harder for users to correlate logs with the corresponding code when searching for an actual variable value (e.g., `/dev/foo gets managed as device` instead of `{{ device_name }} gets managed as device`). Placing the variable part at the end of a task name improves log readability and makes it easier to search for the corresponding code.



## Ansible lint<a id="linting"></a>

You MUST check your playbooks, collections, roles, and other applicable files with [`ansible-lint`](https://docs.ansible.com/ansible-lint/).


**Reasoning:**

Ansible Lint is an official project by the Ansible Core Team and is widely adopted. It can be run offline and provides a command-line tool for linting playbooks, helping to identify areas for potential improvement. Following its recommendations promotes consistent, high-quality code.



## Linguistic guidelines<a id="linguistic-guidelines"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

You **SHOULD**

* follow the official [Ansible Developers Style Guide](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/index.html)
* follow [Spelling - Word Usage - Common Words and Phrases to Use and Avoid](https://docs.ansible.com/ansible/latest/dev_guide/style_guide/spelling_word_choice.html) recommendations.


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



## Reasoning<a id="reasoning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

According to Read Hat and most of the Ansible community, one should refer to the following resources when developing:

* [Red Hat's Coding Style Good Practices for Ansible](https://github.com/redhat-cop/automation-good-practices/blob/main/coding_style/README.adoc#ansible-guidelines)
* [Best Practices of the Ansible User Guide](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

However, neither these resources nor the [Ansible documentation](https://docs.ansible.com/ansible/latest) in general follow a consistent code style or define one comprehensively. This document addresses that gap.



## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust, readable and consistent code. It was inspired by [Whitecloud Analytics's Ansible styleguide](https://github.com/whitecloud/ansible-styleguide).
