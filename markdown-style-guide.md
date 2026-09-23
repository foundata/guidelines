# Markdown style guide

This document defines the style for writing technical documentation in Markdown.
It aims to keep source files easy to read, search and review while producing
predictable output on the renderers used by foundata projects.

The guide assumes that contributors already know Markdown and Git. It is a
reference for choices that affect portability, maintenance and review, not a
Markdown syntax tutorial.

The terms MUST, SHOULD, and other key words are used as defined in
[RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [Goals and scope](#goals-and-scope)
- [Applicability and precedence](#applicability-and-precedence)
- [Markdown dialect and portability](#markdown-dialect-and-portability)
- [File format and names](#file-format-and-names)
- [Document structure](#document-structure)
- [Headings, anchors and tables of contents](#headings-anchors-and-tables-of-contents)
- [Paragraphs and line breaks](#paragraphs-and-line-breaks)
- [Lists](#lists)
  - [Ordered lists](#ordered-lists)
  - [List contents](#list-contents)
- [Emphasis and inline code](#emphasis-and-inline-code)
- [Links and images](#links-and-images)
- [Code blocks](#code-blocks)
- [Block quotes, thematic breaks and tables](#block-quotes-thematic-breaks-and-tables)
- [Raw HTML and comments](#raw-html-and-comments)
- [Prose and normative language](#prose-and-normative-language)
- [Linting and automatic formatting](#linting-and-automatic-formatting)
- [Generated Markdown](#generated-markdown)
- [Author information](#author-information)


## Goals and scope<a id="goals-and-scope"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Markdown source is part of a project's maintained interface. Contributors read
it in editors, diffs, terminal output and rendered documentation. A useful style
must work in each of those settings.

**You SHOULD:**

- Write Markdown that remains understandable as plain text.
- Prefer syntax with consistent behavior across the project's supported
  renderers.
- Keep structural choices easy to identify with ordinary text tools such as
  `rg`, `grep` and `git diff`.
- State the reason for a rule when the choice is not self-evident or when a
  plausible alternative exists.


This guide covers human-authored Markdown files, including `README.md`,
contributor documentation, runbooks, design documents and style guides. It does
not define the required content of those documents or replace a project's
documentation architecture.


## Applicability and precedence<a id="applicability-and-precedence"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide defines the baseline for foundata repositories. A repository may have
stricter rules or may need different syntax because of its renderer, static site
generator or upstream contribution policy. The narrowest applicable rule takes
precedence.

**You MUST:**

- Follow the target repository's documented rules when they conflict with this
  guide.
- Follow the syntax requirements of the renderer that publishes the document.
- Keep the existing unordered-list marker when making a limited change to a
  document that consistently uses another marker, unless converting the complete
  document is part of the requested change.

**You SHOULD:**

- Document renderer-specific syntax and formatting exceptions in the repository.
- Put a mechanical whole-document conversion in a separate commit or clearly
  identified part of a change so reviewers can distinguish it from content
  edits.

**Reasoning:**

- A technically valid Markdown change can still break a static site template,
  generated documentation pipeline or upstream contribution check.
- Mixing list markers during an incremental edit violates document consistency.
  Silently reformatting the complete file makes the substantive change harder to
  review.


## Markdown dialect and portability<a id="markdown-dialect-and-portability"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[CommonMark](https://spec.commonmark.org/) is the portable syntax baseline.
[GitHub Flavored Markdown (GFM)](https://github.github.com/gfm/) extends
CommonMark with features such as tables, task list items, strikethrough and
extended autolinks.

**You MUST:**

- Use CommonMark syntax unless the target renderer and repository explicitly
  support an extension.
- Verify renderer-specific syntax on the renderer that will publish the
  document.

**You SHOULD:**

- Limit GFM syntax to repositories rendered by GitHub or another documented
  GFM-compatible renderer.
- Prefer a portable CommonMark representation when it communicates the same
  information clearly.

**You MUST NOT:**

- Assume that syntax accepted by an editor preview works in the publishing
  system.
- Add front matter, MDX, Hugo shortcodes or another processor-specific construct
  to an ordinary Markdown file without a documented consumer for it.

**Reasoning:**

- Markdown implementations differ. Naming the baseline and the permitted
  extensions makes compatibility a testable property.
- Editor previews often use a different parser or configuration from the final
  publishing system.


## File format and names<a id="file-format-and-names"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use UTF-8 encoding without a
  [Byte Order Mark (BOM)](https://en.wikipedia.org/wiki/Byte_order_mark).
- Use Unix line endings (LF, `\n`).
- End the file with one newline.
- Remove trailing whitespace.
- Use spaces for Markdown indentation. Tabs are allowed only when they are
  literal content inside a code block.

**You SHOULD:**

- Use the `.md` extension.
- Use lowercase, hyphen-separated names for ordinary Markdown files, for example
  `deployment-guide.md`.
- Keep conventional names such as `README.md`, `CONTRIBUTING.md`,
  `CHANGELOG.md`, `SECURITY.md` and `LICENSE.md` uppercase.
- Preserve an existing filename when renaming it would break external links or
  established tooling.

**Reasoning:**

- A fixed encoding and line-ending format avoids platform-specific diffs and
  parser problems.
- Trailing spaces can create a hard line break in Markdown. Removing them
  prevents invisible formatting from changing rendered output.
- Predictable filenames are easier to type and link from case-sensitive systems.
- [Cool URIs don't change](https://www.w3.org/Provider/Style/URI)


## Document structure<a id="document-structure"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use no more than one level-one heading (`#`) in a document.
- Make the level-one heading identify the document.
- Follow the heading hierarchy without skipping levels.
- Separate headings, paragraphs, lists, block quotes and fenced code blocks with
  one or more blank lines.
- Keep content in the section where a reader would look for it. Do not use
  heading levels merely to change visual size.

**You SHOULD:**

- Put the level-one heading on the first line unless required front matter must
  precede it. When that front matter declares a `title` the renderer displays,
  the key is the level-one heading; do not repeat it as `#`.
- Start with a short paragraph that defines the document's purpose and scope.
- Use two or three blank lines before a heading when it benefits unrendered
  readability, except a heading on the first line of the document.

**You MUST NOT:**

- Add an empty section as a placeholder. Track planned content in an issue
  instead.
- Use more than three consecutive blank lines.

**Reasoning:**

- A valid hierarchy gives screen readers, generated navigation and document
  converters a useful outline.
- Blank lines make block boundaries explicit to both readers and parsers.
- Empty sections describe intended work rather than current behavior and tend to
  become stale.


## Headings, anchors and tables of contents<a id="headings-anchors-and-tables-of-contents"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use headings with leading `#` characters (ATX heading format).
- Add one space between the `#` characters and the heading text.
- Write headings in sentence case.
- Keep heading text unique among sibling sections unless the renderer and linter
  can distinguish repeated headings reliably.

**You SHOULD:**

- Omit closing `#` characters.
- Maintain a table of contents for long documents generated or kept in sync
  automatically rather than updated by hand.
- Limit the table of contents to a bounded heading depth.
- Add an explicit anchor when stable links matter, especially in documents with
  long headings that may be renamed or would otherwise produce bulky, long
  generated anchors.
- Use lowercase ASCII words separated by hyphens for explicit anchor
  identifiers.
- Treat a published anchor as an interface. Preserve the old anchor or provide a
  compatible replacement when changing a heading. It is also possible to set two
  anchors to keep [old links working](https://www.w3.org/Provider/Style/URI).

**Good example:**

```markdown
## Error handling<a id="error-handling"></a>
```

**Bad examples:**

```markdown
Error handling
==============

## Error Handling ##

#### Retry policy
```

The last heading is invalid when it follows a level-two heading without a
level-three heading between them.

**Reasoning:**

- ATX headings (`#` char) are easy to recognize and edit at every supported
  level.
- Sentence case matches the other foundata guidelines and avoids treating
  headings like product names.
- Renderer-generated heading identifiers can change when heading text or
  renderer behavior changes. An explicit anchor keeps incoming links stable.


## Paragraphs and line breaks<a id="paragraphs-and-line-breaks"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use a blank line to separate paragraphs.
- Wrap ordinary prose, including prose in list items and block quotes, only
  through the project's configured formatter.
- Use a backslash at the end of a line when a hard line break is part of the
  content.

**You MUST NOT:**

- Manually wrap or re-wrap a paragraph. Rerun the formatter instead of choosing
  break points by hand.
- Use two trailing spaces to create a hard line break.
- Insert a source line break merely because an editor window is narrow.

**You MAY:**

- Use `<br>` instead of a backslash for an intentional hard break when targeting
  a renderer that does not reliably render the backslash form.

**Good example (formatter output):**

```markdown
They are experienced infrastructure engineers who want control over decisions
and evidence over assumptions; unprompted large edits or silently incorporated
material would undermine that.
```

**Bad example (manual, inconsistent wrapping):**

```markdown
They are experienced infrastructure engineers who want
control over decisions and evidence over assumptions; unprompted large edits or silently incorporated material
would undermine that.
```

**Intentional hard line break:**

```markdown
First address line\
Second address line
```

Fallback for a renderer that does not honor the backslash form:

```markdown
First address line<br>
Second address line
```

**Reasoning:**

- A formatter-driven wrap is deterministic, so it does not add diff noise beyond
  the words that actually changed.
- Search and grep across a wrapped sentence can miss a match that spans a line
  break. This guide accepts that cost for the benefits of a formatter-enforced
  wrap.
- CommonMark defines an ordinary source newline inside a paragraph as a soft
  line break; renderers overwhelmingly render it as a single space in the
  output, so a formatter-wrapped paragraph reads correctly.
- Trailing spaces are hard to see and conflict with the requirement to remove
  trailing whitespace.


## Lists<a id="lists"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use the same unordered-list marker throughout a document.
- Put one space between an unordered-list marker and its content.
- Keep indentation consistent at each nesting level.

**You SHOULD:**

- Use `-` as the unordered-list marker.
- Use a list only when its items are parallel enough to scan as a group.
- Use complete sentences with terminal punctuation when list items are
  sentences.
- Use fragments consistently and omit terminal punctuation when every item is a
  short fragment.

**Good example:**

```markdown
- First item
- Second item
  - Nested item
```

**Bad example:**

```markdown
* First item
- Second item
+ Third item
```

**Reasoning:**

- A single marker makes the source consistent and permits literal searches for
  list items.
- `-` is visually less noisy than `*`, does not compete with `*italic*` or
  `**bold**`, and is slightly easier to search for literally.
- Parallel grammar makes it easier to compare list items.


### Ordered lists<a id="ordered-lists"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use a period after the number, for example `1.`.
- Number items sequentially when the source order carries meaning.

**You SHOULD:**

- Use an ordered list only when order, rank or the number of items matters.
- Use an unordered list when items can be rearranged without changing the
  instruction or argument.

**Good example:**

```markdown
1. Validate the configuration.
2. Apply the change.
3. Verify the service.
```

**Bad example:**

```markdown
1. DNS servers
2. NTP servers
3. Package mirrors
```

The bad example implies an order that the items do not have.

**Reasoning:**

- Sequential source numbers remain useful when reading a file in a terminal or
  reviewing a diff that does not render Markdown.
- Choosing the list type by meaning prevents visual formatting from implying a
  sequence that does not exist.


### List contents<a id="list-contents"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Indent nested unordered lists by two spaces relative to their parent item.
- Indent continuation blocks enough to keep them inside the intended list item.
- Add a blank line before and after a fenced code block or another block element
  inside a list item.

**You SHOULD:**

- Keep a list tight when every item contains a single paragraph.
- Use a loose list when an item contains several paragraphs or other block
  elements.
- Avoid more than three list levels. Use headings or separate sections when
  deeper nesting obscures the structure.
- Use GFM task list items only for work that a reader can actually complete or
  verify.

**Example with a continuation block:**

````markdown
- Show the active Git configuration and the file that defines each value:

  ```sh
  git config --list --show-origin
  ```

- Check repository-specific values against the project's documented settings.
````

**Reasoning:**

- CommonMark uses indentation to decide whether a block belongs to a list item.
  Explicit indentation avoids content escaping from the list after a renderer
  change.
- Deeply nested lists are difficult to follow in plain text and rendered output.
- A checkbox suggests state and ownership. Using one as decoration gives readers
  the wrong signal.


## Emphasis and inline code<a id="emphasis-and-inline-code"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

- Use `*text*` for emphasis.
- Use `**text**` for strong emphasis.
- Use emphasis sparingly. Prefer a heading or a direct sentence when the
  structure carries the meaning.
- Use backticks for commands, options, filenames, paths, environment variables,
  identifiers and literal values.
- Use the spelling and letter case required by the referenced program or
  interface inside inline code.

**You MUST NOT:**

- Use bold text in place of a heading.
- Put ordinary prose in inline code merely to draw attention to it.
- Add spaces between emphasis or code delimiters and their contents.

**Good example:**

```markdown
Run `git diff --check` before committing. The command reports *whitespace errors* but does not modify files.
```

**Bad example:**

```markdown
** Validation **

Run git diff --check before committing. The command reports `whitespace errors`.
```

**Reasoning:**

- Consistent delimiters make emphasis predictable in source and avoid ambiguity
  near unordered lists.
- Inline code distinguishes literal input and identifiers from the surrounding
  sentence.
- Excessive emphasis makes it harder to see which information is exceptional.


## Links and images<a id="links-and-images"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use link text that identifies the destination or purpose.
- Use a relative link for a file in the same repository unless the publishing
  system requires an absolute URL.
- Include useful alternative text for an image that conveys information.
- Verify internal links, explicit anchors and external links before publishing.

**You SHOULD:**

- Use inline links when a destination appears once or a few times.
- Use reference links when a long destination is repeated or when separating
  destinations makes dense source easier to read.
- Link to the primary specification, project documentation or other
  authoritative source for a technical claim.
- Link to the most specific stable page that supports the surrounding text.
- Write repository paths with a leading `./`, for example
  `[configuration](./config/example.yml)`.

**You MUST NOT:**

- Use vague link text such as "here", "this page" or "read more" when the
  destination can be named.
- Use a bare URL in prose unless the URL itself is the subject.
- Rely on an image as the only source of an instruction, value or status.
- Use an empty alt attribute for an informative image.

**Good examples:**

```markdown
See the [CommonMark specification](https://spec.commonmark.org/) for the parsing rules.

Review the [shell scripting style guide](./shell-scripting-style-guide.md).

![Output showing two failed link checks](./images/link-check-failures.png)
```

**Bad examples:**

```markdown
Click [here](https://spec.commonmark.org/).

See https://spec.commonmark.org/ for more information.

![](./images/link-check-failures.png)
```

**Reasoning:**

- Descriptive link text remains understandable out of context and helps
  screen-reader users navigate by links.
- Relative repository links continue to work in forks and on non-default
  branches.
- Primary sources give reviewers evidence they can check without reconstructing
  the author's assumptions.


## Code blocks<a id="code-blocks"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use fenced code blocks instead of indented code blocks.
- Add an information string that identifies the language or format. Use `text`
  for plain text, terminal output or a format without a suitable identifier.
- Keep code examples valid for the language and versions described by the
  document, unless the example is explicitly marked as invalid.
- Follow the relevant language style guide inside a code block.
- Use a fence longer than any run of the same delimiter inside the example.

**You SHOULD:**

- Use backticks for fences.
- Put commands and their output in separate blocks when combining them would
  make either ambiguous.
- Omit shell prompt characters from commands intended for copying.
- Include enough context for the example to be understood without adding
  unrelated setup.
- Mark omitted code with a comment that is valid for the example's language.

**Good example:**

````markdown
```sh
git diff --check
```
````

**Bad examples:**

````markdown
    git diff --check

```
$ git diff --check
```
````

**Reasoning:**

- Fences are explicit and remain readable when moved into lists or block quotes.
- Information strings enable syntax highlighting and let documentation tools
  identify the block's language.
- Prompt characters make copied commands fail and do not reliably distinguish
  input from output.


## Block quotes, thematic breaks and tables<a id="block-quotes-thematic-breaks-and-tables"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

- Use a block quote for quoted material, not as a general-purpose callout box.
- Identify the source of quoted material when attribution matters.
- Prefer headings and whitespace over thematic breaks for ordinary section
  structure.
- Use a table only when readers need to compare values across consistent
  columns.
- Keep tables small enough to read in source form.
- Use a list or several subsections when cells require paragraphs, code blocks
  or substantial explanation.

**You MUST:**

- Treat pipe tables as a GFM extension and verify that the target renderer
  supports them.
- Include a header row in a pipe table.
- Escape a literal pipe character in table content when the renderer requires
  it.

**Good table:**

```markdown
| File | Purpose |
|------|---------|
| `README.md` | Project entry point |
| `CONTRIBUTING.md` | Contribution rules |
```

**Reasoning:**

- Block quotes carry the semantic meaning of a quotation. Reusing them for
  arbitrary notes loses that distinction.
- Tables work for compact comparisons but become difficult to edit and review
  when cells contain prose.
- Thematic breaks add little when headings already express the document
  structure.


## Raw HTML and comments<a id="raw-html-and-comments"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Verify raw HTML on the target renderer. Renderers may escape, sanitize or
  remove it.
- Keep information required by the reader in rendered content rather than an
  HTML comment.

**You SHOULD:**

- Avoid raw HTML when standard Markdown expresses the same structure.
- Limit raw HTML in portable documents to small, documented exceptions such as
  explicit `<a id="..."></a>` anchors.
- Use HTML comments only for maintenance instructions that belong in the source.

**You MUST NOT:**

- Use raw HTML for visual styling that depends on a repository host's current
  CSS.
- Put credentials, private operational details or other sensitive information in
  HTML comments. Comments remain present in the source and often in rendered
  page output.

**Reasoning:**

- Raw HTML reduces portability and may be processed differently by sanitizers.
- Hidden comments are still published source. They are not an access-control
  mechanism.


## Prose and normative language<a id="prose-and-normative-language"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

- Use active voice and present tense when they make the actor and behavior
  clear.
- Use standard American English unless a project requires another variety.
- Address the reader as "you" in instructions.
- Name commands, files, settings and actors instead of relying on "it", "this"
  or "the system" when the reference could be unclear.
- Define an abbreviation on first use unless the target audience will know it
  without explanation.
- State facts, constraints and observed behavior directly.
- Keep examples realistic enough to expose the decision or failure mode the rule
  addresses.

**For normative documents, you MUST:**

- Use uppercase MUST, MUST NOT, SHOULD, SHOULD NOT and MAY only with their RFC
  2119 and RFC 8174 meanings.
- Distinguish requirements from recommendations.
- Give a reason for a SHOULD when a reader needs to judge whether an exception
  is justified.

**You MUST NOT:**

- Add introductory explanations for concepts the stated audience already knows
  unless the explanation is needed to understand a rule.
- Present a preference as a compatibility or security requirement without
  evidence.
- Use unverified claims such as "best practice", "industry standard" or "all
  renderers support" as reasoning.

**Reasoning:**

- The target audience consists of experienced infrastructure engineers. They
  need the rule, its boundary and the evidence behind it more than a general
  introduction to the technology.
- Normative terms lose their value when requirements and preferences use the
  same language.
- Concrete actors and interfaces make instructions easier to test.


## Linting and automatic formatting<a id="linting-and-automatic-formatting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Run the repository's documented [`rumdl`](https://github.com/rvben/rumdl)
  `check` invocation before publishing a change, and resolve every reported
  violation.

**You SHOULD:**

- Run `git diff --check` to detect trailing whitespace and whitespace errors.
- Run the repository's documented `rumdl` `fmt` invocation before committing.
- Use an invocation that undocumented local configuration cannot alter and run
  the same invocation locally and in continuous integration.
- Document every disabled or exceptional lint rule whose reason is not apparent
  from the invocation. Use `rumdl rule` to list available rules,
  `rumdl explain MDxxx` for a rule's detailed behavior and examples, or browse
  `https://rumdl.dev/mdxxx/` directly.
- Use a pinned installation >= 0.2.72 of `rumdl` so that all needed features are
  available and changing the version stays a deliberate and reviewable step.
- Check links and render the document with the publishing system (if any) when
  changing anchors, renderer-specific syntax or complex nesting.


The following commands implement this guide through command-line options alone.
They need no `rumdl` configuration file:

```sh
# Extended (opt-in) rumdl rules deliberately not enabled here:
#   MD063 - heading capitalization: title-cases proper nouns inside heading
#           text (for example "Generated Markdown" becomes "Generated
#           markdown" under the sentence-case style), and this guide has no
#           actively maintained list of the proper nouns its headings use.
#           An `ignore-words` list per proper noun avoids this, so this rule
#           is a candidate to enable later if that list gets maintained.
#   MD074 - MkDocs nav validation: not applicable, this repo does not use MkDocs
#   MD093 - inline formatting in headings: this guide's own headings use
#           backticks for file names, which the rule rejects.
#
# Front matter: MD025 and MD041 default to `front-matter-title = "title"`, so
# a `title:` key counts as the level-one heading and `fmt` demotes a repeated
# `# Heading` to `##`. If the renderer ignores that key, add to both commands:
#   --config 'MD025.front-matter-title=""' --config 'MD041.front-matter-title=""'
#
# MD080 is limited to `levels=[1,2]`: repeats below that are normal, for
# example the `### Added` blocks of every `CHANGELOG.md` release.
#
# For details on any rule below: `rumdl rule MDxxx` (short summary) or
# `rumdl explain MDxxx` (full explanation with examples and a doc link), or
# browse https://rumdl.dev/mdxxx/ directly. `rumdl rule` alone lists all rules.

# Format: rewrites files, fixing everything that has a safe automatic fix.
rumdl fmt \
  --no-config \
  --deny-config-warnings \
  --extend-enable MD060,MD070,MD072,MD073,MD080,MD082,MD083,MD084,MD085,MD087,MD088,MD090 \
  --config 'MD003.style="atx"' \
  --config 'MD004.style="dash"' \
  --config 'MD007.indent=2' \
  --config 'MD012.maximum=3' \
  --config 'MD013.line-length=80' \
  --config 'MD013.reflow=true' \
  --config 'MD013.reflow-mode="default"' \
  --config 'MD013.code-blocks=false' \
  --config 'MD013.code-spans=false' \
  --config 'MD013.tables=false' \
  --config 'MD024.siblings-only=true' \
  --config 'MD029.style="ordered"' \
  --config 'MD033.allowed-elements=["a","br"]' \
  --config 'MD046.style="fenced"' \
  --config 'MD060.style="aligned"' \
  --config 'MD060.column-align-header="center"' \
  --config 'MD060.loose-last-column=true' \
  --config 'MD072.key-order=["title", "name", "draft", "date", "description", "categories", "category", "tags", "author"]' \
  --config 'MD080.levels=[1,2]' \
  --config 'MD082.allow-parent-headings=true' \
  .

# Check: validates without modifying files, non-zero exit on any violation.
rumdl check \
  --no-config \
  --deny-config-warnings \
  --extend-enable MD060,MD070,MD072,MD073,MD080,MD082,MD083,MD084,MD085,MD087,MD088,MD090 \
  --config 'MD003.style="atx"' \
  --config 'MD004.style="dash"' \
  --config 'MD007.indent=2' \
  --config 'MD012.maximum=3' \
  --config 'MD013.line-length=80' \
  --config 'MD013.reflow=true' \
  --config 'MD013.reflow-mode="default"' \
  --config 'MD013.code-blocks=false' \
  --config 'MD013.code-spans=false' \
  --config 'MD013.tables=false' \
  --config 'MD024.siblings-only=true' \
  --config 'MD029.style="ordered"' \
  --config 'MD033.allowed-elements=["a","br"]' \
  --config 'MD046.style="fenced"' \
  --config 'MD060.style="aligned"' \
  --config 'MD060.column-align-header="center"' \
  --config 'MD060.loose-last-column=true' \
  --config 'MD072.key-order=["title", "name", "draft", "date", "description", "categories", "category", "tags", "author"]' \
  --config 'MD080.levels=[1,2]' \
  --config 'MD082.allow-parent-headings=true' \
  .
```

Both commands share every flag; only the verb differs. `rumdl check .` or
`rumdl fmt .` without these options applies only the default rules; useful for a
quick look, but it does not implement this guide.

**Reasoning:**

- Applying the formatter is faster and more consistent than fixing each reported
  issue by hand. `fmt` never touches a violation it cannot fix safely, such as a
  duplicate heading or an empty section; those stay as diagnostics for
  deliberate review.
- Command-line options keep the policy visible where the check runs and avoid a
  second file to review, because `rumdl` accepts every setting this guide needs
  as an inline `--config` override.
- `--no-config` makes the result reproducible.
- `--deny-config-warnings` turns an unrecognized configuration option into an
  error.
- `MD072` sorts front matter alphabetically by default, which would bury the key
  naming the document below its description. The `key-order` list leads with the
  identity, publication and summary keys that renderers and tools read first,
  then the taxonomy keys. Any key the list does not name follows them
  alphabetically, so every file keeps one predictable order.
- `git diff --check` remains necessary alongside `rumdl`. `MD009` cannot flag
  the exact two-trailing-space hard break this guide bans, because `rumdl`
  rejects any `br-spaces` setting below 2, the CommonMark-mandated minimum for
  that mechanism to work at all.
- Rendering and link checks catch failures that source linting cannot detect,
  including removed HTML, changed anchors and unsupported extensions.


## Generated Markdown<a id="generated-markdown"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Change the generator or its input instead of editing generated Markdown by
  hand.
- Make generated status clear in the file or in repository documentation.
- Regenerate and review the complete output after changing a generator.

**You SHOULD:**

- Make generators produce Markdown that follows this guide when the target
  format permits it.
- Exclude generated files from rules that the generator cannot satisfy, and
  scope the exclusion to those files.
- Keep generated output deterministic so identical input produces an identical
  file.

**Reasoning:**

- Hand edits disappear on the next generation run.
- A narrow lint exception preserves useful checks for human-authored files.
- Deterministic output makes generator changes reviewable and avoids unrelated
  diffs.


## Author information<a id="author-information"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) for technical
Markdown documents maintained in source repositories.
