# Licensing guide: how to change a license, re-licensing projects

To re-license a project (i.e., place it under a different or additional license), all contributors generally need to agree, as we do not use [Contributor License Agreements (CLAs)](https://en.wikipedia.org/wiki/Contributor_License_Agreement).


## Table of contents

* [Internal contributors only (within the organization)](#internal-contributors)
  * [Further reading, examples](#internal-contributors-further-reading)
* [External contributors (outside the organization)](#external-contributors)
  * [Further reading, examples](#external-contributors-further-reading)


## Internal contributors only (within the organization)<a id="internal-contributors"></a>

Within an organization, all contributors are usually accessible, making it easier to initiate discussions and seek consensus. Here, the process might look as follows:

1. **Initiate Discussion:** Start an open discussion internally to explain why re-licensing is being considered and the potential benefits or implications.
2. **Achieve Consensus:** Ensure all contributors understand the changes and agree to the new terms.
3. **Formal Documentation:** Document the agreement (e.g., via signed emails or a shared platform where contributors can explicitly approve the change).


### Further reading, examples<a id="internal-contributors-further-reading"></a>

* [absible-skeletons: Issue #6, change license from Apache 2.0 to GPL-3.0-or-later](https://github.com/foundata/ansible-skeletons/issues/6)


## External contributors (outside the organization)<a id="external-contributors"></a>

When dealing with external contributors, the process can be more complex due to challenges like identifying and contacting all contributors. A detailed process might include:

1. **Identify Contributors:**
   * Examine the project's Git history to identify all contributors who have made substantial contributions.
   * Use commit logs, pull request records, and issue discussions to create a list of contributors.
2. **Reach Out for Consent:**
   * **Preferred Approach:** Contact all known contributors directly, asking for their consent to re-license their work under either:
     * Both the old and the new license; or
     * [CC-0](https://creativecommons.org/publicdomain/zero/1.0/deed.en) (a public domain dedication).
   * Use multiple communication channels to increase the chances of reaching everyone, including:
     * **Email:** Send personalized messages to contributors based on their contact details in commit logs or project profiles.
     * **Project Announcements:** Use a prominent banner or message on the project’s main page or README to inform contributors about the proposed changes and how they can respond.
     * **Community Platforms:** Announce on forums, social media, or platforms where contributors may be active (e.g., GitHub Discussions, mailing lists).
3. **Handle Unreachable Contributors:**
   * If some contributors cannot be reached despite reasonable efforts, their contributions may need to be rewritten or replaced. This can involve:
     * **Refactoring Code:** Rewrite parts of the codebase associated with unreachable contributors.
     * **Community Contribution:** Ask the community to help re-implement or replace specific contributions to ensure compliance with the new licensing terms.
4. **Document the Process:**
   * Maintain detailed records of all communication attempts and consents received. This transparency is essential for legal and community trust purposes.

### Further reading, examples<a id="external-contributors-further-reading"></a>

* [DokuWiki content relicensing](https://www.dokuwiki.org/devel:ideas:relicensing) and [Licensing Change page](https://www.dokuwiki.org/licensing_change)