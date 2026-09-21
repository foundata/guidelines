# Git: `gitattributes` configuration

The `gitattributes` config assigns attributes to paths. It decides which bytes
Git writes into the working tree, which bytes `git archive` writes into a
release artifact, and how Git diffs and merges a file. A `.gitattributes` file
in the repository root is the usual place for it. It is tracked, so every
clone, every contributor and every build host applies the same rules.

MUST, SHOULD and other key words are used as defined in
[RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [Goals and scope](#goals-and-scope)
- [Applicability and precedence](#applicability-and-precedence)
- [Default starting point for a repository's `.gitattributes`](#gitattributes-file-default)
  - [Reasoning](#gitattributes-file-default-reasoning)
- [Line endings are not cosmetic](#line-endings)
- [Exception: files that must keep CRLF](#exception-crlf)
- [Exception: files whose bytes are asserted](#exception-byte-exact)
- [Release artifacts: `export-ignore`](#export-ignore)
  - [Python source distributions](#export-ignore-python)
- [`export-subst`](#export-subst)
- [Optional attributes](#optional-attributes)
  - [Diff drivers](#diff-drivers)
  - [Merge behavior](#merge-behavior)
- [Forge-specific attributes](#forge-specific)
- [Where `.gitattributes` does not apply](#not-applicable)
- [Verification and migration](#verification-and-migration)
  - [Adopting the policy in an existing repository](#migration)
- [Attribute precedence](#precedence)
- [Author information](#author-information)


## Goals and scope<a id="goals-and-scope"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Without a declaration, the bytes of a checkout depend on each contributor's
[`core.autocrlf`](https://git-scm.com/docs/git-config#Documentation/git-config.txt-coreautocrlf)
setting. Git for Windows offers `core.autocrlf=true` as its installation
default, so one commit produces different files on different machines, and
`git archive` carries that difference into release artifacts. A tracked
`.gitattributes` moves the decision from the client to the repository.

This guide covers the attributes foundata repositories need: line endings,
byte-exact files, archive contents, and the optional diff, merge and hosting
attributes. It does not cover clean and smudge filters, Git LFS or custom merge
driver definitions.


## Applicability and precedence<a id="applicability-and-precedence"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide defines the baseline for foundata repositories. A specific project,
upstream community or packaging ecosystem MAY extend or override it. The
narrowest applicable rule takes precedence.

**You MUST:**

- Follow a repository's own rules when they differ from this guide, including
  when contributing to a repository outside foundata.
- Keep an attribute that a consumer of the repository depends on, even when
  this guide would not ask for it.


## Default starting point for a repository's `.gitattributes`<a id="gitattributes-file-default"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Use the following as the default `.gitattributes` of any unspecific Git
repository:

```gitattributes
# Attributes for this repository, see https://git-scm.com/docs/gitattributes
#
# Store every text file with LF in the repository and write LF into the
# working tree on every platform, regardless of a contributor's local
# core.autocrlf or core.eol setting. Files Git detects as binary are left
# untouched.
* text=auto eol=lf

### Repository-specific exceptions

# [... none right now ...]
```

Add exceptions below the marked heading, with a comment naming what requires
them. The rest of this guide describes the exceptions that come up in practice.


### Reasoning<a id="gitattributes-file-default-reasoning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- `text=auto` leaves the text-or-binary decision to Git's content inspection,
  which is more reliable than a maintained list of file extensions. A PNG
  containing `\r\n` byte sequences stays unconverted under this line.
- `eol=lf` is what makes the outcome platform-independent. It overrides
  `core.autocrlf` and `core.eol`, and it applies to `git archive` as well,
  which is where the difference becomes a published artifact. `text=auto`
  alone does not do this: it normalizes the repository side only and leaves
  the checkout side to the client.
- One rule plus named exceptions stays reviewable. Its behavior for a file type
  nobody thought about is defined, so a new extension needs no maintenance.
- A per-extension matrix looks more explicit than it is. Every extension it
  does not list falls back to the default anyway, `binary` lines for images
  duplicate a detection Git already performs correctly, and a repeated
  `whitespace=` value with a fixed tab width contradicts languages such as Go
  and file formats such as Makefiles that require tabs. Declare a path
  explicitly where detection is wrong or where a consumer requires specific
  bytes, and let the default handle everything else.
- Contributors need no local Git configuration change. Attributes win over
  `core.autocrlf`, so a Windows default installation produces the same bytes as
  a Linux one.


## Line endings are not cosmetic<a id="line-endings"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

`git archive` applies the same conversion as a checkout. Exporting a commit on
a machine with `core.autocrlf=true` therefore produces different bytes than
exporting the same commit on Linux, and any build running on that export
inherits the difference.

Measured on 2026-09-21 on Windows Server 2025, from a clean clone of
`foundata/releasing` v2.2.0 with Git for Windows' default `core.autocrlf=true`:
the exported `version.py` came out CRLF, and the resulting artifacts differed
from the published Linux build of the same commit. The source distribution was
65301 bytes against 64694, the wheel 74676 against 74150. The repository has no
`.gitattributes`, so nothing pinned this.

**You MUST:**

- Declare line endings in a tracked `.gitattributes` for every repository whose
  contents are built, published, hashed or compared.

**Reasoning:**

- A release is a commit. Two hosts exporting one commit must produce the same
  bytes, otherwise a rebuild cannot confirm a published artifact and a
  reproducibility claim is unverifiable.
- The check is cheap. With the default in place, both invocations below print
  the same digest; without it, they differ:

  ```sh
  git -c core.autocrlf=false archive --format=tar HEAD | sha256sum
  git -c core.autocrlf=true  archive --format=tar HEAD | sha256sum
  ```

- Git converts LF to CRLF on checkout only for blobs stored with LF; a blob
  already containing CRLF passes through unchanged. Repositories whose files
  were committed from Windows are therefore sometimes unaffected today. That is
  a property of the current blobs, not a rule, and the first contributor
  committing the same file from Linux changes it.


## Exception: files that must keep CRLF<a id="exception-crlf"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Some consumers require specific bytes. Chocolatey's
[character encoding rules](https://docs.chocolatey.org/en-us/create/create-packages/#character-encoding)
require UTF-8 with a byte-order mark (BOM) for PowerShell scripts, because
PowerShell needs the BOM to recognize a script as UTF-8; for `*.nuspec` the BOM
is optional. The [PowerShell style guide](./powershell-style-guide.md) requires
UTF-8 with BOM and CRLF for PowerShell sources, for compatibility with Windows
PowerShell 5.1 and Windows tooling.

```gitattributes
### Repository-specific exceptions

# Windows PowerShell and Chocolatey packaging, see the PowerShell style guide.
*.ps1    text eol=crlf
*.psm1   text eol=crlf
*.psd1   text eol=crlf
*.nuspec text eol=crlf
```

**You MUST:**

- Declare `text eol=crlf` for every path a consumer requires as CRLF, instead
  of relying on the bytes a contributor happened to commit.
- Keep the BOM requirement out of Git. Enforce it with `.editorconfig`
  (`charset = utf-8-bom`), the editor and a check in continuous integration.

**You MUST NOT:**

- Use `working-tree-encoding=UTF-8-BOM`. Git does not implement that name; it
  reaches `iconv_open()` and fails wherever the platform's iconv does not know
  it. On Linux with Git 2.55, `git add` aborts with
  `fatal: failed to encode 'x.ps1' from UTF-8-BOM to UTF-8`.

**Reasoning:**

- `text eol=crlf` normalizes the stored blob to LF and writes CRLF into the
  working tree and into every export, on every platform. The result no longer
  depends on who committed the file or on which system.
- A BOM is file content. It travels in the blob untouched by line-ending
  conversion, so `eol=crlf` preserves it. Git will not add one to a file that
  lacks it, which is why the BOM needs an editor or a check rather than an
  attribute.
- `working-tree-encoding` is meant for content that cannot be stored as UTF-8,
  such as UTF-16 sources; Git's documented example with a BOM is
  `UTF-16LE-BOM`. PowerShell files stored as UTF-8 need no transcoding at all.
- Declaring the requirement also documents it. A reviewer sees why the file
  differs from the repository default instead of discovering it from a failed
  Chocolatey package validation.


## Exception: files whose bytes are asserted<a id="exception-byte-exact"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Golden files, recorded corpus snapshots and fixtures with a stored digest are
data, even when they look like text. Any conversion invalidates them.

```gitattributes
# Fixtures with recorded digests, no platform may rewrite these.
tests/fixtures/**  -text
tests/corpus/**    binary
```

**You MUST:**

- Declare `-text` or `binary` for every path whose exact bytes a test, a
  recorded digest, a signature or a provenance record asserts.

**You SHOULD:**

- Use `-text` when reviewers still benefit from a textual diff and a three-way
  merge, for example a golden file of expected program output.
- Use `binary`, the macro for `-text -diff -merge`, when the content is not
  meaningfully reviewable as text. Git then shows the path as changed, produces
  no patch text and leaves a conflict for manual resolution.

**Reasoning:**

- A corpus provenance test in a foundata repository failed on Windows for
  exactly this reason: the fixtures were checked out with CRLF, so their
  digests no longer matched. The code was correct and the test was correct.
- Unsetting `text` disables conversion completely. An `eol` value inherited
  from the `*` line stays visible in `git check-attr` output but has no effect
  once `text` is unset.
- A generated patch for a binary blob is noise in review and can be large; the
  `binary` macro removes it along with a merge that would silently corrupt the
  file.


## Release artifacts: `export-ignore`<a id="export-ignore"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

foundata builds export a commit with `git archive` and build from that export,
so the working tree cannot leak into an artifact. That makes `export-ignore`
the content list of the artifact rather than a convenience.

```gitattributes
# Not part of a release artifact.
.gitattributes  export-ignore
.gitignore      export-ignore
.github         export-ignore
DEVELOPMENT.md  export-ignore
```

**You MUST:**

- Exclude a path only when neither the build nor any consumer of the artifact
  reads it.
- Keep everything the build reads or the artifact must ship, including
  `README.md`, `LICENSES/`, `REUSE.toml`, the package metadata and any file
  they reference. Excluding one of these turns into a failing build or an
  artifact that violates its own license metadata.
- Verify the result instead of predicting it:

  ```sh
  git archive --format=tar HEAD | tar -t
  ```

**You SHOULD:**

- Decide per repository rather than copying a fixed list. Ask for each
  candidate whether someone rebuilding from the artifact needs it.
- Exclude repository mechanics that have no meaning outside the repository,
  such as `.gitattributes`, `.gitignore`, continuous integration configuration
  and editor settings.
- Treat contributor documentation such as `DEVELOPMENT.md`, `DESIGN.md` or
  `ARCHITECTURE.md` as a judgment call. It is small, and for some projects it
  is the documentation a downstream maintainer wants.

**Reasoning:**

- `export-ignore` affects `git archive` only. A clone keeps every excluded
  file, so this is a packaging decision and never a way to hide content.
- Excluding tests is the common mistake. Distribution maintainers run the test
  suite of the artifact they package; a test tree excluded from the export
  cannot be run and cannot be restored by packaging configuration.
- For `export-ignore`, a directory pattern such as `.github` is enough, because
  the archive skips the whole tree. Other attributes do not work that way:
  Git's manual states that a directory pattern does not recursively apply to
  the paths inside it, so use `dir/**` for those.


### Python source distributions<a id="export-ignore-python"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A foundata Python release builds the source distribution from the export and
the wheel from that source distribution, so `export-ignore` decides the
contents of both.

**You MUST:**

- Check the source distribution against the packaging metadata before adding an
  exclusion. `license-files`, `readme` and dynamic version sources all resolve
  against files that must exist inside the export.

**Reasoning:**

- Packaging configuration cannot restore what the export dropped. A
  `MANIFEST.in` entry or a build-backend include list only selects from the
  files present in the directory the backend builds from.
- Build backends that collect files from Git, such as `setuptools-scm` or
  `hatch-vcs`, read the tracked file list and ignore `export-ignore` entirely.
  A project using one of them gets a different source distribution when it is
  built from a clone instead of an export, which is one more reason to build
  from the export.


## `export-subst`<a id="export-subst"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

`export-subst` makes `git archive` expand `$Format:...$` placeholders, for
example `$Format:%H$` for the commit hash.

**You MUST NOT:**

- Use `export-subst` in foundata repositories.

**Reasoning:**

- It makes one tracked line mean two different things. The file in a clone
  contains the placeholder and the file in the artifact contains a hash, so a
  byte comparison between a rebuilt export and a checkout no longer works, and
  neither does running the file from a clone.
- Nothing expands when `git archive` is given a tree instead of a commit or a
  tag, which produces a released file containing a literal `$Format:%H$`.
- foundata projects carry their version and revision in tracked files that the
  release tooling maintains. A placeholder would add a second, archive-only
  source for data the build already controls.


## Optional attributes<a id="optional-attributes"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

The attributes in this section change review and merge ergonomics. They are
worth adding when a repository actually has the problem they solve.


### Diff drivers<a id="diff-drivers"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

A diff driver tells Git how to find the enclosing function or section for a
hunk header.

```gitattributes
*.py   diff=python
*.go   diff=golang
*.md   diff=markdown
*.sh   diff=bash
```

**You MAY:**

- Set a built-in diff driver for the languages a repository mainly contains.

**Reasoning:**

- The hunk header changes from a nearby line to the enclosing function,
  heading or section, which makes a diff readable without opening the file.
- The drivers are built into Git and need no configuration, so a clone gets the
  behavior without a setup step. Git's
  [`gitattributes` documentation](https://git-scm.com/docs/gitattributes)
  lists the available names.


### Merge behavior<a id="merge-behavior"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

```gitattributes
# Regenerate, never merge.
uv.lock -merge
```

**You SHOULD:**

- Unset `merge` for generated lockfiles. Git then leaves the path conflicted
  so the file gets regenerated with its tool instead of merged into something
  that looks plausible and is not valid.
- Prefer a changelog fragment directory over merging a single changelog file
  where the tooling supports it, as foundata's Ansible collections do.

**You MAY:**

- Set `merge=union` for an append-only list where both sides should be kept,
  such as a contributors file.

**Reasoning:**

- A three-way merge of a lockfile can resolve without conflict and still
  produce a dependency set that was never resolved by the tool.
- `union` takes the lines from both sides and writes no conflict markers. The
  order of added lines is arbitrary and nothing prompts anyone to look, so it
  only fits content where order does not matter and a wrong result is visible.


## Forge-specific attributes<a id="forge-specific"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Some hosting platforms read attributes of their own. GitHub uses
`linguist-generated` to collapse a file in a pull request diff and
`linguist-vendored` to keep a tree out of the repository language statistics.

**You MUST NOT:**

- Use an attribute that only one hosting platform interprets, including
  `linguist-generated`, `linguist-vendored`, `linguist-language` and
  `linguist-detectable`.

**You SHOULD:**

- Record that a tree is generated or vendored where every reader finds it: in
  the contributor documentation, in a README inside the tree, or in a header
  the generator writes into the files.

**Reasoning:**

- These attributes have no effect in Git and no effect on any other platform.
  They buy a cosmetic improvement in one vendor's web interface at the price
  of a repository that presents itself correctly only while it stays there.
- Whether a tree is generated is information a reader needs in a clone, in a
  release artifact and after a migration. Written into the repository, it
  survives all three.
- Declining them keeps the file portable. Every attribute in this guide is
  interpreted by Git itself, so a move between platforms changes nothing about
  how the repository behaves.


## Where `.gitattributes` does not apply<a id="not-applicable"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

`export-ignore` is read by `git archive` and by nothing else. Every other tool
that produces an artifact decides its contents with its own mechanism, usually
by reading the working tree or the tracked file list. An exclusion therefore
has to be declared once for every tool that builds an artifact from the
repository.

**You MUST:**

- Declare an exclusion in the mechanism belonging to the tool that produces the
  artifact, and repeat it for every further tool that produces one from the
  same repository.
- Verify an exclusion against the artifact the tool produces, not against
  `git archive` output.

**You MUST NOT:**

- Use attributes to keep a file out of the repository. That is
  [`.gitignore`](./git-gitignore.md); attributes apply to tracked paths.

The mechanisms currently in use at foundata:

|          Artifact          |                                      Produced by                                       | Exclusions declared in |
| -------------------------- | -------------------------------------------------------------------------------------- | ---------------------- |
| Source export              | `git archive`                                                                          | `export-ignore` in `.gitattributes` |
| Python source distribution | build backend, run on the export                                                       | the export, plus the backend's own include list |
| Ansible collection         | `ansible-galaxy collection build`                                                      | `build_ignore` in `galaxy.yml` |
| Container image            | Buildah or Podman, see the [OCI container image guide](./oci-container-image-guide.md) | `.containerignore` in the build context |

**Reasoning:**

- A tool that reads the working tree or the tracked file list never sees
  `export-ignore`, so an attribute meant as an exclusion silently ships the
  file. The reverse holds as well: a `build_ignore` or `.containerignore`
  entry does nothing to a `git archive` export.
- The table lists what foundata builds today and will go out of date. For a
  packaging tool it does not name, ask which files that tool reads and what
  its own documentation says about excluding them. Git attributes are the
  answer only for `git archive`.


## Verification and migration<a id="verification-and-migration"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

- Check what Git actually resolves for a path rather than reading the patterns:

  ```sh
  # All attributes in effect for a path, including macro expansion.
  git check-attr -a -- src/example.ps1

  # Index and working-tree line endings plus the attributes behind them.
  git ls-files --eol

  # Tracked files not stored with LF.
  git ls-files --eol | grep -v 'i/lf'
  ```

**Reasoning:**

- `git check-attr` resolves precedence, later-line overrides and macros, which
  a pattern list read by eye does not.
- `git ls-files --eol` reports the index and working-tree state separately, so
  it distinguishes a file stored with CRLF from one merely checked out that
  way.


### Adopting the policy in an existing repository<a id="migration"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Adding the file changes nothing by itself; existing blobs keep their stored
line endings until they are rewritten.

**You MUST:**

- Commit the byte-exact declarations first, in their own commit, before
  renormalizing anything. Fixtures, corpus snapshots and signed data marked
  `-text` or `binary` are then out of reach of the rewrite.
- Regenerate every recorded digest that the rewrite invalidates, and say so in
  the commit message.

**You SHOULD:**

- Renormalize in a separate commit that contains nothing else:

  ```sh
  git add --renormalize .
  git status
  git diff --cached --stat
  ```

**Reasoning:**

- `git add --renormalize` rewrites stored blobs to the declared form. Every
  file whose line endings change gets different bytes in the working tree of
  every clone afterwards, so a checksum, signature or provenance record
  computed from those bytes becomes wrong. This is the same failure the
  attributes are meant to prevent, and doing it in the wrong order causes it
  deliberately.
- A renormalization touches many files and carries no review value. Keeping it
  apart from content changes lets a reviewer skip it and keeps `git blame`
  honest for the lines that really changed.
- Ordering the declarations before the rewrite means the working tree never
  passes through a state in which a fixture is converted, so no test result has
  to be explained away.


## Attribute precedence<a id="precedence"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Git resolves each attribute separately, in this order:

1. `$GIT_DIR/info/attributes`, which has the highest precedence and is not
   tracked.
2. `.gitattributes` in the directory of the path, then in each parent directory
   up to the top level. The closer file wins.
3. The user's `core.attributesFile`, then the system-wide file.

Within one file, a later line overrides an earlier one, per attribute.

**You MUST:**

- Put every rule that has to hold for everyone in the tracked `.gitattributes`
  at the repository root.

**You SHOULD:**

- Express subtree rules as patterns in the root file, such as `tests/corpus/**`,
  rather than adding a nested `.gitattributes`, unless the subtree is genuinely
  self-contained, for example vendored code that carries its own file.
- Restrict `.git/info/attributes` to local experiments, and remove it again.

**Reasoning:**

- `.git/info/attributes` and the user-level file are per machine and invisible
  to everyone else. A build that depends on them produces a result nobody can
  reproduce, and the difference does not show up in review.
- A rule in the root file is found by reading one file. Nested files split the
  policy across the tree, and the effective value for a path then depends on
  how deep it sits.


## Author information<a id="author-information"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to make checkouts
and release artifacts of a commit byte-identical on every platform. It follows
Git's [`gitattributes` documentation](https://git-scm.com/docs/gitattributes)
and records the exceptions foundata projects need for Chocolatey packaging,
byte-exact test data and archive contents.
