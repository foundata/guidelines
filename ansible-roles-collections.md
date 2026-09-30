# Ansible roles and collections

This guide defines how to organize Ansible roles and collections and describe
role parameters. It covers collection boundaries, naming, dependencies and role
argument specifications.

For task, playbook and template authoring, follow the
[Ansible playbook guidelines](./ansible-playbooks.md). For modules and
supporting plugin code, follow the
[Ansible module development guide](./ansible-modules.md).

The terms MUST, SHOULD, and other key words are used as defined in
[RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [Scoping (collections and roles)](#scoping)
- [Role argument specifications](#roles)
- [Author information](#author-information)


## Scoping (collections and roles)<a id="scoping"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Scope collections by
  **managed subsystem or encapsulated, self-contained software** (examples:
  `foundata.sshd`, `foundata.logrotate`, `foundata.ad`) — never by machine role,
  edition, or SKU (no `windows_server`, no `linux_desktop`). Express platform or
  edition restrictions via supported-platform metadata and asserts; express
  per-host-class differences via inventory data.
- Keep exactly one base collection per operating system (`foundata.linux`,
  `foundata.windows`) and define its content **positively**: primitives that the
  upstream base collections lack, plus machine-lifecycle roles applicable to any
  host of that OS (`reboot`, `disk`, `user`, …). The base collection is not a
  bin for leftovers: a subsystem without a home stays a documented script or
  playbook until it earns a collection.
- Create a separate collection for a subsystem only when there is concrete
  automation demand **and** at least one of the following holds — otherwise
  implement it as a role in the base collection:
  - it imposes a distinct upstream dependency other consumers should not inherit
    (e.g., `microsoft.ad`),
  - it carries a distinct risk or review domain (e.g., destructive directory
    operations),
  - it has an independent consumer set (usable without the rest).

**You MUST NOT:**

- Build 1:1 wrapper modules or roles around upstream functionality. Facades are
  legitimate only when they compose several primitives under one opinionated
  contract (n:1 — e.g., a `user` role that also manages SSH authorized keys).

**You SHOULD:**

- Mirror upstream collection boundaries when in doubt (`foundata.ad` ↔
  `microsoft.ad`; domain join lives on the AD side because
  `microsoft.ad.membership` does).
- Name collections after the software's own distinctive name (`nginx`, `sshd`,
  `ad`). When the name is a generic protocol or service term with
  implementations on several platforms, add the platform prefix `win_` for
  Windows subsystems (`win_fileserver`, `win_dhcp`). Do not use vendor prefixes
  such as `ms_`: they mark the vendor, not the platform gate (SQL Server also
  runs on Linux).
- Use a single `run` role for single-lifecycle collections and named lifecycle
  roles for multi-lifecycle ones (`foundata.podman`: `host`, `quadlet`). Drop
  scope prefixes that repeat the collection name (role `objects` in
  `foundata.ad`, not `ad_objects`).
- Keep dependencies one-way: verticals may depend on the base collection, never
  the reverse.
- Reserve names for foreseeable subsystems in design documents instead of
  creating empty collections.

**Good examples:**

```text
foundata.linux            # base: auto_update, disk, reboot, sudo, sysctl, user
foundata.sshd             # vertical: encapsulated software, role "run"
foundata.ad               # vertical: own upstream dep (microsoft.ad) + own risk domain
foundata.win_fileserver   # vertical: generic term -> win_ prefix
foundata.ad.objects       # role: no "ad_" stutter; vars objects_ad_*
```

**Bad examples:**

```text
foundata.windows_server   # machine-role axis; only negatively definable -> grab-bag
foundata.ntfs             # collection around a single primitive module -> module in foundata.windows
foundata.ms_dhcp          # vendor prefix instead of platform prefix
foundata.windows.registry # 1:1 wrapper around ansible.windows.win_regedit
foundata.ad.ad_objects    # scope prefix repeats the collection (vars: ad_objects_ad_*)
```

**Reasoning:**

- The subsystem axis matches both our namespace practice and the upstream
  ecosystems: the `microsoft.*` namespace consists exclusively of
  subsystem/product verticals (ad, iis, sql, wsl, hyperv, scvmm, scom, mecm).
  Machine-role collections have no positive definition and degenerate into
  grab-bags (the `community.windows` effect).
- Every collection costs a skeleton, CI, releases, and documentation; FQCN moves
  after consumers exist are breaking changes (upstream needed multi-year
  deprecation cycles for `win_domain*` → `microsoft.ad`). The demand gate
  prevents premature micro-collections; the split criteria catch the cases where
  a late split would be the more expensive mistake.
- Dependency hygiene: a base collection that depends on a vertical (or its
  upstream) forces those pins onto every consumer.
- 1:1 wrappers double the documentation surface, lag upstream features, and hide
  the ecosystem from users. Opinionated composition is where in-house
  collections add value.


## Role argument specifications<a id="roles"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use
  [`meta/argument_specs.yml`](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_reuse_roles.html#specification-format)
  to describe role parameters.

**Good examples:**

```yaml
# meta/argument_specs.yml
---

argument_specs:
  main:
    short_description: "Install and configure the example application, main entry point of the role"
    description:
      - "This role installs and configures the example application."
      - "It supports Debian and RedHat-based systems."
    author: "Your Name"
    options:

      example_version:
        type: "str"
        required: false
        default: "latest"
        description: "Version of the example application to install."

      example_config_path:
        type: "path"
        required: false
        default: "/etc/example/config.yml"
        description: "Path to the configuration file."

      example_enabled:
        type: "bool"
        required: false
        default: true
        description: "Whether to enable the example service."
```

**Reasoning:**

- The `argument_specs.yml` file documents role parameters, including types,
  defaults, and descriptions.
- Tools such as
  [DocSmith for Ansible](https://github.com/foundata/ansible-docsmith) can
  generate documentation from it.
- Ansible uses this specification to validate role arguments at runtime,
  catching configuration errors early.
- It is the machine-readable source for role parameter documentation and stays
  with the role implementation.


## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust,
readable and consistent code. It was inspired by
[Whitecloud Analytics's Ansible styleguide](https://github.com/whitecloud/ansible-styleguide).
