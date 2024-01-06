# How to name Git repositories

MUST, SHOULD and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

* [General rules](#general-rules)
* [Semantic naming schema](#semantic-naming-schema)
  * [Explanation](#explanation)
    * [`<prefix>`](#explanation-prefix)
    * [`<category>`](#explanation-category)
    * [`<resource-name>`](#explanation-resource)
  * [Edge cases](#edge-cases)
    * [Duplication](#duplication)


## General rules<a id="general-rules"></a>

A repository name

* MUST start with a letter or number.
* MUST NOT contain any whitespace character.
* MUST use the dash `-` as the delimiter for name parts.
* SHOULD only contain lowercase letters (`a-z`), numbers (`0-9`)
  * The characters `.`, and `_` are deprecated


## Semantic naming schema<a id="semantic-naming-schema"></a>

There is probably information to be included in the repository name itself. Additional information SHOULD follow the following schema:

```
<prefix>-<category>-<resource>
```

### Examples

* `roundcube-plugin-foo`
* `roundcube-plugin-bar-baz`
* `dokuwiki-template-vector`
* `chocolatey-extension-usewindow` (cf. note about [duplications](#duplication))
* `ansible-role-http`
* `ansible-collection-acme`


### Explanation<a id="explanation"></a>

#### `<prefix>`<a id="explanation-prefix"></a>

* For easy filtering and grouping of repositories belonging to a certain ecosystem or language.
* Only lowerchase characters `[a-z]` and numbers `[0-9]` allowed.
* Optional as there might be no senseful prefix or ecosystem. This is often the case for non-programming in-house repositories like [`guidelines`](./README.md).
* Examples: `ansible`, `proxmox`, `python`, `roundcube`.


#### `<category>`<a id="explanation-category"></a>

* An optional category, specific to a certain ecosystem.
* Only lowerchase characters `[a-z]` and numbers `[0-9]` allowed.
* Optional if there is no senseful category. This is often the case if there is only one kind of resource in a ecosystem.
* Examples: `plugin`, `skin`, `template`, `role`, `collection`


#### `<resource>`:<a id="explanation-resource"></a>

* Mandatory, unique core part of the repository name.
* Only lowerchase characters `[a-z]`, numbers `[0-9]` and additional `-` as word separator allowed.
* If there is an obvious name within a certain ecosystem (e.g. an upstream package ID), use it in a sanitized way:
  * Replace uppercase with lowercase characters
  * Replace `_` with `-`
* If there is no obvious ID to be used you are free to choose one following the same rules.


### Edge cases<a id="edge-cases"></a>

#### Duplication<a id="duplication"></a>

If a `<prefix>` or `<category>` is also a common part of `<resource>` and this leads to duplication, drop the duplicates. So if the package is called `foo-package` and belongs to the `foo-` ecosystem, do NOT name the repository `foo-foo-package` but `foo-package` instead. The same is true if the package ID contains the type or category in some way. Name filtering is still possible this but the name does not feel odd when working with the repository on the command line.

Examples:

* If we would maintain the `ansible-lint` package, we would name the repository `ansible-lint` instead of `ansible-ansible-lint`.
* The `usewindow.extension` repository for Chocolatey is named `chocolatey-extension-usewindow` instead of `chocolatey-extension-usewindow-extension`.
