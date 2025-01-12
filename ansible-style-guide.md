# Ansible style guide (playbooks)

This document defines the style to follow when writing Ansible playbooks. Refer to [`ansible-style-guide-example.yml`](ansible-style-guide-example.yml) for rules illustrated in code and for further clarification.

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

* [YAML files](#yaml-files)
* [Spacing](#spacing)
* [Quoting](#quoting)
* [Naming of variables, roles, plugins and modules](#naming)
* [Booleans](#booleans)
* [Maps (`key: value`)](#maps)
  * [Referencing maps: bracket notation](#maps-referencing)
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
* Use two spaces for [indentation](https://yaml.org/spec/1.2.2/#61-indentation-spaces).
* Indent list contents beyond the list definition.
* Use Unix line feed (LF, `\n`) for new lines.
* Use [UTF-8 encoding](https://yaml.org/spec/1.2.2/#52-character-encodings).
* Trim trailing whitespace whenever possible, but end your files with a new line.


**You SHOULD**

* Use `.yml` as the extension for new roles and collections.
  * Stay consistent with existing extensions if `.yaml` is already used in a role.
* Start scripts with comments explaining their purpose, including example usage if necessary.
* Include blank lines around the `---` separator, followed by the rest of the file.
* Check all [`YAML_FILENAME_EXTENSIONS`](https://docs.ansible.com/ansible/latest/reference_appendices/config.html#yaml-filename-extensions) when searching for files (e.g., `vars_files`, `include_vars`, plugins, or similar functions).


**Good examples:**

```yaml
# The Playbook tries to connect to host and verifies if there is an
# existing, usable Python.
#
# Example usage:
#   ansible-playbook -e data="pong" playbook.yml
#   ansible-playbook -e data="crash" playbook.yml

---

- hosts: localhost
  tasks:

    - name: "Connect to host, verify a usable Python"
      ansible.builtin.ping:
        data: "{{ ping_return }}"
```


**Bad examples:**

```yaml
---
- hosts: localhost
  tasks:
    - name: "Connect to host, verify a usable Python"
      ansible.builtin.ping:
        data: "{{ ping_return }}"
```


**Reasoning:**

* YAML 1.2 has been the standard since 2009 and uses only `true` and `false` for booleans, avoiding many potential edge-case issues. Allowing YAML 1.1 is no longer practical.
* The `.yml` extension must be used for consistency. It is predominant in the Ansible ecosystem, even though [yaml.org](https://yaml.org/faq.html) recommends `.yaml`.
* Adding comments at the very beginning of a file allows for quickly identifying the purpose or usage of a script, either by opening the file or using the `head` command.
* Ending files with a new line is a common Unix best practice. It prevents terminal prompt misalignment when printing files to, for example, STDOUT.


## Spacing<a id="spacing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD**

* have blank lines between
  * two host blocks
  * two task blocks
  * host and include blocks
* use 2 spaces to represent sub-maps when indenting.
* start multi-line maps with a `-`.
* use a single space separating Jinja2 template markers from variable names or expressions.

Have a look at [`ansible-style-guide-example.yml`](ansible-style-guide-example.yml) for a more in-depth example of proper spacing (and other things).


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
      bar: "{{ baz | default('foo') }}"
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
          bar: "{{baz|default('foo')}}"
```


## Quoting<a id="quoting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST**

* quote strings.
* write a long string, we use the "folded scalar" style and omit all special quoting.
* a whole value if it starts with `{{`.


**You SHOULD**

* Prefer double quotes (`"`) over single quotes (`'`). The only time you should use single quotes is when nesting things makes it far easier (for example Jinja map references with other quoting style).


**You MUST NOT**

* quote non-string types (for example booleans (`true`, `false`) or numbers like `1337`).
* things referencing the local Ansible environment (for example names of variables one is assigning values to).

Have a look at [`ansible-style-guide-example.yml`](ansible-style-guide-example.yml) for a more in-depth example of proper quoting (and other things).


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

* Single quotes in YAML are special and do not behave like most programmers expect:
  * Escaping with `\` is *not* possible, instead `''` is used.
  * They to *not* prevent variable interpolation
* It is easier to troubleshoot malformed strings when they should be properly escaped to have the desired effect.
* YAML requires that if you start a value with `{{ foo }}` you quote the whole line to distinguish between a value and a YAML dictionary.
* Syntax highlighting usually works far better when stating strings by quoting.




## Naming of variables, roles, plugins and modules<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST**

* use [`snake_case`](https://en.wikipedia.org/wiki/Snake_case).
* use `[a-z0-9_]` only.
* start variables with a letter.


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

* Ansible itself uses `snake_case` for module names and parameters. As they are influencing a wide range of playbooks it makes sense to extend this convention to variable names even if they are technically not limited to it.
* Names of plugin and roles must follow the rules of the Python namespace (which does not allow for example minus or dots). See [StackOverflow](https://stackoverflow.com/a/37831973), [Galaxy Issue 775](https://github.com/ansible/galaxy/issues/775) and a [comment from Issue 779](https://github.com/ansible/galaxy/issues/779#issuecomment-401632750) for more information:
  > For that to work, namespaces need to be Python compatible, which means they can’t contain ‘-’.
* The [Ansible Galaxy documentation on role names](https://galaxy.ansible.com/docs/contributing/creating_role.html#role-names).



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

* use only one space after the colon when designating a key-value pair
* use the map syntax, regardless of how many pairs exist in the map.


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

* The map syntax is far easier to read and less error prone.
* Version control diffs are less noisy and more meaningful as only new and changed parameters are getting highlighted.



### Referencing maps: bracket notation<a id="maps-referencing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST**

* use bracket notation to access maps / dictionaries for new projects.
* follow the style of existing projects and files (to keep the code consistent).


**You SHOULD**

* rewrite projects to use bracket notation (instead of dot notation) if the project maintainers are OK with it.


**You MUST NOT**

* mix dot and bracket notation.


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

* Bracket notation makes it easier do distinguish between keys and attributes or methods of python dictionaries. It usually results in better editor highlighting, too.
* Bracket notation can be easily be used with variables as keys.
* Dot notation can cause problems because keys can collide with attributes and methods of python dictionaries.


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
```


**Reasoning:**

Well-defined parameter rules are helping to create consistent code.



## Ansible lint<a id="linting"></a>

You MUST check your playbooks, roles and other applicable files with [`ansible-lint`](https://docs.ansible.com/ansible-lint/).


**Reasoning:**

Ansible Lint is a Ansible Core Team project and widely adopted. You can run it offline and it provides a commandline tool for linting playbooks and helps you to find lines that could potentially be improved. Following its advice is helping to create consistent code.



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

According to Read Hat and most of the Ansible community, one should refer to the following resources when developing:

* [Red Hat's Coding Style Good Practices for Ansible](https://github.com/redhat-cop/automation-good-practices/blob/main/coding_style/README.adoc#ansible-guidelines)
* [Best Practices of the Ansible User Guide](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)

However, neither these resources nor the [Ansible documentation](https://docs.ansible.com/ansible/latest) in general follow a consistent code style or define one comprehensively. This document addresses that gap.



## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust, readable and consistent code. It was inspired by [Whitecloud Analytics's Ansible styleguide](https://github.com/whitecloud/ansible-styleguide).
