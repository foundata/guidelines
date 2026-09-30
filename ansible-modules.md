# Ansible module development guide

This document defines how to develop and review Ansible modules and the plugin
code around them: module utilities, documentation fragments, action plugins,
filter plugins and test plugins. Its goal is the best possible modules:
correct, safe, clean, current and fast. It follows established Ansible practice
first and applies general Python rules where they make sense for plugin code.

It complements the [Ansible style guide](./ansible-playbooks.md), which covers
YAML, playbooks and collection boundaries, and the
[Python style guide](./python.md), which covers general Python.
This guide does not restate the
[Ansible developer guide](https://docs.ansible.com/ansible/latest/dev_guide/);
read that documentation for the framework's own mechanics.

Connection, inventory, callback and lookup plugins are out of scope.

The terms MUST, SHOULD, and other key words are used as defined in
[RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [When to write a module](#when-to-write-a-module)
- [Terms](#terms)
- [Scope and precedence](#scope-precedence)
  - [Python style guide rules in plugin code](#python-rules)
- [Supported runtimes](#supported-runtimes)
  - [Choosing the minimum ansible-core version](#minimum-core-version)
- [Naming and layout](#naming-layout)
- [Payload and dependency boundaries](#payload-dependencies)
- [Arguments and ownership](#arguments-ownership)
- [Convergence and results](#convergence-results)
- [Performance](#performance)
- [Check mode and diff mode](#check-diff-mode)
- [Secrets and errors](#secrets-errors)
- [HTTP transport](#http-transport)
- [Command-line execution](#cli-execution)
- [Activation, actions and bootstrap](#activation-bootstrap)
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


## When to write a module<a id="when-to-write-a-module"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A module is the right tool when a product's durable state is changed through an
API, a command-line interface or a documented console, and that change needs an
identity, a comparison and a verified result. It is the wrong tool when a task
file, an existing module or a template already does the job.

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

- A one-to-one wrapper around a single HTTP endpoint or command invocation.
  Wrapping the vendor's interface is not the same as offering a resource.
- A handful of straightforward calls that
  [`ansible.builtin.uri`](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/uri_module.html)
  or a documented command already expresses, where no identity resolution,
  normalization or recovery is involved.
- Work that belongs to a role: sequencing several modules, rendering files on
  the target, or orchestrating a lifecycle.

**You MUST NOT:**

- Build a role whose only content is a loop that forwards a list variable into
  one module. The Ansible style guide's
  [scoping rules](./ansible-playbooks.md#scoping) forbid such one-to-one
  facades: they duplicate the module's interface without adding anything and
  drift from it over time. A role earns its place by sequencing, validating or
  recovering, not by relaying parameters.
- Generate a module per upstream endpoint because a specification lists them.

**You SHOULD:**

- Plan the intended catalogue of resources before implementing the first one,
  and record the agreed release scope, so deferred areas stay explicit instead
  of turning into an arbitrary pilot.
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


## Terms<a id="terms"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- **Resource module:** converges the state of one kind of product object, such
  as a firewall rule or a user, to a declared state.
- **Action module:** performs an operation, such as activating saved changes,
  updating firmware or rebooting, instead of converging a value.
- **Info module:** reads state and never changes it.
- **Payload:** the module together with the module utilities Ansible assembles
  and runs on the execution host.
- **Execution host:** the host that runs the module process. It is the control
  node for tasks delegated to `localhost` and a managed host otherwise.
- **Application identity:** the account a product's command-line interface runs
  as. It can differ from the module's own user, for example inside a container.
- **Execution locator:** the `exec` option of a command-line module. It tells
  the module how to reach the product's command-line interface from the
  execution host: container, users, executable. A **locator profile** is the set
  of locator forms a collection supports for one product, each with the fields
  it accepts.
- **Product series:** a product's release line, such as OPNsense 26.7. A
  collection declares its support in series.
- **Write window:** the product series a collection release admits for writes.
- **Eligibility:** whether an operation or option is allowed on the detected
  product build, decided by a predicate before any change. Eligibility can be
  narrower than the write window, for example to exclude a defective patch
  release.
- **Resource catalogue:** `docs/resources.yml` of a product collection. It lists
  the intended resources with identity, transport, execution host and evidence.
  It is a development index; nothing reads it at runtime.
- **Collection contract:** what a consumer may rely on across the whole
  collection: the ownership model, the null contract, the activation policy,
  the supported product series and ansible-core versions, and the locator
  profiles. It lives in the README or in a page linked from it; the contract
  of a single module lives in that module's documentation.
- **Design record:** the developer-facing record of the decisions behind the
  contract, their evidence, dated test results and open work. By house
  convention `docs/design.md`, or the repository's existing design location.
  It explains the contract; it is not the contract.


## Scope and precedence<a id="scope-precedence"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Plugin code is governed by several sources. They are applied in a fixed order,
so a conflict always has one answer.

**You MUST:**

- Apply the sources in this order, the first one taking precedence:
  1. ansible-core's runtime behavior and the
     [sanity tests](https://docs.ansible.com/ansible/latest/dev_guide/testing_sanity.html),
     which a module cannot opt out of.
  2. Established Ansible ecosystem practice: the
     [community collection requirements](https://docs.ansible.com/ansible/latest/community/collection_contributors/collection_requirements.html)
     and the tooling maintained collections use, described in
     [Checks and tooling](#checks-tooling).
  3. This guide.
  4. The [Python style guide](./python.md), where a rule makes sense
     for plugin code. The table in
     [Python style guide rules in plugin code](#python-rules) states
     which rules apply.
- Apply each document to its own subject:

  |                                                       Subject                                                       | Document |
  | ------------------------------------------------------------------------------------------------------------------- | -------- |
  | Decisions on product ownership, resource semantics, locator profiles and compatibility windows, with their evidence | The collection's design record |
  | The resulting collection contract, and each module's contract                                                       | README and module documentation |
  | Module and plugin implementation, checks and review                                                                 | This guide |
  | YAML, tasks, roles, variables, collection scoping                                                                   | [Ansible style guide](./ansible-playbooks.md) |

- Raise a design amendment when a required operation cannot satisfy both the
  product contract and the framework. Do not invent an implicit override.

**You MUST NOT:**

- Weaken a safety rule to satisfy a tool. Adjust the tool configuration or
  record a reviewed, scoped exception instead.

**You SHOULD:**

- Link upstream references rather than copying their instructions into
  collection documentation, which then ages separately.

**Reasoning:**

- Framework compatibility is not a formatting preference. A module that ignores
  it does not run.
- The Python style guide is written for applications, libraries and scripts
  that own their interpreter, packaging and output. A module owns none of these.

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
| Type annotations                                      | Yes                    | Checked with mypy against the newest ansible-core |
| Ruff lint families and `ruff format`                  | Yes                    | Run through `antsibull-nox` |
| UTF-8, LF, no encoding declaration                    | Yes                    |             |
| Domain exceptions inside, translation at the boundary | Yes                    | The boundary is `fail_json` |
| Dependency ranges instead of pins                     | Yes                    | For Python packages a module requires |


## Supported runtimes<a id="supported-runtimes"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A module runs on whichever host the task selects. For an API collection that is
normally the control node, so the control node's ansible-core gates
installation directly. Three interpreters are involved and they are not the
same: the development interpreter, the controller interpreter and the payload
interpreter on the execution host.

**You MUST:**

- Declare the minimum ansible-core version as `requires_ansible` in
  `meta/runtime.yml`.
- Declare the payload Python floor in `tests/config.yml`, `>=3.9` unless the
  design record states otherwise:

  ```yaml
  modules:
    python_requires: ">=3.9"
  ```

- Keep payload code and every module utility it reaches compatible with that
  floor, wherever the module usually runs.
- Document execution host requirements for Python, Python packages and
  command-line tools in the README and in the affected plugin documentation.
- Run sanity, unit tests and the collection's file-only integration targets
  on every ansible-core series `requires_ansible` admits, plus the development
  branch, and the payload unit tests on the lowest declared Python. Run live
  product integration tests at least on the lowest and the highest admitted
  series.
- Document delegation for modules that talk to a remote endpoint, and document
  both the module's user and the application identity for modules that call a
  command-line interface.

**You MUST NOT:**

- Omit `tests/config.yml`. Without it, ansible-test assumes every Python version
  the core supports; for ansible-core 2.16 that includes Python 2.7 and 3.6.
- Assume a task delegated to `localhost` uses the controller's own interpreter.
- Claim support for an ansible-core series that no repeatable test run covers.

**Reasoning:**

- Where a module executes is a task decision. Using HTTP does not make a module
  run on the controller, and delegating to `localhost` does not make it run in
  the controller's interpreter.
- `tests/config.yml` is what makes ansible-test skip the Python 2 checks and the
  legacy boilerplate tests. Code without the old `__future__` and
  `__metaclass__` lines passes every supported ansible-core version.
- Module code is identical across ansible-core versions, so product behavior
  proven on the lowest and the highest version holds for the ones in between.
  Framework behavior around a module does change between versions, which is
  why sanity, unit and file-only integration tests cover every one of them.

**Enforcement:** the sanity and unit sessions of
[Checks and tooling](#checks-tooling), which derive the version list from
`requires_ansible`.

### Choosing the minimum ansible-core version<a id="minimum-core-version"></a>

Set the minimum to the ansible-core shipped by the control nodes the collection
serves, not to the newest maintained series. The default is `>=2.16`. The
notable control-node anchors, as of September 2026:

| ansible-core | Shipped as the control-node default by |
| ------------ | -------------------------------------- |
| 2.12         | Ubuntu 22.04 LTS                       |
| 2.14         | RHEL 9, Debian 12                      |
| 2.16         | RHEL 10, Ansible Automation Platform 2.5 to 2.7 default execution environment, Ubuntu 24.04 LTS, SLES 15 through Package Hub |
| 2.18         | SLES 16                                |
| 2.19         | Debian 13                              |
| 2.20         | Ubuntu 26.04 LTS, Fedora 44            |

Raising the minimum removes platforms as control nodes and is therefore a
breaking release. It also buys less than it seems:

- Module code does not change. The signatures of `AnsibleModule`, `open_url`
  and `run_command` are the same from 2.16 to 2.21. Framework behavior around
  a module does change, for example how 2.19 captures exceptions and
  tracebacks, which is why the framework tests run on every version.
- The payload Python floor does not change. It is set by where modules run;
  ansible-core 2.20 still supports Python 3.9 on managed hosts.
- Type checking runs against the newest ansible-core regardless of the minimum.
- More ansible-core versions cost test time, not configuration.
- Supporting an older version slows nobody down: a consumer on 2.21 still gets
  2.21's engine.

The real difference concerns controller plugins. ansible-core 2.19 replaced the
templating engine: it inverted the template trust model, added
`trust_as_template` for plugins that create template strings, and changed how
undefined values reach filters and tests
([porting guide](https://docs.ansible.com/ansible/latest/porting_guides/porting_guide_core_2.19.html)).
Modules are not touched by the templating change. The error handling change
of the same release does reach them, see [Secrets and errors](#secrets-errors).

**You MUST:**

- Keep the design record's reason for the minimum next to `requires_ansible`,
  and review it when a listed platform rebases.
- Test a plugin that creates template strings or handles templated values on
  both sides of ansible-core 2.19, or raise the collection's minimum to 2.19.

**You SHOULD:**

- Keep product collections module-only, which keeps the whole 2.19 question
  away from them.


## Naming and layout<a id="naming-layout"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Module and option names are part of the public interface and cannot be
corrected later without a redirect and a deprecation cycle.

**You MUST:**

- Name a resource module after the resource, in `snake_case`, without repeating
  the collection name: `firewall_rule` in `foundata.opnsense`, never
  `opnsense_firewall_rule`. The fully qualified name already carries the
  namespace.
- Use the singular for a module that manages one resource per invocation and
  the plural for one that manages a list of resources of one type:
  `firewall_rule` and `firewall_rules`.
- Name a read-only module `<resource>_info`. Reserve the `_facts` suffix for
  modules that deliberately populate `ansible_facts`.
- Name an action module after its subsystem and its verb, so it cannot be
  mistaken for a resource: `firewall_apply`, `firmware_update`,
  `system_reboot`.
- Place code where the framework expects it: `plugins/modules/`,
  `plugins/module_utils/`, `plugins/doc_fragments/`, `plugins/action/`,
  `plugins/filter/`, `plugins/test/`, and controller-only shared helpers in
  `plugins/plugin_utils/`.
- Prefix internal module utility files with an underscore and say in their
  docstring that they are internal. Everything without an underscore is a
  public interface subject to the collection's compatibility policy.
- Define connection options once, in a documentation fragment shared by every
  module of the transport, with the established names: `url`,
  `validate_certs`, `ca_path`, `timeout` and `use_proxy`, plus the product's
  credential options.
- Declare an
  [action group](https://docs.ansible.com/ansible/latest/dev_guide/developing_collections_structure.html)
  in `meta/runtime.yml` for the modules that share a connection fragment, so a
  consumer supplies connection parameters once through `module_defaults`, and
  document the group in the README. Every member of the group MUST use that
  fragment.

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
    - firewall_apply
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

- The `_info` convention lets a reader, a linter and an automated review tell a
  read from a write without opening the file.
- Ansible merges a group's `module_defaults` into the arguments of every member
  without filtering them. A member that lacks one of the shared options fails
  with an unsupported parameter, so group membership and fragment use have to
  match exactly.
- Consistent connection option names let consumers move between collections
  without relearning how to point a module at its endpoint.

**Enforcement:** the `action_groups` check of `antsibull-nox` verifies group
membership against the fragment; review covers names.


## Payload and dependency boundaries<a id="payload-dependencies"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A module is not installed like a Python package. Ansible assembles a payload
and ships it to the execution host, so only code reachable through the
supported
[module utility](https://docs.ansible.com/ansible/latest/dev_guide/developing_module_utilities.html)
mechanism arrives with it.

**You MUST:**

- Import shared payload code through `ansible.module_utils` or
  `ansible_collections.<namespace>.<collection>.plugins.module_utils`, using
  imports that are statically discoverable.
- Use the Python standard library and
  `ansible.module_utils.common.text.converters` for text handling and
  compatibility. Both work on every supported ansible-core version.
- Keep controller-only helpers in `plugins/plugin_utils/` when actions, filters
  or tests share them, and never import those from a payload.
- Guard an optional third-party import and report a missing dependency through
  `missing_required_lib` before performing any operation. State in the
  documentation where the dependency has to be installed: a Galaxy dependency
  does not install a Python package.
- Test the built and installed collection, including a module run on an
  execution host, not only an import on the controller.

**You MUST NOT:**

- Import `ansible.module_utils.six` or `ansible.module_utils._text`. `_text`
  warns about its deprecation from ansible-core 2.21, and both are scheduled
  for removal in 2.24.
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

- The assembler follows static imports. Anything it cannot see is missing at
  runtime, on a host you may not be able to inspect.
- The compatibility layers existed for Python 2. With a Python 3 payload floor
  they only add deprecation warnings.

**Enforcement:** import and pylint sanity tests, a test of the
missing-dependency path, and the build and import check of
[Checks and tooling](#checks-tooling).


## Arguments and ownership<a id="arguments-ownership"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

The argument specification validates shape. It does not establish who owns a
field on the target, which is the harder half of the contract.

**You MUST:**

- Define explicit types, choices, list element types and nested options
  wherever the schema is known. Express conditional requirements with
  `required_if`, `required_together`, `required_one_of` and
  `mutually_exclusive`, and test those cases.
- Distinguish an omitted value, `false`, zero, an empty string and an empty
  collection. Never test a managed field for truthiness.
- Apply one null contract. For a declared option, Ansible delivers an omitted
  value and an explicit `null` identically as `None`, so both mean unmanaged.
  Inside an open dictionary, key membership survives validation: a present
  key with `null` is a declared null. Send it as the product's null where the
  product has one, otherwise reject it. Offer an explicit reset operation
  where the product distinguishes a reset from a null.
- Leave mutable resource fields without a default, so an omitted field stays
  unmanaged instead of becoming a silent write. A default such as `{}`
  satisfies `required_if` and turns an omission into a declaration.
- Resolve identity before writing: read the complete result, reject an
  ambiguous match, and verify ownership and eligibility.
- Refuse a field that the deployment owns or that an external overlay manages,
  naming the conflict, rather than fighting another writer on every run.
- Validate an open dictionary with a product-owned schema. `type: "raw"` marks
  input as unvalidated; it is not an excuse to skip validation.
- Use `present` and `absent` when existence is the question, and put reads in a
  separate `_info` module.

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

- Truthiness collapses `false`, `0`, `""` and "not set" into one branch. Those
  are four different instructions in a configuration interface.
- A default on a mutable field converts the module from "manage what I declare"
  into "own everything", which silently overwrites values set elsewhere.
- Two owners for one field produce a flapping resource that looks like an
  idempotency bug and is really a design error.

**Enforcement:** `validate-modules`, argument validation unit tests, explicit
tests for an omitted option, a declared null inside a dictionary, empty and
false values and duplicate identities, plus review of the ownership claim.


## Convergence and results<a id="convergence-results"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Convergence is the core promise: after a successful run, the declared state
holds. A transport success is not that promise.

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
  policy.
- Define rename and adoption behavior, concurrency protection and partial-write
  recovery. After an ambiguous outcome such as a timeout, read again by
  identity or operation ID before any retry.
- Track mutation attempts through command execution, response parsing and
  read-back. On failure, return `changed: true` for confirmed changes. If a
  write may have landed, return `changed: true` with `outcome: unknown` until
  reconciliation establishes the result. Report `changed: false` only when
  no change is known to have occurred.

**You MUST NOT:**

- Write to standard output or install a `logging` handler in payload code.
  Standard output carries the module's JSON result.
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
errors into `ProductApiError`; `TransportTimeout` is a subclass. A read-back
includes any bounded wait needed for propagation.

```python
MISSING = object()


def verify(persisted: dict | None, changed: bool) -> None:
    """Verify managed fields while preserving the mutation status."""
    if persisted is None:
        module.fail_json(
            msg=f"{name!r} is missing after the write",
            changed=changed,
            exception=None,
        )
    mismatch = sorted(
        key for key, value in desired.items() if persisted.get(key, MISSING) != value
    )
    if mismatch:
        module.fail_json(
            msg=f"Write accepted but not persisted: {', '.join(mismatch)}",
            changed=changed,
            persisted_fields=sorted(set(desired) - set(mismatch)),
            exception=None,
        )


write_attempted = False
try:
    current = client.find(name)  # None when the resource does not exist
    if current is None:
        if module.check_mode:
            module.exit_json(changed=True, name=name)
        write_attempted = True
        try:
            client.create(name, desired)
        except TransportTimeout:
            # Reconcile by identity before considering another write.
            persisted = client.find(name)
            if persisted is None:
                raise ProductApiError("Creation outcome is unknown") from None
        else:
            persisted = client.find(name)
        verify(persisted, changed=True)
        module.exit_json(changed=True, name=name)

    diff = {
        key: value for key, value in desired.items() if current.get(key, MISSING) != value
    }
    if diff and not module.check_mode:
        write_attempted = True
        client.update(current["id"], diff)
        verify(client.find(name), changed=True)
    module.exit_json(changed=bool(diff), name=name, changed_fields=sorted(diff))
except ProductApiError:
    module.fail_json(
        msg="Resource reconciliation failed",
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

- Persisted state, accepted request and effective behavior are three separate
  facts. Products routinely confirm the first while failing the third.
- Writing only the difference is what keeps undeclared fields alive, and it
  narrows the window in which a concurrent editor can be overwritten.
- Read-back catches normalization mismatches that would otherwise appear as
  permanent drift on every run.

**Enforcement:** unit tests over a fake transport that holds state and counts
writes, a repeated real run, timeout and concurrency cases, and an
effective-behavior probe in the integration scenario.


## Performance<a id="performance"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Every task invocation starts a Python process on the execution host and unpacks
the payload; an API module then opens a connection and authenticates. Measured
on a workstation with ansible-core 2.20 and a local connection, a module that
does nothing costs about 165 ms per invocation: fifty invocations took 8.3
seconds, one took 0.2 seconds. A loop over two hundred firewall rules pays that
two hundred times, plus two hundred reads of the rule list.

**You MUST:**

- Make no redundant reads. A singular module resolves its resource with one
  direct lookup by identity where the product offers one. A list-capable
  module reads the collection once, or in batched queries, and resolves
  identities in memory. Neither issues one search per item, and neither scans
  a whole collection for a single resource that has an indexed lookup.
- Read every page of a paginated listing, and treat a truncated listing as an
  error, never as "not found".
- Write only changed items.
- Trigger activation once per invocation or workflow, never once per item.
- Poll with a deadline and a growing interval.

**You MUST NOT:**

- Treat a list-capable module as the authoritative set of all resources.
  Resources it does not list stay unmanaged unless a separately documented,
  bounded purge option says otherwise.

**You SHOULD:**

- Offer a list-capable resource module when realistic configurations have tens
  of items or more. Each item carries its own identity, state and result, and
  the singular module stays available for single changes. Both share their
  module utilities.
- Reuse one client, connection and authentication per invocation.
- Keep module utilities lean. Every imported utility travels in each payload,
  and a small client on `ansible.module_utils.urls` often replaces a large SDK.
- Count requests in unit tests, so a regression from one lookup to a scan is
  caught.

**For list-capable modules:**

- Validate every item before the first write: schema, identity, eligibility
  and ownership. Reject duplicate identities and conflicting declarations for
  the same identity instead of applying them in order.
- State the transaction boundary. Without a product transaction the module
  applies items one by one; on the first failure it stops and reports which
  items were applied, which failed and which were not attempted, with
  `changed: true` when anything was applied. Document whether a rerun is safe.
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

- The fixed cost of an invocation is paid on the control node or managed host
  for every item and every run. For configuration that changes rarely, almost
  all of it is overhead.
- Keeping unlisted resources unmanaged preserves the ownership rule of
  [Arguments and ownership](#arguments-ownership) while removing the loop.

**Enforcement:** request counts in unit tests, review, and duration
observations from integration tests.


## Check mode and diff mode<a id="check-diff-mode"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Declaring `supports_check_mode=True` is a promise that a run changes nothing.
It is not a statement about the implementation.

**You MUST:**

- Keep check mode free of any change to managed state, including discovery
  calls, authentication helpers with side effects and cleanup paths.
- Apply the same ownership and eligibility validation in check mode as in a
  normal run, so a run that would be refused is refused during planning.
- Base a prediction on a real read and a normalized plan. Document an
  incomplete prediction instead of inventing identifiers.
- Add `diff` only when the caller requested it through `module._diff`, and
  limit it to bounded, sanitized changes to managed state.
- Allowlist public fields on both sides of a diff using the product schema.
  Exclude secrets returned by the product, including old credentials that
  differ from the caller's inputs and therefore are not masked by `no_log`.
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
result = {"changed": bool(diff), "name": name}
if module._diff:
    visible = sorted(PUBLIC_DIFF_FIELDS.intersection(diff))
    if visible:
        before = current or {}
        result["diff"] = {
            "before": {key: before[key] for key in visible if key in before},
            "after": {key: desired[key] for key in visible},
        }
if module.check_mode or not diff:
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
  window. A module that writes during it breaks the one guarantee they rely on.
- A diff is output. The full current state of a resource usually contains more
  than the caller is entitled to see in a log.

**Enforcement:** assert a write count of zero on every check-mode path. Test
diffs with different old and new secrets, including nested values, and review
the declared support attributes.


## Secrets and errors<a id="secrets-errors"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

`no_log` is the last line of defense, not a sanitization design. It masks
values Ansible knows about, in places Ansible controls.

**You MUST:**

- Set `no_log=True` on every secret input, including nested suboptions and
  secret-bearing free-form maps. Mark a non-secret parameter whose name merely
  looks sensitive with an explicit `no_log=False`.
- Keep secrets out of process arguments, URLs, result keys, diffs, warnings and
  diagnostics. Treat an encoded or transformed secret, and a secret returned by
  the product, as sensitive.
- Convert an expected operational failure into `fail_json` at the module
  boundary. Let utilities raise narrow domain exceptions, and build the message
  from the operation name, a code and allowlisted fields.
- Bound any captured response or output before it can reach a message, and keep
  raw bodies internal.
- Pass `exception=None` when calling `fail_json` from an exception handler for
  an expected failure. From ansible-core 2.19, `fail_json` otherwise attaches
  the active exception whenever the controller enables traceback capture
  (`ANSIBLE_DISPLAY_TRACEBACK`), and a formatted traceback ends with the
  exception's own message, which a product exception may have filled with a
  raw response. Every supported ansible-core version accepts the argument.
- Catch every product and transport exception before it leaves `main()`. From
  ansible-core 2.19 the framework turns an unhandled exception into a module
  result whose message is the exception's text.
- Test with a synthetic secret that it appears in none of the serialized
  success result, the failure result, the invocation data, the diff or an
  action plugin's output, with traceback capture enabled during the test.
- Give an unreadable secret an explicit set-once or rotation contract with an
  acceptance probe, or exclude the operation.

**You MUST NOT:**

- Return an untrusted response body or a traceback because it was truncated.
- Pass a secret as a command-line argument.
- Pass parameter values or product responses to `module.log`. It writes to the
  execution host's journal or syslog and masks only values registered through
  `no_log`.
- Swallow a failure and return success.

**Good examples:**

```python
except ProductApiError as error:
    module.fail_json(
        msg="Alias update was rejected by the appliance",
        error_code=error.code,  # allowlisted, product-defined
        resource=name,  # non-secret identity
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

- Automatic masking cannot protect a process listing, an attribute on a raw
  exception or a value the product echoes back in an error message.
- A truncated body is still an untrusted body. Truncation limits size, not
  disclosure.
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
  and disable `netrc`, which `open_url` reads by default.
- Set a socket inactivity timeout and a monotonic elapsed-time budget. Read
  the body with `read1` and check the budget between reads. Retries and polling
  share the original deadline. Bound the data kept and close every response,
  including the one an `HTTPError` carries. Document the limits: DNS lookup
  is outside the socket timeout, and slow response headers, chunk metadata
  or decompression can delay the next budget check.
- Check the application-level status as well as the HTTP status. A successful
  status line routinely carries an application validation failure.
- Classify retry safety per operation, and restrict an automatic retry after an
  ambiguous write to a verified idempotency or reconciliation mechanism.

**You MUST NOT:**

- Disable certificate verification automatically when a request fails.
- Treat the HTTP method as a read-only classification. Check mode has to use
  operations proven to be read-only, not operations named `GET`.
- Use `read(size)` in a loop and assume each call returns within one socket
  timeout. It can perform repeated reads while bytes keep arriving. Use
  `read1` for incremental body reads.

**Good examples:**

This example requests uncompressed JSON and rejects other content encodings.
Collections that support compression need tests for their decoded reader's
size and timing behavior.

```python
# Create once per operation, outside any retry or polling loop.
deadline = time.monotonic() + self.deadline_seconds
remaining = deadline - time.monotonic()
if remaining <= 0:
    raise ProductApiError("Request budget exhausted")

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
except HTTPError as error:
    status = error.code
    error.close()  # the error object carries a response body
    raise ProductApiError(f"{method} {path} failed", status=status) from None

chunks: list[bytes] = []
size = 0
with response:
    if response.headers.get("Content-Encoding", "identity").strip().lower() != "identity":
        raise ProductApiError("Unsupported response content encoding")
    while True:
        if time.monotonic() >= deadline:
            raise ProductApiError("Request budget exhausted")
        chunk = response.read1(min(65536, MAX_BODY_BYTES + 1 - size))
        if time.monotonic() >= deadline:
            raise ProductApiError("Request budget exhausted")
        if not chunk:
            break
        size += len(chunk)
        if size > MAX_BODY_BYTES:
            raise ProductApiError(f"{method} {path} returned more than {MAX_BODY_BYTES} bytes")
        chunks.append(chunk)
raw = b"".join(chunks)

try:
    decoded = raw.decode("utf-8")
except UnicodeDecodeError:
    raise ProductApiError("Response is not valid UTF-8") from None
try:
    payload = json.loads(decoded)
except json.JSONDecodeError:
    raise ProductApiError("Invalid JSON response") from None
if not isinstance(payload, dict):
    raise ProductApiError("Expected a response object")
if payload.get("result") == "failed":
    raise ProductApiError("Validation failed", details=payload.get("validations"))
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

- Redirects can disclose credentials, and `netrc` can silently select
  credentials the caller did not supply.
- An unbounded read turns a misbehaving endpoint into an out-of-memory failure
  on the execution host.
- For an uncompressed, non-chunked body, `read1` returns after at most one
  underlying read, so budget detection can overrun by one socket timeout.
  Python's chunked reader also parses framing between data reads; a slow
  chunk header or trailer can take longer.

The playbook `timeout` keyword can stop the controller waiting on a task,
but does not guarantee module process cleanup. With the local connection,
the module may keep running after the task fails. Reconcile an interrupted
write before retrying it.

**Enforcement:** unit tests over a fake opener covering certificate handling,
redirects, authentication, application status, schema, size and time limits,
plus slow-body tests for the budget, header and chunk-framing tests for its
documented limits, and integration tests for the real API semantics.


## Command-line execution<a id="cli-execution"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A module that drives a product's command-line interface runs on a host that has
that interface. The invocation differs per deployment path, so it belongs in a
declared locator profile rather than in the module's logic.

ansible-core constrains how a module may run a process.
`module.run_command` has no timeout parameter and reads output without a limit.
The sanity tests reject direct use of `subprocess` and of the `os` process
functions in modules and module utilities alike.

**You MUST:**

- Run subprocesses through `module.run_command` with an argument list,
  `use_unsafe_shell=False`, `expand_user_and_vars=False`, explicit option
  boundaries, and a validated executable path and object identifiers. Without
  the expansion switch, `run_command` expands `$NAME`, `${NAME}` and `~` in
  every argument even though no shell is involved.
- Send secrets through stdin or another protected channel supported by the
  product. Use `binary_data=True` when the exact bytes matter.
- Qualify the deadline mechanism for each locator profile. The example uses
  GNU coreutils `timeout -k`, which signals its process group. Descendants
  that detach from that group need separate cleanup. BusyBox signals only
  the monitored PID and has different exit statuses; other implementations
  need their own tests. Declare the implementation and executable path as
  prerequisites. Report interrupted writes as unknown and reconcile before
  retrying.
- Bound what is parsed and echoed: request bytes with `encoding=None`, check
  the size of both streams before decoding or parsing, and never place raw
  output in a message. This is a size check, not a memory bound;
  `run_command` buffers both streams completely before it returns.
- Use a reviewed supervisor in a module utility where output is untrusted or
  unbounded. It reads both streams with a byte limit while they are produced,
  needs a documented sanity ignore entry for `ansible-bad-function`, and is
  tested against a hanging process, flooding output, a descendant that keeps
  stdin open, and descendant cleanup.
- Validate the return code and the structure of the output before using a
  returned field.
- Verify the module's user and the application identity separately before a
  write, and reject unused or conflicting locator fields. A matching host user
  does not establish the identity inside a container.
- Keep the inherited and supplied environment within the locator profile's
  documented policy. `environ_update` adds variables; it does not remove
  inherited ones.

**You MUST NOT:**

- Pass a `timeout` argument to `run_command`. It does not exist.
- Rely on a timer that calls `process.kill()` from `before_communicate_callback`
  as the deadline. It kills only the immediate child. A descendant that holds
  the stdin pipe keeps `run_command` blocked until it exits, and an exit
  status of `-9` alone does not show that the timer fired.
- Quote values inside an argument list as if a shell would parse them.
- Interpolate caller data into interpreter source. Ship fixed helper source and
  pass the declaration as data.

**Good examples:**

This profile uses a qualified GNU `timeout` and a command with bounded output.
The command reserves statuses 124 and 137 for the wrapper. The module has
already handled check mode and validated the declaration before this write.

```python
DEADLINE_SECONDS = 120
KILL_AFTER_SECONDS = 10
MAX_OUTPUT_BYTES = 1024 * 1024

argv = [
    profile.timeout_path,
    "-k",
    str(KILL_AFTER_SECONDS),
    str(DEADLINE_SECONDS),
    *locator_argv(profile),
    RECONCILE_SOURCE,
]


def fail_unknown(message: str, **details: object) -> None:
    module.fail_json(
        msg=message,
        changed=True,
        outcome="unknown",
        exception=None,
        **details,
    )


try:
    rc, stdout, stderr = module.run_command(
        argv,
        data=json.dumps({"settings": desired}),
        environ_update=profile.environment,
        use_unsafe_shell=False,
        expand_user_and_vars=False,
        encoding=None,
        handle_exceptions=False,  # preserve mutation status in the outer handler
    )
    # GNU profile only; BusyBox may return 143/137 or negative signal numbers.
    if rc in (124, 137, -signal.SIGKILL):
        fail_unknown("Reconciliation timed out or was killed", rc=rc)
    if len(stdout) > MAX_OUTPUT_BYTES or len(stderr) > MAX_OUTPUT_BYTES:
        fail_unknown("Reconciliation produced more output than expected", rc=rc)
    if rc != 0:
        fail_unknown("Reconciliation failed", rc=rc)
    lines = stdout.decode("utf-8").strip().splitlines()
    if not lines:
        fail_unknown("Reconciliation returned no report")
    report = json.loads(lines[-1])
    if not isinstance(report, dict) or type(report.get("changed")) is not bool:
        fail_unknown("Reconciliation returned an invalid report")
except (FileNotFoundError, PermissionError):
    module.fail_json(
        msg="Reconciliation could not start; check the executable and permissions",
        changed=False,
        outcome="unchanged",
        exception=None,
    )
except (OSError, ValueError):
    fail_unknown("Reconciliation could not be completed or its report decoded")
```

Validate the remaining report fields against the product schema and verify
the postcondition before returning success. These steps retain the same
mutation status on failure.

GNU `timeout` normally returns 124 on expiry. With `KILL`, the result can be
137 or a negative signal number when Python observes the wrapper's death.
Status alone cannot distinguish every external kill or command exit. Where
codes collide, use a supervisor that records expiry separately; GNU's
`--preserve-status` does not resolve the ambiguity.

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

- Everything the framework gives you for argument safety is lost the moment a
  shell interprets the string.
- A deadline is the only thing standing between a hung product command and a
  stuck play with no output.
- Stopping the client does not stop work it started elsewhere. `podman exec`
  leaves the process inside the container running, which is why an expired
  deadline is an unknown outcome and not a failure to retry.

**Enforcement:** exact argument list and stdin assertions, expansion tests
with literal `$NAME`, `${NAME}` and `~` arguments, a hanging child, a
flooding child and a descendant that keeps stdin open, the pylint sanity
test, and qualification against the real command-line interface.


## Activation, actions and bootstrap<a id="activation-bootstrap"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This section applies to modules for products that persist a change and apply it
separately, and to modules that initialize a product. Host-local collections
are usually unaffected.

**You MUST:**

- Separate persistence from activation wherever the product does, and
  distinguish an accepted request, a completed operation and a verified
  effective state.
- Define what `changed` means for an action, including a deliberately
  non-idempotent one, and define its check-mode prediction. Do not present an
  action as resource convergence.
- Wait for a bounded completion where the product exposes job status, and never
  report an accepted request as proof of effect.
- Handle pending work left by an earlier failed run, even when nothing changed
  in the current run. Where the product applies global pending state, document
  and enforce the required exclusive-writer or maintenance policy before
  making changes.
- Establish recovery before a connectivity-sensitive change, or exclude it. A
  client-side rescue cannot repair a severed management path.
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
# The module states what it verified; the workflow probes the effect.
module.exit_json(
    changed=True,
    status=response["status"],
    verified="request accepted; effective state not verified by this module",
)
```

```yaml
# The shipped workflow runs the probe on every execution, not only on change.
- name: "Activate the saved firewall changes"
  foundata.opnsense.firewall_apply:
    activate: "always"  # also clears activation left pending by a failed run

- name: "Read the rule set the appliance reports as loaded"
  foundata.opnsense.firewall_rule_info:
    source: "active"  # loaded rules, not the saved configuration
  register: __opnsense_active_rules

- name: "Verify the declared settings in the loaded rule"
  ansible.builtin.assert:
    that:
      - "__opnsense_loaded_matches | length == 1"
      - "__opnsense_loaded_matches[0]['settings']['action'] == 'pass'"
      - "__opnsense_loaded_matches[0]['settings']['destination_port'] == '443'"
    fail_msg: >-
      The loaded rule does not match the declaration. The integration
      scenario also probes traffic through the firewall.
  vars:
    __opnsense_loaded_matches: >-
      {{ __opnsense_active_rules['rules']
         | selectattr('name', 'equalto', 'allow-https') | list }}
```

Compare every declared field using the resource module's normalization rules,
or verify the expected active revision. For deletion, assert absence. Finding
the right name alone does not verify an update.

Where the product exposes no loaded state, the workflow probes behavior
instead, as the integration scenario does with a query through the firewall,
and the documentation names what stays unverified.

**Bad examples:**

```python
# BAD: claims an effect the module never observed
module.exit_json(changed=True, msg="Firewall rules are now active")
```

```yaml
# BAD: a change-triggered activation never runs when a previous run left work pending
- name: "Apply firewall changes"
  foundata.opnsense.firewall_apply:
  when:
    - __rule_result is changed
```

**Reasoning:**

- A saved rule that was never applied is the most damaging kind of silent
  failure: the play is green and the policy is the old one.
- Activation is usually global. Applying one change can commit an operator's
  unrelated pending work, which needs a stated policy rather than luck.

**Enforcement:** state-machine unit tests for the action and bootstrap paths,
workflow tests including the pending-state case, and recovery evidence from a
real target.


## Info and facts modules<a id="info-facts-modules"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Name a read-only module `<resource>_info`, support check mode, and return
  `changed: false`.
- Reserve `_facts` for intentional `ansible_facts` population and return the
  collected values under that key.
- Keep a read free of managed product changes, token rotation, refresh actions
  and initialization. Document an unavoidable authentication or audit side
  effect and distinguish it from a resource change.
- Validate the response schema even when the target is outside the write
  window. Fail explicitly, or return a separately documented raw diagnostic
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

An action plugin runs on the controller and wraps a module. It is not a place
for product logic.

**You MUST:**

- Add an action plugin only for controller-side work the module cannot do, such
  as reading a file or rendering a template on the controller.
- Derive from `ActionBase`, invoke the module through `_execute_module`, and
  preserve the task context, delegation, privilege escalation, check and diff
  behavior and the module's failure result. State async support honestly.
- Validate action-only inputs, clean up temporary files on every failure path,
  and sanitize data the action itself adds to the result. A module's `no_log`
  specification does not cover output the action invents.
- Test a plugin that creates template strings or handles templated values on
  both sides of ansible-core 2.19, or raise the collection's minimum version, as
  described in
  [Choosing the minimum ansible-core version](#minimum-core-version).
- Document the behavior in the paired module's documentation, and test both the
  module alone and the real task path.

**You MUST NOT:**

- Change the caller's task arguments in place.
- Force `localhost` silently, write diagnostics to standard output, or treat an
  arbitrary returned string as a template.

**Reasoning:**

- Controller preprocessing adds a second validation boundary and a second place
  where a secret can escape into a result.
- An action plugin that drops a task's delegation or check-mode flag turns a
  reviewed playbook into something else at runtime.

**Enforcement:** action unit tests with a fake loader, connection and module
executor, plus real task tests covering delegation and check mode on every
ansible-core version.


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
- Catch every exception and return `false`, which makes an undefined variable
  look like a valid negative result.

**Reasoning:**

- Templating may evaluate an expression lazily or more than once. A filter with
  a side effect produces different results depending on when it is rendered.
- ansible-core 2.19 changed how undefined values reach filters and tests and
  now reports overly broad exception handling that used to hide them.

**Enforcement:** purity and input unit tests, real templating tasks,
documentation lint, and review of the intended semantics.


## Shared code and documentation fragments<a id="shared-code"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Shared code reaches every consumer, and so does a mistake in it. A
documentation fragment is part of that public surface.

**You MUST:**

- Keep product parsers, adapters, schemas, normalization and fixtures in the
  product's own collection. Share only product-independent mechanics.
- Share a helper at the stability level its actual consumers have earned. A
  released collection imports stable helpers only; an unreleased branch may
  import an experimental one.
- Mark an internal utility with a leading underscore and say so in its
  docstring. Treat a public helper's signature, its exceptions and a fragment's
  options as versioned interfaces.
- Build a fresh argument specification, or deep-copy a nested one, before
  extending it. A shared specification edited in place corrupts every other
  consumer in the same process.
- Share documentation through fully qualified fragments and test the merged
  documentation against the real specification, including each consumer's
  overrides.
- Declare collection dependencies in `galaxy.yml` with the lowest version the
  code actually needs, and test that version and the latest compatible one.
- Meet a shared helper's safety conditions, such as bounded output, secret
  redaction and a process deadline, before it becomes stable.

**You MUST NOT:**

- Extract a helper that has one consumer and call it shared.
- Add a runtime dependency to a dependency-free utility collection to satisfy a
  style rule, such as a typing backport for a decorator.

**Good examples:**

```python
def build_spec(extra: dict | None = None) -> dict:
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
- Module specifications are dictionaries. Sharing one by reference is an action
  at a distance across collections that unit tests rarely reproduce.

**Enforcement:** consumer and build checks, the dependency version tests,
fragment and specification agreement checks, and review of the extraction
benefit.


## Module documentation<a id="module-documentation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

For a module-first collection the module documentation, not a role's
`argument_specs.yml`, is the primary public interface description.

**You MUST:**

- Start every module with exactly `#!/usr/bin/python`, followed by the license
  lines of the [licensing guide](./licensing-apply.md), and keep the file
  non-executable. Other plugin and module utility files have no shebang.
- Order the rest as the upstream
  [module format](https://docs.ansible.com/ansible/latest/dev_guide/developing_modules_documenting.html)
  requires: `from __future__ import annotations`, raw-string `DOCUMENTATION`,
  `EXAMPLES` and `RETURN`, then the ordinary imports and the implementation.
  The `__future__` import lets `X | None` annotations run on Python 3.9.
- Keep options, suboptions, defaults, aliases, types, choices and conditional
  requirements consistent with the argument specification. Use collection
  versions for `version_added`, never ansible-core versions.
- Document every non-standard returned value and the condition under which it
  appears.
- State identity and adoption, omission, deletion and reset semantics, the
  execution host, prerequisites, the activation policy, check and diff limits,
  and what the module actually verifies.
- Use
  [semantic markup](https://docs.ansible.com/ansible/latest/dev_guide/ansible_markup.html):
  `O()` for options, `V()` for values, `RV()` for return values, `E()` for
  environment variables, `M()` for module names and `P()` for other plugins.
  Reserve `C()` for literal code and `L()` or `U()` for links.
- Write runnable YAML tasks in `EXAMPLES`, following the
  [Ansible style guide](./ansible-playbooks.md).
- State the collection contract where consumers read: in the README or in a
  page linked from it. Existing documentation that covers those subjects
  satisfies this rule; do not create a new top-level document merely to hold
  them.
- Keep the design record's current decisions apart from its dated evidence
  and execution logs, so a reader can tell what holds now from how it came
  about. Rationale that would crowd the record may live in a page linked
  from it.

**You MUST NOT:**

- Add an encoding declaration or the legacy `absolute_import` and
  `__metaclass__` lines. They serve Python 2 only.
- Use Markdown syntax such as backticks inside descriptions.
- Hand-maintain an option table in the README that duplicates the module
  documentation.
- Present an untested product path as supported.

**Good examples:**

```python
#!/usr/bin/python
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: foundata GmbH (https://foundata.com)

from __future__ import annotations

DOCUMENTATION = r"""
module: firewall_rule
short_description: Manage one OPNsense firewall rule through the API
description:
  - "With O(state=absent), removes only the named rule and never the appliance."
  - "Changes are saved but not activated. Use M(foundata.opnsense.firewall_apply) afterwards."
version_added: "1.0.0"
extends_documentation_fragment:
  - foundata.opnsense.api
"""
```

**Bad examples:**

```yaml
description:
  - "With `state: absent` this removes the resource."   # BAD: Markdown, not semantic markup
  - "Returns the API response."                          # BAD: undocumented shape
```

**Reasoning:**

- ansible-test requires the exact module shebang and rejects executable module
  files; Ansible replaces the interpreter line when it builds the payload.
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

Four layers answer four different questions. None substitutes for another.

|               Layer                | Question it answers |
| ---------------------------------- | ------------------- |
| Sanity                             | Does the collection meet the framework's requirements on every supported version? |
| Unit tests with a fake transport   | Does the logic converge, fail and recover correctly? |
| `ansible-test integration` targets | Does the shipped module load, parse arguments and return results on this ansible-core version? |
| Molecule                           | Does the product behave as promised on a real target? |

**You MUST:**

- Run sanity, unit tests and the file-only integration targets on every
  ansible-core version the collection admits, plus the development branch,
  and the payload unit tests on the lowest declared Python. Exercise the real
  argument specification and the JSON exit and failure paths in some tests
  rather than replacing `AnsibleModule` everywhere with a permissive fake.
- Cover creation, update, no-op, deletion, omission and reset, invalid input,
  ambiguous identity, ineligible targets, check and diff mode, secret masking
  with traceback capture enabled, partial writes and the `changed` they report,
  delayed visibility, malformed responses, request counts and retry after a
  timeout, wherever they apply.
- Make fake transports and clocks controllable, and assert the calls made and
  the resulting state, not merely that a mock returned the value the test
  supplied.
- Qualify claimed product operations, builds and locator profiles with real
  integration evidence and cleanup, at least on the lowest and the highest
  admitted ansible-core version. Keep destructive and network tests opt-in and
  bounded to test-owned fixtures.
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

**Enforcement:** the sessions of [Checks and tooling](#checks-tooling), review
of the tests, and catalogue links from a claimed operation to its evidence.


## Compatibility and releases<a id="compatibility-releases"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A collection release supports a bounded set of ansible-core versions and, for a
product collection, a bounded set of product series. Consumers pick the release
that matches their fleet, as they do for operating system support.

**You MUST:**

- Preserve public arguments, results, identities, fragments and helper
  interfaces within the promised compatibility policy, and record every
  behavioral change, removed support, migration and deprecation in a changelog
  fragment.
- Deprecate declaratively where Ansible supports it: `removed_in_version` with
  `removed_from_collection` and `deprecated_aliases` in the argument
  specification, and `plugin_routing` in `meta/runtime.yml` for whole modules,
  with tombstones for removed content.
- Build and install the exact release artifact and run discovery, import and
  execution checks against it before publishing.

**For modules that manage product state:**

- Pass the collection's eligibility check before every change, including
  command-line and action paths. Keep version and capability discovery
  read-only and free of side effects.
- Distinguish eligible ranges from the exact builds actually tested. A tested
  patch release does not authorize every patch in its series.
- Fail before any change on an ineligible target, and let read-only modules
  warn instead.

**You MUST NOT:**

- Add a public `api_version` option unless upstream offers selectable, named
  API versions whose semantic differences require a consumer choice. A product
  release is not an API version, and such an option must never bypass the
  eligibility check.
- Drop a product series or an ansible-core version, or change the meaning of an
  omitted field, in a patch release.
- Read the resource catalogue or any other development index at runtime.

**You SHOULD:**

- Keep `module.deprecate()` calls rare. The sanity rules for them differ between
  ansible-core versions: 2.16 requires `collection_name`, and 2.21 adds rules
  against passing it.

**Reasoning:**

- The eligibility check belongs in the shared client, before the request is
  sent, so no module can forget it.
- Compatibility covers behavior and dependencies, not only the spelling of an
  option. A silently changed default is a breaking change without a renamed
  parameter.
- Declarative deprecations are checked by the sanity tests and read the same on
  every ansible-core version.

**Enforcement:** a policy test comparing the runtime compatibility definition
with the positive support claims in the documentation and the catalogue,
changelog lint, and the build and import check.


## Checks and tooling<a id="checks-tooling"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Use [`antsibull-nox`](https://docs.ansible.com/projects/antsibull-nox/), the
check runner maintained Ansible community collections use, instead of a
hand-assembled toolchain. It runs `ansible-test` sanity, unit and integration
sessions in containers for every ansible-core version `requires_ansible`
admits, and adds lint, documentation, license and build checks. Red Hat's
`tox-ansible` covers the `ansible-test` part; `antsibull-nox` additionally
covers REUSE, documentation and the Galaxy importer, which foundata
collections rely on.

**You MUST:**

- Provide a `noxfile.py` and an `antsibull-nox.toml` in the collection root.
- Run the full sanity suite on every admitted ansible-core version and the
  development branch. Never reduce it to a single test.
- Run the unit tests of modules and module utilities on the lowest declared
  Python as well. ansible-test runs those tests on target-only Python
  versions, for example `ansible-test units --docker --python 3.9`; in
  `antsibull-nox` the units session takes `core_python_versions`.
- Run the file-only integration targets on every admitted ansible-core
  version. They execute a real task through the real argument parser, which
  no unit test does.
- Format and lint Python with Ruff, including import sorting, lint YAML
  including the documentation blocks with yamllint, and type-check with mypy
  against the newest ansible-core.
- Explain every sanity ignore entry with the affected ansible-core version, the
  reason and the condition under which it can be removed.

**You MUST NOT:**

- Suppress a documentation or specification mismatch to obtain a passing run.
- Apply a global `ignore_errors` or a blanket `ignore_missing_imports`.
- Treat a checker's target version, or the compile and import sanity tests,
  as proof that a standard library feature exists on the payload floor. They
  are necessary and not sufficient: a call to a newer standard library
  function compiles and imports on Python 3.9 and fails only when it runs.
  The payload unit tests on the floor catch it.

**Good examples:**

```python
# noxfile.py
# /// script
# dependencies = ["nox>=2025.02.09", "antsibull-nox"]
# ///

import sys

import nox

try:
    import antsibull_nox
except ImportError:
    print("You need to install antsibull-nox in the same Python environment as nox.")
    sys.exit(1)

antsibull_nox.load_antsibull_nox_toml()


if __name__ == "__main__":
    nox.main()
```

```toml
# antsibull-nox.toml
version = 1

[collection]
min_python_version = "ansible-test-config"

[sessions]

[sessions.lint]
run_isort = false              # Ruff sorts imports
run_black = false              # Ruff formats
run_ruff_format = true
run_ruff_autofix = true
ruff_autofix_select = ["I"]
run_ruff_check = true
run_flake8 = false             # Ruff covers it
run_pylint = false             # sanity runs pylint with ansible-core's rules
run_yamllint = true
run_mypy = true
mypy_config = ".mypy.ini"

[sessions.docs_check]

[sessions.license_check]

[sessions.extra_checks]
run_no_unwanted_files = true
run_no_trailing_whitespace = true
run_action_groups = true

[[sessions.extra_checks.action_groups_config]]
name = "api"
pattern = "^.*$"
exclusions = []
doc_fragment = "foundata.opnsense.api"

[sessions.build_import_check]
run_galaxy_importer = true

[sessions.ansible_test_sanity]
include_devel = true

[sessions.ansible_test_units]
include_devel = true
split_by_python_version = true
# Payload unit tests also on the lowest declared Python, per ansible-core version.
core_python_versions = { "2.16" = ["3.9", "3.12"], "2.21" = ["3.9", "3.14"] }

[sessions.ansible_test_integration_w_default_container]
include_devel = true
```

```toml
# ruff.toml
target-version = "py39"
line-length = 88

[lint]
select = ["E4", "E7", "E9", "F", "I", "B", "C4", "UP", "RUF"]

[lint.per-file-ignores]
# Documentation constants precede the ordinary imports by design.
"plugins/modules/*.py" = ["E402"]
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

Run the `ansible-test` sessions by tag and the Molecule scenarios separately:

```sh
nox                  # lint, docs, licenses, extra checks, build and import
nox -t sanity        # every admitted ansible-core version
nox -t units         # includes the payload Python floor
nox -t integration   # file-only integration targets
MOLECULE_GLOB='extensions/molecule/**/molecule.yml' molecule test --all
```

CI runs all five. Run the Molecule command in separate environments for the
lowest and highest admitted ansible-core series, using compatible tool
versions in each. An explicit matrix of `molecule test -s <scenario>` jobs may
replace `--all` if it covers every required scenario. A bare `molecule test`
runs only the default scenario.

A bare `nox` run excludes the `ansible-test` sessions. Check `nox --list` and
the generated CI matrix against the declared core and Python support.

**Reasoning:**

- `antsibull-nox` derives the ansible-core versions from `requires_ansible`, so
  the declared support and the tested support cannot drift apart.
- ansible-core ships no type information. `follow_untyped_imports` analyzes it
  anyway, which is how maintained community collections type-check against it,
  instead of ignoring every Ansible import.
- Sanity tests carry their own pinned pylint and pep8 configuration. A second
  pylint run with other rules adds maintenance without adding safety.

**Enforcement:** the collection's CI runs the sessions; review covers every
configuration exception and sanity ignore entry.


## Review checklist<a id="review-checklist"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Apply this list to every pull request that changes plugin code. Mark an item as
not applicable with a reason; a passing linter is not evidence of product
behavior.

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
  recover by identity after a timeout; failures carry `changed` and an unknown
  marker ([Convergence and results](#convergence-results)).
- [ ] **Performance:** no per-item searches, pagination complete, activation
  batched; a list-capable module validates everything first and reports per
  item ([Performance](#performance)).
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
- [ ] **Actions:** accepted, completed and verified distinguished; pending work
  handled; bootstrap state-aware
  ([Activation, actions and bootstrap](#activation-bootstrap)).
- [ ] **Reads:** `_info` naming, check mode, no side effects
  ([Info and facts modules](#info-facts-modules)).
- [ ] **Controller plugins:** justified; tested across ansible-core 2.19
  ([Action plugins](#action-plugins),
  [Filter and test plugins](#filter-test-plugins)).
- [ ] **Sharing:** fresh specifications; fragments tested with each consumer;
  stable helpers only in releases ([Shared code](#shared-code)).
- [ ] **Documentation:** header, markup, returns and limits accurate; the
  collection contract stated where consumers read; decisions separated from
  evidence in the design record
  ([Module documentation](#module-documentation)).
- [ ] **Tests:** every layer on every admitted ansible-core version, payload
  units on the floor; product claims backed by integration evidence
  ([Testing](#testing)).
- [ ] **Release:** eligibility checked before changes; deprecations declarative;
  changelog fragment present
  ([Compatibility and releases](#compatibility-releases)).
- [ ] **Checks:** all `antsibull-nox` sessions pass; every ignore entry
  explained ([Checks and tooling](#checks-tooling)).


## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust,
readable and consistent Ansible modules and plugins. It builds on the
[Ansible developer guide](https://docs.ansible.com/ansible/latest/dev_guide/)
and the
[Ansible community collection requirements](https://docs.ansible.com/ansible/latest/community/collection_contributors/collection_requirements.html),
which remain the authority for the framework's own rules.
