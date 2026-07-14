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
* [Stand-alone projects](#stand-alone-projects)
  * [Reasoning](#stand-alone-projects-reasoning)
* [AI-related repositories](#ai-repositories)
  * [AI categories](#ai-categories)
    * [AI harness-locked variants](#ai-harness-variants)


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


## Stand-alone projects<a id="stand-alone-projects"></a>

Stand-alone applications that are not artifacts of a particular ecosystem SHOULD omit both `<prefix>` and `<category>`. Their repository name SHOULD be the normalized project or product name.

Programming languages, operating systems, protocols, frameworks and other implementation details SHOULD NOT be added merely to classify the project. They MAY be used as a prefix only when the repository is itself an ecosystem-specific artifact rather than an application implemented with that technology.

Examples:

* ScanMole, a Python application for Linux: `scanmole`
* DAVable, a Go CalDAV and CardDAV server with a Python test suite: `davable`


### Reasoning<a id="stand-alone-projects-reasoning"></a>

The important distinction is:

* **Belongs to an ecosystem:** `ansible-role-foo`, `roundcube-plugin-bar`
* **Implemented using a technology:** `scanmole`, not `python-scanmole`
* **Supports a platform or protocol:** `davable`, not `go-caldav-server-davable`

A programming language or target platform is an implementation detail and can change over the lifetime of a project. A project may also use several languages, as DAVable does by using Go for the server and Python for its test suite. Encoding one language in the repository name would therefore be incomplete and could require a disruptive rename later.

The capitalization of a project or product name does not affect the repository name. Normalize a single-word name by converting uppercase letters to lowercase; do not introduce artificial word separators. Therefore, use `scanmole` and `davable`, not `scan-mole` or `dav-able`.


## AI-related repositories<a id="ai-repositories"></a>

AI-related repositories MUST follow the [semantic naming schema](#semantic-naming-schema) with `ai` as the `<prefix>`:

```
ai-<category>-<resource>
```

The `ai` prefix groups things that are interchangeable and whose primary domain is AI-assisted execution, prompting, agent behavior, or AI-tool integration. It SHOULD NOT be used merely because a project uses AI internally during development. This is narrower than it first appears: a prompt, skill, or MCP server usually works across multiple models or providers, whereas an Ansible playbook does not run in Puppet (so an `automation` prefix would be too broad to be useful).

The provider, model, editor, or harness an artifact currently works best with SHOULD NOT be part of the repository name, as portability in this field is a moving target. Model tuning or provider preference MUST NOT be encoded as a repository-name suffix and SHOULD instead be documented in metadata instead: `compatibility:` front matter fields, README notes, or subdirectories, all of which can be updated without renaming the repository.


### AI categories<a id="ai-categories"></a>

The `<category>` MUST remain a single dashless token and MUST come from the list below:

- `agent`: defines autonomous or semi-autonomous behavior: a loop, role, and tool use. If it only supplies instructions for an agent, it is a `skill`.
- `command`: a command or command pack invoked explicitly by the user.
- `dataset`: data only (training, fine-tuning, or evaluation examples), with no grader.
- `eval`: a standalone evaluation suite or benchmark whose purpose is measuring the quality of AI artifacts (graders, rubrics, fixtures, scoring or regression logic). It MAY use any framework or a custom runner; the category names the purpose, not a format.  If it is data only, it is a `dataset`. Files scoped to a single artifact SHOULD live inside that artifact's repository (e.g. for skills, the [Agent Skills standard places these in an `evals/` directory](https://agentskills.io/skill-creation/evaluating-skills), with `evals/evals.json` defining the test cases) rather than as a separate `ai-eval-*` repository.
- `hook`: logic run automatically at defined lifecycle points, as opposed to a `command`, which is invoked explicitly.
- `mcp`: a server speaking the [MCP protocol](https://en.wikipedia.org/wiki/Model_Context_Protocol), whatever it exposes. A non-MCP callable is a `tool`; a client or gateway takes its best-fit category (often `tool`).
- `plugin`: an installable bundle of two or more of the above.
- `policy`: machine- or harness-enforced constraints or guardrail configs (permissions, redaction, allow-deny lists). Natural-language instructions are a `prompt` or `skill`.
- `prompt`: prompt text, templates, or collections, with no enforcement or execution logic.
- `skill`: a reusable instruction or knowledge module an agent loads (e.g. a `SKILL.md` package), usually following the [Agent Skills specification](https://agentskills.io/specification). More than prompt text (→ `prompt`), but defines no agent loop (→ `agent`).
- `tool`: a single capability an agent calls, not delivered as an MCP server.

If a repository genuinely spans several categories, use the most encompassing one otherwise the one matching its primary purpose. A new category SHOULD only be introduced if it has both a recurring need, and a sharp boundary from existing categories. Residual overlap SHOULD be resolved by the category definitions and the rule above, not by adding more categories.

Examples: `ai-agent-release-manager`, `ai-command-deploy`, `ai-dataset-support-tickets`, `ai-eval-summarization`, `ai-mcp-github`, `ai-policy-output-redaction`, `ai-prompt-ansible-collection`, `ai-skill-pdf-extraction`, `ai-tool-jira`


#### AI harness-locked variants<a id="ai-harness-variants"></a>

Model-specific behaviour is rare and volatile, so it stays in metadata, never the name. If you *really* need to keep separate, different builds of the same artifact per harness, add the harness as a postfix: `ai-<category>-<resource>-<harness>`.

`<harness>` MUST come from a documented token list which never contains models:

- `antigravity` (Google, formerly `geminicli`)
- `claudecode` (Anthropic)
- `codex` (OpenAI)
- `copilot` (Microsoft / GitHub)
- `cursor`
- `junie` (JetBrains)
- `kiro` (AWS, Amazon)
- `opencode`
- `zed`
- As of 2026-05, there are 30+ established coding CLIs, and listing all of them turns a useful filter into noise. We add them only when a real locked repo needs them.

Since `<resource>` can contain `-`, a trailing segment can look like part of the name: `ai-skill-code-review-cursor` could be a Cursor variant of `code-review`, or an artifact named `code-review-cursor`. Treat a trailing segment as a harness postfix only if it is in the token list.

Examples:

```
ai-command-deploy                # portable version, if one exists
ai-command-deploy-claudecode     # Claude Code build
ai-command-deploy-codex          # Codex build
ai-hook-format-claudecode        # Claude Code build
ai-hook-format-cursor            # Cursor build
```
