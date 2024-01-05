# How to name Git repositories

MUST, SHOULD and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

* [General rules](#general-rules)
* [Semantic naming schema](#semantic-naming-schema)
  * [Explanation](#explanation)
  * [Edge cases](#edge-cases)
    * [Duplication](#duplication)


## General rules<a id="general-rules"></a>

A repository name

* MUST start with a letter or number.
* MUST NOT contain any whitespace character.
* SHOULD only contain lowercase letters (`a-z`), numbers (`0-9`), and the characters `.`, `-` and `_`.


## Semantic naming schema<a id="semantic-naming-schema"></a>

There is probably information to be included in the repository name itself and a word separator to be used. Additional information SHOULD follow the following schema:

```
<language/framework/ecosystem>-<category>-<resource/project/package>
```

Examples:

* `roundcube-plugin-foo`
* `roundcube-plugin-foo-bar`
* `dokuwiki-template-vector`
* `chocolatey-usewindow.extension` (cf. note about [duplications](#duplication))


### Explanation<a id="explanation"></a>

`<language/framework/ecosystem>`:

* An optional prefix for easy filtering and grouping of repositories.
* Examples: `ansible`, `proxmox`, `python`.

`<category>`:

* An optional category specific to a certain ecosystem.
* Examples: `plugin`, `skin`, `template`, `role`, `collection`

`<resource/project/package>`:

* The unique core part of the repository name.
* If there is an obvious name within a certain ecosystem (e.g. a package ID), use it with lowercase characters.
* If there is no obvious ID to be used you are free to choose one. Use only lowercase letter and `-` (preferred) or `_` (deprecated) to separate multiple words.


### Edge cases<a id="edge-cases"></a>

#### Duplication<a id="duplication"></a>

If a `<language/framework/ecosystem>` is also a common prefix for `<resource/project/package>` and this leads to duplication, drop a duplication as filtering is still possible while keeping it would feel odd when working with the repository on the command line. So if the package is called `foo-package` and belongs to the `foo-` ecosystem, do NOT name the repository `foo-foo-package` but `foo-package` instead. The same is true if the package ID contains the type or category in some way.

Examples:

* If we would maintain the `ansible-lint` package, we would name the repository `ansible-lint` instead of `ansible-ansible-lint`.
* The `usewindow.extension` repository for Chocolatey is named `chocolatey-usewindow.extension` instead of `chocolatey-extension-usewindow.extension`.
