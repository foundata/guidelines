# Licensing guide: How to choose a license
<!--REUSE-IgnoreStart-->


## Table of contents

* [Licenses to choose from](#licenses-to-choose-from)
  * [GNU General Public License v3.0 or later (`GPL-3.0-or-later`)](#gpl-30-or-later)
  * [GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`)](#agpl-30-or-later)
  * [GNU Lesser General Public License v3.0 or later (`LGPL-3.0-or-later`)](#lgpl-30-or-later)
  * [Apache License 2.0 (`Apache-2.0`)](#apache-20)
  * [MIT License (`MIT`)](#mit)
  * [Creative Commons Attribution Share Alike 4.0 International (`CC-BY-SA-4.0`)](#cc-by-sa-40)
  * [Creative Commons Attribution 4.0 International (`CC-BY-4.0`)](#cc-by-40)
* [Reasoning](#reasoning)
* [Disclaimer](#disclaimer)



## Licenses to choose from

[*⇑ Back to TOC ⇑*](#table-of-contents)

**Our defaults for software projects are:**

* [`GPL-3.0-or-later`](#gpl-30-or-later) as copyleft license
* [`Apache-2.0`](#apache-20) as permissive license


**Our defaults for projects with focus on media, design, 3D-printing plans or physical objects are:**

* [`CC-BY-SA-4.0`](#CC-BY-SA-4.0) as copyleft license
* [`CC-BY-4.0`](#CC-BY-4.0) as permissive license


Many projects operate within a broader ecosystem that has a license preferred by the community, often aligned with the primary project or product. Consider this when selecting a license. Check existing repositories or search online for `<project> licensing requirements` to understand community expectations.

The licenses listed here are widely recognized and **all of them allow commercial and private use, modification, and distribution while requiring that copyright and license notices be preserved.** The primary differences lie in their treatment of [copyleft](https://en.wikipedia.org/wiki/Copyleft)—specifically, the obligations of third parties regarding modifications or embedding the work into a larger project—and their applicability to software. **We favor copyleft over permissive licenses.**



### GNU General Public License v3.0 or later (`GPL-3.0-or-later`)<a id="gpl-30-or-later"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **strong [copyleft](https://en.wikipedia.org/wiki/Copyleft)** license with the following main characteristics:

* Copyright and license notices must be preserved.
* Modifications must be released under the same license.
* Embedding into a larger work is only possible when the larger work is using the same or a compatible license.
* [Listed as free by the FSF](https://www.gnu.org/licenses/license-list.en.html#GNUGPLv3)
* [OSI Approved](https://opensource.org/license/gpl-3-0/)


Used by / default for the following:

* [Ansible](https://docs.ansible.com/ansible/devel/community/collection_contributors/collection_requirements.html#collection-licensing-requirements)


Further reading:

* [Choose a license: GNU General Public License v3.0](https://choosealicense.com/licenses/gpl-3.0/)
* [Software Package Data Exchange (SPDX): `GPL-3.0-or-later`](https://spdx.org/licenses/GPL-3.0-or-later.html)
* [GNU.org How to Use GNU Licenses for Your Own Software](https://www.gnu.org/licenses/gpl-howto.html)



### GNU Affero General Public License v3.0 or later (`AGPL-3.0-or-later`)<a id="agpl-30-or-later"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **very strong [copyleft](https://en.wikipedia.org/wiki/Copyleft)** license with the following main characteristics:

* Copyright and license notices must be preserved.
* Modifications must be released under the same license.
* Embedding into a larger work is only possible when the larger work is using the same or a compatible license.
* The source code of a modified version must be made available if it is used to provide a service over a network (e.g. as [SaaS](https://en.wikipedia.org/wiki/Software_as_a_service)).
* [Listed as free by the FSF](https://www.gnu.org/licenses/license-list.en.html#AGPLv3.0)
* [OSI Approved](https://opensource.org/license/agpl-v3/)


Used by / default for the following:

* [Grafana](https://github.com/grafana/grafana#license)


Further reading:

* [Choose a license: GNU Affero General Public License v3.0](https://choosealicense.com/licenses/agpl-3.0/)
* [Software Package Data Exchange (SPDX): `AGPL-3.0-or-later`](https://spdx.org/licenses/AGPL-3.0-or-later.html)



### GNU Lesser General Public License v3.0 or later (`LGPL-3.0-or-later`)<a id="lgpl-30-or-later"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **[copyleft](https://en.wikipedia.org/wiki/Copyleft)** license, especially useful for libraries to be used in other software. It has the following main characteristics:

* Copyright and license notices must be preserved.
* Modifications must be released under the same license.
* Embedding into a larger work is possible when
  * the larger work is using the same or a compatible license or
  * the larger work is distributed under different terms and without source code but using the project only through provided interfaces
* [Listed as free by the FSF](https://www.gnu.org/licenses/license-list.en.html#LGPLv3)
* [OSI Approved](https://opensource.org/license/lgpl-3-0/)


Used by / default for the following:

* [7-Zip](https://7-zip.org/license.txt) (most of it, LGPL 2.1 or later)
* [GTK](https://gitlab.gnome.org/GNOME/gtk/-/blob/main/COPYING) (LGPL 2.1 or later)


Further reading:

* [Choose a license: GNU Lesser General Public License v3.0](https://choosealicense.com/licenses/lgpl-3.0/)
* [Software Package Data Exchange (SPDX): `LGPL-3.0-or-later`](https://spdx.org/licenses/LGPL-3.0-or-later.html)
* [Wikipedia: GNU Lesser General Public License: Compatibility](https://en.wikipedia.org/wiki/GNU_Lesser_General_Public_License#Compatibility)
* [Wikipedia: GNU Lesser General Public License: Programming language specifications](https://en.wikipedia.org/wiki/GNU_Lesser_General_Public_License#Programming_language_specifications)



### Apache License 2.0 (`Apache-2.0`)<a id="apache-20"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **permissive** license with the following main characteristics:

* Copyright and license notices must be preserved.
* Modifications must be stated (even if only internally).
* [Listed as free by the FSF](https://www.gnu.org/licenses/license-list.en.html#apache2)
* [OSI Approved](https://opensource.org/license/apache-2-0/)


Used by / default for the following:

* [Chocolatey](https://docs.chocolatey.org/en-us/information/legal#open-source-edition)
* [Puppet](https://github.com/puppetlabs/puppet/blob/main/LICENSE)


Further reading:

* [Choose a license: Apache License 2.0](https://choosealicense.com/licenses/apache-2.0/)
* [Apache.org: How to apply the ALv2 (for Apache developers)](https://www.apache.org/legal/apply-license.html)
* [Software Package Data Exchange (SPDX): `Apache-2.0`](https://spdx.org/licenses/Apache-2.0.html)
* [OSI: Apache License, Version 2.0](https://opensource.org/license/apache-2-0/)



### MIT License (`MIT`)<a id="mit"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **permissive and simple** license with the following main characteristics:

* Copyright and license notices must be preserved.
* [Listed as free by the FSF](https://www.gnu.org/licenses/license-list.en.html#Expat)
* [OSI Approved](https://opensource.org/license/mit/)


Used by / default for the following:

* [Tailwind CSS](https://github.com/tailwindlabs/tailwindcss/blob/master/LICENSE)


Further reading:

* [Choose a license: MIT License](https://choosealicense.com/licenses/mit/)
* [Software Package Data Exchange (SPDX): `MIT`](https://spdx.org/licenses/MIT.html)



### Creative Commons Attribution Share Alike 4.0 International (`CC-BY-SA-4.0`)<a id="cc-by-sa-40"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **strong [copyleft](https://en.wikipedia.org/wiki/Copyleft)** license for documents and media files. It has the following main characteristics:

* Attribution
* Copyright and license notices must be preserved.
* Modifications must be released under the same license.
* Embedding into a larger work is only possible when the larger work is using the same or a compatible license.
* [Listed as free by the FSF but not GPLv3 compatible](https://www.gnu.org/licenses/license-list.en.html#ccbysa). [Can be one-way converted to GPLv3](https://creativecommons.org/2015/10/08/cc-by-sa-4-0-now-one-way-compatible-with-gplv3/) though.
* [**Not** to be used for software](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software) and therefore not OSI approved.


Used by / default for the following:

* [KDE (for documentation)](https://community.kde.org/Policies/Licensing_Policy)


Further reading:

* [CC-BY-SA 4.0 Deed / Summary](https://creativecommons.org/licenses/by-sa/4.0/deed)
* [Software Package Data Exchange (SPDX): `CC-BY-SA-4.0`](https://spdx.org/licenses/CC-BY-SA-4.0.html)
* [CC Blog: CC-BY-SA 4.0 now one-way compatible with GPLv3](https://creativecommons.org/2015/10/08/cc-by-sa-4-0-now-one-way-compatible-with-gplv3/))



### Creative Commons Attribution 4.0 International (`CC-BY-4.0`)<a id="cc-by-40"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A **permissive** license with the following main characteristics:

* Attribution
* Copyright and license notices must be preserved.
* Modifications must be stated (even if only internally).
* [Listed as free by the FSF](https://www.gnu.org/licenses/license-list.en.html#ccby).
* [**Not** to be used for software](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software) and therefore not OSI approved.


Further reading:

* [CC-BY 4.0 Deed / Summary](https://creativecommons.org/licenses/by/4.0/deed)
* [Software Package Data Exchange (SPDX): `CC-BY-4.0`](https://spdx.org/licenses/CC-BY-4.0.html)



## Reasoning

[foundata](https://foundata.com/) is committed to open source. A good open source license allows reuse of code while retaining copyright. Using well-known licenses also reduces [legal mumbo jumbo](https://en.wikipedia.org/wiki/Mumbo_jumbo_(phrase)) when working with third-parties, helping you achieve results more efficiently. Therefore you should **choose one of the [licenses listed in this document](#licenses-to-choose-from) whenever possible. We usually only check whether there are obvious reasons against the publication of source code**, like confidential contracting work for a customer.

[Copyleft](https://en.wikipedia.org/wiki/Copyleft) licenses like GNU (A)GPL 3.0 [or later](https://foundata.com/en/blog/2024/use-gpl-or-later/) might prevent some organizations from using a project as they do not want to release the source code of their own modifications. Sadly, corporate compliance sometimes even nonsensically prohibits the usage of copyleft projects altogether, even if nobody plans to modify anything. Nonetheless, we **prefer [free](https://www.gnu.org/licenses/license-list.en.html) copyleft licenses** whenever they align with a project's ecosystem, as [we are not concerned about corporate-anti-oss use cases](https://foundata.com/en/blog/2024/copyleft-open-source-licenses/).



## Disclaimer

[*⇑ Back to TOC ⇑*](#table-of-contents)

1. **This is not legal advice.** If in doubt: Ask persons in charge and/or a lawyer as some additional rules might apply (like the [Arbeitnehmererfindungsgesetz (ArbnErfG)](https://www.gesetze-im-internet.de/arbnerfg/) mentioned in your employment contract).
2. After choosing and/or applying a license or in any case of uncertainty, **communicate with persons in charge for a last check before releasing a new project or repository** to the public.

<!--REUSE-IgnoreEnd-->
