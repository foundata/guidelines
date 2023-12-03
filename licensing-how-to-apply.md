# Licensing guide: How to apply licenses

This document explains how to apply one or more licenses in your project after [choosing](./licensing-how-to-choose-a-license.md) them.

[foundata](https://foundata.com/)'s projects are usually following the [REUSE specification](https://reuse.software/spec/). It is helpful to [install the `reuse` tool](https://reuse.readthedocs.io/en/latest/readme.html#install), usually be available as package of the same name (e.g. via `dnf` or `apt`).



## Table of contents

* [Step 1: Choose the license(s)](#choose-license)
* [Step 2: Add license text(s)](#add-text)
* [Step 3: Add a machine readable copyright file](#machine-readable-file)
  * [Multiple licenses](#machine-readable-file-multiple-licenses)
* [Step 4: Add licensing and copyright information in the `README.md`](#human-info)
  * [Multiple licenses](#human-info-multiple-licenses)
* [Step 5: REUSE linting (optional)](#linting)
* [Step 6: license header comments (optional)](#license-header)
  * [Reasoning](#license-header-reasoning)
  * [Issues](#license-header-issues)
* [Frequently Asked Questions (FAQ)](#faq)
  * [How to update the copyright year?](#update-copyright-year)
* [Disclaimer](#disclaimer)



## Step 1: Choose the license(s)<a id="choose-license"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Read our [guideline on how to choose a license](./licensing-how-to-choose-a-license.md) if you are new to the topic. It provides reasoning and summarizes the characteristics of each of the relevant ones.

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
   reuse download CC-BY-SA-4.0 CC-BY-4.0 MIT Apache-2.0
   ```


## Step 3: Add a machine readable copyright file<a id="machine-readable-file"></a>

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
   Replace `GPL-3.0-or-later` with your [SPDX license identifier](https://spdx.org/licenses/) and all other information as needed. The `Files:` field expects a whitespace-separated list and can appear multiple times, see [the official documentation](https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/#files-field) for more information on the syntax, e.g. on how to defined excludes.


### Multiple licenses<a id="machine-readable-file-multiple-licenses"></a>

You can add additional stanzas when using multiple licenses and/or third party components in the same project. [SAP's OpenUI5 `.reuse/dep5` file](https://github.com/SAP/openui5/blob/master/.reuse/dep5) is a good real-world example on how to do so.



## Step 4: Add licensing and copyright information in the `README.md`<a id="human-info"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Add a `Licensing, copyright` section in the `README.md` (or a comparable central place which is easy for humans to notice and read). Please use the following template to do so:

```markdown
## Licensing, copyright

Copyright (c) YYYY, foundata GmbH (https://foundata.com)

This project is licensed under GNU General Public License v3.0 or later (SPDX-License-Identifier: `GPL-3.0-or-later`), see [`LICENSES/GPL-3.0-or-later.txt`](./LICENSES/GPL-3.0-or-later.txt) for the full text.

Almost all files have a machine readable `SDPX-License-Identifier:` comment denoting its respective license(s) or an equivalent entry in an accompanying `.license` file. Some files which will not be part of a release (like changelog or build fragments) or documentation usually do not have a license notice. This conforms to the [REUSE specification](https://reuse.software/spec/).
```

Replace `YYYY` with the year of the first release (even if the project was only released internally) and adapt the mentioned license, filenames and links as needed.

Feel free to add additional author information not suitable for the [inline license notice](#license-header) as additional section:

```markdown
## Author information

This project was created and is maintained by [foundata](https://foundata.com/). If you like it, you might [buy them a coffee](https://buy-me-a.coffee/).

Special thanks to:

* John Doe fixing the bug in `foo.cpp`
* [... List of additional people or projects ...]
```


### Multiple licenses<a id="human-info-multiple-licenses"></a>

If you are using multiple licenses in the same project, adapt the wording of the "licensed under" sentence. Please use the following template to do so:

```markdown
This project is primarily licensed under GNU General Public License v3.0 or later (SPDX-License-Identifier: `GPL-3.0-or-later`), see [`LICENSES/GPL-3.0-or-later.txt`](./LICENSES/GPL-3.0-or-later.txt) for the full text. Parts of the project are licensed differently, see `[.reuse/dep5]` for details.
```

Adapt the mentioned license, filenames and links as needed.


## Step 5: REUSE linting (optional)<a id="linting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[Use `reuse lint`](https://reuse.readthedocs.io/en/stable/usage.html#lint) to confirm the project's compliance to the [REUSE specification](https://reuse.software/spec/):

```bash
reuse lint
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

It is a good idea to add `reuse lint` into your project's continuous integration pipeline (if any). [Files in `.gitignore` get automatically excluded](https://reuse.software/faq/#exclude-file) from REUSE compliance testing and [ignoring parts of a file](https://reuse.readthedocs.io/en/latest/usage.html#ignoring-parts-of-a-file) is possible by adding `REUSE-IgnoreStart` and `REUSE-IgnoreEnd`.



## Step 6: license header comments (optional)<a id="license-header"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Because of some [issues](#license-header-issues), **add license headers only to files intended to be used stand-alone** without context and repository. This is usually the case for helper scripts or projects like [`pve_backup_usb.sh`](https://github.com/foundata/proxmox-pve_backup_usb/blob/main/pve_backup_usb.sh).

Please use the following template if you want to include header comments:

```
SPDX-License-Identifier: GPL-3.0-or-later
SPDX-FileCopyrightText: foundata GmbH <https://foundata.com>
```

Replace `GPL-3.0-or-later` with your [SPDX license identifier](https://spdx.org/licenses/) as needed. Use `OR` to [declare multiple licenses for the file at the same time](https://reuse.software/faq/#multi-licensing) (e.g. `SPDX-License-Identifier: GPL-3.0-or-later OR Apache-2.0 OR MIT`). For binaries, images and other uncommentable files, put the comment into a accompanying `<filename>.license` textfile (e.g. `foo.jpg.license` for `foo.jpg`).

**Never add a license notice for the following files** as this would disturb readability, maintainability or common tooling:

* [build artifacts](https://reuse.software/tutorial/#build-artifacts) and comparable files usually listed in a project's `.gitignore`
* tooling helper files and directories like `.gitignore`, `.github`, `.reuse` or `.ansible-lint`
* repository bureaucracy files like changelogs, `SECURITY`, `README.md`, `CONTRIBUTING.md` and the text files below the `LICENSES` directory
* third party components as thy should not be edited (simply list their license in the [copyright file](#machine-readable-file))


### Reasoning<a id="license-header-reasoning"></a>

At least [GNU](https://www.gnu.org/licenses/gpl-howto.html.en#why-license-notices) recommends to include license header comments in source files as it helps to prevent confusion or errors. Files sometimes get copied or forked into new projects an third parties might not have a well organized repository bureaucracy. Without a statement about what their license is, moving files into another context might eliminate all trace of that point. As this makes sense, we follow this recommendation for files intended to be used stand-alone and a high propability to exists somewhere without the repository.

We do not include a copyright year nor links to license texts in the header comments to keep maintenance easy while still being informative. There is no legal disadvantage by doing so, the year is mostly historical common but optional information, especially if the [the `README.md`](#human-info) provides the year. Thanks to the commit history and public repositories, open source projects usually have no problems proving the chronological in a way that third parties can understand. This should also be legally more robust than a simple year in an easily changed file if somebody claims some kind of prior art. We therefore maintain the year and links to license texts only at central places like a project's [`README.md`](#human-info).


### Issues<a id="license-header-issues"></a>

Sadly, there are issues when using license header comments:

* It is possible to produce conflicts between the [copyright file](#machine-readable-file) and the license header. You *must* avoid that as the legal order of precedence is unclear.
* `reuse spdx` adds two `LicenseInfoInFile` keys even if the license is the same
* `reuse lint` and the whole specification 3.0 [does not define the order of precedence](https://github.com/fsfe/reuse-tool/issues/779) in case of conflicts.



## Frequently Asked Questions (FAQ)<a id="faq"></a>

### How to update the copyright year?<a id="update-copyright-year"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

It is not *needed* to update the copyright year there as it is the legal intention to state the year of the first public release. But it is common to do so anyways and it shows third parties that a project is still alive. We therefore update this data and maintain the copyright year only at [central places like a project's `README.md`](#human-info) to reduce the effort to do so.

Please simply add each year with a release or updates separated by comma. You can use a timespan (`year1-year2`) for multiple subsequent years.

Example: The first release and copyright statement was `Copyright (c) 2013`. There were realeases or updates in several but not all years afterwards:

* `2015` → `Copyright (c) 2013, 2015`.
* `2018` → `Copyright (c) 2013, 2015, 2018`.
* `2019` → `Copyright (c) 2013, 2015, 2018, 2019`.
* `2020` → `Copyright (c) 2013, 2015, 2018-2020`.
* `2021` → `Copyright (c) 2013, 2015, 2018-2021`.
* `2023` → `Copyright (c) 2013, 2015, 2018-2021, 2023`.


## Disclaimer

[*⇑ Back to TOC ⇑*](#table-of-contents)

1. **This is not legal advice.** If in doubt: Ask persons in charge and/or a lawyer as some additional rules might apply.
2. After choosing and/or applying a license or in any case of uncertainty, **communicate with persons in charge for a last check before releasing a new project or repository** to the public.
