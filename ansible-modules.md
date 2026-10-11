# Ansible module development guide

This guide covers developing and reviewing Ansible modules, module utilities,
documentation fragments, action plugins, filter plugins and test plugins.
It follows Ansible practice, with general Python rules where applicable.

It complements the [Ansible playbook guidelines](./ansible-playbooks.md), the
[Ansible roles and collections guide](./ansible-roles-collections.md), and the
[Python style guide](./python.md), which covers general Python.
This guide does not restate the
[Ansible developer guide](https://docs.ansible.com/ansible/latest/dev_guide/);
read that documentation for the framework's own mechanics.

Connection, inventory, callback and lookup plugins are out of scope.

The terms MUST, SHOULD, and other key words are used as defined in
[RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).

Before the first module, read Terms, When to write a module, Supported
runtimes, Naming and layout, Payload and dependency boundaries, Arguments and
ownership, Convergence and results, Check mode and diff mode, Secrets and
errors, the transport section your product uses, Module documentation and
Testing. The other sections are reference for the step that needs them:
Resource engine with the second resource, Activation when the product
separates saving from applying, Compatibility and releases before the first
release, Checks and tooling when a session changes.


## Table of contents

- [Terms](#terms)
- [When to write a module](#when-to-write-a-module)
- [Scope and precedence](#scope-precedence)
  - [Python style guide rules in plugin code](#python-rules)
- [Supported runtimes](#supported-runtimes)
  - [Choosing the minimum ansible-core version](#minimum-core-version)
- [Naming and layout](#naming-layout)
- [Payload and dependency boundaries](#payload-dependencies)
- [Arguments and ownership](#arguments-ownership)
- [Convergence and results](#convergence-results)
- [Performance](#performance)
- [Resource engine](#resource-engine)
- [Check mode and diff mode](#check-diff-mode)
- [Secrets and errors](#secrets-errors)
- [HTTP transport](#http-transport)
- [Command-line execution](#cli-execution)
  - [Execution locator](#execution-locator)
- [Activation, operations and bootstrap](#activation-bootstrap)
- [Info and facts modules](#info-facts-modules)
- [Action plugins](#action-plugins)
- [Filter and test plugins](#filter-test-plugins)
- [Shared code and documentation fragments](#shared-code)
- [Module documentation](#module-documentation)
- [Testing](#testing)
- [Compatibility and releases](#compatibility-releases)
- [Checks and tooling](#checks-tooling)
- [Review checklist](#review-checklist)
- [Author information](#author-information)


## Terms<a id="terms"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- **Resource module:** converges the state of one kind of product object, such
  as a firewall rule or a user, to a declared state.
- **Operational module:** performs an operation, such as activating saved
  changes, updating firmware or rebooting, instead of converging a value.
- **Info module:** reads state and never changes it.
- **Action plugin:** runs on the controller from `plugins/action/` and handles
  controller-side work around module execution.
- **Payload:** the module together with the module utilities Ansible assembles
  and runs on the execution host.
- **Execution host:** the host that runs the module process. It is the control
  node for tasks delegated to `localhost` and a managed host otherwise.
- **Application identity:** the account a product's command-line interface runs
  as. It can differ from the module's own user, for example inside a container.
- **Execution locator:** the `exec` option of a command-line module. It tells
  the module how to reach the product's command-line interface from the
  execution host: container, users, executable. A **locator** is one form it
  takes: a `kind` with the fields it accepts, its host-side and target-side
  prerequisites, and its qualified deadline and cleanup mechanism. A **locator
  profile** is the set of locators a collection supports for one product.
- **File-only integration target:** an `ansible-test integration` target that
  runs the shipped modules against a fake product server or local command
  fixtures. It never qualifies a product series.
- **Installed-artifact acceptance:** the test layer that builds the release
  artifact, installs it in a separate environment per ansible-core series and
  runs the claimed product operations against the real product.
- **Lane:** one `antsibull-nox` session for one ansible-core series and one
  Python version.
- **Qualification:** evidence from the real product or command-line
  interface, on the stated ansible-core series, that a claimed operation,
  build or locator behaves as documented. A fake server or a helper's own
  tests never qualify.
- **Product series:** a product's release line, such as OPNsense 26.7. A
  collection declares its support in series.
- **Supported series:** the product series a collection release is tested
  against. On any other series a module warns and proceeds.
- **Eligibility:** whether an operation or option is allowed on the detected
  target. An operation is ineligible only where it is known to be harmful or
  impossible there, for example on a defective build or without a required
  plugin. An ineligible operation fails before any change.
- **Resource engine:** the module utility that implements the resource
  lifecycle once per product, see [Resource engine](#resource-engine). A
  **definition** describes one resource for it: identity, endpoints or
  commands, managed fields, secret fields and the activation it needs.
- **Public error schema:** the categories, codes and further result keys a
  collection's failures may carry, allowlisted in its module utilities; see
  [Convergence and results](#convergence-results).
- **Utility collection:** a collection of product-independent mechanics, such
  as transport, deadlines and safe failure, that product collections share;
  see [Shared code](#shared-code).
- **Workflow role:** a role that sequences the collection's modules, named
  `config` by the
  [roles guide's scoping rules](./ansible-roles-collections.md#scoping).
- **Interface inventory:** a generated file per product series that lists the
  objects and fields of the product's configuration interface. It is
  development evidence; nothing reads it at runtime.
- **Collection contract:** what a consumer may rely on across the whole
  collection: the ownership model, the null contract, the activation policy,
  the supported product series and ansible-core versions, and the locator
  profiles. It lives in the README or in a page linked from it; the contract
  of a single module lives in that module's documentation.
- **Architecture and rationale** (the architecture record): the
  developer-facing description of the collection's current structure,
  execution boundaries and significant technical decisions, with their
  rationale and links to supporting evidence. By house convention
  `docs/architecture.md`, or the repository's existing architecture
  documentation. Execution logs belong in test artifacts and change history in
  Git. Public contracts remain in the README and module documentation. A design
  delivered before the collection exists uses the same structure in `design.md`
  of its design directory; the record moves into `docs/architecture.md` when the
  collection is created. The record's **Scope** section carries the release
  scope: the context (deployment paths in use, who operates the product, their
  first tasks), deployment ownership per path, the administration tasks an
  operator performs as ranked candidates, each mapped to the inventory objects
  it needs and rated for value, risk class (what a wrong run can damage: none,
  the management connection, secrets, a global activation or data) and
  evidence cost, with a status (planned for, qualified, shipped in, blocked by,
  excluded because), the cuts (the first two resources for engine evidence,
  the first release for operator value, later releases in order), and every
  exclusion with its guard decision: the guard chosen against the excluded
  task and the evidence that would lift it.


## When to write a module<a id="when-to-write-a-module"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**A module is RECOMMENDED for:**

- A coherent product resource with a stable identity: a firewall rule, a user,
  a named settings family.
- Repeated read, compare, write and read-back logic that would otherwise be
  rebuilt in Jinja for every resource.
- Operations that need check mode, a diff, sanitized errors or a retry that is
  safe only with identity-based recovery.
- An operation whose transport is awkward or unsafe from a task, such as one
  that must send a secret outside the process arguments.

**A module is NOT RECOMMENDED for:**

- Work already covered by a task file, an existing module or a template.
- A handful of straightforward calls that
  [`ansible.builtin.uri`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/uri_module.html)
  or a documented command already expresses, where no identity resolution,
  normalization or recovery is involved.
- Work that belongs to a role: sequencing several modules, rendering files on
  the target, or orchestrating a lifecycle.

**You MUST:**

- Implement a cut of the Scope section only after the owner approved it in a
  commit of its own whose subject starts with `scope: approve`, for the first
  release `scope: approve the 1.0.0 cut`. After the approval, change only the
  Status cells of the section until the next approval. Open issues for the
  next cut only and link them to the section.

**You MUST NOT:**

- Build a one-to-one wrapper module around a single HTTP endpoint or command
  invocation, as the
  [roles guide's scoping rules](./ansible-roles-collections.md#scoping) also
  forbid. A product operation that has no resource shape, such as activating
  saved changes, exporting a backup or updating firmware, is an operational
  module, not a wrapper.
- Build a role that only forwards a list variable to a module in a loop. See
  the [scoping rules](./ansible-roles-collections.md#scoping).
- Generate a module per upstream endpoint because a specification lists them.

**You SHOULD:**

- Choose the first two resources for the engine evidence they yield and
  every further resource for operator value, as ranked in the Scope section.
  Rank administration tasks, not inventory objects; a module per endpoint is
  the inventory copied.
- Keep a product collection module-only: modules, module utilities and
  documentation fragments. Add action, filter or test plugins only for work a
  module cannot do (see
  [Choosing the minimum ansible-core version](#minimum-core-version)).
- Prefer composing a maintained upstream collection when its coverage,
  ownership, errors, check mode and activation semantics genuinely fit.

**Reasoning:**

- An Ansible resource contract and an upstream endpoint are different things.
  The endpoint describes a request; the module promises convergence, a
  verifiable result and safe failure.
- Every public module is a long-lived interface. The cost is not writing it, it
  is keeping its promise across product releases.
- A forwarding role duplicates the module's interface and can drift from it.
  Sequencing, validation or recovery gives a role a separate purpose.


## Scope and precedence<a id="scope-precedence"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Apply the sources in this order, the first one taking precedence:
  1. ansible-core's runtime behavior and the
     [sanity tests](https://docs.ansible.com/ansible/latest/dev_guide/testing_sanity.html),
     which a module cannot opt out of.
  2. Established Ansible ecosystem practice: the
     [community collection requirements](https://docs.ansible.com/projects/ansible/latest/community/collection_contributors/collection_requirements.html)
     and the tooling maintained collections use, described in
     [Checks and tooling](#checks-tooling).
  3. This guide.
  4. The [licensing guide](./licensing-apply.md), for license notices and
     `REUSE.toml`.
  5. The [Python style guide](./python.md), where a rule makes sense
     for plugin code. The table in
     [Python style guide rules in plugin code](#python-rules) states
     which rules apply.
- Apply each document to its own subject:

  |                                                          Subject                                                           | Document |
  | -------------------------------------------------------------------------------------------------------------------------- | -------- |
  | Current structure and decisions on ownership, resource semantics, locator profiles and compatibility, with their rationale | The collection's architecture record |
  | The resulting collection contract, and each module's contract                                                              | README and module documentation |
  | Module and plugin implementation, checks and review                                                                        | This guide |
  | YAML, tasks, templates and variables                                                                                       | [Ansible playbook guidelines](./ansible-playbooks.md) |
  | Collection boundaries and role argument specifications                                                                     | [Ansible roles and collections guide](./ansible-roles-collections.md) |

- Propose a contract or architecture change for review when a required operation
  cannot satisfy both the product contract and the framework. Do not invent an
  implicit override.

**You MUST NOT:**

- Weaken a safety rule to satisfy a tool. Adjust the tool configuration or
  record a reviewed, scoped exception instead.

**You SHOULD:**

- Link upstream references rather than copying their instructions into
  collection documentation.

**Reasoning:**

- Framework compatibility is not a formatting preference. A module that ignores
  it does not run.
- The Python style guide is written for applications, libraries and scripts
  that own their interpreter, packaging and output. A module owns none of these.
- Copied upstream instructions can drift from their source.

### Python style guide rules in plugin code<a id="python-rules"></a>

|                Python style guide rule                | Applies to plugin code | Replacement |
| ----------------------------------------------------- | ---------------------- | ----------- |
| Python 3.12 minimum                                   | No                     | The ansible-core support matrix and `tests/config.yml`, see [Supported runtimes](#supported-runtimes) |
| `src/` layout, build backend, entry points            | No                     | The Galaxy collection layout |
| Runtime dependencies in `pyproject.toml`, lock file   | No                     | `galaxy.yml` for collections; module `requirements` documentation and execution environment files for Python packages; `pyproject.toml` only for development tools |
| No shebang in library modules                         | No                     | Modules start with `#!/usr/bin/python`; other plugin files have none, see [Module documentation](#module-documentation) |
| stdlib `logging` for diagnostics                      | No                     | `module.warn` and `module.debug` in payloads, `Display` in controller plugins, see [Convergence and results](#convergence-results) |
| `SystemExit(main())`, exit codes                      | No                     | `exit_json` and `fail_json` |
| `subprocess.run(timeout=...)`                         | No                     | `run_command` with a deadline, see [Command-line execution](#cli-execution) |
| pytest 9 strict configuration                         | No                     | `ansible-test units` provides pytest per ansible-core version |
| mypy `strict` and `explicit-override`                 | No                     | The mypy settings in [Checks and tooling](#checks-tooling); `typing.override` needs Python 3.12 |
| Type annotations                                      | Yes                    | Checked with mypy against the newest ansible-core; postpone payload annotations with `from __future__ import annotations`, see [Supported runtimes](#supported-runtimes) |
| Ruff lint families and `ruff format`                  | Yes                    | Run through `antsibull-nox` |
| UTF-8, LF, no encoding declaration                    | Yes                    |             |
| Domain exceptions inside, translation at the boundary | Yes                    | The boundary is `fail_json` |
| Dependency ranges instead of pins                     | Yes                    | For Python packages a module requires |


## Supported runtimes<a id="supported-runtimes"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Distinguish the development interpreter, the controller interpreter and the
payload interpreter on the execution host selected by the task.

**You MUST:**

- Declare the minimum ansible-core version as `requires_ansible` in
  `meta/runtime.yml`.
- Declare the payload Python floor in `tests/config.yml`, `>=3.9` unless the
  architecture record justifies another floor:

  ```yaml
  modules:
    python_requires: ">=3.9"
  ```

- Keep payload code and every module utility it reaches compatible with that
  floor, wherever the module usually runs.
- Document execution host requirements for Python, Python packages and
  command-line tools in the README and in the affected plugin documentation.
- Test on the matrix of [Testing](#testing); it follows `requires_ansible`.
- Document delegation for remote API modules. For command-line modules,
  document both the module's user and the application identity.

**You MUST NOT:**

- Omit `tests/config.yml`.
- Assume a task delegated to `localhost` uses the controller's own interpreter.
- Claim support for an ansible-core series that no repeatable test run covers.
- Evaluate type unions such as `int | str` at runtime on Python 3.9.
  Use `isinstance(value, (int, str))` for runtime checks and
  `typing.Union[int, str]` for runtime type aliases. Keep annotation consumers
  compatible with the payload floor.

**Reasoning:**

- Where a module executes is a task decision. Using HTTP does not make a module
  run on the controller, and delegating to `localhost` does not make it run in
  the controller's interpreter.
- `modules.python_requires` covers `plugins/modules/` and
  `plugins/module_utils/`. Controller-only utilities use the controller's
  supported Python versions; separate `module_utils` and `plugin_utils`
  sections do not configure them.
- Without `tests/config.yml`, ansible-test tests every Python version the
  core supports on targets, including versions below the payload floor.
- Framework behavior changes between core versions, which is why sanity, unit
  and file-only integration tests cover every admitted series.
- `from __future__ import annotations` postpones annotations only. On Python
  3.9, neither union spelling works in `isinstance`, and
  `typing.get_type_hints()` fails when it evaluates `int | str`.

**Enforcement:** the sanity and unit sessions of
[Checks and tooling](#checks-tooling), which derive the version list from
`requires_ansible`.

### Choosing the minimum ansible-core version<a id="minimum-core-version"></a>

**You MUST:**

- Choose the minimum for the control nodes the collection serves, not the
  newest maintained series. Use `>=2.19` by default.
- State the reason for the minimum next to `requires_ansible`: a link to
  the architecture record where it exists, otherwise the skeleton's
  anchors comment. Review it when a listed platform rebases.
- Correct a declared minimum that the content never satisfied in a bugfix
  release; raise a minimum that worked in a breaking release.

**Reasoning:**

- Raising the minimum removes supported control-node platforms and requires a
  breaking release. The payload Python floor still depends on execution hosts;
  ansible-core 2.20 supports Python 3.9 on managed hosts.
- We write Jinja's own filters and tests as `ansible.builtin.<name>`, which
  ansible-core resolves from 2.19 (a 2.19 major change, documented by
  `ansible-doc`). Any content with expressions therefore needs 2.19; older cores
  fail at the first such name.
- Framework changes can affect modules even when their code stays the same.
  In 2.19, exception capture changed; see [Secrets and errors](#secrets-errors).
- Controller plugins also face 2.19's new template trust model,
  `trust_as_template` and undefined-value handling
  ([porting guide](https://docs.ansible.com/ansible/latest/porting_guides/porting_guide_core_2.19.html)).
  These templating changes do not affect module code.
- Type checking uses the newest ansible-core regardless of the minimum.
  Supporting older versions adds test runs without changing a consumer's
  chosen engine.

Control-node defaults as of September 2026:

| ansible-core | Shipped as the control-node default by |
| ------------ | -------------------------------------- |
| 2.12         | Ubuntu 22.04 LTS                       |
| 2.14         | RHEL 9, Debian 12                      |
| 2.16         | RHEL 10, Ansible Automation Platform 2.5 to 2.7 default execution environment, Ubuntu 24.04 LTS |
| 2.18         | SLES 16                                |
| 2.19         | Debian 13                              |
| 2.20         | Ubuntu 26.04 LTS, Fedora 44            |


## Naming and layout<a id="naming-layout"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Name a resource module after the resource, in `snake_case`, without repeating
  the collection name: `firewall_rule` in `foundata.opnsense`, never
  `opnsense_firewall_rule`.
- Use the singular for a module that manages one resource per invocation and
  the plural for one that manages a list of resources of one type:
  `firewall_rule` and `firewall_rules`.
- Name an info module `<resource>_info`. Reserve the `_facts` suffix for
  modules that deliberately populate `ansible_facts`.
- Name an operational module after the scope it acts on and its verb:
  `firewall_rule_apply`, `firmware_update`, `system_reboot`. Where a product
  activates per object family, one module per family; never merge
  activations with different semantics behind one module.
- Place code where the framework expects it: `plugins/modules/`,
  `plugins/module_utils/`, `plugins/doc_fragments/`, `plugins/action/`,
  `plugins/filter/`, `plugins/test/`, and controller-only shared helpers in
  `plugins/plugin_utils/`.
- Do not name a plugin file after a standard library package. A module
  utility called `http.py` makes pylint lint the standard library's `http`
  under that name during sanity on ansible-core 2.21.
- Prefix internal module utility files with an underscore and say in their
  docstring that they are internal. Everything without an underscore is a
  public interface subject to the collection's compatibility policy.
- Define connection options once, in a documentation fragment shared by every
  module of the transport, with the established names: `url`,
  `validate_certs`, `ca_path`, `timeout` and `use_proxy`, plus the product's
  credential options.
- Declare an
  [action group](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections_structure.html)
  in `meta/runtime.yml` for modules sharing a connection fragment. Document it
  in the README and require every member to use that fragment.

**You SHOULD:**

- Keep one transport per module. A second transport for the same resource
  needs its own documented ownership and identity semantics, and usually its
  own name.
- Name an environment variable fallback for a connection option in its
  documentation, and keep `no_log` on the option when it carries a secret.

**Good examples:**

```yaml
# meta/runtime.yml
action_groups:
  api:
    - firewall_alias
    - firewall_alias_apply
    - firewall_rule_apply
    - firewall_rule
    - firewall_rules
    - system_info
```

**Bad examples:**

```text
plugins/modules/opnsense_firewall_rule.py   # stutters with the collection name
plugins/modules/firewall_rules.py           # plural, but manages one rule
plugins/modules/get_firewall_rule.py        # use firewall_rule_info
plugins/modules/api_call.py                 # a dispatcher, not a resource
```

**Reasoning:**

- Module and option names are public interfaces; after the first release,
  changing them requires a redirect and deprecation cycle. The fully qualified
  module name already carries the namespace.
- The `_info` convention lets a reader, a linter and an automated review tell a
  read from a write without opening the file.
- Ansible merges a group's `module_defaults` into the arguments of every member
  without filtering them. A member that lacks one of the shared options fails
  with an unsupported parameter. Matching fragments let consumers supply
  connection parameters once for the group.
- Consistent connection option names let consumers move between collections
  without relearning how to point a module at its endpoint.

**Enforcement:** the `action_groups` check of `antsibull-nox` verifies group
membership against the fragment; review covers names.


## Payload and dependency boundaries<a id="payload-dependencies"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Import shared payload code through `ansible.module_utils` or
  `ansible_collections.<namespace>.<collection>.plugins.module_utils`, using
  imports that are statically discoverable.
- Use the Python standard library and
  `ansible.module_utils.common.text.converters` for text handling and
  compatibility.
- Keep controller-only helpers in `plugins/plugin_utils/` when actions, filters
  or tests share them, and never import those from a payload.
- Guard an optional third-party import and report a missing dependency through
  `missing_required_lib` before any operation. Document where the dependency
  must be installed.
- Test the built and installed collection through the installed-artifact
  acceptance of [Testing](#testing), which runs a module on an execution
  host, not only an import on the controller.

**You MUST NOT:**

- Import `ansible.module_utils.six` or `ansible.module_utils._text`.
- Import `ansible.errors`, `ansible.plugins`, another module's entry point, a
  repository `src/` package or a file under `docs/` from a payload.
- Instantiate `AnsibleModule` at import time in a helper.

**Good examples:**

```python
import traceback
from urllib.error import HTTPError

from ansible.module_utils.basic import AnsibleModule, missing_required_lib
from ansible.module_utils.common.text.converters import to_text

try:
    import somesdk
except ImportError:
    SDK_IMPORT_ERROR = traceback.format_exc()
else:
    SDK_IMPORT_ERROR = None


def main() -> None:
    module = AnsibleModule(argument_spec={}, supports_check_mode=True)
    if SDK_IMPORT_ERROR:
        module.fail_json(msg=missing_required_lib("somesdk"), exception=SDK_IMPORT_ERROR)
```

**Bad examples:**

```python
# BAD: not shipped with the payload, raises ImportError on the execution host
from ansible.errors import AnsibleError

# BAD: deprecated compatibility layers; use urllib.error and common.text.converters
from ansible.module_utils._text import to_text
from ansible.module_utils.six.moves.urllib.error import HTTPError

# BAD: a module is an entry point, not a library
from ansible_collections.foundata.example.plugins.modules.other import helper
```

**Reasoning:**

- Ansible assembles and ships the payload through static
  [module utility](https://docs.ansible.com/ansible/latest/dev_guide/developing_module_utilities.html)
  imports. Repository files outside that mechanism do not travel with it.
- Galaxy dependencies do not install Python packages on the execution host.
- The standard library and text converters replace Python 2 compatibility
  layers on the supported runtimes. `_text` warns from ansible-core 2.21;
  it and `six` are scheduled for removal in 2.24.

**Enforcement:** import and pylint sanity tests, a test of the
missing-dependency path, and the build and import check of
[Checks and tooling](#checks-tooling).


## Arguments and ownership<a id="arguments-ownership"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Define explicit types, choices and nested options wherever the schema is
  known. For every option or suboption with `type="list"`, declare `elements`
  in both the argument specification and `DOCUMENTATION`.
- Express dependencies with `required_by`, `required_if`, `required_together`,
  `required_one_of` and `mutually_exclusive`, and test those cases.
  Use `required_by` for presence-based dependencies and `required_if` for
  value-dependent ones.
- Distinguish an omitted value, `false`, zero, an empty string and an empty
  collection. Never test a managed field for truthiness.
- Treat omitted declared options and explicit `null` options as unmanaged.
  Inside an open dictionary, send a present `null` as the product's null if
  supported; otherwise reject it. Offer explicit reset operations where reset
  differs from null.
- Leave mutable resource fields without defaults so omission means unmanaged.
- Resolve identity before writing: read the complete result, reject an
  ambiguous match, and verify ownership and eligibility.
- Refuse a field that the deployment owns or that an external overlay manages,
  and name the ownership conflict.
- Validate open dictionaries with a product-owned schema, including
  `type: "raw"` input.
- Use `present` and `absent` when existence is the question.

**You MUST NOT:**

- Expose replacement, override or purge semantics for a set of resources
  without a bounded, documented ownership contract, including what an empty
  input means.
- Enumerate upstream examples as a closed `options` schema and thereby reject
  valid upstream keys.

**Good examples:**

```python
argument_spec = {
    "name": {"type": "str", "required": True},
    # No default: an omitted value stays unmanaged on the appliance.
    "enabled": {"type": "bool"},
    "state": {"type": "str", "default": "present", "choices": ["present", "absent"]},
    "settings": {"type": "dict"},  # no default: required_if can see an omission
    "credentials": {
        "type": "dict",
        "options": {
            "username": {"type": "str"},
            "password": {"type": "str", "no_log": True},
        },
    },
}
module = AnsibleModule(
    argument_spec=argument_spec,
    required_if=[("state", "present", ["settings"])],
    supports_check_mode=True,
)

# Keys the caller declared are managed, including a declared null.
desired = dict(module.params["settings"] or {})
```

**Bad examples:**

```python
# BAD: an explicit "enabled: false" is silently ignored
if module.params["enabled"]:
    payload["enabled"] = "1"

# BAD: the default turns every run into a write for a field nobody manages
spec["enabled"] = {"type": "bool", "default": True}

# BAD: picks the first of several matches instead of failing on ambiguity
existing = client.search(name=module.params["name"])[0]

# BAD: a closed schema rejects keys the product added in its last release
spec["settings"] = {"type": "dict", "options": {"description": {"type": "str"}}}

# BAD: satisfies required_if even when the caller omitted settings entirely
spec["settings"] = {"type": "dict", "default": {}}

# BAD: drops a declared null together with the undeclared keys
desired = {key: value for key, value in settings.items() if value is not None}
```

**Reasoning:**

- The argument specification validates shape, not ownership of target fields.
- `required_by` triggers for any non-`None` parameter, including `false`, empty
  values and defaults. `required_by={"purge": "target"}` therefore requires
  `target` for `purge=False`; `required_if=[("purge", True, ["target"])]` does
  not.
- Ansible delivers omitted declared options and explicit `null` as `None`.
  Open dictionaries preserve key membership, so a present null remains
  distinguishable from an omitted key.
- Truthiness collapses `false`, `0`, `""` and "not set" into one branch. Those
  are four different instructions in a configuration interface.
- Defaults make undeclared fields look managed and can overwrite other owners'
  values. Even `{}` satisfies `required_if` and hides an omission.
- Two owners for one field produce a flapping resource that looks like an
  idempotency bug and is really a design error.

**Enforcement:** `validate-modules`, argument validation unit tests, explicit
tests for an omitted option, a declared null inside a dictionary, empty and
false values and duplicate identities, plus review of the ownership claim.


## Convergence and results<a id="convergence-results"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

After a successful run, the declared state holds.

**You MUST:**

- Read, normalize with the product's own rules, compare only managed fields,
  write the smallest safe difference, then read back and fail on a confirmed
  mismatch. Allow for bounded propagation delay where the product has it.
- Keep missing fields distinct from explicit nulls during comparison and
  verification, unless the product contract makes them equivalent.
- Verify the postcondition of every state: identity and managed fields after a
  creation or an update, and absence after a deletion.
- Return `changed: false` for an already-converged run, and return documented,
  JSON-serializable results on both the changed and the unchanged path.
- End through `exit_json` or `fail_json`. Report non-secret diagnostics with
  `module.warn` or `module.debug`.
- Decode bytes at the transport boundary with an explicit encoding and error
  policy, or at the product's protocol boundary where the transport is
  bytes-only and the output may be binary.
- Define rename and adoption behavior, concurrency protection and partial-write
  recovery. After an ambiguous outcome such as a timeout, read again by
  identity or operation ID before any retry.
- Track mutation attempts through command execution, response parsing and
  read-back. Report confirmed changes with `changed: true`. Report possible
  writes with `changed: true` and `outcome: unknown` until reconciled. Use
  `changed: false` only when no change occurred.
- Return these keys from a resource module, and no generic `resource` key, no
  separate prediction key and no free text in `verified`:
  - `changed`.
  - The normalized public resource under its singular product key (`alias`,
    `organization`), with the field meanings and types of the `_info` module,
    without secrets and unstable internals. Product-assigned identifiers live
    inside it and are omitted for a creation in check mode; the key is `null`
    after deletion.
  - `changed_fields`: the managed options that differed before the write,
    empty for creation and deletion.
  - `verified`: `predicted` where check mode skips a write the run would
    make; otherwise `observed` after a read-back or a run that changes
    nothing, in either mode, and `unverifiable` where the product exposes no
    state, which the resource documents.
  - `diff` only when requested, see
    [Check mode and diff mode](#check-diff-mode).
- Return from an operational module `changed` (`true` only when it acted),
  `activated` (a boolean: whether it activated, or would in check mode),
  `verified` with the same three values, and `verification`, a mapping per
  named object with `in_sync`, `drift` or `unverifiable`, where the module
  compares named objects.
- Return from every failure, besides `msg`: `changed`; `outcome`;
  `operation`, the step that failed; the identity under its option names,
  where the module has one; and `error_category`, `error_code` and
  `http_status` from the collection's public error schema, with
  `http_status` `null` where no HTTP status applies. Further keys come from
  the same schema.
- Set `outcome` to one of three values; `changed` is `false` with the first
  and `true` with the others:
  - `unchanged`: no write started, or the product refused it and a read-back
    shows the state as before.
  - `unknown`: a write started and its effect is not established.
  - `changed`: a write took effect, and a later step failed.

**You MUST NOT:**

- Write to standard output or install a `logging` handler in payload code.
- Use a key Ansible interprets, such as `failed`, `msg`, `rc`, `invocation`,
  `ansible_facts`, `warnings`, `deprecations`, `results` or `skipped`, with a
  meaning other than its
  [documented one](https://docs.ansible.com/ansible/latest/reference_appendices/common_return_values.html).
- Report request acceptance as verified convergence.
- Retry a creation because the response was lost.
- Sort a list whose order is significant, or treat missing data as an empty
  resource.

**Good examples:**

Here the client validates responses and translates transport and decoding
errors into `ProductApiError`; `TransportTimeout` is a subclass. Each exception
exposes `category`, `code` and `status`: a locally defined category, an
allowlisted error code or `None`, and an HTTP status or `None`. The constructor
provides safe defaults; raw exception text and response bodies stay internal.
A read-back validates identity and includes any bounded propagation wait.
Recovery shares the operation's original deadline; if no budget remains,
return an unknown outcome and reconcile on a later invocation.

This excerpt returns reconciliation metadata. `current` and `desired` are
normalized and schema-validated; the public diff fields contain only
non-secret scalar values. `public_view` keeps the allowlisted public fields.
Argument, ownership and eligibility checks precede the excerpt. Payload files
start with `from __future__ import annotations`, see
[Module documentation](#module-documentation).

```python
MISSING = object()
PUBLIC_DIFF_FIELDS = frozenset({"enabled", "action", "destination_port"})


def verify(persisted: dict | None) -> dict:
    """Return the persisted resource after checking every managed field."""
    if persisted is None:
        raise ProductApiError(
            "Missing after the write", category="verification", code="missing_after_write"
        )
    if any(persisted.get(key, MISSING) != value for key, value in desired.items()):
        raise ProductApiError(
            "Write accepted but not persisted", category="verification", code="not_persisted"
        )
    return persisted


state = module.params["state"]
write_attempted = False
operation = "find"
try:
    current = client.find(name)  # None when the resource does not exist
    if state == "absent":
        changed = current is not None
        delta = {}
        before, after = current or {}, {}
    elif current is None:
        changed = True
        delta = desired
        before, after = {}, desired
    else:
        delta = {
            key: value for key, value in desired.items() if current.get(key, MISSING) != value
        }
        changed = bool(delta)
        before = {key: current[key] for key in delta if key in current}
        after = delta

    result = {
        "changed": changed,
        "rule": (
            None if state == "absent"
            else public_view({**(current or {}), **desired, "name": name})
        ),
        "changed_fields": (
            sorted(delta) if state == "present" and current is not None else []
        ),
        "verified": "predicted" if module.check_mode and changed else "observed",
    }
    if module._diff and changed:
        public_before = {key: before[key] for key in PUBLIC_DIFF_FIELDS if key in before}
        public_after = {key: after[key] for key in PUBLIC_DIFF_FIELDS if key in after}
        if public_before or public_after:
            result["diff"] = {"before": public_before, "after": public_after}
    if module.check_mode or not changed:
        module.exit_json(**result)

    write_attempted = True
    if state == "absent":
        operation = "delete"
        client.delete(current["id"])
        operation = "verify"
        if client.find(name) is not None:
            raise ProductApiError(
                "Resource remains after deletion", category="verification", code="still_present"
            )
    elif current is None:
        operation = "create"
        try:
            client.create(name, desired)
        except TransportTimeout:
            # Reconcile by identity before considering another write.
            operation = "verify"
            persisted = client.find(name)
            if persisted is None:
                raise ProductApiError(
                    "Creation outcome is unknown", category="verification", code="create_unknown"
                ) from None
        else:
            operation = "verify"
            persisted = client.find(name)
        result["rule"] = public_view(verify(persisted))
    else:
        operation = "update"
        client.update(current["id"], delta)
        operation = "verify"
        result["rule"] = public_view(verify(client.find(name)))
    module.exit_json(**result)
except ProductApiError as error:
    module.fail_json(
        msg="Resource reconciliation failed",
        operation=operation,
        name=name,
        error_category=error.category,
        error_code=error.code,
        http_status=error.status,
        changed=write_attempted,
        outcome="unknown" if write_attempted else "unchanged",
        exception=None,
    )
```

**Bad examples:**

```python
# BAD: acceptance is not convergence
response = client.update(name, desired)
module.exit_json(changed=True, status=response["status"])

# BAD: replaces the whole object, discarding fields nobody declared
client.replace(name, desired)

# BAD: a lost response becomes a duplicate resource
try:
    client.create(name, desired)
except TransportTimeout:
    client.create(name, desired)
```

**Reasoning:**

- Standard output carries the module's JSON result; diagnostics there corrupt
  it.
- Persisted state, accepted request and effective behavior are three separate
  facts. Products routinely confirm the first while failing the third.
- Writing only the difference is what keeps undeclared fields alive, and it
  narrows the window in which a concurrent editor can be overwritten.
- Read-back catches normalization mismatches that would otherwise appear as
  permanent drift on every run.
- Callers assert on `verified`, so it is one of three words. A boolean cannot
  say why a state is unverified, and three builds from the same guide
  returned a string, a boolean and a mapping under that name.
- `verified` names the evidence behind the returned state. A check-mode run
  that changes nothing reads the same state as a normal run, so both report
  `observed`; the caller learns the mode from `ansible_check_mode`.
- `changed: true` on a failure covers a confirmed and a possible write alike.
  `outcome` tells them apart, so a caller knows whether to reconcile first.

**Enforcement:** unit tests over a fake transport that holds state and counts
writes, a repeated real run, timeout and concurrency cases, and an
effective-behavior probe in the Molecule scenario.


## Performance<a id="performance"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Avoid redundant reads. Use a direct identity lookup for a singular resource
  where available. For lists, read once or in batches and resolve identities
  in memory. Do not search per item or scan a whole collection for a single
  indexed resource.
- Read every page of a paginated listing, and treat a truncated listing as an
  error, never as "not found".
- Conclude that a resource is absent only from the product's documented
  absence response, or from a complete listing whose completeness you
  verified: every page read and any declared total matched. A transport
  failure, a malformed body or a message text is an error, never an empty
  result that leads to a create.
- Write only changed items.
- Trigger activation once per invocation or workflow, never once per item.
- Poll with a deadline and a growing interval.

**You MUST NOT:**

- Treat a list-capable module as the authoritative set of all resources.
  Leave unlisted resources unmanaged unless a documented, bounded purge option
  says otherwise.

**You SHOULD:**

- Offer a list-capable resource module when realistic configurations have tens
  of items or more. Give each item its own identity, state and result. Retain
  the singular module and share module utilities between both.
- Reuse one client, connection and authentication per invocation.
- Keep module utilities lean.
- Count requests in unit tests to detect redundant lookups and scans.

**For list-capable modules:**

- Validate every item before the first write: schema, identity, eligibility
  and ownership. Reject duplicate identities and conflicting declarations for
  the same identity instead of applying them in order.
- Document the transaction boundary and rerun safety. Without a product
  transaction, apply items sequentially and stop on the first failure. Report
  applied, failed and unattempted items, with `changed: true` if any applied.
- Return a per-item result with identity, state, `changed` and any error, and
  `changed` for the whole invocation.
- Activate once after the last item, or not at all when an item failed and
  the product would apply the partial set.

**Good examples:**

```yaml
- name: "Manage the web tier firewall rules in one invocation"
  foundata.opnsense.firewall_rules:
    rules:
      - name: "allow-https"
        settings:
          action: "pass"
          destination_port: "443"
      - name: "legacy-ftp"
        state: "absent"
```

**Bad examples:**

```yaml
# BAD for large sets: one process, one authentication and one full read per rule
- name: "Manage the web tier firewall rules"
  foundata.opnsense.firewall_rule:
    name: "{{ __firewall_rule_item['name'] }}"
    settings: "{{ __firewall_rule_item['settings'] }}"
  loop: "{{ firewall_rules }}"
  loop_control:
    loop_var: "__firewall_rule_item"
```

**Reasoning:**

- Each invocation pays for Python startup and payload unpacking; API modules
  also establish connections and authenticate. Batching avoids repeating
  those costs for each item.
- Imported utilities travel in each payload. A small client on
  `ansible.module_utils.urls` can avoid a large SDK dependency.
- Keeping unlisted resources unmanaged preserves the ownership rule of
  [Arguments and ownership](#arguments-ownership) while removing the loop.

**Enforcement:** request counts in unit tests, review, and duration
observations from the installed-artifact acceptance.


## Resource engine<a id="resource-engine"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Most products expose their resources in one uniform way. A hand-written module
per resource then repeats the same reading, comparing, writing and verifying,
and every copy has to get the rules of this guide right again.

**You MUST:**

- Curate every definition. Decide identity, ownership, omission and deletion
  per resource. A generated list of endpoints is no substitute.
- Keep the engine in the product's collection. Share only transport and safety
  mechanics across products, see [Shared code](#shared-code).
- Write an irregular resource by hand on the same client instead of adding a
  special case to the engine.
- Make an engine reject an incomplete or ambiguous lookup, keep the predicted
  state apart from the observed one, report partial progress when a later
  step fails, check the outcome of an activation, and protect pending changes
  of others.

**You SHOULD:**

- Implement the resource lifecycle once per product, as an engine in the
  collection's module utilities: identity resolution, comparison of managed
  fields, minimal writes, read-back, check mode, diff, secret handling, the
  eligibility check and the hand-off to activation.
- Describe each resource as a short definition for that engine: identity,
  endpoints or commands, managed fields with their types, secret fields and
  the activation it needs.
- Keep a module file thin: documentation, argument specification and one call
  into the engine. Serve the singular and the list-capable module of a
  resource from the same definition.
- Use the definition as the product-owned schema that validates an open
  settings dictionary.
- Generate the README's overview of resources from the definitions instead of
  keeping a list by hand.

**You MAY:**

- Generate a module's documentation and argument specification from its
  definition. Commit the generated files and let `validate-modules` check them.

**Good examples:**

```python
class FirewallAlias(Resource):
    """Definition of an OPNsense firewall alias for the product engine."""

    endpoint = "firewall/alias"
    identity = "name"
    fields = {
        "type": Choice("host", "network", "port", "url"),
        "content": ListOf(str),
        "description": str,
        "enabled": bool,
        "password": str,
    }
    secret_fields = frozenset({"password"})
    activation = "firewall_alias_apply"


class UnboundHostOverride(Resource):
    """A composite identity and listing rows that belong to another resource."""

    endpoint = "unbound/settings"
    identity = ("hostname", "domain", "rr")  # no declared uniqueness; more than one match is refused
    exclude_rows = (("isAlias", True),)  # listing rows that are not objects of this resource
```

```python
def main() -> None:
    module = AnsibleModule(
        argument_spec=build_spec(FirewallAlias),
        supports_check_mode=True,
    )
    run_resource(module, FirewallAlias)
```

**Reasoning:**

- With an engine, a rule of this guide is implemented and tested once per
  product. A new resource costs a definition and its tests.
- The pattern is established. The community
  [OPNsense collection](https://github.com/O-X-L/ansible-opnsense) serves well
  over a hundred modules from one shared base.
- No inspected community engine fulfills the five engine duties above
  together, from rejecting an ambiguous lookup to protecting pending changes.
- A special case inside the engine is paid for by every resource. A
  hand-written module keeps the exception in one place.

**Enforcement:** unit tests of the engine over a fake transport, a test per
definition, review of every hand-written resource module, and a search for
resource names in the engine that returns nothing.


## Check mode and diff mode<a id="check-diff-mode"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Keep check mode free of any change to managed state, including discovery
  calls, authentication helpers with side effects and cleanup paths.
- Apply the same ownership and eligibility validation in check mode as in a
  normal run.
- Base a prediction on a real read and a normalized plan. Document an
  incomplete prediction instead of inventing identifiers.
- Add `diff` only when the caller requested it through `module._diff`, and
  limit it to bounded, sanitized changes to managed state.
- Allowlist public fields on both sides of a diff using the product schema.
  Exclude product-returned secrets, including old credentials.
- Describe the actual support level in `attributes.check_mode` and
  `attributes.diff_mode`, including partial support.
- Test the changed and unchanged paths with check mode and diff mode toggled
  independently.

**You MUST NOT:**

- Create a resource and delete it again to simulate a prediction.
- Put a raw API envelope, a command line or a secret into a diff.

**Good examples:**

```python
# These schema-validated fields contain only public scalar values.
PUBLIC_DIFF_FIELDS = frozenset({"enabled", "action", "destination_port"})
result = {
    "changed": bool(delta),
    "rule": public_view({**(current or {}), **desired, "name": name}),
    "changed_fields": sorted(delta) if current is not None else [],
    "verified": "predicted" if module.check_mode and delta else "observed",
}
if module._diff:
    visible = sorted(PUBLIC_DIFF_FIELDS.intersection(delta))
    if visible:
        before = current or {}
        result["diff"] = {
            "before": {key: before[key] for key in visible if key in before},
            "after": {key: desired[key] for key in visible},
        }
if module.check_mode or not delta:
    module.exit_json(**result)
```

```yaml
attributes:
  check_mode:
    description: Predicts changes from a read; a creation cannot predict the assigned identity.
    support: partial
  diff_mode:
    description: Returns the managed fields that would change, without secret values.
    support: full
```

**Bad examples:**

```python
# BAD: changes the target to find out what would happen
probe = client.create(name, desired)
client.delete(probe["id"])

# BAD: a diff nobody asked for, containing the whole current object
result["diff"] = {"before": current, "after": desired}
```

**Reasoning:**

- Check mode is what operators use to inspect a change before a maintenance
  window. `supports_check_mode=True` promises no writes but does not prevent
  them; validation must also reject changes that normal mode would refuse.
- A diff is output. The full current state of a resource usually contains more
  than the caller is entitled to see in a log.
- `no_log` does not mask old credentials that differ from the caller's inputs.

**Enforcement:** assert a write count of zero on every check-mode path. Test
diffs with different old and new secrets, including nested values, and review
the declared support attributes.


## Secrets and errors<a id="secrets-errors"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Set `no_log=True` on every secret input, including nested suboptions and
  secret-bearing free-form maps. Mark a non-secret parameter whose name merely
  looks sensitive with an explicit `no_log=False`.
- Keep secrets out of process arguments, URLs, result keys, diffs, warnings and
  diagnostics. Treat an encoded or transformed secret, and a secret returned by
  the product, as sensitive.
- Treat every product response as secret-bearing unless the resource
  definition allowlists the field. Publish only allowlisted fields of the
  resource under management, never a listing row used for identity
  resolution.
- Convert an expected operational failure into `fail_json` at the module
  boundary. Let utilities raise narrow domain exceptions, and build the message
  from the operation name, a code and allowlisted fields.
- Validate diagnostic codes and categories against the collection's public
  error schema; use fixed fallbacks for unknown errors. Parse output-derived
  diagnostics with a reviewed product-specific parser. Return known codes and
  locally defined messages without raw input values.
- Bound any captured response or output before it can reach a message, and keep
  raw bodies internal.
- Pass `exception=None` when calling `fail_json` from an exception handler for
  an expected failure.
- Catch every product and transport exception before it leaves `main()`.
- Test that synthetic secrets are absent from serialized success and failure
  results, invocation data, diffs and action plugin output. Enable traceback
  capture during these tests. From ansible-core 2.23 the raw module result
  carries `_ansible_new_secrets`, the declared `no_log` values for the
  controller; remove that key before the check and assert that it holds only
  the declared values.
- Give an unreadable secret an explicit set-once or rotation contract with an
  acceptance probe, or exclude the operation.

**You MUST NOT:**

- Return an untrusted response body or a traceback because it was truncated.
- Echo raw `stderr`, `str(error)` or a product exception's message into results,
  warnings or logs.
- Pass parameter values or product responses to `module.log`.
- Swallow a failure and return success.

**Good examples:**

```python
except ProductApiError as error:
    module.fail_json(
        msg="Alias update was rejected by the appliance",
        operation=operation,
        name=name,  # non-secret identity under its option name
        error_category=error.category,  # allowlisted, product-defined
        error_code=error.code,
        http_status=error.status,
        changed=write_attempted,
        outcome="unknown" if write_attempted else "unchanged",
        exception=None,  # never attach the active exception's text
    )
```

```python
# The secret travels on stdin, never in the arguments.
rc, stdout, stderr = module.run_command(
    argv,
    data=json.dumps({"password": module.params["password"]}),
)
```

**Bad examples:**

```python
# BAD: both values can contain server-controlled or secret text
module.fail_json(msg=str(error), response=body)

# BAD: with traceback capture enabled, the raw exception text lands in the result
except ProductApiError:
    module.fail_json(msg="Alias update was rejected by the appliance")

# BAD: visible in the process list of every user on the host
argv = ["product", "user", "set", "--password", module.params["password"]]

# BAD: hides a failure as a successful no-op
except ProductApiError:
    module.exit_json(changed=False)
```

**Reasoning:**

- `no_log` masks known values in framework-controlled output. It cannot protect
  process listings, raw exception attributes or unknown product-returned
  secrets. `module.log` writes to the execution host's journal or syslog and
  masks only values registered through `no_log`.
- From ansible-core 2.19, `fail_json` can attach the active exception when
  `ANSIBLE_DISPLAY_TRACEBACK` enables capture. The traceback includes the
  exception's message, potentially containing a raw response. With
  `exception=None`, every supported core attaches a plain call stack instead,
  which carries no exception message. The result still has an `exception` key
  in a capturing run.
- From 2.19, unhandled exceptions also become module results containing their
  text. Expected failures therefore need translation before leaving `main()`.
- Truncation limits size, not disclosure; debug logging does not sanitize text.
- An error message is an interface. Built from allowlisted fields it stays
  useful and safe; built from `str(error)` it is neither reliable nor bounded.

**Enforcement:** specification tests, synthetic-secret tests across every
serialized path, a reviewed error schema, and review of the product's own
logging, which `no_log` does not control.


## HTTP transport<a id="http-transport"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Build a small client on
  [`ansible.module_utils.urls`](https://docs.ansible.com/ansible/latest/dev_guide/developing_module_utilities.html),
  or use a declared, justified product SDK. Keep the product's authentication
  and response semantics in the product's own utilities.
- Validate certificates by default and make certificate authority, proxy,
  authentication and endpoint behavior explicit options.
- Refuse to follow a redirect that would carry credentials to another origin,
  and disable `netrc`.
- Set a socket inactivity timeout and a monotonic elapsed-time budget. Read
  bodies with `read1`, check the budget between reads, and share the deadline
  across retries and polling.
- Bound response data and close every response, including those in `HTTPError`.
  Document the budget's DNS, header, chunk-framing and decompression limits.
- Compare the received size with a declared `Content-Length` and treat a
  shorter body as a protocol failure. `read1` reports a closed connection as
  the end of the body.
- Check the application-level status as well as the HTTP status.
- Classify retry safety per operation, and restrict an automatic retry after an
  ambiguous write to a verified idempotency or reconciliation mechanism.
- Translate expected failures during both connection setup and body reads
  into domain exceptions: `URLError`, Ansible connection and TLS errors,
  socket errors and malformed HTTP responses. Classify socket timeouts and
  elapsed-budget expiry as `TransportTimeout`; preserve mutation status.

**You MUST NOT:**

- Disable certificate verification automatically when a request fails.
- Infer read-only behavior from the HTTP method. Use only proven read-only
  operations in check mode.
- Use `read(size)` in a loop and assume each call returns within one socket
  timeout.

**You SHOULD:**

- Prefer `ansible.module_utils.urls.open_url` for product API clients.

**Good examples:**

This example requests uncompressed JSON and rejects other content encodings.
Collections that support compression need tests for their decoded reader's
size and timing behavior. The domain exceptions follow the interface in
[Convergence and results](#convergence-results).

```python
import json
import socket
import ssl
import time
from http.client import HTTPException
from urllib.error import HTTPError, URLError

from ansible.module_utils.urls import ConnectionError as UrlConnectionError
from ansible.module_utils.urls import SSLValidationError, open_url

# Create once per operation, outside any retry or polling loop.
deadline = time.monotonic() + self.deadline_seconds
remaining = deadline - time.monotonic()
if remaining <= 0:
    raise TransportTimeout("Request budget exhausted", category="timeout", code="deadline_exceeded")

chunks: list[bytes] = []
size = 0
try:
    response = open_url(
        url,
        method=method,
        data=body,
        headers={**headers, "Accept-Encoding": "identity"},
        validate_certs=self.validate_certs,
        ca_path=self.ca_path,
        use_proxy=self.use_proxy,
        timeout=min(self.timeout, remaining),  # socket inactivity
        url_username=self.api_key,
        url_password=self.api_secret,
        force_basic_auth=True,
        follow_redirects="none",  # never hand credentials to another origin
        use_netrc=False,
        decompress=False,
        http_agent=USER_AGENT,
    )
    with response:
        if response.headers.get("Content-Encoding", "identity").strip().lower() != "identity":
            raise ProductApiError(
                "Unsupported response content encoding", category="response", code="content_encoding"
            )
        while True:
            if time.monotonic() >= deadline:
                raise TransportTimeout(
                    "Request budget exhausted", category="timeout", code="deadline_exceeded"
                )
            chunk = response.read1(min(65536, MAX_BODY_BYTES + 1 - size))
            if time.monotonic() >= deadline:
                raise TransportTimeout(
                    "Request budget exhausted", category="timeout", code="deadline_exceeded"
                )
            if not chunk:
                break
            size += len(chunk)
            if size > MAX_BODY_BYTES:
                raise ProductApiError(
                    "Response exceeds the size limit", category="response", code="body_too_large"
                )
            chunks.append(chunk)
except HTTPError as error:
    status = error.code
    error.close()  # the error object carries a response body
    raise ProductApiError(
        "HTTP request failed", category="http", code="http_error", status=status
    ) from None
except (socket.timeout, TimeoutError):
    raise TransportTimeout(
        "HTTP request timed out", category="timeout", code="socket_timeout"
    ) from None
except URLError as error:
    if isinstance(error.reason, (socket.timeout, TimeoutError)):
        raise TransportTimeout(
            "HTTP connection timed out", category="timeout", code="socket_timeout"
        ) from None
    if isinstance(error.reason, ssl.SSLCertVerificationError):  # core 2.20 and later
        raise ProductApiError(
            "TLS validation failed", category="transport", code="tls_validation"
        ) from None
    raise ProductApiError(
        "HTTP connection failed", category="transport", code="connection_failed"
    ) from None
except SSLValidationError:  # raised by core 2.19; 2.20 and newer raise URLError
    raise ProductApiError(
        "TLS validation failed", category="transport", code="tls_validation"
    ) from None
except UrlConnectionError:
    raise ProductApiError(
        "HTTP connection failed", category="transport", code="connection_failed"
    ) from None
except OSError:
    raise ProductApiError(
        "HTTP transport I/O failed", category="transport", code="io_error"
    ) from None
except HTTPException:
    raise ProductApiError(
        "Invalid or incomplete HTTP response", category="transport", code="http_protocol"
    ) from None
raw = b"".join(chunks)

try:
    decoded = raw.decode("utf-8")
except UnicodeDecodeError:
    raise ProductApiError(
        "Response is not valid UTF-8", category="response", code="invalid_utf8"
    ) from None
try:
    payload = json.loads(decoded)
except json.JSONDecodeError:
    raise ProductApiError(
        "Invalid JSON response", category="response", code="invalid_json"
    ) from None
if not isinstance(payload, dict):
    raise ProductApiError("Expected a response object", category="response", code="response_type")
if payload.get("result") == "failed":
    raise ProductApiError("Validation failed", category="product", code="validation_failed")
```

**Bad examples:**

```python
# BAD: a failure is not a reason to stop verifying certificates
try:
    response = open_url(url, validate_certs=True)
except SSLValidationError:
    response = open_url(url, validate_certs=False)

# BAD: the status line says 200, the body says the write was rejected
open_url(url, method="POST", data=body)
module.exit_json(changed=True)
```

**Reasoning:**

- `fetch_url` returns a readable response on success, but its `HTTPError`
  handler reads the entire error body and some failure paths call `fail_json`
  directly. With `open_url`, the client controls response reading, size limits
  and exception translation before the module decides how to report failure.
  See the upstream
  [implementation](https://github.com/ansible/ansible/blob/stable-2.19/lib/ansible/module_utils/urls.py).
- Redirects can disclose credentials, and `netrc` can silently select
  credentials the caller did not supply; `open_url` reads it by default.
- A successful HTTP status can carry an application validation failure.
- An unbounded read turns a misbehaving endpoint into an out-of-memory failure
  on the execution host.
- For an uncompressed, non-chunked body, `read1` returns after at most one
  underlying read; budget detection can overrun by one socket timeout.
  `read(size)` can keep reading while bytes arrive, delaying the budget check.
- DNS lookup is outside the socket timeout. Slow response headers, chunk
  framing and decompression can also delay budget checks.
- The playbook `timeout` stops the controller waiting but does not guarantee
  process cleanup. A local-connection module may continue after the task fails,
  leaving an interrupted write's outcome unknown.

**Enforcement:** unit tests over a fake opener covering certificate handling,
redirects, authentication, application status, schema, size and time limits,
exceptions during opening and reading, plus slow-body tests for the budget,
header and chunk-framing tests for its documented limits, and the
installed-artifact acceptance for the real API semantics.


## Command-line execution<a id="cli-execution"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Command-line modules reach the product's CLI through a qualified locator: on
the execution host, or inside a container or behind a wrapper that the host
reaches. A locator lists its host-side and its target-side prerequisites
separately.

**You MUST:**

- Keep deployment-specific invocations in a declared locator, see
  [Execution locator](#execution-locator).
- Run subprocesses through `module.run_command` with an argument list,
  `use_unsafe_shell=False`, `expand_user_and_vars=False`, explicit option
  boundaries, and validated executable paths and object identifiers.
- Send secrets through stdin or another protected channel supported by the
  product. Pass bytes only together with `binary_data=True`. Distinguish no
  stdin from an empty stream: `run_command` opens no pipe for empty data.
  Treat an incomplete write to stdin as an uncertain failure, even when the
  command exits 0.
  Probe a native reader with delayed input, input larger than a pipe buffer
  and an early close: a CLI that reads its stdin nonblocking takes what is
  available and fails on the rest. Where it cannot consume a stream
  reliably, a fixed product helper writes the input to a private target file
  (exclusive creation, owner and mode checked) and passes the path to the
  documented native import, removing the file on success, failure and
  interruption; qualify that cleanup like any other.
- Qualify each locator's deadline mechanism and descendant cleanup. Declare
  the implementation and executable path as prerequisites; a conventional
  executable name is no proof of its implementation, so record the version
  output at qualification and select an implementation-specific path where a
  distribution provides one. Record the cleanup scope (process group,
  cgroup, container session), how survivors are detected and which escapes
  remain.
- Qualify a target-side watchdog for a container or wrapper locator,
  prepared from the remaining budget of the same deadline; host
  process-group cleanup does not reach the target. Inspect the target for
  survivors after expiry, and exclude commands that detach unless a session
  or cgroup mechanism is qualified.
- Use the operation's remaining monotonic budget and state which observer
  owns the expiry flag. A status-only wrapper that backs it up fires later,
  with its margin and its cleanup grace documented; a command status alone is
  never observed expiry.
- Give the `timeout` wrapper command a duration above zero. Round a remaining
  budget up, never down to zero.
- Request bytes with `encoding=None` and check both streams' sizes before
  decoding or parsing. Never put raw output in a message.
- Use a reviewed supervisor in a module utility where output is untrusted or
  unbounded. It owns stdin and both output pipes together: it may take the
  `Popen` object in a synchronous `before_communicate_callback`, provided it
  bypasses core's own communication loop, bounds every read and write,
  closes every pipe and bounds cleanup on every exit; test that handoff on
  every admitted core. Add a sanity ignore only for a diagnostic the
  implementation produces, with the versions, the reason and the removal
  condition. Test hangs, output floods, descendants holding stdin open,
  survivors after expiry and after a successful parent exit, including a
  descendant that closes its pipes.
- Validate the return code and the structure of the output before using a
  returned field. A non-zero exit is a result for the product's parser, like
  an HTTP status the client classifies, never an exception of the transport.
- Verify the module's user and the application identity separately before a
  write: resolve both to numeric IDs in their namespace, probe the
  application identity through the same locator prefix as the write with a
  bounded, validated probe format, and probe again after a locator or
  container change. A host UID never stands in for a target UID.
- Reject unsupported non-null locator options after argument parsing. Shared
  mechanics enforce the declared field set; product code validates values,
  conflicts and prefix grammar.
- Keep the inherited and supplied environment within the locator's
  documented policy. Validate the environment the child will actually
  receive: `os.environ`, plus the module-level `run_command_environ_update`,
  plus the per-call update, after core's `PYTHONPATH` rewrite. Document
  target-environment inheritance separately for a container or a wrapper.
  Additions alone are not an allowlist.
  For a container or a wrapper, inspect the environment the target command
  actually inherits, privately and before a write; host validation says
  nothing about it. Allow target overrides only for non-secret keys: a value
  in `--env KEY=value` is argv.
- Expose whether the requested write invocation started when a transport
  bundles preflight and the write, separately from any probe it ran;
  combine it with earlier attempts at the module boundary. It is no
  evidence that the product committed anything.

**You MUST NOT:**

- Pass a `timeout` argument to `run_command`.
- Rely on a timer that calls `process.kill()` from `before_communicate_callback`
  as the deadline.
- Quote values inside an argument list as if a shell would parse them.
- Interpolate caller data into interpreter source. Ship fixed helper source and
  pass the declaration as data.

**Good examples:**

This locator uses a qualified GNU `timeout` and a command with bounded output.
The command reserves statuses 124 and 137 for the wrapper. The module has
already handled check mode and validated the declaration before this write.
Its product utility supplies `parse_product_cli_error`, which accepts any byte
input and returns a known code from the public error schema. Malformed or
unknown output gets a fixed fallback. The parser performs no I/O, raises no
operational exceptions and never echoes raw text or unchecked extracted values.

```python
import json
import math
import signal
import time

KILL_AFTER_SECONDS = 10
MAX_OUTPUT_BYTES = 1024 * 1024
# The wrapper backs up the module's own deadline observer and fires later.
wrapper_seconds = math.ceil(deadline - time.monotonic()) + 1

argv = [
    locator.timeout_path,
    "-k",
    str(KILL_AFTER_SECONDS),
    str(wrapper_seconds),
    *locator_argv(locator),
    RECONCILE_SOURCE,
]


def fail_unknown(message: str, category: str, code: str) -> None:
    module.fail_json(
        msg=message,
        operation="reconcile",
        error_category=category,
        error_code=code,
        http_status=None,
        changed=True,
        outcome="unknown",
        exception=None,
    )


try:
    rc, stdout, stderr = module.run_command(
        argv,
        data=json.dumps({"settings": desired}),
        environ_update=locator.environment,
        use_unsafe_shell=False,
        expand_user_and_vars=False,
        encoding=None,
        handle_exceptions=False,  # preserve mutation status in the outer handler
    )
    # GNU timeout only; BusyBox may return 143/137 or negative signal numbers.
    # A wrapper status says the command was stopped, not that the deadline
    # fired; the module's own observer decides expiry.
    if rc in (124, 137, -signal.SIGKILL):
        fail_unknown("Reconciliation was stopped before it reported", "transport", "command_stopped")
    if len(stdout) > MAX_OUTPUT_BYTES or len(stderr) > MAX_OUTPUT_BYTES:
        fail_unknown("Reconciliation output exceeds the limit", "response", "output_too_large")
    if rc != 0:
        fail_unknown("Reconciliation failed", "product", parse_product_cli_error(stderr).code)
    lines = stdout.decode("utf-8").strip().splitlines()
    if not lines:
        fail_unknown("Reconciliation returned no report", "response", "invalid_command_result")
    report = json.loads(lines[-1])
    if not isinstance(report, dict) or type(report.get("changed")) is not bool:
        fail_unknown("Invalid reconciliation report", "response", "invalid_command_result")
except (FileNotFoundError, PermissionError):
    module.fail_json(
        msg="Reconciliation could not start; check the executable and permissions",
        operation="reconcile",
        error_category="transport",
        error_code="command_start",
        http_status=None,
        changed=False,
        outcome="unchanged",
        exception=None,
    )
except OSError:
    fail_unknown("Reconciliation could not be completed", "transport", "command_io")
except ValueError:
    fail_unknown("Undecodable reconciliation report", "response", "invalid_command_result")
```

Validate the remaining report fields against the product schema and verify
the postcondition before returning success. These steps retain the same
mutation status on failure.

**Bad examples:**

```python
# BAD: shell parsing plus injection through a caller-supplied value
module.run_command(f"product set {value}", use_unsafe_shell=True)

# BAD: caller data compiled into interpreter source
source = f"Setting.set('{name}', '{value}')"

# BAD: no such parameter; the call is unbounded
module.run_command(argv, timeout=60)

# BAD: "$HOME/product" and "~" are expanded before the command sees them
module.run_command(["product", "set", "path", "$HOME/product"])

# BAD: rejected by sanity in modules and module utilities alike
subprocess.run(argv, timeout=60, check=True)
```

**Reasoning:**

- `run_command` has no timeout parameter, writes stdin synchronously before
  its selector loop and buffers both streams completely. Checking sizes
  afterward limits parsing and reporting, not memory use; a kill timer on
  the child fixes neither property.
  Sanity tests reject direct `subprocess` and `os` process calls in modules
  and module utilities.
- Without `expand_user_and_vars=False`, `run_command` expands `$NAME`,
  `${NAME}` and `~` even without a shell. Shell parsing adds another
  interpretation of the arguments.
- GNU `timeout -k` signals its process group; detached descendants need
  separate cleanup. BusyBox signals only the monitored PID and uses different
  exit statuses, so deadline implementations need separate qualification.
- GNU `timeout` treats a duration of zero as no limit. The `ansible-test`
  image of the development branch ships uutils at `/usr/bin/timeout` and GNU
  coreutils at `/usr/bin/gnutimeout`; the name proves nothing.
- Without `binary_data=True`, `run_command` appends a newline to its input.
  On bytes that raises `TypeError`, after the child process has started.
- GNU `timeout` normally returns 124 on expiry; `KILL` can produce 137 or a
  negative signal number. Command exits and external kills can share those
  statuses. `--preserve-status` does not resolve the ambiguity.
- A timer's `process.kill()` stops only the immediate child. A descendant can
  hold stdin open and block `run_command`; `-9` alone does not prove the timer
  fired.
- A matching host user does not establish the identity inside a container.
  `environ_update` adds variables without removing inherited ones.
- Stopping the client does not stop work it started elsewhere. `podman exec`
  can leave the container process running, so expiry does not prove a write
  failed.

**Enforcement:** exact argument list and stdin assertions, expansion tests
with literal `$NAME`, `${NAME}` and `~` arguments, an empty stream and an
incomplete stdin write, a hanging child, a flooding child, a descendant that
keeps stdin open and one that survives a successful exit, expiry with a
colliding status, the pylint sanity test, and qualification against the real
command-line interface. A shared helper's local tests qualify its mechanics,
never a product's locator.

### Execution locator<a id="execution-locator"></a>

The `exec` option tells a command-line module how to reach the product's
command-line interface. A collection's locator profile names the locators it
supports for a product, each a kind with its fields, and rejects everything
else. API modules have no locator.

```yaml
exec:
  kind: "podman"     # podman | package | custom
  user: ""           # user of the module process on the execution host
  container: ""      # podman: the container to enter
  target_user: ""    # application identity inside the container or wrapper
  executable: ""     # custom: absolute path
  argv: []           # custom: arguments before the product command
  chdir: "/"         # working directory of the module process
  env: {}            # environment of the module process, allowlisted keys
  target_chdir: ""   # working directory of the application command
  target_env: {}     # environment of the application command, allowlisted keys
```

**You MUST:**

- Let `become` establish `user` and verify it in the module. Never switch users
  inside the module.
- Select `target_user` through explicit container options or a qualified
  product wrapper, and verify it before a write. Matching user IDs on the host
  say nothing about the identity inside a container, and container UID 0 is a
  different identity from host root.
- Treat `custom` as a facility the caller is trusted with. It runs only the
  prefixes the product's `custom` locator validates and does not confine
  them.
- Keep the product-specific end of the command line in the product's module
  utilities, including its option grammar; `--` is the wrapper's boundary,
  not a universal insertion.
- Use JSON on stdin and a final JSON report line for helpers the collection
  ships itself. Parse a native command-line interface in its own supported
  formats.

**Enforcement:** unit tests that reject undeclared kinds and fields, identity
probes per locator, and review of every `custom` use.


## Activation, operations and bootstrap<a id="activation-bootstrap"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

These rules apply when persistence and activation are separate, or when a
module initializes a product.

**You MUST:**

- Separate persistence from activation wherever the product does, and
  distinguish an accepted request, a completed operation and a verified
  effective state.
- Define what `changed` means for an operational module, including a
  deliberately non-idempotent one. Define its check-mode prediction without
  presenting a non-idempotent operation as convergence.
- Where the product exposes the active state, make activation converge:
  compare the active state with the saved state, activate only on a
  difference or on an explicit `activate: always`, verify afterwards, and
  report `changed` only when it activated. An activation whose reply is
  lost reports `outcome: unknown`, also with `activate: always` when the
  state was already in sync, because nothing proves the activation ran.
  Where the active state is not observable, document that the module
  reports a change on every run and exclude it from idempotence checks
  explicitly.
- Wait for a bounded completion where the product exposes job status, and never
  report an accepted request as proof of effect.
- Handle pending work from earlier failed runs, even if this run changes
  nothing. For global activation, state the writer-coordination policy in the
  module documentation and the README: who may write while automation runs,
  and what a second writer causes. Add a parameter only where the product
  can detect or prevent a second writer (revision checks, a configuration
  lock, a maintenance mode); never ask the caller to assert a condition the
  module cannot verify.
- Establish recovery before a connectivity-sensitive change, or exclude it.
- Make bootstrap distinguish fresh, complete, partial and inconsistent
  initialization, verify the completed state, and prevent duplicate
  initialization under a race.

**You MUST NOT:**

- Put a migration, an upgrade, a first-user creation or an activation inside an
  ordinary read or an ordinary resource write.
- Turn bootstrap into recurring administrator or password reconciliation.
- Add a second transport silently as a fallback when an operation is
  unavailable. Report the coverage gap.

**Good examples:**

```python
# The module states what it verified; the workflow role (`config`) probes the effect.
module.exit_json(
    changed=True,
    activated=True,
    verified="unverifiable",  # the product exposes no loaded state for this scope
)
```

```yaml
# The workflow role runs the probe on every execution, not only on change.
- name: "Activate the saved firewall rules the appliance has not loaded"
  foundata.opnsense.firewall_rule_apply:
    activate: "auto"  # loaded versus saved; also clears activation left pending by a failed run
    verify:
      - "allow-https"

- name: "Read the rule set the appliance reports as loaded"
  foundata.opnsense.firewall_rule_info:
    source: "active"  # loaded rules, not the saved configuration
  register: __opnsense_active_rules

- name: "Verify the declared settings in the loaded rule"
  ansible.builtin.assert:
    that:
      - "__opnsense_loaded_matches | ansible.builtin.length == 1"
      - "__opnsense_loaded_matches[0]['settings']['action'] == 'pass'"
      - "__opnsense_loaded_matches[0]['settings']['destination_port'] == '443'"
    fail_msg: >-
      The loaded rule does not match the declaration. The Molecule
      scenario also probes traffic through the firewall.
  vars:
    __opnsense_loaded_matches: >-
      {{ __opnsense_active_rules['rules']
         | ansible.builtin.selectattr('name', 'ansible.builtin.equalto', 'allow-https')
         | ansible.builtin.list }}
```

Compare every declared field using the resource module's normalization rules,
or verify the expected active revision. For deletion, assert absence. Finding
the right name alone does not verify an update.

Where the product exposes no loaded state, the
[workflow role](./ansible-roles-collections.md#workflow-roles) probes behavior
instead, as the Molecule scenario does with a query through the firewall,
and the documentation names what stays unverified.

**Bad examples:**

```python
# BAD: claims an effect the module never observed
module.exit_json(changed=True, msg="Firewall rules are now active")
```

```yaml
# BAD: a change-triggered activation never runs when a previous run left work pending
- name: "Apply firewall changes"
  foundata.opnsense.firewall_rule_apply:
  when:
    - __rule_result is ansible.builtin.changed
```

**Reasoning:**

- A saved rule that was never applied is the most damaging kind of silent
  failure: the play is green and the policy is the old one.
- Activation is usually global. Applying one change can commit an operator's
  unrelated pending work, which needs a stated policy rather than luck.
- A caller-side promise such as `exclusive_writer: true` changes nothing on
  the wire, can never be false in practice, and blocks check mode; it
  documents the policy in the wrong place.
- A client-side rescue cannot repair a severed management path.

**Enforcement:** state-machine unit tests for operational modules and
bootstrap, workflow role tests including the pending-state case, and recovery
evidence from a real target.


## Info and facts modules<a id="info-facts-modules"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Support check mode and return `changed: false`.
- Return the values a `_facts` module collects under `ansible_facts`.
- Keep a read free of managed product changes, token rotation, refresh actions
  and initialization. Document an unavoidable authentication or audit side
  effect and distinguish it from a resource change.
- Validate the response schema even when the target is outside the supported
  series. Fail explicitly, or return a separately documented raw diagnostic
  shape, rather than inventing normalized state.

**You MUST NOT:**

- Express a read as `state: info` on a write module.
- Provision anything, such as a missing plugin, to make a read succeed.

**Reasoning:**

- Read-only modules are what operators run in check mode to plan a change and
  in monitoring to observe one. A hidden write breaks both uses.
- A normalized result invented from an unrecognized schema is worse than a
  failure: it is a wrong answer presented as a correct one.

**Enforcement:** naming and documentation checks, a transport-level prohibition
on writes in unit tests, check-mode result tests, and review of the endpoint's
own side effects.


## Action plugins<a id="action-plugins"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Add an action plugin only for controller-side work the module cannot do, such
  as reading a file or rendering a template on the controller.
- Derive from `ActionBase` and invoke the module through `_execute_module`.
  Preserve task context, delegation, privilege escalation, check and diff
  behavior, and module failures. Document actual async support.
- Validate action-only inputs, clean up temporary files on every failure path,
  and sanitize data the action adds to the result.
- Where `requires_ansible` admits a core older than 2.19, test a plugin that
  creates template strings or handles templated values on both sides of 2.19,
  see [Choosing the minimum ansible-core version](#minimum-core-version).
- Document the behavior in the paired module's documentation, and test both the
  module alone and the real task path.

**You MUST NOT:**

- Put product logic in an action plugin.
- Change the caller's task arguments in place.
- Force `localhost` silently, write diagnostics to standard output, or treat an
  arbitrary returned string as a template.

**Reasoning:**

- Controller preprocessing adds a second validation boundary and a second place
  where secrets can escape. The module's `no_log` specification does not cover
  output the action plugin adds.
- An action plugin that drops a task's delegation or check-mode flag turns a
  reviewed playbook into something else at runtime.

**Enforcement:** action unit tests with a fake loader, connection and module
executor, plus real task tests covering delegation and check mode on every
admitted ansible-core series.


## Filter and test plugins<a id="filter-test-plugins"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Keep filters and tests deterministic and free of input and output, and never
  change caller data. A test plugin returns a real boolean.
- Export documented names through `FilterModule.filters()` or
  `TestModule.tests()`, and document every public name, using adjacent YAML
  when one file exports several.
- Let an undefined value propagate as Jinja and Ansible expect, and catch
  specific exception types only. Translate expected invalid input into an
  appropriate Ansible error without echoing secret input.
- Test empty, null, malformed, Unicode and undefined input through actual
  templating as well as through direct calls, on both sides of ansible-core
  2.19 when the collection supports older versions.

**You MUST NOT:**

- Call a product from a filter or a test.
- Catch every exception and return `false`.

**Reasoning:**

- Templating may evaluate an expression lazily or more than once. A filter with
  a side effect produces different results depending on when it is rendered.
- ansible-core 2.19 changed how undefined values reach filters and tests and
  now reports overly broad exception handling that used to hide them.
- Catching all exceptions can turn an undefined variable into a false result.

**Enforcement:** purity and input unit tests, real templating tasks,
documentation lint, and review of the intended semantics.


## Shared code and documentation fragments<a id="shared-code"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Keep product parsers, adapters, schemas, normalization and fixtures in the
  product's own collection. Share only product-independent mechanics.
- Change a shared helper and its consumers together until their first
  publication, and publish them at the same time. From then on, a public
  helper's signature, exceptions and defaults and a fragment's options are
  versioned interfaces, see
  [Compatibility and releases](#compatibility-releases).
- Build a fresh argument specification, or deep-copy a nested one, before
  extending it.
- Share documentation through fully qualified fragments and test the merged
  documentation against the real specification, including each consumer's
  overrides.
- Declare collection dependencies in `galaxy.yml` with the lowest version the
  code actually needs, and test that version and the latest compatible one.
- Meet a shared helper's safety conditions, such as bounded output, secret
  redaction and a process deadline, before it is published.

**You MUST NOT:**

- Publish a shared helper that has one consumer. Move it into that consumer.
- Add a runtime dependency to a dependency-free utility collection to satisfy a
  style rule, such as a typing backport for a decorator.

**Good examples:**

Payload files start with `from __future__ import annotations`, see
[Module documentation](#module-documentation).

```python
def base_spec(extra: dict | None = None) -> dict:
    """Return a fresh specification; callers may extend the copy safely."""
    spec = copy.deepcopy(_BASE_SPEC)
    if extra:
        spec.update(copy.deepcopy(extra))
    return spec
```

**Bad examples:**

```python
# BAD: every later consumer inherits this key
_BASE_SPEC["validate_certs"] = {"type": "bool", "default": False}
```

**Reasoning:**

- Two consumers are the smallest evidence that an interface is general rather
  than one product's shape with a generic name.
- An unpublished interface has no outside consumer to protect. Versioning it
  while its shape is still being found costs effort and prevents nothing.
- Editing a shared argument specification in place changes it for every
  consumer in the process. A fresh copy prevents that cross-module state.

**Enforcement:** consumer and build checks, the dependency version tests,
fragment and specification agreement checks, and review of the extraction
benefit.


## Module documentation<a id="module-documentation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Module documentation is the primary public interface description for a
module-first collection.

**You MUST:**

- Start every module with exactly `#!/usr/bin/python`, followed by the
  [license comment header](./licensing-apply.md#license-comment-headers) with
  the upstream license line that starts with
  `# GNU General Public License v3.0+` between its two tags, as in the example
  below. The upstream
  [module format](https://docs.ansible.com/ansible/latest/dev_guide/developing_modules_documenting.html)
  asks for a copyright line before the license declaration, and the
  [`validate-modules` sanity test](https://docs.ansible.com/projects/ansible/latest/community/collection_contributors/collection_requirements.html#ci-testing)
  requires the GNU line within the first twenty lines. The GNU line is
  ecosystem practice and takes precedence over the licensing guide's rule
  against links in headers. Keep the file non-executable. Other plugin and
  module utility files have no shebang and start with the license comment
  header.
- Order the rest as the upstream
  [module format](https://docs.ansible.com/ansible/latest/dev_guide/developing_modules_documenting.html)
  requires: `from __future__ import annotations`, raw-string `DOCUMENTATION`,
  `EXAMPLES` and `RETURN`, then the ordinary imports and the implementation.
  For the limits of postponed annotations on Python 3.9, see
  [Supported runtimes](#supported-runtimes).
- Include `author` and document every module-specific option. Validate merged
  documentation against the argument specification. `validate-modules`
  requires each `author` entry to end with a GitHub handle in parentheses,
  `Name (@handle)`, or to be `!UNKNOWN`; a plain name with an e-mail address
  fails sanity.
- Keep options, suboptions, defaults, aliases, types, choices and conditional
  requirements consistent with the argument specification. Use collection
  versions for `version_added`, never ansible-core versions.
- Document every non-standard returned value and the condition under which it
  appears. Follow the upstream
  [`RETURN` schema](https://docs.ansible.com/ansible/latest/dev_guide/developing_modules_documenting.html#return-block):
  top-level values need `description`, `returned` and `type`; document known
  nested fields with `contains` and list element types with `elements`.
- State identity and adoption, omission, deletion and reset semantics, the
  execution host, prerequisites, the activation policy, check and diff limits,
  and what the module actually verifies.
- Use
  [semantic markup](https://docs.ansible.com/ansible/latest/dev_guide/ansible_markup.html):
  `O()` for options, `V()` for values, `RV()` for return values, `E()` for
  environment variables, `M()` for module names and `P()` for other plugins.
  Reserve `C()` for literal code and `L()` or `U()` for links.
- Write runnable YAML tasks in `EXAMPLES`, following the
  [Ansible playbook guidelines](./ansible-playbooks.md).
- State the collection contract in the README or a linked page. Reuse existing
  documentation that covers it; do not create a redundant top-level document.
- Keep the architecture record about the current implementation and the
  reasoning that still explains it. Link supporting evidence when it justifies
  a decision or support claim. Track planned work in issues, retain execution
  logs as test artifacts, and leave edit history in Git.

**You MUST NOT:**

- Add an encoding declaration or the legacy `absolute_import` and
  `__metaclass__` lines.
- Use Markdown syntax such as backticks inside descriptions.
- Hand-maintain an option table in the README that duplicates the module
  documentation.
- Present an untested product path as supported.

**You SHOULD:**

- Link a tested resource module, its utilities and tests from contributor
  documentation as an end-to-end reference. Keep it in the collection's test
  suite.
- Include samples for return values; the validator does not require them.

**Good examples:**

These are documentation excerpts, not a complete module. The first omits
resource options, attributes, `EXAMPLES`, `RETURN` and the implementation.

<!--REUSE-IgnoreStart-->
```python
#!/usr/bin/python
# SPDX-FileCopyrightText: foundata GmbH <https://foundata.com>
# GNU General Public License v3.0+ (see LICENSES/GPL-3.0-or-later.txt or https://www.gnu.org/licenses/gpl-3.0.txt)
# SPDX-License-Identifier: GPL-3.0-or-later

from __future__ import annotations

DOCUMENTATION = r"""
module: firewall_rule
short_description: Manage one OPNsense firewall rule through the API
description:
  - "With O(state=absent), removes only the named rule and never the appliance."
  - "Changes are saved but not activated. Use M(foundata.opnsense.firewall_rule_apply) afterwards."
version_added: "1.0.0"
author:
  - foundata Development Team (@foundata)
extends_documentation_fragment:
  - foundata.opnsense.api
"""
```
<!--REUSE-IgnoreEnd-->

Document the resource key once; `verified` tells a read-back from a
prediction:

```python
RETURN = r"""
rule:
  description: Normalized public state of the rule.
  returned: always; V(null) after deletion; without product-assigned identifiers for a creation in check mode.
  type: dict
  contains:
    name:
      description: Rule name.
      type: str
      sample: allow-https
    action:
      description: Configured packet action.
      type: str
      sample: pass
changed_fields:
  description: >-
    Managed options that differed before the write; empty for creation
    and deletion.
  returned: always
  type: list
  elements: str
  sample: [destination_port]
verified:
  description: >-
    V(predicted) where check mode skips a write; otherwise V(observed) after
    a read-back or a run that changes nothing, and V(unverifiable) where the
    product exposes no state.
  returned: always
  type: str
  sample: observed
"""
```

**Bad examples:**

```yaml
description:
  - "With `state: absent` this removes the resource."   # BAD: Markdown, not semantic markup
  - "Returns the API response."                          # BAD: undocumented shape
```

**Reasoning:**

- We aim to follow the
  [Ansible community package collection requirements](https://docs.ansible.com/projects/ansible/latest/community/collection_contributors/collection_requirements.html),
  including passing upstream sanity tests. The module format, GPLv3 header
  check (which checks the GNU sentence literally), documentation schemas and
  argument-spec checks are upstream rules.
- ansible-test requires the exact module shebang and rejects executable module
  files; Ansible replaces the interpreter line when it builds the payload.
- Connection fragments do not document resource-specific options. A role's
  `argument_specs.yml` does not describe a module's interface either.
- Semantic markup lets the documentation renderer link an option to its
  definition and keeps the same text readable in `ansible-doc`.
- `version_added` means the ansible-core version in a core module and the
  collection version in a collection. Mixing the two misleads every consumer
  deciding whether they can use an option.

**Enforcement:** the shebang, `validate-modules` and documentation sanity
tests, the documentation and yamllint sessions of
[Checks and tooling](#checks-tooling), and human review of the rendered output.


## Testing<a id="testing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

|               Layer                | Question it answers |
| ---------------------------------- | ------------------- |
| Sanity                             | Does the collection meet the framework's requirements on every supported version? |
| Unit tests with a fake transport   | Does the logic converge, fail and recover correctly? |
| `ansible-test integration` targets | Does the shipped module load, parse arguments and return results on this ansible-core version? |
| Installed-artifact acceptance      | Does the built release, installed per series, perform the claimed product operations against the real product? |
| Molecule                           | Does the product behave as promised on a real target? |

**You MUST:**

- Run sanity, unit tests and the file-only integration targets on every
  admitted ansible-core series and the development branch. Run payload unit
  tests on the lowest declared Python and on the newest Python of each series.
- Run the Molecule scenarios on the newest released admitted series.
- Run the installed-artifact acceptance on the lowest and the newest released
  admitted series, and on further series only where the support contract
  requires it. Install the built artifact in a separate environment per
  series, prove with verbose module paths which copy ran, and qualify the
  claimed product operations, builds and locators against the real
  product, with cleanup. Keep destructive and network tests opt-in and
  limited to test-owned fixtures.
- Exercise the real argument specification and JSON exit and failure paths;
  do not replace `AnsibleModule` with a fake in every test. Feed arguments by
  setting `basic._ANSIBLE_ARGS` to the JSON bytes of
  `{"ANSIBLE_MODULE_ARGS": {...}}` including `_ansible_remote_tmp` and
  `_ansible_keep_remote_files`. From ansible-core 2.21 the parser also needs a
  serialization profile: set `basic._ANSIBLE_PROFILE = "legacy"` where that
  attribute exists. Traceback capture is a module argument in a unit test,
  `_ansible_tracebacks_for`, accepted from ansible-core 2.19 on.
- Import only `ansible.module_utils` in unit tests that run on the payload
  floor. `ansible-test units` provides nothing else of the package there, so
  gate version-dependent cases on a feature of `module_utils`, not on
  `ansible.release`.
- Give an integration target that exercises payload code the `context/target`
  alias. Only then do the Python lanes run its module under that Python;
  `context/controller` targets run on the controller interpreter.
- Cover applicable lifecycle cases: creation, update, no-op, deletion, omission,
  reset, invalid input, ambiguous identity, an unsupported series, an
  ineligible operation, check and diff mode.
- Cover applicable failure and transport cases: secret masking with traceback
  capture enabled, partial writes and their `changed` results, delayed
  visibility, malformed responses, request counts and retry after a timeout.
- Make fake transports and clocks controllable, and assert the calls made and
  the resulting state, not merely that a mock returned the value the test
  supplied.
- Type unit tests like plugin code; the mypy settings cover `tests/unit`.
  Fixtures carry their types in `conftest.py`, and a test signature repeats
  them and returns `None`, so that misuse of a fixture is a type error
  before the test runs.
- Give the file-only integration targets a fake product server started by a
  hidden setup target, or local command fixtures for a command transport, so
  that every module runs a real task against state on every admitted
  ansible-core version. The fake is test material and imitates only what the
  targets exercise.
- Keep Molecule for deployment, bootstrap, activation and effective behavior,
  and share assertion task files with integration targets instead of
  maintaining two convergence suites.

**You MUST NOT:**

- Require production credentials for a unit test.
- Treat a passing fake-transport suite as product qualification.

**Good examples:**

```python
def test_lost_create_response_recovers_by_identity(fake_client):
    fake_client.drop_response_after("create", TransportTimeout)  # the write lands
    run_module(name="web", settings={"port": 443})
    assert fake_client.write_count("create") == 1  # no blind second create
    assert fake_client.state["web"]["port"] == 443
```

**Bad examples:**

```python
# BAD: asserts the value the test itself supplied
client.update.return_value = {"changed": True}
assert run_module(name="web")["changed"] is True
```

**Reasoning:**

- Sanity cannot detect unsafe convergence, and a fake cannot prove an
  appliance's behavior. Each layer is blind to the others' failures.
- Coverage is a diagnostic, not an approval score. A suite that asserts its own
  mocks measures nothing.

**Enforcement:** the sessions of [Checks and tooling](#checks-tooling) and
review of the tests against the operations the documentation claims.


## Compatibility and releases<a id="compatibility-releases"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A collection release supports a bounded set of ansible-core versions and, for a
product collection, product series.

**You MUST:**

- From the first release on, preserve public arguments, results,
  identities, fragments and helper interfaces under the compatibility policy.
  Record behavioral changes, removed support, migrations and deprecations in
  changelog fragments.
- Deprecate declaratively where Ansible supports it: `removed_in_version` with
  `removed_from_collection` and `deprecated_aliases` in the argument
  specification, and `plugin_routing` in `meta/runtime.yml` for whole modules,
  with tombstones for removed content.
- Build and install the exact release artifact and run discovery, import and
  execution checks against it before publishing.

**For modules that manage product state:**

- Declare the supported series and each operation's exclusions in one
  compatibility definition in the module utilities.
- Detect the product version on the target. Never trust a version the caller
  supplies, and refresh a cached result after an upgrade or a reconnect.
- Warn once per module run when the detected series is not supported, name
  the supported series in the warning, and proceed.
- List exclusions per operation: known defective builds and required editions
  or plugins, each with its evidence. Everything else is allowed.
- Fail before any change where an operation is excluded on the detected
  target, and where an option does not exist there.
- Run both checks before every change, including command-line paths and
  operational modules. Keep version and capability discovery read-only and
  free of side effects.
- Declare a product series supported only after the installed-artifact
  acceptance passes on it.
  Test each new release of a supported series.
- Qualify a recovery feature such as a rollback by its observed effect.
- Keep adapters in `module_utils/<family>/`, one per product series only where
  wire behavior differs.
- Support one product series per release by default. Drop the previous series
  in a breaking release, and remove its adapters, exclusions, support
  statements and examples in the same change.
- State in the README which collection release last supported each dropped
  series, so consumers of an older series can stay on it.
- For a hosted service without a detectable version, declare a service
  compatibility policy: the supported API contract, the date it was qualified,
  and the schema or capability checks. Do not invent a product version.

**You MUST NOT:**

- Add deprecations, compatibility shims or migration notes for an interface
  that was never published.
- Add a public `api_version` option unless upstream offers selectable, named
  API versions whose semantics require a consumer choice. Never let the option
  bypass eligibility checks.
- Drop a product series or an ansible-core version, or change the meaning of an
  omitted field, in a patch release.
- Add an adapter or a workaround for a series the release does not support.
- Read the interface inventory or any other development file at runtime.

**You SHOULD:**

- Keep `module.deprecate()` calls rare.

**You MAY:**

- Support two product series in one release when there is a concrete reason,
  such as a fleet that cannot upgrade in one step.

**Reasoning:**

- The compatibility check belongs in the product's client, before the
  request is sent, so no module can forget it.
- A module that refuses every untested series stops working on the day
  upstream releases, and most releases change nothing a module touches. The
  warning tells the operator about the risk, and the read-back after each
  write reports a wrong result.
- Compatibility covers behavior and dependencies, not only the spelling of an
  option. A silently changed default is a breaking change without a renamed
  parameter.
- Declarative deprecations are checked by the sanity tests and read the same on
  every ansible-core version.
- The sanity rules for `module.deprecate()` differ between cores: older ones
  required `collection_name`, 2.21 adds rules against passing it.
- A defect can appear in one patch release of a supported series. An exclusion
  names that build and keeps the series supported. A product release is also
  distinct from a selectable API version.
- Supporting two product series in one code base keeps adapters alive and
  doubles the product tests. One series per release leaves that cost with the
  consumers who need the overlap.
- Ansible loads one version of a collection per run. A fleet on two product
  series needs a release that supports both, or one run per series with its
  own collection installation.
- A product can answer a recovery request with a success status and still not
  perform it.

**Enforcement:** a policy test comparing the runtime compatibility definition
with the positive support claims in the documentation, tests that an
unsupported series warns and an excluded operation fails before any change,
changelog lint, and the build and import check.


## Checks and tooling<a id="checks-tooling"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use [`antsibull-nox`](https://docs.ansible.com/projects/antsibull-nox/) with
  `noxfile.py` and `antsibull-nox.toml` in the collection root.
- Implement the matrix of [Testing](#testing) in `antsibull-nox` sessions.
  Never reduce sanity to a single test. Set the units session's
  `core_python_versions`; a direct run for the default floor is
  `ansible-test units --docker --python 3.9`.
- Format and lint Python with Ruff, including import sorting. Lint YAML and
  documentation blocks with yamllint. Type-check with mypy against the newest
  ansible-core.
- Run `ansible-lint --strict` with the house configuration on integration
  targets, Molecule scenarios and any roles or playbooks, and validate the
  changelog with `antsibull-changelog`, as the
  [playbook guide's Linting section](./ansible-playbooks.md#linting)
  requires. Check Markdown as the [Markdown guide](./markdown.md) describes.
- Explain every sanity ignore entry with the affected ansible-core version, the
  reason and the condition under which it can be removed, and every skipped
  sanity test with its reason beside `skip_tests`.

**You MUST NOT:**

- Suppress a documentation or specification mismatch to obtain a passing run.
- Apply a global `ignore_errors` or a blanket `ignore_missing_imports`.
- Treat a checker's target version, or the compile and import sanity tests,
  as proof of standard library availability on the payload floor. Exercise
  those features in payload unit tests on that floor.

**Good examples:**

The `collection_modules` and `collection_modules_grid` skeletons ship these
sessions in `antsibull-nox.toml`; a collection rendered from
`collection_default` merges them into its existing sections instead of
appending a second copy, and a collection that already carries them keeps its
tuned lanes and skips:

```toml
# antsibull-nox.toml, excerpt as collection_modules renders it
[sessions.license_check]
# The per-file check ignores REUSE.toml and misreads the license sentence in
# README.md. Every file the licensing guide exempts from headers would need an
# ignore entry. "reuse lint" still checks the licensing.
run_license_check = false

[sessions.ansible_test_sanity]
include_devel = true
# changelog: changelogs/fragments also holds the fragment template and the
# archive, which this test rejects. Use "antsibull-changelog lint" instead.
# no-smart-quotes: the license text in LICENSES/ uses typographic quotes.
skip_tests = ["changelog", "no-smart-quotes"]

[sessions.lint]
# Also the Python of the integration targets, such as the fake product.
extra_code_files = ["tests/integration"]
run_isort = false
run_black = false
run_ruff_format = true
run_ruff_autofix = true
ruff_autofix_select = ["I"]
run_ruff_check = true
run_flake8 = false
run_pylint = false
run_yamllint = true
yamllint_config_plugins = ".yamllint"
yamllint_config_plugins_examples = ".yamllint"
run_mypy = true
mypy_config = ".mypy.ini"

# max_version can omit the next series: antsibull-nox knows it before PyPI
# publishes it and installs its lanes from the stable GitHub branch.
[sessions.ansible_test_units]
include_devel = true
split_by_python_version = true
core_python_versions = { "2.19" = ["3.9", "3.13"], "2.20" = ["3.9", "3.14"], "2.21" = ["3.9", "3.14"], "2.22" = ["3.9", "3.15"], "devel" = ["3.10", "3.15"] }

[sessions.ansible_test_integration_w_default_container]
include_devel = true
core_python_versions = { "2.19" = ["3.9", "3.13"], "2.20" = ["3.9", "3.14"], "2.21" = ["3.9", "3.14"], "2.22" = ["3.9", "3.15"], "devel" = ["3.10", "3.15"] }
```

Ruff replaces isort, Black and flake8; sanity runs pylint. The two
`yamllint_config_plugins` settings apply the repository's `.yamllint` to
plugin documentation blocks; the default applies yamllint's 80-column rules to
`DOCUMENTATION` and `EXAMPLES`. `core_python_versions` names one lane on the
payload floor and one on the newest Python per series; read the newest from
ansible-test's constants of that series, it moves (3.15 since 2.22). A series
missing from the mapping runs on every Python it supports.

`antsibull-nox` knows ansible-core versions before they reach PyPI; set
`max_version` to leave an unreleased series out. Its lanes install
ansible-core from the GitHub archive of the series' stable branch; they run,
and they test a moving target. The development branch drops Python versions
ahead of the releases, 3.9 since 2.23, so its lanes name the branch's own
floor and do not raise the collection's. `DOCUMENTATION` strings
start with `---` when the house `.yamllint` requires a document start.

```toml
# ruff.toml
target-version = "py39"
line-length = 88

[lint]
select = ["E4", "E7", "E9", "F", "I", "B", "C4", "UP", "RUF", "W505"]

[lint.pycodestyle]
# Comments and docstrings, which the formatter does not reflow (W505).
max-doc-length = 88

[lint.per-file-ignores]
# Documentation constants precede the ordinary imports by design.
"plugins/modules/*.py" = ["E402"]

[lint.isort]
# Keep collection imports in their own block after the ansible-core imports.
known-first-party = ["ansible_collections"]
```

```ini
# .mypy.ini
[mypy]
check_untyped_defs = True
disallow_untyped_defs = True
strict_equality = True
strict_bytes = True
warn_redundant_casts = True
warn_unreachable = True

[mypy-ansible.*]
follow_untyped_imports = True
```

The module-only skeletons define the `ansible-lint`, `markdown`, `changelog`
and `molecule` sessions in `noxfile.py`. Run the `ansible-test` meta
sessions and the Molecule scenarios separately:

```sh
nox                              # lint, docs, licenses, extra checks, build and import,
                                 # ansible-lint, Markdown and changelog
nox -s ansible-test-sanity       # every admitted ansible-core version
nox -s ansible-test-units        # includes the payload Python floor
nox -s ansible-test-integration  # file-only integration targets
nox -s molecule                  # the default scenario; arguments after -- go to Molecule
```

These sessions implement the matrix of [Testing](#testing).

Check `nox --list` and the generated CI matrix against the declared core and
Python support. Select sessions by name; `antsibull-nox` registers tags for
its CI matrix generator only, so `nox -t sanity` selects nothing.

**Reasoning:**

- `antsibull-nox` derives the ansible-core versions from `requires_ansible`, so
  the test matrix follows declared support. Alongside containerized
  `ansible-test` sessions, it provides lint, documentation, license, build and
  Galaxy importer checks.
- A bare `nox` excludes the `ansible-test` sessions; a bare `molecule test` runs
  only the default scenario.
- Integration targets exercise a real task through Ansible's argument parser.
  Payload unit tests on the Python floor catch unavailable standard library
  features that compile and import checks can miss.
- ansible-core ships no type information. `follow_untyped_imports` analyzes it
  anyway, which is how maintained community collections type-check against it,
  instead of ignoring every Ansible import.
- Sanity tests carry their own pinned pylint and pep8 configuration. A second
  pylint run with other rules adds maintenance without adding safety.

**Enforcement:** the collection's CI runs the sessions; review covers every
configuration exception and sanity ignore entry.


## Review checklist<a id="review-checklist"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Apply this list to every pull request that changes plugin code. Explain any
item marked not applicable.

- [ ] **Scope:** a resource, not an endpoint wrapper; no facade role
  ([When to write a module](#when-to-write-a-module)).
- [ ] **Runtime:** `requires_ansible` and `tests/config.yml` declared; payload
  code meets the Python floor ([Supported runtimes](#supported-runtimes)).
- [ ] **Names:** module, option and action group names follow the rules; group
  members use the group's fragment ([Naming and layout](#naming-layout)).
- [ ] **Payload:** static imports only; no `six`, `_text` or controller-only
  imports; missing dependencies reported
  ([Payload and dependency boundaries](#payload-dependencies)).
- [ ] **Arguments:** types and conditions validated; null contract explicit;
  missing dictionary keys distinct from null; no defaults on mutable fields
  ([Arguments and ownership](#arguments-ownership)).
- [ ] **Convergence:** no redundant reads, write the difference, read back,
  recover by identity after a timeout
  ([Convergence and results](#convergence-results)).
- [ ] **Results:** resource key, `changed_fields` and `verified` as defined;
  failures carry `changed`, `outcome`, `operation`, the identity and the
  error schema's keys ([Convergence and results](#convergence-results)).
- [ ] **Performance:** no per-item searches, pagination complete, activation
  batched; a list-capable module validates everything first and reports per
  item ([Performance](#performance)).
- [ ] **Engine:** a new resource is a definition on the product engine; a
  hand-written resource module is justified
  ([Resource engine](#resource-engine)).
- [ ] **Check and diff:** zero writes in check mode; diff requested, bounded and
  sanitized ([Check mode and diff mode](#check-diff-mode)).
- [ ] **Secrets:** `no_log` on nested inputs; `exception=None` in handlers;
  synthetic-secret tests on every serialized path with traceback capture
  enabled; nothing sensitive in `module.log`
  ([Secrets and errors](#secrets-errors)).
- [ ] **Transport:** certificates, redirects, `netrc`, size and time limits,
  application status ([HTTP transport](#http-transport)).
- [ ] **Commands:** argument lists with expansion disabled, secrets on stdin,
  qualified deadline and cleanup, bounded output, both identities verified
  ([Command-line execution](#cli-execution)).
- [ ] **Locator:** each locator declared and qualified; undeclared kinds and
  fields rejected ([Execution locator](#execution-locator)).
- [ ] **Operations:** accepted, completed and verified distinguished; pending
  work handled; bootstrap state-aware
  ([Activation, operations and bootstrap](#activation-bootstrap)).
- [ ] **Reads:** `_info` naming, check mode, no side effects
  ([Info and facts modules](#info-facts-modules)).
- [ ] **Controller plugins:** justified; templating tested on both sides of
  2.19 where the minimum is older
  ([Action plugins](#action-plugins),
  [Filter and test plugins](#filter-test-plugins)).
- [ ] **Sharing:** fresh specifications; fragments tested with each consumer;
  no published helper with a single consumer ([Shared code](#shared-code)).
- [ ] **Documentation:** header, markup, returns and limits accurate; the
  collection contract stated where consumers read; architecture and rationale
  current, with planned work in issues and supporting evidence linked
  ([Module documentation](#module-documentation)).
- [ ] **Tests:** every lane of the matrix passes; product claims rest on the
  installed-artifact acceptance ([Testing](#testing)).
- [ ] **Release:** unsupported series warn, excluded operations fail before
  changes; deprecations declarative; changelog fragment present; one product
  series unless the README names a reason; writer-coordination policy
  documented ([Compatibility and releases](#compatibility-releases)).
- [ ] **Checks:** all `antsibull-nox` sessions pass; every ignore entry
  explained ([Checks and tooling](#checks-tooling)).


## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust,
readable and consistent Ansible modules and plugins. It builds on the
[Ansible developer guide](https://docs.ansible.com/ansible/latest/dev_guide/)
and the
[Ansible community collection requirements](https://docs.ansible.com/projects/ansible/latest/community/collection_contributors/collection_requirements.html),
which remain the authority for the framework's own rules.
