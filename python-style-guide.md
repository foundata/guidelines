# Python style guide

This document defines the style for writing Python applications, libraries and scripts. It aims to produce code that is readable, maintainable, testable and compatible with the supported Python versions.

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [When to use Python](#when-to-use-python)
- [Supported Python versions](#supported-python-versions)
- [Project structure and metadata](#project-structure-and-metadata)
- [Linting, formatting and type checking](#linting-formatting-type-checking)
  - [Recommended `pyproject.toml` configuration](#recommended-pyproject-configuration)
  - [Additional Ruff rule categories](#additional-ruff-rule-categories)
- [File format and executable scripts](#file-format-and-executable-scripts)
- [Formatting and imports](#formatting-and-imports)
- [Naming](#naming)
- [Type annotations](#type-annotations)
- [Docstrings and comments](#docstrings-and-comments)
- [Functions, classes and data structures](#functions-classes-data-structures)
- [Error handling](#error-handling)
- [Logging and command-line output](#logging-and-command-line-output)
- [Paths, files and external commands](#paths-files-external-commands)
- [Testing](#testing)
- [Continuous integration](#continuous-integration)
- [Dependencies and environments](#dependencies-and-environments)
- [Miscellaneous](#miscellaneous)
- [Author information](#author-information)



## When to use Python<a id="when-to-use-python"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Python is a general-purpose programming language with strong support for automation, command-line applications, web services, data processing and system integration. It is often a better choice than shell when a task needs structured data, non-trivial logic, robust error handling or automated tests.


**Python is RECOMMENDED for:**

- Applications and services with non-trivial business logic.
- Automation that parses or produces structured formats such as JSON, XML or YAML.
- Cross-platform tools where a suitable Python runtime can be provided.
- Tools that benefit from type annotations, unit tests and reusable modules.
- Command-line applications that have multiple commands, complex options or persistent state.


**Python is NOT RECOMMENDED for:**

- Tiny wrappers that only invoke one or two commands and are more portable as a POSIX shell script.
- Environments where no suitable Python runtime can be installed or shipped.
- Performance-critical components whose measured requirements cannot be met by Python or appropriate native libraries.


**You SHOULD:**

- Prefer Python over shell once quoting, data structures, error handling or tests become difficult to reason about.
- Keep operating-system integration at clear boundaries so the core logic can be tested without privileged access or a particular host.


**Reasoning:**

- Python provides data structures, exceptions, packaging, type checking and test frameworks that shell does not provide reliably for larger programs.
- Choosing Python still creates a runtime and dependency requirement. That cost should be justified for very small scripts.



## Supported Python versions<a id="supported-python-versions"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use Python 3.12 as the minimum version for new projects.
- Declare the minimum version in [`pyproject.toml`](https://packaging.python.org/en/latest/specifications/pyproject-toml/):
  ```toml
  [project]
  requires-python = ">=3.12"
  ```
- Keep the source compatible with the declared minimum version. Configure formatters, linters and type checkers for the same minimum version.
- Test the minimum version and every newer stable Python version that the project claims to support.
- Use features from the minimum supported version only, unless compatibility is provided explicitly and tested.


**You MAY:**

- Lower the minimum to Python 3.11 when Debian 12 is a dedicated target platform for the project. This exception MUST be documented in the project README and reflected consistently in project metadata, tool configuration and repeatable test commands.
- Require a newer Python version when a project has a concrete technical reason. Document the reason and test that version as the new minimum.


**You MUST NOT:**

- Lower the minimum version merely because an older interpreter happens to be installed on a development system.
- Claim compatibility with a Python version that is not tested in CI or an equivalent repeatable test environment.
- Use the operating system's unversioned `python` command as evidence of the project's supported runtime. Select or provide the required interpreter explicitly on validated target systems.


**Recommended supported-version test matrix:**

```yaml
python-version:
  - "3.12"
  - "3.13"
  - "3.14"
```

Update the matrix as new stable Python versions are adopted. Do not add a version before the project and its dependencies pass on it.


**Reasoning:**

- Python 3.12 is the default baseline for our current target platforms and avoids carrying compatibility code for systems that are outside the normal scope.
- [Debian 12 provides Python 3.11](https://packages.debian.org/bookworm/python3), so supporting it is a deliberate product and maintenance decision rather than the general default.
- `requires-python = ">=3.12"` affects dependency resolution, but metadata alone does not prove compatibility. The supported range is established by repeatable tests.



## Project structure and metadata<a id="project-structure-and-metadata"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use a single [`pyproject.toml`](https://packaging.python.org/en/latest/guides/writing-pyproject-toml/) as the central project, build and tool configuration file.
- Declare runtime dependencies in `[project.dependencies]` and development-only dependencies in `[dependency-groups]` or the package manager's equivalent.
- Declare `[build-system]` for every project distributed as a Python package.
- Keep import package names valid Python identifiers. Use `snake_case` if a distribution name contains dashes.
- Keep tests outside the import package unless they intentionally form part of a distributed library.


**You SHOULD:**

- Use the `src` layout for installable applications and libraries:
  ```text
  project/
  ├── pyproject.toml
  ├── README.md
  ├── src/
  │   └── example_app/
  │       ├── __init__.py
  │       ├── cli.py
  │       └── core.py
  └── tests/
      ├── integration/
      └── unit/
    ```
- Use [`uv_build`](https://docs.astral.sh/uv/concepts/build-backend/) as the build backend for ordinary pure-Python packages:
  ```toml
  [build-system]
  requires = ["uv_build>=0.11.0,<0.12.0"]
  build-backend = "uv_build"
  ```
- Expose installed commands through `[project.scripts]` instead of relying on executable source files:
  ```toml
  [project.scripts]
  example-app = "example_app.cli:main"
  ```
- Keep the command-line or web-framework layer thin. Put reusable business logic in ordinary modules that can be called directly by tests.
- Keep `__init__.py` small and free of expensive imports or application startup side effects.


**You MUST NOT:**

- Modify `sys.path` to make local imports work.
- Rely on the current working directory to locate package data or application resources.
- Put substantial application logic in `__main__.py`, a console-script wrapper or framework callback when it can live in a testable function or class.


**Reasoning:**

- The `src` layout prevents tests from accidentally importing source files from the repository instead of the installed package.
- Central configuration reduces duplicated or contradictory settings.
- `uv` is the project manager and build frontend, while `uv_build` is the build backend. `uv_build` is appropriate for pure-Python packages; projects with native extensions, custom build steps or unsupported layouts need another suitable backend.
- Thin entry points keep framework behavior separate from domain behavior and make tests faster and clearer.



## Linting, formatting and type checking<a id="linting-formatting-type-checking"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use [Ruff](https://docs.astral.sh/ruff/) for formatting, linting and import organization.
- Use a static type checker. [mypy](https://mypy.readthedocs.io/en/stable/) is the default unless a project documents another choice.
- Use one type checker as the project's authoritative source of diagnostics.
- Provide repeatable commands for formatting checks, linting, type checking and tests.
- Fix every diagnostic. A suppression MUST select the narrowest possible rule or error code and include a short explanation when the reason is not obvious.
- Run checks against production code and tests.


**You SHOULD:**

- Use [pytest](https://docs.pytest.org/en/stable/) for tests.
- Pin development tools in the project's lock file so local and automated results are reproducible.
- Let automated tools decide mechanical style. Do not manually reformat code away from Ruff's output.
- Retain an established type checker unless migration provides a concrete benefit.


**You MAY:**

- Use [ty](https://docs.astral.sh/ty/coming-from-mypy-or-pyright/) instead of mypy when the project has evaluated its currently unimplemented checks and documents why the remaining coverage is acceptable.
- Use [Pyright](https://github.com/microsoft/pyright/blob/main/docs/installation.md) instead of mypy when the project documents a concrete benefit that justifies adding its Node.js runtime and toolchain.


**Commands:**

```sh
uv run ruff format --check .
uv run ruff check .
uv run mypy src tests
uv run pytest
```

To apply safe automatic changes locally:

```sh
uv run ruff check --fix .
uv run ruff format .
```

Run lint fixes before formatting because a lint fix can produce code that needs to be formatted. Review automatic fixes before committing them. Some lint fixes can change behavior even when Ruff labels them safe.


**Good examples:**

```python
value = legacy_api()  # type: ignore[no-untyped-call]  # Upstream has no type hints.
```

```python
def command(app: App = framework_dependency()) -> None:  # noqa: B008
    """Run the command with the framework-provided application."""
    # The framework requires this dependency marker in the parameter default.
    ...
```


**Bad examples:**

```python
value = legacy_api()  # type: ignore
```

```python
def command(app: App = framework_dependency()) -> None:  # noqa
    ...
```


**Reasoning:**

- Ruff provides one fast tool for formatting, common correctness checks and the import sorting traditionally handled by `isort`. A separate `isort` invocation is unnecessary and can conflict with the formatter.
- Mypy is mature, runs within the Python development environment and supports plugins for frameworks whose dynamic behavior cannot be described completely by standard annotations.
- Ty integrates naturally with Ruff and uv and is substantially faster, but it does not yet implement every check provided by mypy and Pyright.
- Pyright provides strong inference and [typing-specification conformance](https://github.com/python/typing/blob/main/conformance/results/results.html), but its official command-line distribution requires Node.js. That additional runtime makes it unsuitable as the general default for these Python projects. As of 2026-Q3, the `pyright` package on PyPI is a community-maintained wrapper around the Node.js implementation, not an official Python-native distribution.
- Type annotations without a type checker are documentation that can silently become incorrect.
- Type inference, narrowing behavior, diagnostic codes and framework integrations differ between checkers. Checker-specific suppressions and workarounds therefore become part of the source and can make a later migration more expensive.
- Narrow suppressions remain reviewable and stop unrelated errors from being hidden later.


### Recommended `pyproject.toml` configuration<a id="recommended-pyproject-configuration"></a>

Adapt package names and test paths, but keep the Python target and line length consistent across tools:

```toml
[dependency-groups]
dev = [
  "mypy",
  "pytest>=9.0",
  "pytest-cov",
  "ruff",
]

[tool.ruff]
line-length = 88
target-version = "py312"

[tool.ruff.lint]
select = [
  "E4",  # pycodestyle import errors
  "E7",  # pycodestyle statement errors
  "E9",  # pycodestyle runtime errors
  "F",   # Pyflakes
  "I",   # import sorting
  "B",   # flake8-bugbear
  "C4",  # flake8-comprehensions
  "UP",  # pyupgrade
  "RUF", # Ruff-specific rules
]

[tool.ruff.format]
docstring-code-format = true
indent-style = "space"
line-ending = "lf"
quote-style = "double"
skip-magic-trailing-comma = false

[tool.mypy]
python_version = "3.12"
strict = true
enable_error_code = ["explicit-override"] # Extends strict mode.
warn_unreachable = true                   # Extends strict mode.

[tool.pytest.ini_options]
addopts = [
  "--import-mode=importlib",
]
filterwarnings = ["error"]
strict = true
testpaths = ["tests"]
```

This pytest configuration targets pytest 9 or newer. Its `strict = true` setting includes strict configuration parsing, registered-marker enforcement, unique parametrization IDs and strict expected failures. Because future pytest releases may add further checks to strict mode, projects using it MUST pin pytest through the committed lock file. Projects that remain on pytest 8 MUST configure `xfail_strict = true`, `--strict-config` and `--strict-markers` individually instead.

Do not copy unexplained global ignores from another project. Add exceptions only for behavior the current project actually needs, and prefer per-file ignores for tests or framework-specific code.


### Additional Ruff rule categories<a id="additional-ruff-rule-categories"></a>

The configured `E4`, `E7`, `E9`, `F`, `I`, `B`, `C4`, `UP` and `RUF` categories form the mandatory baseline. They provide focused correctness checks, import sorting and modernization without broadly duplicating Ruff's formatter or mypy.

Projects SHOULD evaluate and enable the following categories when their diagnostics fit the codebase:

- `A`: detects shadowing of built-in names, which this guide prohibits.
- `D`: enforces public docstrings, which this guide requires for production interfaces. Test functions and fixtures are not public APIs and normally do not need docstrings when their names describe their purpose.
- `DTZ`: detects timezone-naive `datetime` usage.
- `G`: detects unsafe or inefficient logging formats.
- `LOG`: detects logging-specific mistakes.
- `N`: enforces PEP 8 naming conventions.
- `PTH`: recommends `pathlib` over legacy path APIs.

When enabling `D`, configure the Google convention explicitly:

```toml
[tool.ruff.lint.pydocstyle]
convention = "google"
```

Ruff treats lexically public test functions, classes and modules as public interfaces. Projects that enable `D` SHOULD ignore that category for the test suite instead of adding docstrings that merely repeat test names:

```toml
[tool.ruff.lint.per-file-ignores]
"tests/**/*.py" = ["D"]
```

The following categories and rules are intentionally not part of the baseline:

- `ANN` duplicates much of the more accurate checking already performed by mypy in strict mode.
- `E501` can reject lines that Ruff's formatter deliberately leaves long because formatting is best-effort around the configured line length.
- `Q` duplicates the formatter's quote handling, and several `Q` rules conflict with the formatter.
- The complete `S` category can be noisy, especially `S101` because pytest uses `assert`. Projects SHOULD evaluate relevant security rules individually and add narrow per-file exceptions for tests where necessary.

Projects MUST NOT enable `ALL` without reviewing and documenting the resulting rule set. Broad prefixes and `ALL` can enable newly added stable rules during a Ruff upgrade; the committed lock file and repeatable checks make such changes reviewable.



## File format and executable scripts<a id="file-format-and-executable-scripts"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use UTF-8 without a byte-order mark (BOM).
- Use Unix line endings (LF, `\n`).
- End files with a single trailing newline.
- Trim trailing whitespace.
- Use four spaces for each indentation level. Do not use tabs for indentation.
- Use `.py` for Python source and `.pyi` only for stub files.


**You SHOULD:**

- Keep importable modules non-executable.
- Use packaging entry points for application commands.
- Use `#!/usr/bin/env python3` only for source files that are intentionally run directly. The deployment MUST still ensure that `python3` resolves to a supported interpreter.


**You MUST NOT:**

- Add an encoding declaration such as `# -*- coding: utf-8 -*-` to ordinary Python 3 source files.
- Use a shebang in library modules that are never executed directly.


**Reasoning:**

- Python 3 source is UTF-8 by default. An encoding declaration adds noise unless a special tool genuinely requires it.
- Console-script entry points select the environment's interpreter and avoid making package modules executable for no reason.



## Formatting and imports<a id="formatting-and-imports"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Follow [PEP 8](https://peps.python.org/pep-0008/) where Ruff does not define the formatting.
- Use Ruff's default line length of 88 characters.
- Use double quotes for strings and triple double quotes (`"""`) for docstrings, as produced by the configured formatter.
- Put imports at the top of a module, after the module docstring and future imports.
- Use absolute imports between top-level packages.


**You SHOULD:**

- Prefer one import per line for imported modules.
- Import names directly only when it improves readability and does not obscure their origin.
- Break expressions with parentheses and trailing commas so Ruff can format them consistently.
- Keep imports free of side effects.


**You MUST NOT:**

- Use wildcard imports (`from module import *`).
- Put several unrelated statements on one line.
- Use backslashes for routine line continuation.
- Align assignments or comments with manual padding that Ruff will not preserve.


**Good examples:**

```python
from pathlib import Path

from example_app.config import AppConfig
from example_app.scanner import Scanner


def create_scanner(config: AppConfig) -> Scanner:
    """Create a scanner from application configuration."""
    return Scanner(
        device=config.device,
        output_directory=Path(config.output_directory),
    )
```


**Bad examples:**

```python
from example_app.config import *
from pathlib import Path; import sys

scanner = Scanner(config.device, \
                  Path(config.output_directory))
```


**Reasoning:**

- An 88-character limit matches Ruff's formatter and avoids a needless conflict between the formatter and a separate style rule.
- Explicit imports make dependencies searchable and prevent unexpected names from entering a module.



## Naming<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Follow PEP 8 naming conventions:
  - `snake_case` for modules, functions, methods, parameters and variables.
  - `PascalCase` for classes and exceptions.
  - `UPPER_SNAKE_CASE` for module-level constants.
- Prefix internal attributes and implementation helpers with one underscore.
- Name exceptions with an `Error` suffix.
- Use descriptive names that reflect purpose, units and meaning.


**You SHOULD:**

- Use plural nouns for collections and singular nouns for individual values.
- Include units where ambiguity is possible, for example `timeout_seconds` or `size_bytes`.
- Name predicates and booleans so they read as conditions, for example `is_searchable`, `has_pages` or `should_overwrite`.
- Use conventional short names such as `i`, `x`, `cls` and `exc` only in their conventional, narrow scope.


**You MUST NOT:**

- Encode types in names, for example `user_dict` or `name_string`, unless the type distinguishes the value's actual role.
- Use a double-leading-underscore name merely to mark an attribute private. Name mangling is for avoiding subclass collisions, not ordinary encapsulation.
- Shadow built-ins such as `list`, `id`, `type`, `input` or `format` without a compelling reason.


**Good examples:**

```python
DEFAULT_TIMEOUT_SECONDS = 30


class ScanError(RuntimeError):
    """Report a scanner operation failure."""


def has_searchable_text(pdf_path: Path) -> bool:
    """Return whether a PDF contains searchable text."""
    ...
```


**Bad examples:**

```python
defaultTimeout = 30


class scan_exception(Exception):
    pass


def checkPDF(filePath):
    ...
```


**Reasoning:**

- Consistent names reduce the amount of project-specific syntax a reader must learn.
- Names should explain domain meaning; the type checker and editor already expose most implementation types.



## Type annotations<a id="type-annotations"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Annotate every function and method parameter and return type, including tests and `__init__` methods. Do not annotate `self` or `cls`.
- Use `-> None` for functions that do not return a value.
- Use the modern built-in generic syntax (`list[str]`, `dict[str, int]`) and union syntax (`str | None`) available in supported Python versions.
- Decorate every method other than `__init__` and `__new__` that overrides a parent implementation with [`@typing.override`](https://docs.python.org/3.12/library/typing.html#typing.override).
- Run the configured type checker and fix its errors.
- Give every `# type: ignore` a specific error code.


**You SHOULD:**

- Let the type checker infer obvious local variable types.
- Prefer standard annotations that remain meaningful across type checkers. Use checker-specific directives, helper types or source-level workarounds only when standard annotations cannot express the required behavior.
- Express behavior with protocols or abstract interfaces when callers need a capability rather than a concrete implementation.
- Use `Any` only at genuinely dynamic boundaries and narrow it to a concrete type as soon as possible.
- Use `TypedDict`, dataclasses or validated models for structured records instead of untyped dictionaries passed across module boundaries.


**You MUST NOT:**

- Repeat type information in a function's docstring.
- Use annotations as a substitute for runtime validation of untrusted input.
- Add `cast()` or `Any` merely to silence a valid type error.


**Good examples:**

```python
from collections.abc import Iterable
from pathlib import Path


def total_size(paths: Iterable[Path]) -> int:
    """Return the combined size of all paths in bytes."""
    return sum(path.stat().st_size for path in paths)


def find_document(name: str) -> Path | None:
    """Return the path of a named document when it exists."""
    ...
```


**Bad examples:**

```python
from typing import Any, Dict, List, Optional


def total_size(paths: List[Path]):
    ...


def find_document(name: Any) -> Optional[Path]:
    ...
```


**Reasoning:**

- A type checker may skip or weaken checking inside unannotated functions. Complete function signatures therefore provide more value than sporadic hints.
- Type hints support static analysis and editor tooling; Python remains dynamic at runtime, so external data still requires validation.



## Docstrings and comments<a id="docstrings-and-comments"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Follow [PEP 257](https://peps.python.org/pep-0257/) and use triple double quotes for docstrings.
- Document every public module, class, function and method with a docstring.
- Use [Google-style docstrings](https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings) when a public docstring needs more than a one-line description.
- Document behavior, side effects, raised exceptions and non-obvious constraints that are part of a public interface.
- Keep comments accurate when changing the related code.


**You SHOULD:**

- Add docstrings to private code when its contract or reasoning is not obvious.
- Start a docstring with a short imperative summary that fits on one line when practical.
- Use comments to explain why a decision or workaround exists, not to narrate what each statement does.
- Include an issue or upstream reference for temporary workarounds.


**You MAY:**

- Omit a docstring from an empty `__init__.py` that exists only to mark a regular package.
- Omit a docstring from an overridden method when it preserves the documented parent contract without adding behavior or constraints.
- Omit docstrings from test functions and fixtures when their descriptive names already communicate their purpose.


**You MUST NOT:**

- Add empty or tautological `Args:`, `Returns:` or `Raises:` sections.
- Repeat parameter and return types already present in annotations.
- Leave commented-out code in the source. Version control already preserves it.


**Good examples:**

```python
def create_pdf(images: list[Path], output_path: Path) -> None:
    """Create a searchable PDF from scanned images.

    Args:
        images: Ordered source images. At least one image is required.
        output_path: Destination that must not already exist.

    Raises:
        ValueError: If `images` is empty.
        FileExistsError: If `output_path` already exists.
    """
```

```python
# SANE reports millimetres as fixed-point values, so preserve Decimal precision.
page_width = Decimal(device_options["br-x"])
```


**Bad examples:**

```python
def create_pdf(images: list[Path], output_path: Path) -> None:
    """Create PDF.

    Args:
        images (list[Path]): The images.
        output_path (Path): The output path.

    Returns:
        None: Nothing.
    """
```


**Reasoning:**

- Public docstrings define contracts that cannot always be expressed through names and types.
- Requiring verbose sections for trivial functions produces boilerplate that is less likely to be maintained. Google style defines structure when detail is useful; it does not require every possible section.



## Functions, classes and data structures<a id="functions-classes-data-structures"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use `None` as the default for optional mutable values and create the value inside the function.
- Use `dataclasses.field(default_factory=...)` for mutable dataclass field defaults.
- Keep module import free of application startup, network access and other surprising side effects.
- Use `if __name__ == "__main__":` when a module intentionally supports direct execution.


**You SHOULD:**

- Keep functions focused on one level of abstraction.
- Prefer explicit return values over mutating arguments.
- Use keyword-only parameters for booleans and for optional arguments whose meaning is unclear at the call site.
- Use dataclasses for data-oriented objects that need named fields and little custom behavior.
- Prefer composition over inheritance unless the relationship is a genuinely substitutable type hierarchy.
- Extract a class only when state and behavior belong together. A module of small functions is often simpler.
- Prefer comprehensions when they remain readable; use an ordinary loop for multiple conditions, side effects or complex transformations.


**You MUST NOT:**

- Use mutable values such as `[]` or `{}` as parameter defaults.
- Use a class solely as a namespace for unrelated static methods.
- Hide control flow or side effects inside a dense comprehension.


**Good examples:**

```python
def add_pages(
    document: Document,
    pages: list[Page] | None = None,
    *,
    run_ocr: bool = True,
) -> Document:
    """Add selected pages to a document."""
    selected_pages = [] if pages is None else list(pages)
    ...
```


**Bad examples:**

```python
def add_pages(document, pages=[], run_ocr=True):
    pages.append(load_cover_page())
    ...
```


**Reasoning:**

- Mutable defaults are created once at function definition time and can leak state between calls.
- Small, explicit interfaces are easier to test and change than implicit mutation or unnecessary class hierarchies.



## Error handling<a id="error-handling"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Raise the most specific appropriate built-in exception, or a project-specific exception that represents a domain failure.
- Catch only exceptions that the current layer can handle, enrich or translate.
- Keep `try` blocks as narrow as practical.
- Preserve the cause when translating an exception by using `raise ... from exc`.
- Include actionable context in error messages without exposing secrets.
- Use context managers for files, locks, temporary resources and other objects that require cleanup.


**You SHOULD:**

- Define a small project exception hierarchy when callers need to distinguish domain failures from programming errors.
- Catch broad exceptions only at process boundaries, such as the outer CLI or job worker, where they can be logged and converted into a controlled failure.
- Allow unexpected exceptions to retain their traceback.
- Use `else` and `finally` when they make the successful path and cleanup clearer.


**You MUST NOT:**

- Use a bare `except:` clause.
- Silently discard an exception with `pass`.
- Catch `Exception` around a large block and continue as if the operation succeeded.
- Use exceptions for ordinary branching when a direct condition is clearer.
- Expose credentials, tokens or complete untrusted payloads in exception messages.


**Good examples:**

```python
class DocumentError(RuntimeError):
    """Base error for document processing failures."""


def load_document(path: Path) -> Document:
    """Load and parse a document from a file."""
    try:
        content = path.read_bytes()
    except OSError as exc:
        raise DocumentError(f"Unable to read document {path}") from exc

    return parse_document(content)
```


**Bad examples:**

```python
def load_document(path):
    try:
        content = open(path, "rb").read()
        return parse_document(content)
    except Exception:
        return None
```


**Reasoning:**

- Specific exceptions make failure behavior part of the interface.
- Narrow handling prevents programming errors from being misreported as expected operational failures.
- Exception chaining retains the original traceback while adding domain context.



## Logging and command-line output<a id="logging-and-command-line-output"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use the standard [`logging`](https://docs.python.org/3/library/logging.html) module for diagnostic messages in applications and reusable modules.
- Create module loggers with `logging.getLogger(__name__)`.
- Configure logging once at the application entry point, not during module import.
- Send machine-readable or requested result data to standard output and diagnostics to standard error.
- Return a non-zero process exit status when a command fails.


**You SHOULD:**

- Use lazy logging arguments instead of formatting the message eagerly.
- Choose levels consistently: `DEBUG` for diagnostic detail, `INFO` for normal progress, `WARNING` for recoverable problems, and `ERROR` for failed operations.
- Keep library code quiet by default.
- Return an integer from `main()` and pass it to `SystemExit`.


**You MUST NOT:**

- Use `print()` for library diagnostics.
- Log the same exception at several layers.
- Log secrets, passwords, access tokens or sensitive document contents.
- Use an f-string in a logging call when lazy arguments work.


**Good examples:**

```python
import logging

LOGGER = logging.getLogger(__name__)


def process_page(page_number: int) -> None:
    """Process one page from the current document."""
    LOGGER.debug("Processing page %d", page_number)


def main() -> int:
    """Run the application."""
    configure_logging()
    process_documents()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

An installed `[project.scripts]` wrapper passes the return value of `main()` to `sys.exit`; `raise SystemExit(main())` provides equivalent behavior when the module is executed directly.


**Bad examples:**

```python
logging.basicConfig(level=logging.DEBUG)


def process_page(page_number):
    print("Processing page", page_number)
    logging.debug(f"Processing page {page_number}")
```


**Reasoning:**

- Libraries do not know how their host application wants to route or format diagnostics.
- Separating result output from diagnostics allows commands to participate in pipelines and gives callers reliable exit-status behavior.



## Paths, files and external commands<a id="paths-files-external-commands"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use [`pathlib.Path`](https://docs.python.org/3/library/pathlib.html) for new path manipulation code.
- Specify an encoding when reading or writing text files. Use `encoding="utf-8"` unless an external format requires another encoding.
- Use context managers when opening files.
- Pass external command arguments as a sequence, not a shell command string.
- Use `check=True` or handle the return code explicitly when command failure is not an expected successful result.
- Set a timeout for external commands that can hang.
- Set explicit connection and operation timeouts for network requests. Do not rely on a client library's default timeout behavior.
- Keep retries bounded by an attempt count or total duration. Retry only operations that are safe to repeat or protected by an idempotency mechanism.


**You SHOULD:**

- Use [`importlib.resources`](https://docs.python.org/3/library/importlib.resources.html) for data shipped inside a package.
- Use [`tempfile`](https://docs.python.org/3/library/tempfile.html) instead of predictable temporary paths.
- Use `shutil` for high-level file operations instead of invoking `cp`, `mv` or `rm`.
- Make destructive file operations explicit and test their failure behavior.
- Write important output through a temporary file followed by an atomic replace when partial files would be harmful.


**You MUST NOT:**

- Build paths by concatenating strings.
- Depend on the current working directory unless it is an explicit part of the command's interface.
- Use `shell=True` unless shell syntax is essential, every interpolated value is controlled, and the reason is documented.
- Use predictable names in a shared temporary directory.


**Good examples:**

```python
import subprocess
from pathlib import Path


def run_ocr(image_path: Path, output_path: Path) -> None:
    """Run OCR for one image."""
    subprocess.run(
        ["tesseract", str(image_path), str(output_path)],
        check=True,
        timeout=300,
    )


def read_config(path: Path) -> str:
    """Read a UTF-8 configuration file."""
    return path.read_text(encoding="utf-8")
```


**Bad examples:**

```python
import os


def run_ocr(image_path, output_path):
    os.system("tesseract " + image_path + " " + output_path)


def read_config(path):
    return open(path).read()
```


**Reasoning:**

- `Path` objects make path operations explicit and portable.
- Argument sequences avoid another layer of shell parsing and command injection.
- Explicit encodings and timeouts turn platform-dependent defaults into visible interface decisions.



## Testing<a id="testing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Add or update automated tests for behavior changes and bug fixes.
- Test public behavior, error conditions and important edge cases.
- Keep tests isolated and repeatable. Tests MUST NOT depend on execution order, local user configuration, wall-clock timing or an external service unless they are explicitly marked as integration tests.
- Use temporary directories and files provided by the test framework.
- Ensure test fixtures in the repository are not modified by tests.
- Run the test suite successfully on every supported Python version before a release.
- Treat warnings as errors. Add narrow filters for understood third-party warnings that cannot yet be fixed.
- Configure pytest expected failures as strict so an unexpectedly passing `xfail` test fails the suite.
- For every project distributed as a Python package, build its wheel and source distribution before a release, install the wheel into a clean environment, and run an import smoke test against the installed artifact. Also run a command-line smoke test when the project exposes an installed command.


**You SHOULD:**

- Use descriptive test names that state the condition and expected behavior.
- Follow Arrange, Act, Assert structure when it improves readability.
- Test through public interfaces instead of private implementation details.
- Add a regression test before or together with a bug fix.
- Separate fast unit tests from tests that need scanners, databases, networks, subprocesses or other external resources.
- Measure coverage to find untested behavior, but do not treat a percentage as a substitute for meaningful assertions.
- Use fakes at project boundaries and avoid mocking ordinary internal calls.
- Keep fixtures small, explicit and close to the tests that use them. Put a fixture in a shared `conftest.py` only when it represents genuinely shared setup.
- Avoid autouse fixtures unless the behavior must apply invisibly to every test in their scope.
- Configure pytest to reject unknown configuration options and unregistered markers. Register every project-specific marker.
- Use pytest's `importlib` import mode for new projects with a `src` layout. Existing projects SHOULD run the complete suite with `--import-mode=importlib` and enable it unless the suite intentionally depends on another import mode.
- Enable pytest's global `strict = true` mode when using pytest 9 or newer with a committed lock file.


**You MUST NOT:**

- Add arbitrary sleeps to make asynchronous tests pass.
- Make tests pass by weakening or removing meaningful assertions.
- Catch unexpected exceptions in a test without asserting their type and relevant message or attributes.
- Require developers to have access to production credentials or hardware for the default unit-test suite.


**Reasoning:**

- Warnings often announce deprecated or ambiguous behavior before it becomes a failure. Treating them as errors prevents warning debt; narrow filters keep unavoidable third-party warnings visible and documented.
- Strict expected failures make an unexpectedly passing `xfail` fail the suite so obsolete workarounds and tests are reviewed instead of remaining silently disabled.
- Strict configuration catches misspelled or removed options, while strict markers catch marker typos that could otherwise select or skip the wrong tests.
- Pytest's `importlib` mode loads tests without adding their directories to `sys.path`. This complements the `src` layout by exposing accidental dependencies on the repository layout, although an existing suite may first need test-to-test imports or informal helper modules refactored.
- Pytest 9 strict mode combines strict configuration, markers, parametrization IDs and expected failures. A committed lock file makes newly added strictness in a future pytest release an explicit dependency update rather than an unreviewed change.


**Good examples:**

```python
from pathlib import Path

import pytest


def test_create_pdf_rejects_empty_image_list(tmp_path: Path) -> None:
    output_path = tmp_path / "document.pdf"

    with pytest.raises(ValueError, match="at least one image"):
        create_pdf([], output_path)

    assert not output_path.exists()
```


**Bad examples:**

```python
def test_pdf():
    try:
        create_pdf([], Path("/tmp/test.pdf"))
    except Exception:
        pass
```


**Reasoning:**

- Tests are executable compatibility and behavior claims.
- Isolated tests fail for changes in the code, not because of unrelated machine or network state.
- Coverage can reveal gaps but cannot determine whether the assertions describe the right behavior.
- Strict warnings and expected failures expose deprecations and stale assumptions instead of allowing them to accumulate silently.
- Testing the built artifact catches missing package data, invalid entry points and packaging mistakes that source-tree tests cannot detect.



## Continuous integration<a id="continuous-integration"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Keep every required formatting, linting, type-checking, testing and package-validation command executable locally without a CI service.
- Run all required checks successfully before a release.
- Test every supported Python version successfully before a release.
- When a project uses CI, run the required checks automatically for relevant changes.


**You SHOULD:**

- Automate the required checks with CI when the project's size, release frequency or number of contributors justifies the infrastructure.
- Prefer a self-hostable CI system or one that is independent of a particular repository hosting provider.


**You SHOULD NOT:**

- Depend on GitHub Actions or another proprietary forge-specific CI service. Provider-specific workflows MUST NOT be the only implementation of build, test or release logic.


**Reasoning:**

- Small or experimental projects can perform the same repeatable validation locally without maintaining CI infrastructure.
- CI provides automatic and visible verification, but it does not define the commands or quality requirements.
- Provider-independent commands keep development and releases possible when a project moves to another repository host or CI system.
- Continuous delivery and deployment are separate decisions and are not required by this guide.



## Dependencies and environments<a id="dependencies-and-environments"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Develop and run project-installed tools in a virtual environment or another isolated environment.
- Declare every direct runtime dependency in `pyproject.toml`.
- Commit the lock file for applications and services when the selected package manager provides one.
- Review dependency changes and run the full test suite after updating them.
- Set lower bounds based on features actually required by the project.
- Add an upper bound only for a known incompatibility, and document or link the reason.


**You SHOULD:**

- Use [`uv`](https://docs.astral.sh/uv/) to manage environments, dependencies and lock files unless a project has an established alternative.
- Prefer the standard library when it provides a clear and robust solution, but do not reimplement mature specialist functionality merely to avoid a dependency.
- Keep runtime dependencies separate from test, lint and documentation tools.
- Update dependencies regularly in small, reviewable changes.
- Use `python -m pip` rather than an ambiguous `pip` executable when working in a project that does not use `uv`.


**You MUST NOT:**

- Install project dependencies into the operating system's Python environment with `sudo pip`.
- Import a package that is available only transitively through another direct dependency. Declare it directly.
- Pin every runtime dependency to an exact version in published library metadata.
- Add broad upper bounds speculatively.
- Commit `.venv`, caches, build output or credentials.


**Reasoning:**

- Isolated environments avoid conflicts with operating-system packages and other projects.
- Applications benefit from reproducible complete environments; reusable libraries need compatible dependency ranges so they can coexist with their callers.
- Unnecessary upper bounds prevent security and compatibility updates and create avoidable resolver conflicts.



## Miscellaneous<a id="miscellaneous"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Use timezone-aware `datetime` values for real timestamps.
- Use [`secrets`](https://docs.python.org/3/library/secrets.html), not `random`, for passwords, tokens and other security-sensitive values.
- Validate untrusted input at the boundary before using it in file paths, queries, templates or external commands.
- Keep secrets out of source code, logs, fixtures and exception messages.


**You SHOULD:**

- Prefer explicit dependency injection over mutable module-level global state.
- Use `enum.Enum` or `enum.StrEnum` for a closed set of meaningful values.
- Use `collections.abc` for abstract parameter types such as `Iterable` or `Sequence`.
- Prefer `is None` and `is not None` when checking for `None`.
- Prefer early returns to deeply nested control flow.
- Keep public interfaces small and avoid exposing internal representation without need.


**You MUST NOT:**

- Use `eval()` or `exec()` with untrusted input.
- Deserialize untrusted data with unsafe object-loading formats or APIs such as `pickle`, `marshal` or an unsafe YAML loader. Use a data-only format and validate the decoded structure instead.
- Use `assert` to validate user input or enforce runtime conditions required for correct operation. Assertions can be disabled.
- Compare booleans with `== True` or `== False`.
- Use `datetime.now()` without a timezone for timestamps that leave the process or are compared across systems.


**Good examples:**

```python
import secrets
from datetime import UTC, datetime

created_at = datetime.now(UTC)
token = secrets.token_urlsafe(32)

if document is None:
    raise DocumentError("Document was not found")
```


**Bad examples:**

```python
from datetime import datetime
import random

created_at = datetime.now()
token = str(random.random())

assert document is not None
```


**Reasoning:**

- Timezone-aware values prevent ambiguous timestamps.
- Security-sensitive randomness and validation have different requirements from simulations, tests and internal invariants.
- Explicit boundaries and small interfaces make behavior easier to test and reason about.



## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust, readable and consistent Python applications, libraries and scripts. It draws on the following primary standards and documentation:

- [Python Enhancement Proposal 8: Style Guide for Python Code](https://peps.python.org/pep-0008/)
- [Python Enhancement Proposal 257: Docstring Conventions](https://peps.python.org/pep-0257/)
- [Python typing documentation](https://typing.python.org/)
- [Python Packaging User Guide](https://packaging.python.org/)
- [Ruff documentation](https://docs.astral.sh/ruff/)
- [mypy documentation](https://mypy.readthedocs.io/en/stable/)
- [pytest documentation](https://docs.pytest.org/en/stable/)
