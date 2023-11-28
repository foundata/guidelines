# Licensing guide

## Table of contents

* [Disclaimer](#disclaimer)
* [Licenses to choose from](#licenses-to-choose-from)
  * [GNU General Public License v3.0 or later](#gnu-general-public-license-v30-or-later)
  * [GNU Affero General Public License v3.0 or later](#gnu-affero-general-public-license-v30-or-later)
  * [GNU Lesser General Public License v3.0 or later](#gnu-lesser-general-public-license-v30-or-later)
  * [Apache License 2.0](#apache-license-20)
  * [MIT License](#mit-license)
* [Reasoning](#reasoning)



## Disclaimer

1. **This is not legal advice.** If in doubt: Ask persons in charge and/or a lawyer as some additional rules might apply (like the [Arbeitnehmererfindungsgesetz (ArbnErfG)](https://www.gesetze-im-internet.de/arbnerfg/) mentioned in your employment contract).
2. After choosing a license and doing preparation or in any case of uncertainty, **communicate with persons in charge for a last check before releasing a new project or repository** to the public.



## Licenses to choose from

The following licenses are well-known and [OSI-approved](https://opensource.org/licenses/). **All of them allow commercial and private use, modification and distribution and instruct that copyright and license notices must be preserved.** The main differences between them are [copyleft](https://en.wikipedia.org/wiki/Copyleft), what a third party has to do with modifications or when embedding a work into another existing project (a "larger work").

**We prefer copyleft over permissive licenses. [`GPL-3.0-or-later`](#gnu-general-public-license-v30-or-later) is our default copyleft license and [`Apache-2.0`](#apache-license-20) our default premissive one.**

However, many projects exist in a wider ecosystem with a license preferred by the community, usually aligned with the main project or product if so. Take this into account when choosing a license. Have a look at existing repositories and/or search the web for `<project> licensing requirements` to get an impression. Examples for preferred licenses in a certain ecosystem.



### GNU General Public License v3.0 or later

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **strong [copyleft](https://en.wikipedia.org/wiki/Copyleft)** license:

* Copyright and license notices must be preserved.
* Modifications have to be released under the same license.
* Embedding into a larger work is only possible when the larger work is using the same or a compatible license.

**How to apply**:

1. Create a `COPYING` text file the root directory of your project (Unix line feed (LF, `\n`) and UTF-8 encoding).
2. Copy the [text of the license](https://www.gnu.org/licenses/gpl-3.0.txt) into the `COPYING` file.
3. Add a `Licensing, copyright` section in the `README.md` (or a comparable central place) that follows the following template:
   ```
   ## Licensing, copyright

   Copyright (c) YYYY, foundata GmbH (https://foundata.com)

   This project is licensed under GNU General Public License v3.0 or later (SPDX-License-Identifier: `GPL-3.0-or-later`), see [`COPYING`](./COPYING) or https://www.gnu.org/licenses/gpl-3.0.txt for the full text.
   ```
   Replace `YYYY` with the year of the first release. Add additional notes as needed.
4. Use a license notice in the header comment of each file that follows the following template:
   ```
   Copyright (c) foundata GmbH (https://foundata.com)
   SPDX-License-Identifier: GPL-3.0-or-later
   ```


**Used by / default for:**

* [Ansible](https://docs.ansible.com/ansible/devel/community/collection_contributors/collection_requirements.html#collection-licensing-requirements)


**Further reading:**

* [Choose a license: GNU General Public License v3.0](https://choosealicense.com/licenses/gpl-3.0/)
* [GNU.org How to Use GNU Licenses for Your Own Software](https://www.gnu.org/licenses/gpl-howto.html)
* [Software Package Data Exchange (SPDX): `GPL-3.0-or-later`](https://spdx.org/licenses/GPL-3.0-or-later.html)



### GNU Affero General Public License v3.0 or later

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **very strong [copyleft](https://en.wikipedia.org/wiki/Copyleft)** license:

* Copyright and license notices must be preserved.
* Modifications have to be released under the same license.
* Embedding into a larger work is only possible when the larger work is using the same or a compatible license.
* The source code of a modified version must be made available if it is used to provide a service over a network (e.g. as [SaaS](https://en.wikipedia.org/wiki/Software_as_a_service)).


**How to apply**:

1. Create a `LICENSE` text file the root directory of your project (Unix line feed (LF, `\n`) and UTF-8 encoding).
2. Copy the [text of the license](https://www.gnu.org/licenses/agpl-3.0.txt) into the `LICENSE` file.
3. Add a `Licensing, copyright` section in the `README.md` (or a comparable central place) that follows the following template:
   ```
   ## Licensing, copyright

   Copyright (c) YYYY, foundata GmbH (https://foundata.com)

   This project is licensed under GNU Affero General Public License v3.0 or later (SPDX-License-Identifier: `AGPL-3.0-or-later`), see [`COPYING`](./COPYING) or https://www.gnu.org/licenses/agpl-3.0.txt for the full text.
   ```
   Replace `YYYY` with the year of the first release. Add additional notes as needed.
4. Use a license notice in the header comment of each file that follows the following template:
   ```
   Copyright (c) foundata GmbH (https://foundata.com)
   SPDX-License-Identifier: AGPL-3.0-or-later
   ```


**Used by / default for:**

* [Grafana](https://github.com/grafana/grafana#license)


**Further reading:**

* [Choose a license: GNU Affero General Public License v3.0](https://choosealicense.com/licenses/agpl-3.0/)



### GNU Lesser General Public License v3.0 or later

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **[copyleft](https://en.wikipedia.org/wiki/Copyleft)** license, especially useful for libraries to be used in other software:

* Copyright and license notices must be preserved.
* Modifications have to be released under the same license.
* Embedding into a larger work is possible when
  * the larger work is using the same or a compatible license or
  * the larger work is distributed under different terms and without source code but using the project only through provided interfaces


**How to apply**:

1. Create a `COPYING` text file the root directory of your project (Unix line feed (LF, `\n`) and UTF-8 encoding).
2. Copy the [text of the GNU GPLv3  license](https://www.gnu.org/licenses/gpl-3.0.txt) into the `COPYING` file.
3. Create an additional `COPYING.LESSER` text file the root directory of your project (Unix line feed (LF, `\n`) and UTF-8 encoding).
4. Copy the [text of the GNU LGPLv3 license](https://www.gnu.org/licenses/lgpl-3.0.txt) into the `COPYING.LESSER` file.
3. Add a `Licensing, copyright` section in the `README.md` (or a comparable central place) that follows the following template:
   ```
   ## Licensing, copyright

   Copyright (c) YYYY, foundata GmbH (https://foundata.com)

   This project is licensed under GNU Lesser General Public License v3.0 or later or later (SPDX-License-Identifier: `LGPL-3.0-or-later`), see [`COPYING`](./COPYING) or https://www.gnu.org/licenses/agpl-3.0.txt as well as [`COPYING.LESSER`](./COPYING.LESSER) or https://www.gnu.org/licenses/lgpl-3.0.txt for the full text.
   ```
   Replace `YYYY` with the year of the first release. Add additional notes as needed.
6. Use a license notice in the header comment of each file that follows the following template:
   ```
   Copyright (c) foundata GmbH (https://foundata.com)
   SPDX-License-Identifier: LGPL-3.0-or-later
   ```


**Used by / default for:**

* [7-Zip](https://7-zip.org/license.txt) (most of it, LGPL 2.1 or later)
* [GTK](https://gitlab.gnome.org/GNOME/gtk/-/blob/main/COPYING) (LGPL 2.1 or later)


**Further reading:**

* [Choose a license: GNU Lesser General Public License v3.0](https://choosealicense.com/licenses/lgpl-3.0/)
* [Wikipedia: GNU Lesser General Public License: Compatibility](https://en.wikipedia.org/wiki/GNU_Lesser_General_Public_License#Compatibility)
* [Wikipedia: GNU Lesser General Public License: Programming language specifications](https://en.wikipedia.org/wiki/GNU_Lesser_General_Public_License#Programming_language_specifications)



### Apache License 2.0

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **permissive** license:

* Copyright and license notices must be preserved.
* Modifications have to be stated (even if only internally).


**How to apply:**

1. Create a `LICENSE` text file the root directory of your project (Unix line feed (LF, `\n`) and UTF-8 encoding).
2. Copy the [text of the license](https://www.apache.org/licenses/LICENSE-2.0.txt) into the `LICENSE` file.
3. Create an additional `NOTICE` text file in the root directory of your project (Unix line feed (LF, `\n`) and UTF-8 encoding).
4. Put the following text into the `NOTICE` file:
   ```
    NOTE: Any derivative works that you distribute must include a readable copy of
          the attribution notices contained in this file (cf. Apache License 2.0;
          § 4.4).


    I.  foundata GmbH

        This resource is based on the work of foundata [1]. If you like it, you
        might buy them a coffee [2].

        [1] https://foundata.com
        [2] https://buy-me-a.coffee
   ```
   You can add an `identifier-string` at the end of the `[2]` URL to make it transparent why somebody is sending a donating. Add additional organizations, notes and adapt the order if applicable. This is especially true if the project is a fork and the heavy lifting was done by a third party. Have a look an [example file](https://www.apache.org/licenses/example-NOTICE.txt) with good descriptions.
5. Add a `Licensing, copyright` section in the `README.md` (or a comparable central place) that follows the following template:
   ```
   ## Licensing, copyright

   Copyright (c) YYYY, foundata GmbH (https://foundata.com)

   This project is licensed under Apache License 2.0 (SPDX-License-Identifier: `Apache-2.0`), see [`LICENSE`](./LICENSE) or https://www.apache.org/licenses/LICENSE-2.0.txt for the full text.
   ```
   Replace `YYYY` with the year of the first release. Add additional notes as needed.
6. Use a license notice in the header comment of each file that follows the following template:
   ```
   Copyright (c) foundata GmbH (https://foundata.com)
   SPDX-License-Identifier: Apache-2.0
   ```


**Used by / default for:**

* [Chocolatey](https://docs.chocolatey.org/en-us/information/legal#open-source-edition)
* [Puppet](https://github.com/puppetlabs/puppet/blob/main/LICENSE)


**Further reading:**

* [Choose a license: Apache License 2.0](https://choosealicense.com/licenses/apache-2.0/)
* [Apache.org: How to apply the ALv2 (for Apache developers)](https://www.apache.org/legal/apply-license.html)
* [Software Package Data Exchange (SPDX): `Apache-2.0`](https://spdx.org/licenses/Apache-2.0.html)
* [OSI: Apache License, Version 2.0](https://opensource.org/license/apache-2-0/)



### MIT License

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **permissive and simple** license:

* Copyright and license notices must be preserved.


**How to apply**:

1. Create a `LICENSE` text file the root directory of your project (Unix line feed (LF, `\n`) and UTF-8 encoding).
2. Copy the following text into the `LICENSE` file and replace `YYYY` with the year of the first release:
   ```
   MIT License

   Copyright (c) YYYY, foundata GmbH (https://foundata.com)

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
   ```
3. Add a `Licensing, copyright` section in the `README.md` (or a comparable central place) that follows the following template:
   ```
   ## Licensing, copyright

   Copyright (c) YYYY, foundata GmbH (https://foundata.com)

   This project is licensed under MIT License (SPDX-License-Identifier: `MIT`), see [`LICENSE`](./LICENSE) for the full text.
   ```
   Replace `YYYY` with the year of the first release. Add additional notes as needed.
4. Use a license notice in the header comment of each file that follows the following template:
   ```
   Copyright (c) foundata GmbH (https://foundata.com)
   SPDX-License-Identifier: MIT
   ```


**Used by / default for:**

* [Tailwind CSS](https://github.com/tailwindlabs/tailwindcss/blob/master/LICENSE)


**Further reading:**

* [Choose a license: MIT License](https://choosealicense.com/licenses/mit/)



## Reasoning

[foundata](https://foundata.com/) is an organization acting within a German legislative framework. So when our team creates creative work (which includes source code), the work is under our exclusive copyright by default. Nobody outside of foundata is allowed to copy, distribute, or modify the work unless a license specifies otherwise. Once the work has third-party contributors, "nobody" even starts including us as each of these third-parties is also a copyright holder.

foundata is driven by open source. A good open source license allows reuse of code while retaining copyright. Using a well-known, [OSI-approved](https://opensource.org/licenses/) licenses also reduces [legal mumbo jumbo](https://en.wikipedia.org/wiki/Mumbo_jumbo_(phrase)) when working with third-parties, helping you to achieve results. Therefore you should **choose one of the [licenses listed in this document](#licenses-to-choose-from) whenever possible. We usually only check whether there are obvious reasons against the publication of source code**, like confidential contracting work for a customer.

[Copyleft](https://en.wikipedia.org/wiki/Copyleft) licenses like GNU (A)GPL 3.0 [or later](https://www.draketo.de/software/gpl-or-later.html) might prevent some organizations from using a project as they do not want to release the source code of their own modifications. Sadly, corporate compliance sometimes even nonsensically prohibits the usage of copyleft projects at all, even if nobody plans to modify anything. We still **prefer copyleft licenses** as long as it fits into the ecosystem of a project as [we do not care about corporate-anti-oss use cases](https://foundata.com/en/blog/2023/use-copyleft-open-source-licenses/).

It is recommended to **include a license header comment in every file** to prevent confusion or errors. Source files sometimes get copied or forked into new projects an third parties might not have a well organized repository bureaucracy. Without a statement about what their license is, moving files into another context might eliminates all trace of that point. Additionally, this helps to manage different licenses in the same project. We do not include a copyright year nor links to license texts in the header comments to keep maintenance easy while still being informative. The license of a project stated central place like a project's `README.md` is legally binding even without the header comments and it is easy to update years and URLs in the central place only.
