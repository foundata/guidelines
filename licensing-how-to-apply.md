# Licensing guide: How to apply licenses

This document explains how to apply one or more licenses in your project after [choosing](./licensing-how-to-choose-a-license.md) them.

[foundata](https://foundata.com/)'s projects are usually following the [REUSE specification](https://reuse.software/spec/). It is helpful to [install the `reuse` tool](https://reuse.readthedocs.io/en/latest/readme.html#install), usually being available as package of the same name (e.g. via `dnf` or `apt`).



## Table of contents

* [Step 1: Choose the license(s)](#choose-license)
* [Step 2: Add license text(s)](#add-text)
* [Step 3: Add a machine-readable copyright file](#machine-readable-file)
  * [Multiple licenses](#machine-readable-file-multiple-licenses)
* [Step 4: Add licensing and copyright information in the `README.md`](#human-info)
  * [Multiple licenses](#human-info-multiple-licenses)
* [Step 5: Add license comment headers (optional, recommended)](#license-comment-headers)
  * [Reasoning](#license-comment-headers-reasoning)
  * [Issues](#license-comment-headers-issues)
* [Step 6: REUSE linting](#linting)
* [Step 7: Register as compliant repository (optional)](#reuse-api)
* [Frequently Asked Questions (FAQ)](#faq)
  * [How to update the copyright year?](#update-copyright-year)
  * [Why does the license detection of GitHub and others not work?](#broken-repo-hoster-license-detection)
* [Disclaimer](#disclaimer)



## Step 1: Choose the license(s)<a id="choose-license"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Read our [guideline on how to choose a license](./licensing-how-to-choose-a-license.md) if you are new to the topic. It provides reasoning and summarizes the characteristics of each of the relevant licenses. TL;DR:

**Our defaults for software projects are:**

* [`GPL-3.0-or-later`](./licensing-how-to-choose-a-license.md#gpl-30-or-later) as [copyleft](https://en.wikipedia.org/wiki/Copyleft) license
* [`Apache-2.0`](./licensing-how-to-choose-a-license.md#apache-20) as premissive license

**Our defaults for projects with focus on media, design, 3D-printing plans or physical objects are:**

* [`CC-BY-SA-4.0`](./licensing-how-to-choose-a-license.md#cc-by-sa-40) as [copyleft](https://en.wikipedia.org/wiki/Copyleft) license
* [`CC-BY-4.0`](./licensing-how-to-choose-a-license.md#cc-by-40) as premissive license



## Step 2: Add license text(s)<a id="add-text"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

1. Create a `LICENSES` directory in your project's root directory. It will contain all the licenses that you use in your project as text files.
   ```bash
   mkdir 'LICENSES'
   ```
3. Put the license text of each used license as [`<SPDX-License-Identifier>`](https://spdx.org/licenses/)`.txt` in the `LICENSES` directory.<br><br>You can download them manually from the [REUSE license-list-data repository](https://github.com/spdx/license-list-data/tree/main/text) or by using the `reuse download` command followed by a list of SPDX license identifiers. Examples:
   ```bash
   reuse download GPL-3.0-or-later
   reuse download Apache-2.0
   reuse download CC-BY-SA-4.0
   reuse download CC-BY-4.0
   reuse download GPL-3.0-or-later MIT Apache-2.0
   ```


## Step 3: Add a machine-readable copyright file<a id="machine-readable-file"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

1. Create a `.reuse` directory in your project's root directory.
   ```bash
   mkdir '.reuse'
   ```
2. Add a UTF-8 encoded text file with Unix line feeds (LF, `\n`) called `dep5` in the `.reuse` directory.
   ```bash
   touch '.reuse/dep5'
   ```
   Please use the following template to do so:
   ```
   Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
   Upstream-Name: <name of your project>
   Upstream-Contact: foundata GmbH <https://foundata.com>
   Source: <URL of the public repository, https://github.com/foundata/...>

   Files: *
   Copyright: foundata GmbH <https://foundata.com>
   License: GPL-3.0-or-later
   ```
   Replace `GPL-3.0-or-later` with your [SPDX license identifier](https://spdx.org/licenses/) and all other information as needed. The `Files:` field expects a whitespace-separated list and can appear multiple times, see [the official documentation](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/#files-field) for more information on the syntax, e.g. on how to defined excludes. The `*` wildcard makes sure all existing files are properly licensed by default even without inline license comment headers or `.license` files.


### Multiple licenses<a id="machine-readable-file-multiple-licenses"></a>

You can add additional stanzas when using multiple licenses and/or third party components in the same project. [SAP's OpenUI5 `.reuse/dep5` file](https://github.com/SAP/openui5/blob/master/.reuse/dep5) is a good real-world example on how to do so with many third party libraries and good usage of `Comment:`.



## Step 4: Add licensing and copyright information in the `README.md`<a id="human-info"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Add a `Licensing, copyright` section in the `README.md` or a comparable central place which is easy for humans to notice and read. Please use the following template to do so:

```markdown
## Licensing, copyright

Copyright (c) YYYY, foundata GmbH (https://foundata.com)

<!--REUSE-IgnoreStart-->
This project is licensed under the GNU General Public License v3.0 or later (SPDX-License-Identifier: `GPL-3.0-or-later`), see [`LICENSES/GPL-3.0-or-later.txt`](LICENSES/GPL-3.0-or-later.txt) for the full text.

The [`.reuse/dep5`](.reuse/dep5) file provides detailed licensing and copyright information in a human- and machine-readable format. This includes parts that may be subject to different licensing or usage terms, such as third party components. The repository conforms to the [REUSE specification](https://reuse.software/spec/), you can use [`reuse spdx`](https://reuse.readthedocs.io/en/latest/readme.html#cli) to create a [SPDX software bill of materials (SBOM)](https://en.wikipedia.org/wiki/Software_Package_Data_Exchange).
<!--REUSE-IgnoreEnd-->
```

Replace `YYYY` with the year of the first release or [code contribution](https://reuse.readthedocs.io/en/latest/scripts.html#starting-point-of-the-codebase) and adapt the mentioned license, filenames and links as needed. The HTML comments prevent linting errors when e.g. listing [multiple licenses](#human-info-multiple-licenses).

Feel free to add additional author information not suitable for the [inline license notice](#license-comment-headers) as additional section:

```markdown
## Author information

This project was created and is maintained by [foundata](https://foundata.com/). If you like it, you might [buy them a coffee](https://buy-me-a.coffee/).

Special thanks to:

* John Doe fixing the bug in `foo.cpp`
* [... List of additional people or projects ...]
```


### Multiple licenses<a id="human-info-multiple-licenses"></a>

The wording of the `README.md`'s licensing and copyright information is already pointing to the [copyright file](#machine-readable-file) (`.reuse/dep5`) and mentions that parts of the project might be subject to different licensing than the main one. If this is not good enough, feel free to adapt the wording of the main "licensed under" sentence to highlight the main licensing rules without the need to maintain every single bit outside of the copyright file. Examples (adapt as needed):

```markdown

The project is dual-licensed under the

* GNU General Public License v3.0 or later (SPDX-License-Identifier: `Apache-2.0`), see [`LICENSES/Apache-2.0.txt`](./LICENSES/Apache-2.0.txt) for the full text.
* Apache License 2.0 (SPDX-License-Identifier: `GPL-3.0-or-later`), see [`LICENSES/GPL-3.0-or-later.txt`](./LICENSES/GPL-3.0-or-later.txt) for the full text.

[... usual template follows ...]
```

```markdown
Parts of the project are licensed differently:

* The project is primarily licensed under the GNU General Public License v3.0 or later (SPDX-License-Identifier: `GPL-3.0-or-later`), see [`LICENSES/GPL-3.0-or-later.txt`](./LICENSES/GPL-3.0-or-later.txt) for the full text.
* Files below `/doc` are licensed under the [Creative Commons Attribution Share Alike 4.0 International](https://creativecommons.org/licenses/by-sa/4.0/deed) license, see [`LICENSES/CC-BY-SA-4.0.txt`](./LICENSES/CC-BY-SA-4.0.txt) for the full text.

The above list might not be exhaustive. [... usual template follows ...]
```



## Step 5: Add license comment headers (optional, recommended)<a id="license-comment-headers"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

While having a [proper copyright file with wildcard](#machine-readable-file) beside an [updated README](#human-info) is compliant and convenient, it is recommended to add license comment headers. Please use the following template if so:

```
SPDX-License-Identifier: GPL-3.0-or-later
SPDX-FileCopyrightText: foundata GmbH <https://foundata.com>
```

Replace `GPL-3.0-or-later` with your [SPDX license identifier](https://spdx.org/licenses/) as needed. Use `OR` to [declare multiple licenses for the file at the same time](https://reuse.software/faq/#multi-licensing) (e.g. `SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0 OR MIT`).

For binaries, images and other uncommentable files, put the comment into a accompanying `<filename>.license` textfile (e.g. `foo.jpg.license` for `foo.jpg`). However, we usually do not use this as long as the binary file is not somehow outstanding as we think `.license` files are clumsy and clutter the repo.

**Consider license comment headers at least for the following files:**

* **Files which are intended to be used stand-alone** without context and repository. This is usually the case for helper scripts or projects like [`pve_backup_usb.sh`](https://github.com/foundata/proxmox-pve_backup_usb/blob/main/pve_backup_usb.sh).
* **Files where header comments are common and not annoying**. Common sense applies: usual source code files with existing header comments are quite easy, but Markdown files are intended to be often read directly and a inline header comment is unusual and would disturb readability.

**Never add a license notice for the following files** as this would disturb readability, maintainability or common tooling:

* [build artifacts](https://reuse.software/tutorial/#build-artifacts) and comparable files usually listed in a project's `.gitignore` (side note: [files listed in a `.gitignore` get automatically excluded](https://reuse.software/faq/#exclude-file) by the reuse-toolset)
* tooling helper files and directories like `.gitignore`, `.github`, `.reuse` or `.ansible-lint`
* repository bureaucracy files like changelogs, `SECURITY`, `README.md`, `CONTRIBUTING.md` and the text files below the `LICENSES` directory
* third party components as thy should not be edited (simply list their license in the [copyright file](#machine-readable-file))


### Reasoning<a id="license-comment-headers-reasoning"></a>

[REUSE](https://github.com/fsfe/reuse-docs/issues/117#issuecomment-1306963966) and many organizations like [GNU](https://www.gnu.org/licenses/gpl-howto.html.en#why-license-notices) recommends to include license header comments in source files as it helps to prevent confusion or errors. So even if the [copyright file](#machine-readable-file) exists as central place for licensing information, files sometimes get copied or forked into new projects and third parties might not have a well organized repository bureaucracy. Without a statement about what their license is, moving single files into another context might eliminate all trace of that point. As this argument makes sense, [we mostly follow this recommendation](#license-comment-headers) with a few exceptions.

We do not include a copyright year nor links to license texts in the header comments to keep maintenance easy while still being informative. There is no legal disadvantage by doing so, the year is mostly historical common but optional information, especially if [the `README.md`](#human-info) provides the year. Thanks to the commit history and public repositories, open source projects usually have no problems proving the chronological in a way that third parties can understand. This should also be legally more robust than a simple year in an easily changed file if somebody claims some kind of prior art. We therefore maintain the year and links to license texts only at central places like a project's [`README.md`](#human-info).


### Issues<a id="license-comment-headers-issues"></a>

There are a few issues when using license comment headers one should know about:

* `reuse lint` and the whole specification 3.0 [does not define the order of precedence](https://github.com/fsfe/reuse-tool/issues/779) in case of conflicts between the [copyright file](#machine-readable-file) and the license header. You *must* avoid conflicts as the legal order of precedence is unclear.
* `reuse spdx` adds two `LicenseInfoInFile` keys in the [SPDX software bill of materials (SBOM)](https://en.wikipedia.org/wiki/Software_Package_Data_Exchange) even if the license is the same (at least up to program version 2.1.0). As of 2024-Q1, this and [comparable toolset issues](https://github.com/fsfe/reuse-tool/issues/885) propably get fixed soon.



## Step 6: REUSE linting<a id="linting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[Use `reuse lint`](https://reuse.readthedocs.io/en/stable/usage.html#lint) to confirm the project's compliance to the [REUSE specification](https://reuse.software/spec/):

```bash
reuse lint
reuse --root '/path/to/project' lint
```

Example output:

```bash
# SUMMARY

* Bad licenses: 0
* Deprecated licenses: 0
* Licenses without file extension: 0
* Missing licenses: 0
* Unused licenses: 0
* Used licenses: GPL-3.0-or-later
* Read errors: 0
* files with copyright information: 16 / 16
* files with license information: 16 / 16

Congratulations! Your project is compliant with version 3.0 of the REUSE Specification :-)
```

Example commit for the changes if everything is fine:

```bash
git commit -m "Update licensing information" -m "This project follows the REUSE specification (https://reuse.software/spec/)."
```

It is a good idea to add `reuse lint` into your project's continuous integration pipeline (if any). [Files listed in `.gitignore` get automatically excluded](https://reuse.software/faq/#exclude-file) from REUSE compliance testing and [ignoring parts of a file](https://reuse.readthedocs.io/en/latest/usage.html#ignoring-parts-of-a-file) is possible by adding `REUSE-IgnoreStart` and `REUSE-IgnoreEnd`.



## Step 7: Register as compliant repository (optional)<a id="reuse-api"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

The Free Software Foundation provides an API plus services to continuously check and display compliance with the REUSE guidelines.

See the following for more information:

* https://api.reuse.software/projects
* https://api.reuse.software/register (please use the `office@` email address for confirmation mails)

They also provide a status badge for your `README.md` like the one showing that [`github.com/foundata/guidelines`](https://github.com/foundata/guidelines) is REUSE compliant:

[![REUSE status](https://api.reuse.software/badge/github.com/foundata/guidelines)](https://api.reuse.software/info/github.com/foundata/guidelines)



## Frequently Asked Questions (FAQ)<a id="faq"></a>

### How to update the copyright year?<a id="update-copyright-year"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

It is not *needed* to update the copyright year as the main legal intention is to state the year of the first public release or code contribution. But it is common to do so anyways, especially as it shows third parties that a project is still alive. We therefore update this data but maintain the copyright year only at [central places like a project's `README.md`](#human-info) to reduce the maintainance effort.

Please simply add each year with a release or updates separated by comma. You can use a timespan (`year1-year2`) for multiple subsequent years.

Example: The first release and copyright statement was `Copyright (c) 2013`. There were realeases or updates in several but not all years afterwards:

* `2015` → `Copyright (c) 2013, 2015`.
* `2018` → `Copyright (c) 2013, 2015, 2018`.
* `2019` → `Copyright (c) 2013, 2015, 2018, 2019`.
* `2020` → `Copyright (c) 2013, 2015, 2018-2020`.
* `2021` → `Copyright (c) 2013, 2015, 2018-2021`.
* `2023` → `Copyright (c) 2013, 2015, 2018-2021, 2023`.


### Why does the license detection of GitHub and others not work?<a id="broken-repo-hoster-license-detection"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[GitHub uses Licensee](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository#detecting-a-license) to attempt to identify the license of a project and [Licensee does not support the REUSE specification](https://github.com/licensee/licensee/issues/490). A workaround to fix the automatic license detection of GitHub and [others](https://forum.openmod.org/t/reuse-incompatible-to-auto-detection-of-license-s/3590) is to place an *additional* `LICENSE` or `COPYING` file in the root directory of your project. This is [allowed by REUSE](https://reuse.software/faq/#tradition). These files are explicitly [ignored by the toolset](https://github.com/fsfe/reuse-tool/blob/0e111c423ccf927f73a9ae7b39d3f88268b015b9/src/reuse/__init__.py#L66-L77) and do not need an additional `.license` file or header.

Please use this workaround *only* if a single license is used for all of the project's files, so that there can be no misunderstandings or conflicts. Simply ignore GitHub's limited behavior in all other cases. Automatic license heuristics is complicated and will never deliver perfect results (which is one of the reasons solved by REUSE and a good license note in a project's `README.md`).

One note on symlinks to prevent content duplication: You can place a symlink at `LICENSES/<your license>.txt` pointing to the `LICENSE` or `COPYING` file in the project's root directory as `reuse lint` follows them. [Licensee sadly does not even support symlinks](https://github.com/licensee/licensee/pull/42), so a more logical symlink from `LICENSE` or `COPYING` pointing to `LICENSES/<your license>.txt` is not solving the issue. We therefore recommend a real *copy* instead of a symlink to keep things accessible when using the workaround.


## Disclaimer

[*⇑ Back to TOC ⇑*](#table-of-contents)

1. **This is not legal advice.** If in doubt: Ask persons in charge and/or a lawyer as some additional rules might apply.
2. After choosing and/or applying a license or in any case of uncertainty, **communicate with persons in charge for a last check before releasing a new project or repository** to the public.
