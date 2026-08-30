# Go style guide

This document defines the style for writing Go applications, commands and libraries. It aims to produce code that is readable, maintainable, testable and compatible with the supported Go versions and target platforms. The language is called "Go"; use "Go" rather than "Golang" in prose ("Golang" remains useful in search queries and domain names such as `golang.foundata.com`).

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [When to use Go](#when-to-use-go)
- [Applications vs. libraries](#applications-vs-libraries)
- [Supported Go versions and toolchains](#supported-go-versions)
  - [Debian 13 compatibility exception](#debian-13-exception)
- [Module paths and the `golang.foundata.com` vanity domain](#module-paths)
- [Repository and package structure](#repository-structure)
- [Dependencies, `go.mod` and `go.sum`](#dependencies)
- [Formatting and imports](#formatting-and-imports)
- [Naming](#naming)
- [Packages, APIs, documentation and comments](#packages-apis-documentation)
- [Variables, constants, zero values and pointers](#variables-constants)
- [Slices, maps and structs](#slices-maps-structs)
- [Interfaces and generics](#interfaces-and-generics)
- [Functions, methods and receivers](#functions-methods-receivers)
- [Error handling](#error-handling)
- [Logging and command-line output](#logging-output)
- [Context, concurrency and goroutine lifetimes](#concurrency)
- [Files, HTTP and external commands](#files-http-external-commands)
- [Testing](#testing)
- [Linting, static analysis and vulnerability scanning](#linting-static-analysis)
  - [Staticcheck](#staticcheck-setup)
  - [golangci-lint (optional)](#golangci-lint-setup)
- [Repeatable checks and continuous integration](#continuous-integration)
- [Generated code and build constraints](#generated-code-build-constraints)
- [Builds, target platforms, cgo and cross-compilation](#builds-cross-compilation)
- [Author information](#author-information)



## When to use Go<a id="when-to-use-go"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Go is a statically typed, compiled general-purpose language defined by the [Go language specification](https://go.dev/ref/spec), with first-class concurrency, a comprehensive standard library and a toolchain that produces self-contained binaries. Its main operational advantage for us is distribution: a Go program can usually be shipped as one static executable with no runtime or dependency installation on the target host.


**Go is RECOMMENDED for:**

- Command-line tools and agents distributed as compiled binaries to heterogeneous Linux targets (see [Builds, target platforms, cgo and cross-compilation](#builds-cross-compilation)).
- Network services: HTTP APIs, proxies, exporters, daemons and other long-running processes.
- Concurrent workloads such as parallel I/O, fan-out API clients or job workers.
- Infrastructure and operations tooling that must start fast and run without an interpreter or virtual environment on the target system.
- Reusable libraries consumed by other Go projects.


**Go is NOT RECOMMENDED for:**

- Tiny wrappers that only invoke one or two commands; a POSIX shell script is simpler (see the [shell scripting style guide](./shell-scripting-style-guide.md)).
- Exploratory data processing, scientific computing or tasks that depend on a mature ecosystem that lives elsewhere (often Python, see the [Python style guide](./python-style-guide.md)).
- Desktop GUI applications; Go's GUI ecosystem is comparatively immature.
- Projects whose team cannot maintain a compiled language and its release pipeline; a build-and-release step is a real, recurring cost compared to editing an interpreted script in place.


**You SHOULD:**

- Prefer Go over Python when the deployment target cannot (or should not) carry an interpreter and dependency set, for example minimal containers, appliances or customer systems.
- Prefer Go over shell once a script needs structured data, retries, concurrency or automated tests.


**Reasoning:**

- Static binaries remove an entire class of deployment problems (interpreter versions, dependency resolution on the target, conflicting system packages).
- Go's standard library covers HTTP, TLS, JSON, archives, cryptography and testing, so many programs need few or no third-party dependencies.
- The cost side is real: Go programs must be compiled per platform, released and updated, whereas a script can be edited on the target. Choose Go when the distribution benefit outweighs the release overhead.



## Applications vs. libraries<a id="applications-vs-libraries"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Several rules in this guide depend on whether a module is an application or a library. The distinction is stated here once; later sections refer back to it under **"For applications"** and **"For libraries"** headings where their rules diverge. Everything not marked that way applies to both.

- **Applications and commands** are compiled and deployed as a whole. Optimize for reproducible builds and operational robustness: the module's `go.mod` and `go.sum` fully determine the dependency set, and most code can live in `internal/` packages.
- **Libraries** are imported by code we do not control. Optimize for compatibility and a small, stable API surface: keep dependencies minimal, follow the [import compatibility rule](https://go.dev/ref/mod#major-version-suffixes) and never break a tagged version.

A single repository MAY contain both (a library with companion commands under `cmd/`). In that case the library rules apply to the exported packages and the application rules to the commands.


**The axes that differ (and where they are specified):**

- API surface and `internal/` usage, see [Repository and package structure](#repository-structure).
- Dependency hygiene, `replace` directives and vendoring, see [Dependencies, `go.mod` and `go.sum`](#dependencies).
- Versioning and tagging discipline, see [Module paths and the `golang.foundata.com` vanity domain](#module-paths).
- Logging behavior, see [Logging and command-line output](#logging-output).


**Reasoning:**

- An application owns its whole build; nobody imports it, so its internal structure is free to change and exact dependency selection is an asset.
- Every exported identifier of a library is an API contract. Go modules make version selection automatic ([minimal version selection](https://go.dev/ref/mod#minimal-version-selection)), so an incompatible change in a library propagates to every consumer that updates.



## Supported Go versions and toolchains<a id="supported-go-versions"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Three different version questions are often conflated. Keep them apart:

1. **The minimum Go version of the source**, declared by the [`go` directive](https://go.dev/ref/mod#go-mod-file-go) in `go.mod`. Since Go 1.21 this is a hard requirement: the language features available to the code are capped at this version, and older toolchains refuse to build the module.
2. **The toolchain used to build and release**, controlled by the installed Go version, the [`toolchain` directive](https://go.dev/ref/mod#go-mod-file-toolchain) and the [`GOTOOLCHAIN`](https://go.dev/doc/toolchain) setting. A newer toolchain can always build a module with an older `go` directive.
3. **The runtime requirements of the produced binary**: operating system, kernel, architecture, and libc when cgo is used. These are properties of the build configuration, not of the `go` directive (see [Builds, target platforms, cgo and cross-compilation](#builds-cross-compilation)).

The [Go release policy](https://go.dev/doc/devel/release#policy) supports each major release until two newer major releases exist, so exactly two major versions receive security fixes at any time. As of 2026-Q3 these are Go 1.26 (current) and Go 1.25.


**You MUST:**

- Use the oldest Go major release still supported upstream as the minimum version for new projects. As of 2026-Q3:
  ```go
  go 1.25.0
  ```
- Build and test releases with the latest patch version of the current stable Go release (Go 1.26.x as of 2026-Q3). Patch releases contain security fixes; see the [release history](https://go.dev/doc/devel/release).
- Also test with the declared minimum version before a release, in CI or an equivalent repeatable environment. The `GOTOOLCHAIN` environment variable makes this easy without a second installation:
  ```sh
  GOTOOLCHAIN=go1.25.12 go test ./...
  ```
  Use the latest patch release of the minimum major version.
- Keep the source compatible with the declared minimum version: use language and standard-library features of newer versions only after raising the `go` directive.
- Raise the `go` directive in a library only when a feature genuinely requires it, and treat the raise as a compatibility-relevant change worth a minor version bump. The `go` directive of a library is consumed by every downstream module.


**You SHOULD:**

- Omit the `toolchain` directive from committed `go.mod` files. It only affects builds where the module is the *main module* — contributors and CI working in the repository, never downstream consumers, whose toolchain selection uses their own main module or workspace ([toolchain selection](https://go.dev/doc/toolchain)). Within the repository, the default (`GOTOOLCHAIN=auto`) already selects or downloads a suitable toolchain when needed, so a committed `toolchain` line forces switches onto contributors without adding compatibility information; the `go` directive alone states the actual requirement.
- Update the minimum version when a new Go major release ships and the previously required one leaves upstream support, as part of ordinary maintenance.
- Use a full `major.minor.patch` version in the `go` directive (`go 1.25.0`, not `go 1.25`). This is the format written by current toolchains and avoids ambiguity in toolchain selection.


**You MUST NOT:**

- Claim support for a Go version that is not exercised by repeatable tests.
- Declare a `go` version newer than the features actually require in a library. It forces upgrades on all consumers.
- Use `GOEXPERIMENT` features (for example the `encoding/json/v2` experiment) in released code. Experiments can change or disappear between releases.


**Reasoning:**

- Since Go 1.21, the `go` directive is a minimum requirement, and the toolchain automatically switches to (or downloads) a newer toolchain when a module or dependency requires it; see [Go toolchains](https://go.dev/doc/toolchain). This makes the directive a reliable, machine-enforced compatibility contract, which older Go versions treated only as a hint.
- Choosing the oldest *upstream-supported* release as the minimum gives consumers and contributors roughly a year of adoption headroom while never claiming support for a release that no longer receives security fixes.
- The [Go 1 compatibility promise](https://go.dev/doc/go1compat) makes building with the newest toolchain low-risk while providing the current compiler, runtime and security fixes to released binaries. The binary carries the runtime of the toolchain that built it, so releases benefit from building on the newest patch release even when the source targets an older language version.


### Debian 13 compatibility exception<a id="debian-13-exception"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Programs are normally distributed as compiled binaries, so the Go version packaged on a target host is irrelevant for running them. The exception is source that must be *compiled with the target distribution's packaged toolchain*, for example when a customer builds from source or a distribution package is planned. [Debian 13 ships Go 1.24](https://packages.debian.org/trixie/golang-go) and that version is frozen for the distribution's lifetime (Debian backports security fixes without changing the language version).

**You MAY** lower the minimum to:

```go
go 1.24.0
```

when compilation with Debian 13's packaged Go compiler is a concrete requirement. If you do:

- Document the exception and its reason in the project README.
- Add the minimum version to the CI test matrix like any other supported version (for example `GOTOOLCHAIN=go1.24.4`, matching Debian 13's packaged compiler), and verify that all dependencies actually build with it: a dependency's newer `go` directive requirement is a build failure on a toolchain that cannot auto-download newer toolchains from the network.
- Do not pin old dependency versions merely to preserve Go 1.24 compatibility. When current versions of a needed dependency require a newer Go version and there is no concrete deployment or consumer requirement for Debian's compiler, drop the exception instead.


**Reasoning:**

- Treating old-version support as a documented, tested exception (instead of a silent habit) keeps the default modern while making the constraint visible where it really exists. This mirrors the Debian exception in the [Python style guide](./python-style-guide.md#supported-python-versions).
- Holding back dependencies for an undocumented compatibility goal accumulates security and maintenance debt invisibly.



## Module paths and the `golang.foundata.com` vanity domain<a id="module-paths"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This section is **foundata policy**, not ecosystem consensus: most public Go projects simply use their repository host's path. We deliberately do not.


**You MUST:**

- Declare every first-party foundata Go module under the vanity domain we control:
  ```go
  module golang.foundata.com/<repository-name>
  ```
  For example, in the `go.mod` of the repository `example`:
  ```go
  module golang.foundata.com/example

  go 1.25.0
  ```
- Use the resulting paths in every first-party import:
  ```go
  import "golang.foundata.com/example/internal/config"
  ```
- Apply Go's [semantic import versioning](https://go.dev/ref/mod#major-version-suffixes): starting with major version 2, the module path carries the major version as a suffix, and imports change with it:
  ```go
  module golang.foundata.com/example/v2
  ```
  ```go
  import "golang.foundata.com/example/v2/internal/config"
  ```
- Write module and import paths without a URL scheme. The public website uses `https://golang.foundata.com/`, but module paths are identifiers, not URLs: `https://` MUST NOT appear in a `module` line or an `import` path.
- Version modules with semantic version tags (`v0.3.1`, `v1.2.0`); see [Module version numbering](https://go.dev/doc/modules/version-numbers).
- Set up the vanity mapping *before* the module is published or tagged: `https://golang.foundata.com/<repository-name>?go-get=1` (and every package path below it) must serve a page whose [`go-import` meta tag](https://go.dev/ref/mod#vcs-find) points Go tooling at the current source repository, for example:
  ```html
  <meta name="go-import" content="golang.foundata.com/example git https://github.com/foundata/example">
  ```
  Only the third field is a repository URL; the first field is the module path and stays stable across hosting changes and major versions (`/v2` resolves through the same mapping, selected by tags).
- Verify resolution before announcing a new module or tag, bypassing proxy caches:
  ```sh
  GOPROXY=direct go list -m golang.foundata.com/<repository-name>@latest
  ```
  A correctly named module without a working mapping is undiscoverable for every consumer.


**You MUST NOT:**

- Use `github.com/foundata/...` as a first-party module path, even though GitHub currently hosts the repositories. `golang.foundata.com/<repository-name>` is the stable public module identity; the vanity domain redirects Go tooling to whatever source hosting is current, so hosting can change without touching a single consumer.
- Rename a published module path without treating it as a new module (a path change breaks every consumer; the old path must keep resolving).


**You SHOULD:**

- Stay on major version `v0` until the API is deliberately stabilized, then tag `v1.0.0` consciously. `v0` signals that breaking changes are still possible without a path change.
- Avoid major version bumps in libraries. Every `/vN` bump forks the import path and forces migration work on all consumers; prefer compatible evolution (see [Functions, methods and receivers](#functions-methods-receivers)).


**Reasoning:**

- A module path is a permanent public identity: it appears in consumers’ `go.mod`, `go.sum`, imports, and the public checksum database. Tying it to a repository host such as `github.com` makes any future migration a breaking change. Vanity URLs avoid that lock-in. Further reading, references:
  - [Vanity import paths in Go](https://sagikazarmark.hu/blog/vanity-import-paths-in-go/) by Márk Sági-Kazár
  - [Using Go Vanity URLs with Hugo](https://blog.jbowen.dev/2020/07/using-go-vanity-urls-with-hugo/) by Jessica Bowen
  - [`go` docs: Remote import paths](https://pkg.go.dev/cmd/go#hdr-Remote_import_paths)
- The major version suffix implements the import compatibility rule ("if an old package and a new package have the same import path, the new package must be backwards compatible with the old package"). It allows `v1` and `v2` of a module to coexist in one build instead of creating unsolvable diamond-dependency conflicts.
- `v0`/`v1` module paths carry no suffix by design; `/v1` and `/v0` are invalid.



## Repository and package structure<a id="repository-structure"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Put `go.mod` at the repository root, one module per repository. We do not use monorepos or multi-module repositories; nested modules add resolution and tagging complexity (per-directory tag prefixes) without benefit for single-project repositories.
- Use [`internal/`](https://go.dev/doc/modules/layout) for every package that is not part of the module's public API. The compiler enforces that `internal/...` packages cannot be imported from outside the module.
- Put each binary's `main` package in `cmd/<binary-name>/` when a module provides commands. The directory name determines the installed binary name.
- Keep `package main` thin: parse flags, wire dependencies, and call testable functions in ordinary packages.


**You SHOULD:**

- Structure applications like this:
  ```text
  example/                        # repository root = module root
  ├── go.mod                      # module golang.foundata.com/example
  ├── go.sum
  ├── README.md
  ├── cmd/
  │   └── example/
  │       └── main.go             # thin entry point
  └── internal/
      ├── config/
      │   ├── config.go
      │   └── config_test.go      # tests live next to the code
      └── scanner/
          ├── scanner.go
          └── scanner_test.go
  ```
- Structure libraries with the importable API at the module root (so `import "golang.foundata.com/example"` works) and implementation details in `internal/`:
  ```text
  example/                        # repository root = module root
  ├── go.mod                      # module golang.foundata.com/example
  ├── go.sum
  ├── README.md
  ├── example.go                  # package example (public API)
  ├── example_test.go
  └── internal/
      └── parser/
          └── parser.go
  ```
- Use the `main`/`run` pattern so the entry point stays testable and signal handling is set up once (see the good example below).
- Split packages by domain responsibility (`config`, `scanner`, `report`), not by kind (`models`, `helpers`, `interfaces`).
- Keep the package tree flat. Introduce a new package when code has a distinct responsibility and a describable API, not to sort files.


**Good examples** (application entry point with the `main`/`run` pattern):

```go
package main

import (
	"context"
	"fmt"
	"os"
	"os/signal"

	"golang.foundata.com/example/internal/config"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	if err := run(ctx, os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, "example:", err)
		os.Exit(1)
	}
}

func run(ctx context.Context, args []string) error {
	cfg, err := config.Load(args)
	if err != nil {
		return fmt.Errorf("loading configuration: %w", err)
	}
	// Wire dependencies and do the actual work here, using ctx for
	// cancellation and cfg for configuration.
	_ = ctx
	_ = cfg
	return nil
}
```


**You SHOULD NOT:**

- Create a `pkg/` directory. It adds a meaningless path segment; `internal/` already separates private code, and everything else is public by definition. The pattern circulates in the community but is not part of any official layout guidance.
- Create a `src/` directory. Go code lives at the module root; `src/` is a convention from other ecosystems (including pre-module GOPATH days) and confuses Go tooling users.


**You MUST NOT:**

- Name a package `util`, `common`, `misc`, `helpers` or similar. Such names carry no information and become dumping grounds; see [Package names](https://go.dev/blog/package-names).
- Import `internal/` packages of another module (the compiler rejects it; do not work around it by copying code without attribution or a documented decision).


**Reasoning:**

- The official [module layout guidance](https://go.dev/doc/modules/layout) describes exactly this: small modules at the root, `cmd/` for multiple binaries, `internal/` for private packages. It does not use `pkg/`.
- Everything outside `internal/` in a library is a public API that must remain compatible forever (or until a `/v2`). Defaulting to `internal/` keeps the maintenance surface deliberately small; exporting later is cheap, un-exporting is a breaking change.
- Unlike in Python (`src` layout, separate `tests/` directory), Go tests belong in the same directory as the code under test — `_test.go` files are the ecosystem-wide convention understood by `go test`, coverage and all tooling.
- A thin `main` with a `run(ctx, args) error` function makes startup logic testable and gives one place for exit codes and signal handling.



## Dependencies, `go.mod` and `go.sum`<a id="dependencies"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Go resolves dependencies with [minimal version selection](https://go.dev/ref/mod#minimal-version-selection): the build uses the *minimum* version that satisfies all requirements, not the newest available. Version selection is therefore reproducible from `go.mod` alone, without a separate lock file — `go.sum` adds cryptographic verification of module content, not version selection.


**You MUST:**

- Commit `go.mod`, and commit `go.sum` whenever it exists, for applications and libraries alike. (`go.sum` is generated as soon as the module has dependencies, including tools; a dependency-free module legitimately has none.)
- Keep the module tidy: `go mod tidy` after dependency changes. CI SHOULD verify this with:
  ```sh
  go mod tidy -diff
  ```
  which reports needed changes without writing files (available since Go 1.23).
- Review dependency updates and run the full test suite after updating them:
  ```sh
  go get -u ./...   # or targeted: go get example.com/dep@v1.4.2
  go mod tidy
  go test ./...
  ```
- Evaluate a dependency before adopting it: maintenance activity, transitive dependency count, API quality, license. Prefer the standard library when it provides a clear and robust solution, but do not reimplement mature specialist functionality merely to avoid a dependency.


**You SHOULD:**

- Keep libraries' dependency sets minimal. Every dependency of a library becomes a (transitive) dependency of every consumer.
- Track developer tools (code generators, linters installed from Go source) with the [`tool` directive](https://go.dev/ref/mod#go-mod-file-tool) (Go 1.24+) so their versions are managed like other dependencies:
  ```sh
  go get -tool golang.org/x/tools/cmd/stringer
  go tool stringer -help
  ```
- Use a [`go.work` workspace](https://go.dev/ref/mod#workspaces) for local development across multiple foundata modules (for example an application plus a library being changed together) instead of `replace` directives.


**You MAY:**

- Vendor dependencies (`go mod vendor`, committed `vendor/` directory) in an application with a concrete requirement for network-free or audit-frozen builds. Document the reason; the Go toolchain uses `vendor/` automatically when present.
- Use the [`ignore` directive](https://go.dev/ref/mod#go-mod-file-ignore) (Go 1.25+) to exclude non-Go directory trees (web assets, third-party checkouts) from package pattern matching.
- Set `GOPRIVATE=golang.foundata.com/<private-prefix>` (plus matching VCS credentials) when working with private first-party modules, so the toolchain fetches them directly instead of through the public proxy and checksum database; see [Private modules](https://go.dev/ref/mod#private-modules).


**You MUST NOT:**

- Commit `go.work` or `go.work.sum`. Workspaces describe a developer's local checkout layout, not the project; a committed workspace file silently changes how everyone's builds resolve modules.
- Commit `replace` directives in libraries. Consumers ignore `replace` in dependency modules, so a library that only builds with its own `replace` is broken for everyone downstream.
- Commit `replace` directives in applications except as a documented temporary measure (for example an urgent fork of an unresponsive upstream) with a link to the tracking issue and a removal plan.
- Edit `go.sum` by hand or delete it to "fix" verification errors. A checksum mismatch means the module content changed for the same version — investigate it; see [Module authentication](https://go.dev/ref/mod#authenticating).
- Depend on `master`/pseudo-versions of third-party modules in released code when tagged releases exist.


**Reasoning:**

- Minimal version selection makes Go dependency resolution reproducible by design: unlike range-based resolvers, publishing a new upstream version never changes an existing build's dependency selection. This is why the application/library lock-file split from the Python guide has no Go equivalent — `go.mod` plays both roles.
- `go.sum` protects against a module version's content being changed after the fact (on the origin server or a proxy). Committing it is what makes `go mod verify` and the checksum database useful.
- The `tool` directive replaces the older `tools.go` blank-import workaround and gives every contributor and CI the same tool versions through the ordinary module mechanism.



## Formatting and imports<a id="formatting-and-imports"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Formatting is not a matter of taste in Go: [`gofmt`](https://pkg.go.dev/cmd/gofmt) defines the one canonical format, and the entire ecosystem relies on it. This guide adds nothing to mechanical style and defines no rules that conflict with `gofmt` output (tabs for indentation, brace placement, alignment and spacing are all owned by the formatter).


**You MUST:**

- Format all Go source with `gofmt` (or a formatter producing identical output, such as `goimports` or `gopls`). Unformatted code MUST NOT be committed; CI SHOULD verify with `goimports`, which checks formatting *and* the import grouping required below (plain `gofmt -l` cannot check the grouping):
  ```sh
  test -z "$(go tool goimports -local golang.foundata.com -l .)"
  ```
- Use UTF-8 without a byte-order mark and Unix line endings (LF, `\n`); this is what all Go tooling produces and expects.
- Group imports into blocks separated by blank lines, in this order: standard library, third-party, first-party (`golang.foundata.com/...`). `gofmt` sorts within blocks but preserves the blank-line grouping.


**You SHOULD:**

- Use [`goimports`](https://pkg.go.dev/golang.org/x/tools/cmd/goimports) with the `-local` flag as the everyday formatter; it is a superset of `gofmt` that also adds/removes import statements and maintains the first-party group:
  ```sh
  go get -tool golang.org/x/tools/cmd/goimports
  go tool goimports -local golang.foundata.com -w .
  ```
- Configure the editor to format on save via [`gopls`](https://pkg.go.dev/golang.org/x/tools/gopls), the official Go language server (set its `local` formatting option to `golang.foundata.com`).
- Keep lines readable. Go has no line-length limit and `gofmt` does not wrap lines; break long expressions at sensible points (after commas, before operators in long conditions) and prefer intermediate variables over deeply nested call chains. Do not contort code to satisfy an arbitrary column number.
- Import packages by their real name. Use an import alias only to resolve a genuine name collision or when the last path element does not match the package name; do not alias for brevity.


**You MUST NOT:**

- Use dot imports (`import . "example.com/pkg"`) outside the rare test-only cases they exist for; they obscure identifier origins.
- Use blank imports (`import _ "..."`) outside their documented use cases (registering drivers or image formats, `embed` without an identifier), and always comment why the blank import is needed.
- Manually "improve" formatting away from `gofmt` output (extra alignment, spaces instead of tabs). It will not survive the next formatter run.


**Good examples:**

```go
import (
	"context"
	"fmt"
	"net/http"

	"github.com/prometheus/client_golang/prometheus"

	"golang.foundata.com/example/internal/config"
	"golang.foundata.com/example/internal/scanner"
)
```


**Bad examples:**

```go
import (
	"golang.foundata.com/example/internal/config"
	"fmt"
	sc "golang.foundata.com/example/internal/scanner" // needless alias
	. "net/http"                                      // dot import
	"context"
	"github.com/prometheus/client_golang/prometheus"
)
```


**Reasoning:**

- A single canonical format eliminates style debates and formatting diffs; [Effective Go](https://go.dev/doc/effective_go#formatting) opens with exactly this argument. Every Go developer reads `gofmt` output everywhere, which is a genuine readability asset.
- Grouped imports make the dependency structure visible at a glance: what comes from the standard library, what is third-party, what is ours.
- `goimports -local` is the standard mechanism for the first-party group; it needs the module prefix, which is another reason a single stable prefix (`golang.foundata.com`) is valuable.



## Naming<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

In Go, naming *is* API design: an identifier starting with an upper-case letter is exported, everything else is package-private. The conventions below follow [Effective Go](https://go.dev/doc/effective_go#names) and the [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments).


**You MUST:**

- Use `MixedCaps` or `mixedCaps`, never underscores, for multi-word identifiers (`maxRetryCount`, `ServeHTTP`). Underscores appear only in test function names (`TestLoad_MissingFile`) and generated code.
- Keep initialisms consistently cased: `userID`, `parseURL`, `HTTPClient` — not `userId`, `parseUrl`, `HttpClient`.
- Use short, all-lowercase, single-word package names without underscores or capitals: `config`, `scanner`, `report`.
- Export an identifier only when it is part of the intended API. Default to unexported.
- Name error variables `ErrXxx` (`ErrNotFound`) and error types `XxxError` (`ParseError`); see [Error handling](#error-handling).


**You SHOULD:**

- Name for the caller, including the package qualifier: `config.Load`, not `config.LoadConfig` — the call site already reads the package name, so repeating it stutters. The package name is part of every use.
- Scale name length with scope: `i`, `r`, `buf` are fine in a five-line loop; a package-level identifier deserves a descriptive name. This is idiomatic Go, not sloppiness — but a short name still has to be conventional or obvious.
- Name getters after the field without a `Get` prefix (`c.Timeout()`, not `c.GetTimeout()`); use `SetTimeout` for the setter.
- Name single-method interfaces with the `-er` suffix (`Reader`, `Scanner`, `Notifier`).
- Include units in names where ambiguity is possible when the type does not carry them (`sizeBytes int64`); prefer types that carry the unit (`timeout time.Duration`) over suffixed names.
- Name booleans and predicates so they read as conditions (`isSearchable`, `hasPages`).


**You MUST NOT:**

- Use `Get` prefixes on getters, `this`/`self` as receiver names, or Hungarian-style type encodings (`userSlice`, `nameString`).
- Shadow predeclared identifiers such as `len`, `cap`, `new`, `min`, `max` or `error` without a compelling reason.


**Good examples:**

```go
package scanner

const defaultTimeout = 30 * time.Second

// ErrNoPages is returned when a document contains no scannable pages.
var ErrNoPages = errors.New("scanner: document has no pages")

type Scanner struct {
	client  *http.Client
	baseURL string
}

func (s *Scanner) HasSearchableText(ctx context.Context, docID string) (bool, error) {
	// ...
}
```


**Bad examples:**

```go
package scanner_utils

const DEFAULT_TIMEOUT_SECONDS = 30

var NoPagesErrorVariable = errors.New("no pages")

type ScannerStruct struct{}

func (this *ScannerStruct) GetHasSearchableText(Doc_Id string) bool {
	// ...
}
```


**Reasoning:**

- The compiler makes case meaningful (exported vs. unexported), so casing conventions are enforced structure, not decoration.
- `UPPER_SNAKE_CASE` constants, `Get` prefixes and type-suffixed names are conventions imported from other languages; Go code that follows them reads as foreign to every Go developer and fights the standard library's own style.
- Repeating the package name in identifiers (`config.ConfigLoad`) doubles information at every call site; [the Google Go Style Guide](https://google.github.io/styleguide/go/decisions#package-vs-exported-symbol-name) and the package names blog post both call this out.



## Packages, APIs, documentation and comments<a id="packages-apis-documentation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Go has one documentation mechanism: [doc comments](https://go.dev/doc/comment) directly above declarations, rendered by `go doc` and [pkg.go.dev](https://pkg.go.dev/). There is no separate docstring or annotation syntax.


**You MUST:**

- Write a doc comment for every exported identifier (package, type, function, method, constant, variable) in a library, and for every exported identifier of application packages whose behavior is not obvious from the name.
- Begin the doc comment with the identifier's name, as a complete sentence: `// Load reads the configuration from the given arguments.` This convention is what tooling and readers rely on.
- Write a package comment (`// Package config ...`) for every package; put it in a dedicated `doc.go` file when it is longer than a few lines or the package has several files.
- Document non-obvious behavior that callers depend on: side effects, concurrency safety, blocking behavior, sentinel errors returned, nil-handling.
- Mark deprecated identifiers with a `Deprecated:` paragraph naming the replacement:
  ```go
  // Deprecated: Use [Scanner.ScanContext] instead; Scan ignores cancellation.
  ```
- Write comments in US English and keep them accurate when changing the related code.


**You SHOULD:**

- Use comments to explain *why* (decisions, constraints, workarounds), not to narrate what each statement does.
- Include an issue or upstream reference for temporary workarounds.
- Use doc links (`[Scanner.Scan]`, `[net/http.Client]`) in doc comments so rendered documentation cross-references properly (supported since Go 1.19; see [Go Doc Comments](https://go.dev/doc/comment)).
- Provide runnable `Example` functions for non-trivial exported APIs (see [Testing](#testing)); they render in the documentation and are compiled and checked by `go test`.


**You MUST NOT:**

- Leave commented-out code in the source. Version control preserves history.
- Write doc comments that merely restate the signature (`// GetName returns the name.` on `func GetName() string`) — either document something useful or, for genuinely self-explanatory unexported identifiers, write nothing.


**Good examples:**

```go
// Package config loads and validates the application configuration.
package config

// Load parses the given command-line arguments and environment and
// returns the resulting configuration.
//
// It returns [ErrMissingDevice] when no scanner device is configured.
// The returned Config is immutable and safe for concurrent use.
func Load(args []string) (*Config, error) {
	// ...
}
```


**Bad examples:**

```go
package config

// load config
func Load(args []string) (*Config, error) {
	// increment counter
	attempts++
	// old approach, maybe needed again someday:
	// cfg := parseLegacyINI(args)
	// ...
}
```


**Reasoning:**

- Doc comments are the API reference: `go doc`, editors via `gopls`, and pkg.go.dev all render them. An undocumented exported identifier is an undocumented public contract.
- Starting with the identifier name makes documentation greppable and reads correctly in every rendering context; this is standard across the entire Go ecosystem (see [Effective Go on commentary](https://go.dev/doc/effective_go#commentary)).



## Variables, constants, zero values and pointers<a id="variables-constants"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Design types so their zero value is useful or at least safe where practical, and document when a type requires a constructor instead. The standard library sets the model: `var buf bytes.Buffer` and `var mu sync.Mutex` are ready to use.
- Never copy a value containing a lock or other synchronization state after first use (`sync.Mutex`, `sync.WaitGroup`, `sync.Once`, `bytes.Buffer`, `strings.Builder`); pass pointers instead. `go vet`'s `copylocks` check catches most cases.
- Use `time.Duration` for durations and `time.Time` for instants — never bare integers with unit-suffixed names crossing API boundaries.
- Use octal literals in `0o` notation for file modes (`0o600`), as required by modern Go style and enforced by linters.


**You SHOULD:**

- Declare with `:=` inside functions when the initial value determines the type; use `var` when declaring the zero value deliberately (`var found bool`) or when the type differs from the initializer's default.
- Keep declarations close to first use, and keep variable scope minimal.
- Define enumerated constants as a named type with `iota`, reserving the zero value for the "unknown/invalid" case so uninitialized values are detectable (see the good examples below).
- Use pointers when the callee must mutate the value, when the value contains synchronization state, or when the struct is genuinely large; otherwise pass values. Do not micro-optimize copies without measurement.
- Group related package-level constants and variables in a single `const`/`var` block.


**You MUST NOT:**

- Use package-level mutable state as an implicit dependency channel. Pass dependencies explicitly (see [Functions, methods and receivers](#functions-methods-receivers)); package-level `var` is acceptable for true constants that `const` cannot express (like sentinel errors or compiled regexps) and registered metrics.
- Rely on pointer-vs-value to signal "optional" in exported APIs when a separate boolean, a zero-value convention or a dedicated type is clearer. A `*int` parameter forces awkward call sites.


**Good examples:**

```go
// Enumerated constants: named type, iota, zero value reserved for "unknown".
type State int

const (
	StateUnknown State = iota
	StateQueued
	StateScanning
	StateDone
)
```

```go
// Zero value is ready to use; no constructor required.
type Counter struct {
	mu sync.Mutex
	n  map[string]int
}

func (c *Counter) Add(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.n == nil {
		c.n = make(map[string]int)
	}
	c.n[key]++
}
```


**Bad examples:**

```go
type Counter struct {
	mu sync.Mutex
	n  map[string]int
}

// Copies the mutex (and races): value receiver on a type containing a lock.
func (c Counter) Add(key string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.n[key]++ // panics: assignment to entry in nil map when used zero-valued
}
```


**Reasoning:**

- Useful zero values remove constructor boilerplate and a class of "forgot to initialize" bugs; this is a core Go design idiom (see [Effective Go on allocation](https://go.dev/doc/effective_go#allocation_new)).
- Copied locks silently stop protecting anything: each copy locks its own mutex. This is one of the most common subtle Go bugs, which is why `go vet` checks for it.
- Zero-as-invalid enums make forgotten assignments visible instead of silently meaning the first real state.



## Slices, maps and structs<a id="slices-maps-structs"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Treat a nil slice as an empty slice: `len`, `cap`, `range` and `append` all work on nil. Return nil for "no results"; do not force callers to distinguish nil from empty (and do not write APIs where the distinction matters, with the documented exception of `encoding/json` marshaling `nil` as `null` and `[]T{}` as `[]`).
- Check the second return value when a map lookup must distinguish "missing" from "zero value": `v, ok := m[k]`.
- Initialize a map before writing to it (`make`, literal, or lazily as in the Counter example above); writing to a nil map panics, reading from one is safe.
- Use field names in composite literals for structs from other packages. Positional literals break silently when the upstream struct gains or reorders fields (`go vet`'s `composites`-related checks and the ecosystem convention both expect keyed literals).


**You SHOULD:**

- Preallocate slices and maps when the size is known: `make([]Page, 0, len(docs))`, `make(map[string]int, n)`.
- Be deliberate about slice aliasing: a subslice shares the backing array, and `append` may or may not allocate a new one. Copy (`slices.Clone`) when retaining a slice beyond the caller's control or handing out internal state.
- Use the [`slices`](https://pkg.go.dev/slices) and [`maps`](https://pkg.go.dev/maps) standard-library packages (`slices.Contains`, `slices.SortFunc`, `maps.Keys`) instead of hand-written loops for common operations.
- Remember that map iteration order is deliberately randomized; sort keys when output must be deterministic.
- Prefer struct embedding only for genuine "is-a with method promotion" cases; a named field is clearer for plain composition. Embedded types become part of the exported method set and can accidentally satisfy interfaces.


**You MUST NOT:**

- Modify a map concurrently from multiple goroutines without synchronization; the runtime detects some cases and crashes deliberately (see [Context, concurrency and goroutine lifetimes](#concurrency)).
- Return internal slices or maps from methods when the caller must not mutate shared state; return a copy or an iterator.


**Good examples:**

```go
func pageTitles(pages []Page) []string {
	titles := make([]string, 0, len(pages))
	for _, p := range pages {
		titles = append(titles, p.Title)
	}
	return titles
}

cfg := Config{
	Device:  "net:localhost",
	Timeout: 30 * time.Second,
}
```


**Bad examples:**

```go
func pageTitles(pages []Page) []string {
	var titles []string // grows with repeated reallocation although len is known
	for i := 0; i < len(pages); i++ {
		titles = append(titles, pages[i].Title)
	}
	return titles
}

cfg := Config{"net:localhost", 30 * time.Second} // breaks when Config changes
```


**Reasoning:**

- Slices are views onto backing arrays, not containers; most slice bugs (surprising mutation at a distance, stale data) come from forgetting the aliasing model.
- Keyed struct literals decouple call sites from field order, which is what allows upstream structs to evolve compatibly — the same reason the API-compatibility section forbids relying on field order.



## Interfaces and generics<a id="interfaces-and-generics"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Go interfaces are satisfied implicitly: any type with the right methods implements the interface, without declarations. This inverts the dependency direction familiar from other languages — the *consumer* defines what it needs.


**You MUST:**

- Understand the nil-interface trap: an interface value holding a typed nil pointer is **not** `== nil`. Never return a concrete pointer type through an `error` (or other interface) result via a nil-typed variable:

```go
// Bad: caller's err != nil check is always true once p is assigned.
func load() error {
	var p *ParseError
	// ... p stays nil on success ...
	return p // non-nil interface wrapping a nil *ParseError
}

// Good: return literal nil on success.
func load() error {
	if failed {
		return &ParseError{}
	}
	return nil
}
```


**You SHOULD:**

- Define interfaces in the package that *consumes* them, sized to what that consumer needs — usually one or two methods. Producers return concrete types; consumers accept small interfaces ("accept interfaces, return structs" as a default, not a dogma: returning an interface is right when the concrete type is genuinely private or varies).
- Keep interfaces small. The standard library's most useful interfaces (`io.Reader`, `io.Writer`, `fmt.Stringer`) have one method.
- Reuse standard-library interfaces (`io.Reader`, `io.Writer`, `fs.FS`) instead of inventing equivalents.
- Use generics where they remove real duplication: functions that operate identically on multiple types (ordered comparisons, slice/map utilities, type-safe containers). Use [`cmp.Ordered`](https://pkg.go.dev/cmp#Ordered) and composed constraints from the standard library where possible. See the Go blog: [When to use generics](https://go.dev/blog/when-generics).
- Start concrete. Write the code for one type first; introduce a type parameter or an interface when a second real use case appears, and prefer an ordinary interface parameter when the method set is all you need.


**You MUST NOT:**

- Add interfaces "for mockability" before any second implementation (test fake included) actually exists at a consumer. Speculative interfaces are indirection without benefit.
- Use `any` (`interface{}`) where a concrete type, a small interface or a type parameter expresses the contract. `any` is the honest type only at genuinely dynamic boundaries (for example decoding arbitrary JSON), and it should be narrowed immediately via type switches or assertions with the `, ok` form.
- Use a type parameter when every call site would instantiate it with the same type, or when the function only calls methods of the constraint — that is what a plain interface parameter is for.


**Good examples:**

```go
// Consumer-side interface: report only needs Scan, not the whole *scanner.Scanner.
package report

type PageScanner interface {
	Scan(ctx context.Context, docID string) ([]Page, error)
}

func Build(ctx context.Context, s PageScanner, docID string) (*Report, error) {
	// ...
}
```

```go
// A generic function that genuinely works for any ordered type.
func Clamp[T cmp.Ordered](v, lo, hi T) T {
	return min(max(v, lo), hi)
}
```


**Bad examples:**

```go
// Producer-side mega-interface, defined next to its only implementation.
package scanner

type ScannerInterface interface {
	Scan(ctx context.Context, docID string) ([]Page, error)
	Close() error
	Configure(cfg Config) error
	Status() Status
	// ... every method the struct happens to have
}
```


**Reasoning:**

- Implicit satisfaction means adding an interface later requires no change to the concrete type, so there is no cost to starting concrete — the opposite of languages where interfaces must be planned upfront.
- Consumer-defined interfaces keep packages decoupled and testable: the test implements the two methods the consumer needs, not a producer's full API. This is the position of the [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments#interfaces) and the [Google Go Style Guide](https://google.github.io/styleguide/go/decisions#interfaces).
- Generics add cognitive and compile cost; the Go team's own guidance is to write concrete code first and reach for type parameters for mechanical, type-shaped duplication only.



## Functions, methods and receivers<a id="functions-methods-receivers"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Be consistent per type with receiver kind: if any method needs a pointer receiver, use pointer receivers for all methods of that type. Mixed receivers create subtle method-set and copy bugs.
- Use a pointer receiver when the method mutates the receiver, when the struct contains synchronization state, or when the type must not be copied.
- Return errors as the last return value; a function that can fail returns `(T, error)`, never an in-band sentinel like `-1` or `""` when a real error is possible.
- Keep exported APIs of published (v1+) libraries backwards compatible: do not remove exported identifiers or change their signatures, do not add methods to exported interfaces (every external implementation breaks), do not change behavior that documented contracts promise. Breaking changes require a new major version (`/v2`) — which is a last resort, see [Module paths](#module-paths).


**You SHOULD:**

- Keep functions focused and short enough to read as one thought; extract when a function does several things, not to hit a line count.
- Use early returns and keep the happy path at minimal indentation ("line of sight" style): handle the error, return, continue.
- Pass dependencies explicitly — as parameters or fields of the receiver — rather than reaching for package-level state.
- Take short receiver names derived from the type (`s` for `Scanner`, `c` for `Config`), consistent across all methods of the type.
- Use a config struct parameter for constructors with several optional settings; reserve functional options for published libraries where API evolution across versions matters, and plain parameters for one or two values. Pick one style per package.
- Make zero-parameter dependencies visible: prefer `NewScanner(client *http.Client)` over a constructor that silently uses `http.DefaultClient`.
- Use named result parameters only when they add documentation value (distinguishing two same-typed results) or are needed by a deferred function; avoid naked `return`s in any function longer than a few lines.
- Design functions to accept `io.Reader`/`io.Writer`/`fs.FS` instead of file paths where practical; it makes them testable without touching the filesystem.


**You MUST NOT:**

- Use variadic `...any` plus runtime type switching as a substitute for a typed API.
- Add boolean parameters whose meaning is invisible at the call site (`scan(true, false)`); use a small option struct or two functions.


**Good examples:**

```go
func (s *Scanner) Scan(ctx context.Context, docID string) ([]Page, error) {
	doc, err := s.fetch(ctx, docID)
	if err != nil {
		return nil, fmt.Errorf("fetching document %q: %w", docID, err)
	}
	if len(doc.Pages) == 0 {
		return nil, ErrNoPages
	}
	return doc.Pages, nil
}
```


**Bad examples:**

```go
// Mixed receivers, in-band error signalling, invisible boolean.
func (s Scanner) Scan(docID string, ocr bool) []Page {
	doc := s.fetch(docID)
	if doc == nil {
		return nil // error? empty? caller cannot tell
	}
	return doc.Pages
}

func (s *Scanner) Close() error { /* ... */ }
```


**Reasoning:**

- The happy-path-left style is a strong ecosystem convention (see [Go Code Review Comments on indentation](https://go.dev/wiki/CodeReviewComments#indent-error-flow)); it makes control flow scannable.
- Method sets differ between `T` and `*T`; consistent receivers avoid a class of "value copy loses the update" and interface-satisfaction surprises.
- In Go, API compatibility is enforced socially and by the module system rather than the compiler: modules guarantee that `v1.x` consumers keep getting compatible code, so the maintainer must actually keep it compatible.



## Error handling<a id="error-handling"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Errors are values, and error handling is regular control flow — explicit at every call site. The tools: [`errors.New`](https://pkg.go.dev/errors), `fmt.Errorf` with `%w`, `errors.Is`, `errors.As`, and custom error types. See [Working with errors in Go 1.13+](https://go.dev/blog/go1.13-errors).


**You MUST:**

- Check every error. Ignoring one requires an explicit `_ =` assignment plus a comment explaining why discarding is correct (rare: best-effort cleanup on an already-failing path, `(*bytes.Buffer).Write` and similar documented can't-fail cases).
- Add context when propagating: `fmt.Errorf("loading configuration: %w", err)`. The context states what *this* layer was doing; do not repeat what the callee already says.
- Wrap with `%w` when callers may need to inspect the underlying error with `errors.Is`/`errors.As`; use `%v` deliberately when the underlying error is an implementation detail that must not become API.
- Test error identity with `errors.Is` (sentinel values) and `errors.As` (typed errors), never with string matching or `==` on wrapped errors.
- Export sentinel errors as `var ErrXxx = errors.New("pkg: description")` and error types as `type XxxError struct{ ... }` when callers need to distinguish failure modes; keep them few, each one is API.
- Write error strings lowercase without trailing punctuation (they get embedded in other messages): `errors.New("scanner: connection lost")`, not `errors.New("Connection lost!")`.
- Handle each error once: either handle it (retry, fallback, log-and-degrade) or return it — not both. Log-and-return produces duplicate, contradictory logs at every layer.


**You SHOULD:**

- Use `errors.Join` or an accumulated error when an operation legitimately produces multiple independent failures (validating all fields, closing several resources).
- Design exported error values/types as deliberately as other API: once callers match on `ErrNotFound`, its meaning is frozen.
- Include the failing operand in the message (`"opening state file %q: %w"`); never include secrets or full untrusted payloads.


**You MUST NOT:**

- Use `panic` for expected failures (missing files, bad input, network errors). Panics are for programmer errors and unrecoverable invariant violations.
- Use `recover` as general exception handling. Recover only at deliberate boundaries — the top of a worker goroutine or a request handler — where it converts a bug into a logged failure of one unit of work instead of a process crash, and re-panic anything you cannot explain.
- Let `MustXxx` helpers (like `regexp.MustCompile`, `template.Must`) escape their intended use: package-level initialization from constant inputs, and tests. Runtime input never goes through `Must`.


**Good examples:**

```go
var ErrNotFound = errors.New("store: document not found")

func (s *Store) Document(id string) (*Document, error) {
	raw, err := s.db.Get(id)
	if errors.Is(err, sql.ErrNoRows) {
		return nil, fmt.Errorf("document %q: %w", id, ErrNotFound)
	}
	if err != nil {
		return nil, fmt.Errorf("reading document %q: %w", id, err)
	}
	return decode(raw)
}

// Caller: match on the sentinel, not the message.
doc, err := store.Document(id)
switch {
case errors.Is(err, store.ErrNotFound):
	return nil, httpError(http.StatusNotFound)
case err != nil:
	return nil, err
}
```


**Bad examples:**

```go
func (s *Store) Document(id string) *Document {
	raw, err := s.db.Get(id)
	if err != nil {
		log.Printf("error: %v", err) // logged here ...
		panic(err)                   // ... and panicking on an expected failure
	}
	doc, _ := decode(raw) // silently ignored error
	return doc
}

if strings.Contains(err.Error(), "not found") { // string matching
	// ...
}
```


**Reasoning:**

- Explicit error returns make failure paths visible in the code that owns the decision. The price is verbosity; the payoff is that error behavior is reviewable line by line.
- `%w` establishes an inspectable chain, but it also makes the wrapped error part of your API — callers may start depending on `errors.Is(err, sql.ErrNoRows)` through your function. That is exactly why the `%w` vs. `%v` decision is deliberate ([Go blog](https://go.dev/blog/go1.13-errors)).
- String-matching on error messages breaks on the next wording change; sentinels and typed errors exist to carry identity.



## Logging and command-line output<a id="logging-output"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use [`log/slog`](https://pkg.go.dev/log/slog) for application diagnostics. Configure the handler (level, format, destination) once at the entry point (see the good examples below).
- Send requested result data to standard output and diagnostics to standard error, so commands can participate in pipelines.
- Return a non-zero exit status when a command fails (see the `main`/`run` pattern in [Repository and package structure](#repository-structure)); use exit code 2 for command-line usage errors, following Unix convention.
- Keep secrets, tokens and sensitive payloads out of log output at every level, including `Debug`.


**You SHOULD:**

- Log structured key-value attributes rather than formatted strings: `slog.Info("page processed", "doc", docID, "page", n)`, not `slog.Info(fmt.Sprintf("processed page %d of %s", n, docID))`.
- Choose levels consistently: `Debug` for diagnostic detail, `Info` for normal progress, `Warn` for recoverable problems, `Error` for failed operations.
- Use `slog.NewJSONHandler` for services whose logs are shipped to aggregation, and the text handler for interactive tools.
- Pass a `*slog.Logger` explicitly (parameter or struct field) in larger applications instead of relying on the process-global default everywhere; the global is acceptable in small commands.


**For libraries:**

- Do not log. Return errors with context and let the application decide what is worth logging and how. A library that genuinely needs optional diagnostics SHOULD accept a `*slog.Logger` from the caller and default to discarding (`slog.New(slog.DiscardHandler)`).


**You MUST NOT:**

- Use `fmt.Println` and friends for diagnostics in anything beyond a throwaway script.
- Log an error and also return it (see [Error handling](#error-handling)).
- Call `log.Fatal`/`os.Exit` outside `main`/`run`-level code: it skips deferred cleanup everywhere below and makes code untestable.


**Good examples:**

```go
// In run(): configure logging once, before any work starts.
logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
	Level: slog.LevelInfo,
}))
slog.SetDefault(logger)

// At the call site: structured attributes, not formatted strings.
slog.Info("page processed", "doc", docID, "page", pageNumber)
slog.Error("scan failed", "doc", docID, "error", err)
```


**Bad examples:**

```go
fmt.Println("processing page", pageNumber)            // diagnostics on stdout
slog.Info(fmt.Sprintf("processed page %d", pageNumber)) // preformatted message
log.Fatalf("scan failed: %v", err)                    // exits deep in library code
```


**Reasoning:**

- `slog` is the standard library's structured logging API (since Go 1.21); using it avoids forcing a third-party logging dependency onto every consumer and integrates with the ecosystem's handler implementations when needed.
- Libraries do not know their host application's logging policy; leaking log output from libraries is the Go equivalent of the "library configures logging" anti-pattern the Python guide prohibits.
- Structured attributes keep log data machine-searchable regardless of the output format the application selects.



## Context, concurrency and goroutine lifetimes<a id="concurrency"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Goroutines are cheap to start and impossible to kill from outside: every goroutine must have a defined way to end. Cancellation is cooperative and flows through [`context.Context`](https://pkg.go.dev/context).


**You MUST:**

- Pass `context.Context` as the first parameter, named `ctx`, of every function on a request/operation path that can block, do I/O, or outlive a caller's interest. Do not store contexts in struct fields; pass them per call ([context blog post](https://go.dev/blog/context)).
- Know how every goroutine you start will end, and what happens if it doesn't. A goroutine blocked forever on a channel or lock is a leak of memory *and* of whatever it holds open.
- Wait for goroutines you start ([`sync.WaitGroup`](https://pkg.go.dev/sync#WaitGroup); since Go 1.25, `wg.Go(func(){...})` replaces the manual `Add`/`Done` pair) — "fire and forget" goroutines outliving their work item are almost always bugs.
- Synchronize all access to shared mutable state: a mutex, a channel, or confinement to one goroutine. The race detector (`go test -race`) MUST be part of the standard test run; a reported race is a bug, never a "benign race" ([race detector docs](https://go.dev/doc/articles/race_detector)).
- Honor cancellation: check `ctx.Err()`/`select` on `ctx.Done()` in loops and pass `ctx` down to blocking calls. Use `context.WithTimeout`/`WithDeadline` for operations with a bounded time budget, and always call the returned `cancel` (typically via `defer`).
- Close a channel only from the sender side (or a coordinator that owns all senders), never from a receiver; and never close a channel twice. Closing is a signal that no more values will be sent — receivers that need it detect it via `v, ok := <-ch` or `range`.


**You SHOULD:**

- Prefer the simplest tool that is correct: a `sync.Mutex` guarding a struct field is often clearer than a channel choreography, and a channel is clearer than a condition variable. "Share memory by communicating" is a design nudge, not a ban on mutexes.
- Group mutex-protected fields directly below the mutex in the struct, with a comment stating what the mutex guards.
- Use unbuffered channels by default; give a channel a buffer only with a reason you can state (known producer burst size, decoupling documented at the declaration).
- Use `context.Value` only for request-scoped metadata that crosses API boundaries (trace IDs, authenticated principal), with unexported key types — never for passing ordinary parameters or dependencies.
- Bound concurrency with a worker pool or semaphore when fanning out (a `chan struct{}` used as a semaphore is fine); unbounded goroutine fan-out turns load spikes into memory spikes.
- Use [`testing/synctest`](https://pkg.go.dev/testing/synctest) (stable since Go 1.25) to test concurrent code that involves time, instead of real sleeps.


**You MUST NOT:**

- Use `time.Sleep` for synchronization — not in production code to "wait until it's probably ready", and not in tests to mask races.
- Start a goroutine in a library without giving the caller control over its lifetime (explicit `Close`/`Shutdown`, or scoped to a call that returns only when the goroutine is done).
- Pass a `nil` context; use `context.Background()` at the top of a program and `context.TODO()` as an explicit refactoring marker.


**Good examples:**

```go
// Bounded fan-out with cancellation and a joined error. On cancellation the
// returned error is non-nil and results may be partial; callers must not
// treat them as complete.
func scanAll(ctx context.Context, s *Scanner, ids []string) (map[string][]Page, error) {
	var (
		mu      sync.Mutex
		results = make(map[string][]Page, len(ids))
		errs    []error
	)
	sem := make(chan struct{}, 4) // at most 4 concurrent scans

	var wg sync.WaitGroup
	for _, id := range ids {
		wg.Go(func() {
			select {
			case sem <- struct{}{}:
				defer func() { <-sem }()
			case <-ctx.Done():
				return // cancellation is recorded once, after wg.Wait
			}
			pages, err := s.Scan(ctx, id)
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				errs = append(errs, fmt.Errorf("document %q: %w", id, err))
				return
			}
			results[id] = pages
		})
	}
	wg.Wait()
	if err := ctx.Err(); err != nil {
		errs = append(errs, err) // cancellation may have skipped documents
	}
	return results, errors.Join(errs...)
}
```


**Bad examples:**

```go
func scanAll(s *Scanner, ids []string) map[string][]Page {
	results := make(map[string][]Page)
	for _, id := range ids {
		go func() {
			pages, _ := s.Scan(context.TODO(), id)
			results[id] = pages // data race: concurrent map write
		}()
	}
	time.Sleep(5 * time.Second) // "should be done by now"
	return results
}
```


**Reasoning:**

- Goroutine leaks are invisible until they aren't: each one pins its stack, its captured variables and often a connection. Making lifetime a review question ("how does this goroutine end?") catches them at design time; this framing follows the [Google Go Style Guide's best practices](https://google.github.io/styleguide/go/best-practices) and Go Code Review Comments on goroutine lifetimes.
- The race detector finds real memory-model violations at runtime with modest overhead — but only on exercised code paths, which is why racy tests must actually run under `-race` in CI.
- Cooperative cancellation through `ctx` is the only cancellation there is; any blocking call that doesn't take a context is a place where shutdown hangs.



## Files, HTTP and external commands<a id="files-http-external-commands"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Build filesystem paths with [`path/filepath`](https://pkg.go.dev/path/filepath) (`filepath.Join`), never by string concatenation. Use `path` only for slash-separated non-filesystem paths (URLs, `io/fs` names).
- Validate or contain untrusted path components. When accessing files under a directory on behalf of untrusted input, use [`os.Root`](https://go.dev/blog/osroot) (Go 1.24+) for traversal-safe access instead of hand-written `..` filtering.
- Close resources you open, normally with `defer` immediately after the error check. For *written* files, check the error of `Close` (and `Sync` where durability matters) — it can report the write failure (see the good examples below).
- Set timeouts on all network activity; the standard library defaults to none:
  - HTTP clients: set `http.Client.Timeout` or use per-request contexts (`http.NewRequestWithContext`). Never use `http.DefaultClient`/`http.Get` for production traffic — they have no timeout.
  - HTTP servers: set `ReadHeaderTimeout` at minimum (Slowloris protection), and `ReadTimeout`/`WriteTimeout`/`IdleTimeout` as appropriate for the service.
- Close HTTP response bodies (`defer resp.Body.Close()`) on every path, and check `resp.StatusCode` — a non-2xx response is not an `err` from `Do`.
- Run external commands with [`os/exec`](https://pkg.go.dev/os/exec) argument slices; there is no shell involved unless you invoke one. Use `exec.CommandContext` so a hung command dies with the operation's context or timeout.
- Use `os.CreateTemp`/`os.MkdirTemp` for temporary files, never predictable names in shared directories.
- Use [`crypto/rand`](https://pkg.go.dev/crypto/rand) for tokens, keys and anything security-sensitive; `math/rand/v2` is fine for everything that only needs to be well-distributed.


**You SHOULD:**

- Stream with `io.Reader`/`io.Writer`/`io.Copy` instead of slurping whole files with `os.ReadFile` when inputs can be large; use the convenience functions for small config-sized files.
- Write important files atomically: write to a temporary file in the same directory, `Sync`, `Close`, then `os.Rename` over the destination.
- Set explicit, restrictive permissions when creating files with sensitive content (`os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o600)`).
- Use [`embed`](https://pkg.go.dev/embed) for static assets that ship with the binary (templates, default configs) instead of locating files relative to the executable at runtime.
- Limit request body sizes on servers (`http.MaxBytesReader`) and set sensible `http.Server` limits before exposing a service.
- Use `http.Server.Shutdown(ctx)` wired to `signal.NotifyContext` for graceful termination of services.
- Bound and review retries: bounded attempts with backoff, and only for operations that are safe to repeat or idempotent.


**You MUST NOT:**

- Invoke a shell (`sh -c`) with interpolated input. If shell syntax is genuinely essential, every interpolated value must be controlled and the reason documented.
- Rely on the current working directory to locate resources unless it is an explicit part of the command's interface.
- Deserialize untrusted input with mechanisms that execute or allocate unboundedly — decode into typed structs, enforce size limits first, and treat `any`-typed decoding results as unvalidated data.


**Good examples:**

```go
// Written file: deferred Close as fallback, explicit Close checked for errors.
func writeReport(path string, data []byte) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close() // fallback cleanup on early return
	if _, err := f.Write(data); err != nil {
		return fmt.Errorf("writing %q: %w", path, err)
	}
	if err := f.Close(); err != nil { // the Close whose error we act on
		return fmt.Errorf("closing %q: %w", path, err)
	}
	return nil
}
```

```go
func fetchStatus(ctx context.Context, client *http.Client, url string) (*Status, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("querying %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("querying %s: unexpected status %s", url, resp.Status)
	}
	var st Status
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&st); err != nil {
		return nil, fmt.Errorf("decoding status: %w", err)
	}
	return &st, nil
}
```

```go
cmd := exec.CommandContext(ctx, "tesseract", imagePath, outputBase)
if out, err := cmd.CombinedOutput(); err != nil {
	return fmt.Errorf("running tesseract on %q: %w (output: %s)", imagePath, err, out)
}
```


**Bad examples:**

```go
resp, _ := http.Get(url)                       // no timeout, error ignored
body, _ := io.ReadAll(resp.Body)               // no close, unbounded read
exec.Command("sh", "-c", "tesseract "+imagePath).Run() // shell injection
```


**Reasoning:**

- The zero timeout defaults in `net/http` are the single most common cause of Go services hanging under network failure; timeouts convert an outage into an error that error handling can deal with.
- `os/exec` without a shell removes command injection by construction — the same reasoning as the argument-list rules in our [Python](./python-style-guide.md#paths-files-external-commands) and [PowerShell](./powershell-style-guide.md) guides.
- `os.Root` moves path-traversal protection from fragile string checks into the kernel-supported file-opening primitive; see the [Go blog on traversal-resistant file APIs](https://go.dev/blog/osroot).



## Testing<a id="testing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Go's [`testing`](https://pkg.go.dev/testing) package plus the `go test` command cover unit tests, benchmarks, fuzzing, examples and coverage without third-party frameworks. The conventions below follow the [Go Test Comments](https://go.dev/wiki/TestComments).


**You MUST:**

- Add or update tests for behavior changes and bug fixes; add the regression test with (or before) the fix.
- Put tests in `_test.go` files next to the code under test. Use the internal package for white-box tests and `package foo_test` for black-box tests of the public API (required anyway for examples that show realistic usage).
- Run tests with the race detector in CI and before releases: `go test -race ./...`.
- Keep the default test suite hermetic: no network, no external services, no dependence on execution order, wall-clock timing or developer-machine state. Guard integration tests that need real infrastructure behind a build tag:
  ```go
  //go:build integration
  ```
  and run them explicitly with `go test -tags=integration ./...`.
- Use `t.TempDir()` for scratch directories and `t.Setenv` for environment changes; both clean up automatically. Test fixtures belong in the package's `testdata/` directory (ignored by the go tool) and MUST NOT be modified by tests.
- Report failures with `t.Errorf`/`t.Fatalf` including what was checked, got, and want. Use `t.Fatalf` only when the test cannot continue, and never from goroutines other than the test's own.


**You SHOULD:**

- Write table-driven tests with subtests for input/output-shaped behavior — `t.Run` gives each case a name, isolated failure, and individual selection with `go test -run 'TestParseSize/rejects'` (see the good examples below).
- Mark test helpers with `t.Helper()` so failures point at the calling test line; pass `*testing.T` as the helper's first parameter. Register cleanup with `t.Cleanup` inside helpers rather than returning teardown functions.
- Use `t.Context()` (Go 1.24+) for a context canceled automatically when the test ends.
- Compare structured values with [`github.com/google/go-cmp/cmp`](https://pkg.go.dev/github.com/google/go-cmp/cmp) (`cmp.Diff`) and print the diff; prefer the standard library plus `go-cmp` over assertion frameworks — keeping test failures as ordinary `t.Errorf` output with explicit got/want is the ecosystem's mainstream and keeps the dependency surface minimal.
- Run tests in parallel (`t.Parallel()` in the test and in subtests) when they are independent; this also surfaces isolation bugs. Use `-shuffle=on` in CI to catch order dependence.
- Write `Example` functions with `// Output:` comments for exported APIs; they are documentation *and* compiled, executed tests (see the good examples below).
- Fuzz parsers and other functions consuming untrusted input ([fuzzing docs](https://go.dev/doc/security/fuzz/)); commit interesting corpus entries under `testdata/fuzz/` (see the good examples below). Run fuzzing locally or in a scheduled job: `go test -fuzz=FuzzParseSize -fuzztime=60s ./internal/config` (fuzzing runs one package at a time; without `-fuzz`, seed corpus entries run as ordinary tests).
- Write benchmarks with `b.Loop()` (Go 1.24+) for performance-relevant code and run them with `go test -bench=. -benchmem`; compare results with [`benchstat`](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat) rather than eyeballing single runs.
- Measure coverage to find untested behavior (`go test -coverprofile=coverage.out ./...`, `go tool cover -func=coverage.out`), but do not treat a percentage as a substitute for meaningful assertions or enforce arbitrary thresholds.
- Use fakes implementing the consumer-side interfaces at project boundaries; avoid mocking frameworks and avoid mocking ordinary internal calls.


**Good examples** (table-driven test with subtests, a runnable example, a fuzz target):

```go
func TestParseSize(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    int64
		wantErr bool
	}{
		{name: "bytes", input: "42", want: 42},
		{name: "kilobytes", input: "4k", want: 4096},
		{name: "rejects empty input", input: "", wantErr: true},
		{name: "rejects negative size", input: "-1", wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := ParseSize(tt.input)
			if (err != nil) != tt.wantErr {
				t.Fatalf("ParseSize(%q) error = %v, wantErr %t", tt.input, err, tt.wantErr)
			}
			if got != tt.want {
				t.Errorf("ParseSize(%q) = %d, want %d", tt.input, got, tt.want)
			}
		})
	}
}

func ExampleParseSize() {
	n, _ := ParseSize("4k")
	fmt.Println(n)
	// Output: 4096
}

func FuzzParseSize(f *testing.F) {
	f.Add("4k")
	f.Fuzz(func(t *testing.T, s string) {
		n, err := ParseSize(s)
		if err == nil && n < 0 {
			t.Errorf("ParseSize(%q) = %d, want >= 0", s, n)
		}
	})
}
```


**You MUST NOT:**

- Use `time.Sleep` to wait for concurrent behavior in tests; synchronize with channels, or use `testing/synctest` for time-dependent logic.
- Skip or weaken assertions to make a test pass, or assert only "no error" when the result value is the point.
- Depend on map iteration order, goroutine scheduling or precise wall-clock durations in assertions.


**Reasoning:**

- Table-driven tests scale case coverage without duplicating scaffolding, and named subtests turn a failing case into an addressable unit; this is the testing style used and recommended across the Go ecosystem.
- The standard `testing` package is deliberately assertion-free; got/want failure messages carry more information than a generic assertion error, and every Go developer can read them. `go-cmp` fills the one real gap (structural diffs) without introducing a DSL.
- Fuzzing and `-race` find the two bug classes reviews miss most reliably: unhandled input shapes and data races. Both are built into `go test`, so the marginal cost is a CI line.
- Examples are the only documentation format that CI compiles and runs, so they cannot silently rot.



## Linting, static analysis and vulnerability scanning<a id="linting-static-analysis"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

The baseline is standard tooling: `gofmt`/`goimports` (see [Formatting and imports](#formatting-and-imports)), [`go vet`](https://pkg.go.dev/cmd/vet), and [`govulncheck`](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck). [Staticcheck](https://staticcheck.dev/) is the one third-party analyzer we add by default; [golangci-lint](https://golangci-lint.run/) is an optional aggregator for projects that want more.


**You MUST:**

- Run `go vet ./...` and fix every diagnostic. Vet reports likely-wrong code (unreachable code, misused `Printf` verbs, copied locks, malformed struct tags); its findings are close to always real bugs. (`go test` runs a subset of vet checks automatically, which is not a substitute for the full run.)
- Scan for known vulnerabilities with `go tool govulncheck ./...` before every release (track [`govulncheck`](https://pkg.go.dev/golang.org/x/vuln/cmd/govulncheck) with the `tool` directive like the other developer tools), and fix findings by updating the affected dependency (or the Go toolchain — the standard library is scanned too). `govulncheck` performs reachability analysis and reports only vulnerabilities in code paths your project actually calls, so findings are actionable, not noise (see [Go's security documentation](https://go.dev/security/), especially its [vulnerability management guidance](https://go.dev/doc/security/vuln/)).
- Fix every diagnostic of the configured analyzers. A suppression MUST be as narrow as possible and carry a short justification when the reason is not obvious:
  ```go
  //lint:ignore SA1019 vendor API v2 requires the deprecated client until 2026-10, see #123
  client := legacy.NewClient()
  ```
  (Staticcheck syntax; for golangci-lint use `//nolint:staticcheck // reason`.)
- Run all checks against production code *and* tests.


**You SHOULD:**

- Use Staticcheck as the standard additional analyzer (see below).
- Rely on [`gopls`](https://pkg.go.dev/golang.org/x/tools/gopls) in the editor: it surfaces vet and Staticcheck-powered diagnostics, formats on save and keeps imports tidy, so problems appear while typing instead of in CI.
- Run `go fix ./...` (rewritten in Go 1.26 around "modernizer" analyzers) after raising the minimum Go version, and review its suggested cleanups like any other diff; see [Using go fix to modernize Go code](https://go.dev/blog/gofix).
- Pin analyzer versions like other dev tooling (the `tool` directive, or a pinned binary version in CI) so results are reproducible.


**You MAY:**

- Use golangci-lint v2 when a project wants a broader, centrally configured linter set (see below). It is an aggregator: it adds configuration surface and upgrade churn in exchange for breadth, which is a good trade for larger or multi-contributor codebases and an unnecessary one for small tools.


**You MUST NOT:**

- Disable a check globally to silence one finding.
- Add analyzers whose findings the project does not intend to fix; a permanently red or permanently ignored check is worse than no check.


### Staticcheck<a id="staticcheck-setup"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[Staticcheck](https://staticcheck.dev/docs/) detects bugs, performance issues, deprecated API usage and style inconsistencies with a low false-positive rate; each check is documented with rationale (checks `SA*`, `S*`, `ST*`, `QF*`). Releases track Go releases (Staticcheck 2026.1 supports Go 1.25 and 1.26).

```sh
# Track the version in go.mod like other tools (Go 1.24+):
go get -tool honnef.co/go/tools/cmd/staticcheck
go tool staticcheck ./...
```

The default check set is a good baseline, but note it excludes several style checks (`ST1000`, `ST1003` and others). Adjust it in a committed `staticcheck.conf` at the repository root rather than in flags, so every environment runs the same set; at minimum, re-enable `ST1000` so the package-comment requirement from [Packages, APIs, documentation and comments](#packages-apis-documentation) is machine-enforced:

```toml
# staticcheck.conf – keep close to defaults; document every deviation.
checks = ["inherit", "ST1000"]  # ST1000: package comments are required by our style guide
```


### golangci-lint (optional)<a id="golangci-lint-setup"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

When adopting [golangci-lint](https://golangci-lint.run/), use the v2 configuration format and start from the `standard` default set (which already includes `govet`, `staticcheck`, `errcheck`, `ineffassign` and `unused` — do not run Staticcheck separately in that case). A minimal `.golangci.yml`:

```yaml
version: "2"

linters:
  default: standard
  enable:
    - gosec      # security-oriented checks
    - misspell   # commonly misspelled English words
  settings:
    misspell:
      locale: "US"

formatters:
  enable:
    - goimports
  settings:
    goimports:
      local-prefixes:
        - "golang.foundata.com"
```

Install it as a binary release pinned to an exact version (the maintainers do not support `go install` builds of it); in CI, pin the same version. Enable additional linters deliberately, one by one, with the same discipline as [Ruff rule categories in the Python guide](./python-style-guide.md#additional-ruff-rule-categories): only when the project intends to keep their findings at zero.


**Reasoning:**

- `go vet` ships with the toolchain, is maintained with the language, and has essentially no false-positive budget — there is no reason not to run it.
- Staticcheck is the de-facto standard second analyzer: mature, documented per-check, and partially integrated into `gopls`. It provides a concrete benefit (hundreds of precise bug patterns vet does not cover) rather than mere popularity.
- `govulncheck`'s call-graph reachability is what makes vulnerability scanning tolerable in practice: it distinguishes "a dependency has a CVE" from "your binary can reach the vulnerable function".
- A fixed, small tool stack keeps checks fast and reproducible; every additional linter is configuration to maintain and upgrade churn to absorb.



## Repeatable checks and continuous integration<a id="continuous-integration"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Keep every required formatting, analysis, build, test and vulnerability-scanning command executable locally without a CI service. Provision the three non-toolchain tools once through the `tool` directive so every environment runs the same pinned versions:
  ```sh
  go get -tool golang.org/x/tools/cmd/goimports
  go get -tool honnef.co/go/tools/cmd/staticcheck
  go get -tool golang.org/x/vuln/cmd/govulncheck
  ```
  The standard sequence (the Staticcheck line reflects the default analyzer setup, see [Linting, static analysis and vulnerability scanning](#linting-static-analysis)):
  ```sh
  test -z "$(go tool goimports -local golang.foundata.com -l .)"  # formatting and import grouping
  go vet ./...                     # toolchain static analysis
  go tool staticcheck ./...        # additional static analysis
  go build ./...                   # everything compiles, including cmd/
  go test -race -shuffle=on ./...  # tests with race detector, shuffled order
  go mod tidy -diff                # go.mod/go.sum are tidy
  go tool govulncheck ./...        # known-vulnerability scan
  ```
- Run all required checks successfully before a release.
- Test the declared minimum Go version and the current stable release before a release (see [Supported Go versions and toolchains](#supported-go-versions)).
- When a project uses CI, run the required checks automatically for relevant changes.


**You SHOULD:**

- Use this version matrix, updating it as versions move:
  ```yaml
  go-version:
    - "1.25.x"   # declared minimum (go directive)
    - "1.26.x"   # current stable; used for release builds
  ```
- Automate the checks with CI when the project's size, release frequency or number of contributors justifies the infrastructure, and prefer a self-hostable CI system or one that is independent of a particular repository hosting provider.
- For released binaries, run the test suite (or at least a smoke test of the built artifact) on every supported target platform: Debian 13, CentOS Stream 10 and Fedora 44 (see [Builds, target platforms, cgo and cross-compilation](#builds-cross-compilation)).
- Cache the Go build and module caches in CI (`go env GOCACHE GOMODCACHE`) to keep runs fast.


**You SHOULD NOT:**

- Depend on GitHub Actions or another proprietary forge-specific CI service as the only implementation of build, test or release logic. Provider-specific workflows MUST NOT be the only place the commands live.


**Reasoning:**

- Go's toolchain makes the full check suite a handful of dependency-light commands, so "runnable locally" costs nothing and keeps development and releases possible when the project moves to another host or CI system — the same policy as the other guides in this repository.
- Testing minimum and current versions catches both directions of drift: accidental use of too-new APIs, and breakage under a newer toolchain before it becomes the release toolchain.



## Generated code and build constraints<a id="generated-code-build-constraints"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Mark generated files with the standard comment so tools and reviewers recognize them ([convention](https://go.dev/s/generatedcode); the line must match `^// Code generated .* DO NOT EDIT\.$` and appear before any non-comment content):
  ```go
  // Code generated by "stringer -type=State"; DO NOT EDIT.
  ```
- Commit generated Go code and regenerate it via [`go generate`](https://pkg.go.dev/cmd/go#hdr-Generate_Go_files_by_processing_source) directives placed next to the source of truth:
  ```go
  //go:generate go tool stringer -type=State
  ```
- Never edit generated files by hand; change the generator input and regenerate.
- Pin generator versions through the `tool` directive so regeneration is reproducible, and verify freshness in CI (`go generate ./... && git diff --exit-code`).
- Use the modern `//go:build` constraint syntax (the legacy `// +build` form is obsolete since Go 1.17; `gofmt` maintains `//go:build` lines).


**You SHOULD:**

- Prefer filename suffixes for whole-file platform code (`scanner_linux.go`, `scanner_windows.go`, `proc_linux_amd64.go`); use `//go:build` expressions for combinations suffixes cannot express (`//go:build linux || darwin`).
- Keep platform-specific code thin: a small per-platform file implementing one internal function, with shared logic in portable code.
- Verify that all first-class platform combinations still compile even without their hardware: `GOOS=windows go build ./...` type-checks the Windows files on any host.


**Reasoning:**

- Committing generated code keeps `go build` working for every consumer without requiring generators installed; the freshness check in CI prevents the committed output from drifting from its source.
- The `DO NOT EDIT` marker is machine-readable: linters, coverage tools and code review tooling use it to skip generated files.



## Builds, target platforms, cgo and cross-compilation<a id="builds-cross-compilation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Our usual Linux targets are **Debian 13, CentOS Stream 10 and Fedora 44**. Programs are normally distributed as compiled binaries rather than built on the target host, so the deciding compatibility factors are the binary's requirements — kernel, architecture and (only with cgo) libc — not the Go version installed on the target.


**You MUST:**

- Build release binaries with the latest patch release of the current stable Go toolchain (see [Supported Go versions and toolchains](#supported-go-versions)).
- Test released binaries on every supported target platform (Debian 13, CentOS Stream 10, Fedora 44) — at minimum an automated smoke test of the real artifact on each.
- When cgo is required: document the resulting libc requirement in the README, build on the supported platform with the oldest glibc, and test the resulting binary on every supported platform. As of 2026-Q3 that build platform is CentOS Stream 10 (glibc 2.39, the RHEL 10 baseline); [Debian 13 ships glibc 2.41](https://packages.debian.org/trixie/libc6) and [Fedora 44 ships glibc 2.43](https://packages.fedoraproject.org/pkgs/glibc/glibc/). Re-check this ordering whenever the platform set changes instead of assuming any particular distribution is oldest. glibc symbol versioning makes binaries built against older glibc run on newer ones, not the reverse.
- Build with `-trimpath` for releases so binaries do not embed absolute build paths, which removes one machine-specific input from the build.


**You SHOULD:**

- Prefer pure-Go builds with cgo disabled when technically appropriate:
  ```sh
  CGO_ENABLED=0 go build -trimpath ./cmd/example
  ```
  The result depends only on the kernel ABI and runs on any of our targets. It can also run in `FROM scratch` containers, *provided* the image supplies everything else the program needs at runtime — typically CA certificates for TLS verification, timezone data (embeddable via the standard [`time/tzdata`](https://pkg.go.dev/time/tzdata) package) and `/etc/passwd`/`/etc/group` entries when user lookups happen. Note the standard library falls back to pure-Go implementations where it otherwise uses the platform's C libraries (most visibly `net`'s DNS resolution and `os/user` lookups): behavior is well-defined but can differ from glibc behavior on hosts with NSS-based setups (LDAP users, unusual resolver configurations); test on the targets when name or user resolution matters.
- Cross-compile from any development machine; with cgo disabled this needs nothing but environment variables:
  ```sh
  CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o dist/example-linux-amd64 ./cmd/example
  CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -o dist/example-linux-arm64 ./cmd/example
  ```
- Version binaries from build metadata: when building a tagged module checkout, the toolchain stamps the version and VCS revision into the binary (readable via [`runtime/debug.ReadBuildInfo`](https://pkg.go.dev/runtime/debug#ReadBuildInfo) and `go version -m <binary>`; module version stamping since Go 1.24). Add an explicit `-ldflags "-X main.version=..."` only when the build process cannot rely on VCS metadata.
- Verify what a binary requires and contains before shipping: `go version -m dist/example-linux-amd64` shows toolchain, module versions and build settings (including `CGO_ENABLED`), and `go tool govulncheck -mode=binary` scans a built artifact.


**You MAY:**

- Strip debug information for size (`-ldflags "-s -w"`) when binary size genuinely matters. Panic stack traces keep file/line information either way, but debugger and symbol-based tooling support suffers; keep unstripped builds for debugging.


**You MUST NOT:**

- Enable cgo implicitly. `CGO_ENABLED` defaults to `1` on native builds when a C toolchain is present, so a release pipeline that does not set it explicitly can silently produce libc-dependent binaries. Release builds MUST set `CGO_ENABLED` explicitly either way.
- Assume the Go version on the target host matters for running a binary. It does not; the binary embeds its runtime.


**Reasoning:**

- `CGO_ENABLED=0` decouples the binary from the target's libc entirely, which is what makes "build once, run on Debian, CentOS Stream and Fedora" reliable rather than accidental.
- Building cgo binaries against the oldest target glibc and testing everywhere mirrors how glibc compatibility actually works (backwards, not forwards). Which platform that is has to be checked, not assumed: distribution release cadences differ, and an enterprise distribution released earlier can carry an older glibc than a "stable" distribution released later.
- `-trimpath` removes environment-specific paths from binaries and so improves reproducibility. Bit-identical output additionally requires identical toolchain, target, build flags, source state (including VCS metadata that gets stamped into the binary) and — with cgo — an identical C toolchain and libraries; a release pipeline that pins all of these enables supply-chain verification by rebuild.



## Author information<a id="author-information"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust, readable and consistent Go applications, commands and libraries.
