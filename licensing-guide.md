# Licensing guide

**Disclaimer:**

1. **This is not legal advice.** If in doubt: Ask persons in charge and/or ask a lawyer as some additional rules might apply (like the [Arbeitnehmererfindungsgesetz (ArbnErfG)](https://www.gesetze-im-internet.de/arbnerfg/) mentioned in your employment contract).
2. After choosing a license and doing preparation, **communicate with a person in charge for a last check before releasing a new project or repo** to the public.


## Table of contents

* [Reasoning](#reasoning)
* [How to choose a license](#how-to-choose-a-license)


## Reasoning

[foundata](https://foundata.com/) is an organization acting within a German legislative framework. So when our team creates creative work (which includes source code), the work is under our exclusive copyright by default. Nobody outside of foundata is allowed to copy, distribute, or modify the work unless a license specifies otherwise. Once the work has third-party contributors, "nobody" even starts including us as each of these third-parties is also a copyright holder.

An open source license allows reuse of code while retaining copyright. This also simplifies [legal mumbo jumbo](https://en.wikipedia.org/wiki/Mumbo_jumbo_(phrase)) when working with third-parties, helping you to achieve results. As an organization, we are driven by open source. Therefore, one should **choose a well-known, [OSI-approved license](https://opensource.org/licenses/) whenever possible. We usually only check whether there are obvious reasons against the publication of source code** along with appropriate open-source licensing, like confidential contracting work for a customer.


## How to choose a license

**A project or repository should choose one of the following licenses whenever possible**, allowing commercial and private use, modification and distribution and instruct that copyright and license notices must be preserved:

* **[GNU Affero General Public License v3.0](https://choosealicense.com/licenses/agpl-3.0/)** or newer
* **[GNU General Public License v3.0](https://choosealicense.com/licenses/gpl-3.0/)** or newer
* **[GNU Lesser General Public License v3.0](https://choosealicense.com/licenses/lgpl-3.0/)** or newer
* **[Apache License 2.0](https://choosealicense.com/licenses/apache-2.0/)**
* **[MIT License](https://choosealicense.com/licenses/mit/)**

The **main differences between them are what a third party has to do with modifications** or when embedding a work into another existing project (a "larger work"):

* **GNU Affero General Public License v3.0** is a very strong [copyleft](https://en.wikipedia.org/wiki/Copyleft) license:
  * Copyright and license notices must be preserved.
  * Modifications have to be released under the same license.
  * Embedding into a larger work is only possible when the larger work is using the same or a compatible license.
  * The source code of a modified version must be made available if it is used to provide a service over a network (e.g. [SaaS](https://en.wikipedia.org/wiki/Software_as_a_service)).
* **GNU General Public License v3.0** is a strong [copyleft](https://en.wikipedia.org/wiki/Copyleft) license:
  * Copyright and license notices must be preserved.
  * Modifications have to be released under the same license.
  * Embedding into a larger work is only possible when the larger work is using the same or a compatible license.
* **GNU Lesser General Public License v3.0** is a [copyleft](https://en.wikipedia.org/wiki/Copyleft) license:
  * Copyright and license notices must be preserved.
  * Modifications have to be released under the same license.
  * Embedding into a larger work is possible when
    * the larger work is using the same or a compatible license or
    * the larger work is distributed under different terms and without source code but using the project only through provided interfaces
* **Apache License 2.0** is a permissive license:
  * Copyright and license notices must be preserved.
  * Modifications have to be stated (even if only internally).
* **MIT License** is a permissive and simple license:
  * Copyright and license notices must be preserved.

If nothing is fitting your needs https://choosealicense.com might be useful.
