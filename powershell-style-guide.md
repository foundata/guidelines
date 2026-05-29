# PowerShell style guide

This document defines the style for writing PowerShell scripts and modules. It aims to produce scripts that are compatible with Windows PowerShell 5.1 and PowerShell 7+, while being readable, maintainable, and suitable for automation.

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [When to use PowerShell](#when-to-use-powershell)
- [File format](#file-format)
- [Script header and requirements](#script-header-and-requirements)
- [Indentation and line length](#indentation-and-line-length)
- [Naming](#naming)
- [Quoting and strings](#quoting-and-strings)
- [Variables and parameters](#variables-and-parameters)
- [Attributes and hashtables](#attributes-and-hashtables)
- [Pipeline usage](#pipeline-usage)
- [Output streams](#output-streams)
- [Functions](#functions)
- [Error handling](#error-handling)
- [Paths and files](#paths-and-files)
- [External commands](#external-commands)
- [Comments and help](#comments-and-help)
- [Miscellaneous](#miscellaneous)
- [Linting and automatic formatting](#linting-and-automatic-formatting)
- [Appendix: PowerShell edition requirements](#appendix-powershell-edition-requirements)
- [Appendix: suggested PSScriptAnalyzer settings](#appendix-suggested-psscriptanalyzer-settings)
- [Author information](#author-information)



## When to use PowerShell<a id="when-to-use-powershell"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

PowerShell is a task automation and configuration language with strong integration into Windows, .NET, and many Microsoft administration interfaces. It is especially useful when scripts should return structured objects instead of plain text.


**PowerShell is RECOMMENDED for:**

- Windows administration tasks.
- Scripts that manage services, registry keys, certificates, scheduled tasks, event logs, Active Directory, Microsoft 365, Azure, Hyper-V, or Windows features.
- Scripts that should return structured objects to other PowerShell commands.
- Cross-platform administration scripts when PowerShell 7+ is available on all target systems and Ansible is not an option.
- Reusable automation modules with functions, parameters, help, and tests.


**PowerShell is NOT RECOMMENDED for:**

- Tasks that must run on systems without PowerShell installed, especially Unix-like (Powershell core is widely available but still very uncommon on server systems)
- Very small Unix-style wrapper scripts where POSIX shell is simpler and more portable.
- Complex application logic that is better implemented in a general-purpose programming language.
- Performance-critical data processing where compiled tools or specialized runtimes are more appropriate.


**You SHOULD:**

- Prefer PowerShell when object pipelines, Windows APIs, .NET APIs, or Microsoft modules are central to the task.
- Keep scripts focused. If a script grows into a reusable tool, move logic into functions or a module.
- Separate reusable functions from one-off execution logic.
- Prefer returning structured objects over parsing and printing formatted text.


**Reasoning:**

- PowerShell's main advantage is object-based automation.
- Scripts that return objects are easier to filter, sort, export, test, and compose with other commands. For simple command orchestration on Unix-like systems, POSIX shell may still be the better default.


## File format<a id="file-format"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use [UTF-8](https://en.wikipedia.org/wiki/UTF-8) with [byte-order mark (BOM)](https://en.wikipedia.org/wiki/Byte_order_mark) for PowerShell files.
- Use Windows line endings (`CRLF`, `\r\n`) for PowerShell files.
- End files with a single trailing newline.
- Trim trailing whitespace.
- Use `.ps1` for scripts, `.psm1` for script modules, and `.psd1` for module manifests or data files.


**Reasoning:**

- UTF-8 with BOM and CRLF are chosen for compatibility with Windows PowerShell 5.1 and Windows-focused tooling. This intentionally differs from POSIX shell scripts, where BOM and CRLF can break shebang handling or shell parsing.



## Script header and requirements<a id="script-header-and-requirements"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use the following default script header:
  ```powershell
  #Requires -Version 5.1
  Set-StrictMode -Version Latest
  ```


**You SHOULD:**

- Add additional `#Requires` statements only when the dependency is a hard runtime requirement.
- Add a file-level comment explaining the script's purpose after the requirements and strict-mode declaration.


**You MUST NOT:**

- Add `#Requires -PSEdition Desktop` or `#Requires -PSEdition Core` to scripts that should support both Windows PowerShell 5.1 and PowerShell 7+.


**Good examples:**

```powershell
#Requires -Version 5.1
Set-StrictMode -Version Latest

# Install and configure the example service.
```


**Bad examples:**

```powershell
# Missing explicit requirement and strict mode
Write-Information -MessageData 'Starting installation.'
```

```powershell
#Requires -Version 5.1
#Requires -PSEdition Desktop
Set-StrictMode -Version Latest

# Bad for scripts that should also run on PowerShell 7+.
```


**Reasoning:**

- [`#Requires`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires) prevents a script from running unless its declared prerequisites are met. `#Requires -Version 5.1` means version 5.1 or later, so it allows Windows PowerShell 5.1 and PowerShell 7+. See [Appendix: PowerShell edition requirements](#appendix-powershell-edition-requirements) for when to intentionally restrict a script to one PowerShell edition.
- [`Set-StrictMode`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode) catches many common scripting mistakes, such as references to uninitialized variables and invalid property references.



## Indentation and line length<a id="indentation-and-line-length"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use 4 spaces for each indentation level.
- Do not use tabs for indentation.
- Use consistent indentation throughout a file.
- Keep lines below 120 characters whenever technically possible.


**You SHOULD:**

- Use the ecosystem formatter style provided by `PSScriptAnalyzer`.
- Place opening braces on the same line for functions, control statements, and script blocks.
- Prefer multi-line commands, hashtables, and splatting over very long command lines.
- Break pipelines in the usual PowerShell style when they become long:
  ```powershell
  Get-ChildItem -LiteralPath $DataPath -File |
      Where-Object {
          $_.Length -gt 0
      } |
      Sort-Object -Property LastWriteTime
  ```


**You MUST NOT:**

- Use backticks for routine line continuation.


**Good examples:**

```powershell
if ($service.Status -ne 'Running') {
    Start-Service -Name $service.Name
}

$copyItemParameters = @{
    LiteralPath = $SourcePath
    Destination = $DestinationPath
    Recurse     = $true
    Force       = $true
}

Copy-Item @copyItemParameters
```


**Bad examples:**

```powershell
if ($service.Status -ne 'Running')
{
  Start-Service -Name $service.Name
}

Get-ChildItem -LiteralPath $DataPath -File `
    | Where-Object { $_.Length -gt 0 } `
    | Sort-Object -Property LastWriteTime
```


**Reasoning:**

- The default PSScriptAnalyzer code-formatting profile uses 4-space indentation and same-line opening braces.
- Backtick continuations are fragile because invisible whitespace after the backtick changes parsing. Many PowerShell constructs allow natural line breaks without backticks.



## Naming<a id="naming"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use approved verbs for exported functions and cmdlets.
- Use `Verb-Noun` names for exported functions.
- Use singular nouns in function names.
- Use a visual distinction between public API and local implementation details:
  - `Get-ExampleItem` for functions.
  - PascalCase for function names, parameter names, classes, enum names, and public members: `$ComputerName`
  - camelCase for local variables: `$computerName`
- Use descriptive names and avoid unclear abbreviations.


**You SHOULD:**

- Use module-specific noun prefixes when needed to avoid command-name collisions.
- Use `$script:` scope only when script/module-level state is intentionally shared.


**You MUST NOT:**

- Use aliases or abbreviated command names in scripts.
- Use `snake_case` for PowerShell variables unless required by an external interface.
- Use global variables for normal script state.


**Good examples:**

```powershell
function Get-ExampleItem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $ComputerName
    )

    $normalizedComputerName = $ComputerName.Trim().ToLowerInvariant()

    [pscustomobject]@{
        ComputerName = $normalizedComputerName
    }
}
```


**Bad examples:**

```powershell
function fetch_items {
    param ($computer_name)

    $strComputerName = $computer_name
    gci C:\
}
```


**Reasoning:**

- Microsoft's public PowerShell guidance strongly encourages approved verbs, singular nouns, and PascalCase-style cmdlet and parameter names.
- Community PowerShell style commonly distinguishes PascalCase public API from camelCase local variables.
- PSScriptAnalyzer includes rules such as `PSUseApprovedVerbs`, `PSUseSingularNouns`, `PSAvoidUsingCmdletAliases`, and `PSUseCorrectCasing`.
- PSScriptAnalyzer's [`PSUseCorrectCasing`](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/usecorrectcasing) rule checks command, parameter, keyword, and operator casing, but not local variable naming.



## Quoting and strings<a id="quoting-and-strings"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use single quotes for literal strings.
- Use double quotes only when variable or expression expansion is needed.
- Use braced variable names inside expandable strings: `${DataPath}` instead of `$DataPath`.
- Use `$()` for expressions inside expandable strings.


**You SHOULD:**

- Prefer format strings for complex string composition.
- Prefer local variables over complex expressions inside expandable strings.
- Quote literal string arguments for consistency.
- Avoid escaping-heavy strings by using the quote style that needs fewer escapes.


**You SHOULD NOT:**

- Quote simple variable arguments merely to protect spaces.
- Build paths with string concatenation when `Join-Path` is suitable.


**Good examples:**

```powershell
$serviceName = 'WinRM'
$logFile = Join-Path -Path $DataPath -ChildPath 'install.log'
$message = "Processing ${ComputerName}: ${logFile}"

'Processing {0} ({1} items).' -f $ComputerName, $itemCount

Get-ChildItem -LiteralPath $DataPath
```


**Bad examples:**

```powershell
$serviceName = "WinRM"
$logFile = "${DataPath}\install.log"
$message = "$ComputerName: starting"
Get-ChildItem -LiteralPath "${DataPath}"
```


**Reasoning:**

- PowerShell expands variables in double-quoted strings and treats single-quoted strings as literal strings.
- The [`about_Quoting_Rules`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_quoting_rules) documentation explicitly recommends braces to separate variable names from following characters, especially before a colon because PowerShell can interpret text between `$` and `:` as a scope specifier.
- Unlike POSIX shell, PowerShell does not split a simple variable argument on spaces, so quoting variables only for word-splitting protection is unnecessary.



## Variables and parameters<a id="variables-and-parameters"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use explicit parameter blocks for scripts and functions that accept input.
- Type parameters when a meaningful type is known.
- Use named parameters when calling commands.
- Use `$null` on the left side of comparisons to avoid accidental collection filtering behavior.
- Use `$true` and `$false` boolean values, not strings.


**You SHOULD:**

- Use validation attributes for user-facing parameters.
- Use `[switch]` for boolean command-line switches.
- Use `[string[]]` or another array type when a parameter accepts multiple values.
- Use `$PSBoundParameters` when forwarding explicitly provided parameters to another command.


**You MUST NOT:**

- Depend on undeclared parameters via `$args` in normal scripts or functions.
- Use positional parameters in scripts.
- Compare `$null` on the right side.
- Store secrets in plain string variables when a `PSCredential` or secure secret mechanism is appropriate.


**Good examples:**

```powershell
param (
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $ComputerName,

    [switch] $Force
)

if ($null -eq $ComputerName) {
    throw 'ComputerName is missing.'
}
```


**Bad examples:**

```powershell
param ($computerName, $force)

if ($computerName -eq $null) {
    throw 'computerName is missing.'
}
```


**Reasoning:**

- Typed and validated parameters make scripts self-documenting and catch invalid inputs early. Named parameters are easier to read and are checked by PSScriptAnalyzer's `PSAvoidUsingPositionalParameters` rule.
- In PowerShell, comparisons can behave unexpectedly when the left-hand side is a collection. Placing `$null` on the left side avoids accidental collection-filtering behavior and is checked by `PSPossibleIncorrectComparisonWithNull`.


## Attributes and hashtables<a id="attributes-and-hashtables"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

- Use multi-line attributes when an attribute has multiple arguments or contains long values.
- Keep short, argument-less attributes on a single line.
- Use multi-line hashtables when a hashtable has more than one key, contains long values, or is part of an array/list.
- Put one key-value pair per line in multi-line hashtables.
- Use unquoted hashtable keys when the key is a simple identifier.
- Use quoted hashtable keys only when the key contains spaces, punctuation, or characters that require quoting.
- Avoid semicolons as line terminators; put each statement or hashtable entry on its own line.

**Good examples:**

```powershell
param (
    [Parameter(
        Mandatory = $true,
        HelpMessage = 'Version to install.'
    )]
    [ValidateNotNullOrEmpty()]
    [string] $Version
)

$registryValues = @(
    @{
        Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{618A8F33-C045-400A-A0C5-CFE7793EDE16}'
        Name = 'DisplayVersion'
    }
    @{
        Path = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{618A8F33-C045-400A-A0C5-CFE7793EDE16}'
        Name = 'DisplayVersion'
    }
)
```

**Bad examples:**

```powershell
param (
    [Parameter(Mandatory = $true,
        HelpMessage = 'Version to install.')]
    [ValidateNotNullOrEmpty()]
    [string] $Version
)

$registryValues = @(
    @{ 'Path' = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{618A8F33-C045-400A-A0C5-CFE7793EDE16}'; 'Name' = 'DisplayVersion' };
    @{ 'Path' = 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{618A8F33-C045-400A-A0C5-CFE7793EDE16}'; 'Name' = 'DisplayVersion' };
)
```

**Reasoning:**

- Multi-line attributes keep parameter declarations readable when attributes contain several named arguments or long help messages.
- Multi-line hashtables produce cleaner diffs and are easier to extend than compact inline hashtables.


## Pipeline usage<a id="pipeline-usage"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use full command names in scripts, not aliases.
- Avoid mixing `$_` and `$PSItem` within the same script block.
- Keep pipeline script blocks short and readable.


**You SHOULD:**

- Use `$_` for concise and idiomatic pipeline script blocks.
- Use `$PSItem` or a meaningful local variable when it improves readability in longer script blocks.
- Prefer `foreach` statements for already-materialized in-memory collections.
- Use `ForEach-Object` when streaming objects from another command is useful.


**Good examples:**

```powershell
Get-Service | Where-Object {
    $_.Status -eq 'Running'
}
```

```powershell
Get-ChildItem -LiteralPath $DataPath -File | ForEach-Object {
    $file = $_
    $fileAge = (Get-Date) - $file.LastWriteTime

    if ($fileAge.TotalDays -gt 30) {
        Remove-Item -LiteralPath $file.FullName -WhatIf
    }
}
```

```powershell
foreach ($file in $files) {
    Remove-Item -LiteralPath $file.FullName
}
```


**Bad examples:**

```powershell
Get-ChildItem $DataPath | ? { $_.Length -gt 0 } | % { Write-Host $_.Name }
```

```powershell
Get-ChildItem -LiteralPath $DataPath -File | ForEach-Object {
    if ($_.Length -gt 0 -and $PSItem.LastWriteTime -gt $cutoffDate) {
        $_.FullName
    }
}
```


**Reasoning:**

- Microsoft's [`about_PSItem`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_psitem) documentation says that `$_` and `$PSItem` refer to the current pipeline object, but also states that `$_` is the preferred usage in practice. Use `$PSItem` or a local variable only when it improves readability.



## Output streams<a id="output-streams"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Return data as structured objects whenever possible.
- Use implicit output for normal function output.
- Use `Write-Verbose`, `Write-Debug`, `Write-Information`, `Write-Warning`, and `Write-Error` for non-data messages.
- Keep data output separate from host/UI output.


**You SHOULD:**

- Use `[pscustomobject]` for structured script output.
- Use `Write-Output` only when its pipeline enumeration behavior is intentional.
- Use `Write-Output -NoEnumerate` when an array must be returned as one object.
- Use `return` mainly for early exits, not for normal data output.


**You MUST NOT:**

- Use `Write-Host` for return values, logging, diagnostics, errors, or status messages.
- Use `Format-Table`, `Format-List`, or other `Format-*` commands before the final display step.


**You MAY:**

- Use `Write-Host` for intentional interactive console UI, such as banners, menus, prompts, or colorized display output.
- Suppress `PSAvoidUsingWriteHost` locally when `Write-Host` is intentional and documented.


**Good examples:**

```powershell
[pscustomobject]@{
    Name      = $Name
    Path      = $Path
    Compliant = $true
}
```

```powershell
Write-Verbose -Message 'Querying service state.'
Write-Warning -Message 'Service is not running.'
```

```powershell
Write-Output -InputObject $items -NoEnumerate
```


**Bad examples:**

```powershell
Write-Host "Name=${Name}; Path=${Path}; Compliant=True"
```

```powershell
Get-Service |
    Format-Table -AutoSize |
    Where-Object {
        $_.Status -eq 'Running'
    }
```


**Reasoning:**

The [`PSAvoidUsingWriteHost`](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/rules/avoidusingwritehost) rule explains that `Write-Host` produces display-only host output and does not send data to the pipeline. The rule recommends `Write-Output` or implicit output for pipeline data. The [`about_Return`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_return) documentation shows `Write-Output -NoEnumerate` as a way to return a collection as a single pipeline object.



## Functions<a id="functions"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `Verb-Noun` names for exported functions.
- Use approved verbs for exported functions.
- Use a `param` block for functions that accept input.
- Put `[CmdletBinding()]` before the `param` block for non-trivial reusable functions.
- Return structured objects for machine-readable data.


**You SHOULD:**

- Use `SupportsShouldProcess` for functions that create, modify, delete, restart, install, or otherwise change a system's state.
- Keep functions focused on one task.
- Avoid deeply nested logic by extracting helper functions.
- Put helper functions above the code that calls them.


**Good examples:**

```powershell
function Remove-ExampleFile {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $LiteralPath
    )

    if ($PSCmdlet.ShouldProcess($LiteralPath, 'Remove file')) {
        Remove-Item -LiteralPath $LiteralPath
    }
}
```


**Bad examples:**

```powershell
function DeleteFile($path) {
    Remove-Item $path -Force
}
```


**Reasoning:**

Advanced functions behave more like cmdlets and support common parameters such as `-Verbose`, `-Debug`, and `-ErrorAction`. `SupportsShouldProcess` enables `-WhatIf` and `-Confirm`, which are important safety features for administrative scripts.



## Error handling<a id="error-handling"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `throw` for unrecoverable terminating failures.
- Use `try` / `catch` when an error should be handled or transformed.
- Use `-ErrorAction Stop` on cmdlets whose non-terminating errors must be caught.
- Avoid empty `catch` blocks.
- Write meaningful error messages.


**You SHOULD:**

- Prefer local `-ErrorAction Stop` over broad global preference changes.
- Use `$ErrorActionPreference = 'Stop'` only in short, self-contained scripts where that behavior is intentional.
- Copy `$_` / `$PSItem` from `catch` to a named variable if it is used in more than a short expression.
- Preserve useful exception context when re-throwing.


**You MUST NOT:**

- Use `$?` as the primary error-handling mechanism for cmdlets.
- Ignore errors silently.
- Use flags or string parsing when exceptions or error records are available.


**Good examples:**

```powershell
try {
    $configItem = Get-Item -LiteralPath $ConfigPath -ErrorAction Stop
} catch {
    $errorRecord = $_
    throw "Configuration file not found: ${ConfigPath}. $($errorRecord.Exception.Message)"
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Configuration file does not exist: ${ConfigPath}"
}
```


**Bad examples:**

```powershell
Get-Item -Path $ConfigPath

if (-not $?) {
    Write-Host 'Failed'
}

try {
    Remove-Item -LiteralPath $Path
} catch {
}
```


**Reasoning:**

Many PowerShell cmdlets emit non-terminating errors by default. `try` / `catch` catches terminating errors, so `-ErrorAction Stop` is required when a cmdlet error must be caught. Microsoft's PSScriptAnalyzer recommendations include using `-ErrorAction Stop` when calling cmdlets and avoiding `$?` as a primary error handling mechanism.



## Paths and files<a id="paths-and-files"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `-LiteralPath` when a path comes from a variable, configuration file, user input, or another command and should be interpreted literally.
- Use `-Path` when wildcard expansion is intentional.
- Use `$PSScriptRoot` for script-relative paths.
- Preserve the required encoding and line endings when writing PowerShell files.


**You SHOULD:**

- Prefer `Join-Path` over path string concatenation.
- Use `New-Item -ItemType Directory -Force` for idempotent directory creation.
- Avoid redundant `Test-Path` checks when the operation can be made idempotent directly.


**Good examples:**

```powershell
$configPath = Join-Path -Path $PSScriptRoot -ChildPath 'config.json'
$logPath = Join-Path -Path $DataPath -ChildPath 'install.log'

Get-ChildItem -LiteralPath $DataPath -File
New-Item -ItemType Directory -Path $DataPath -Force
```

```powershell
Get-ChildItem -Path '*.log'
```


**Bad examples:**

```powershell
$configPath = '.\config.json'
$logPath = "${DataPath}\install.log"
Get-ChildItem -Path $DataPath
```


**Reasoning:**

- `$PSScriptRoot` contains the full path of the executing script's parent directory. The [`about_Automatic_Variables`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_automatic_variables) documentation notes that it is valid in scripts beginning with PowerShell 3.0.
- `-LiteralPath` avoids accidental wildcard interpretation in paths containing characters such as `[` or `*`.



## External commands<a id="external-commands"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use PowerShell cmdlets or .NET APIs instead of external commands when they provide the required behavior clearly and reliably.
- Use the call operator (`&`) when invoking a native executable through a path variable.
- Pass dynamic native command arguments as arrays.
- Avoid `Invoke-Expression`.


**You SHOULD:**

- Keep native command invocation small and explicit.
- Check native command exit codes when they matter.
- Document why an external command is needed if a PowerShell-native alternative exists.


**Good examples:**

```powershell
$arguments = @(
    '--config'
    $ConfigPath
    '--verbose'
)

& $ExecutablePath @arguments

if ($LASTEXITCODE -ne 0) {
    throw "External command failed with exit code ${LASTEXITCODE}."
}
```


**Bad examples:**

```powershell
Invoke-Expression "${ExecutablePath} --config ${ConfigPath} --verbose"
```


**Reasoning:**

- `Invoke-Expression` parses and executes a string as PowerShell code, which is usually unnecessary and can be dangerous when data is mixed with code.
- Argument arrays and the call operator avoid fragile quoting and command-injection style problems.



## Comments and help<a id="comments-and-help"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Start non-trivial scripts with a short description of their purpose.
- Write comments and help text in US English.
- Document exported functions with comment-based help.
- Add a reasoning comment when suppressing a linter rule.


**You SHOULD:**

- Use comments to explain why the code does something, not what each line does.
- Add examples to comment-based help for user-facing commands.
- Keep comment lines reasonably short.
- Keep help text close to the function it documents.


**Good examples:**

```powershell
function Get-ExampleItem {
    <#
    .SYNOPSIS
    Returns example items from the configured data source.

    .DESCRIPTION
    Queries the configured data source and returns structured objects for downstream processing.

    .PARAMETER Name
    Name of the item to retrieve.

    .EXAMPLE
    Get-ExampleItem -Name 'demo'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    [pscustomobject]@{
        Name = $Name
    }
}
```


**Bad examples:**

```powershell
function Get-ExampleItem {
    # Set the name variable to name.
    param ($name)

    $name
}
```


**Reasoning:**

- Comment-based help makes functions discoverable through `Get-Help` and supports a consistent user experience.
- `PSScriptAnalyzer` includes `PSProvideCommentHelp` for checking help on functions and scripts.



## Miscellaneous<a id="miscellaneous"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Avoid global state. Prefer parameters, local variables, return objects, and explicit function arguments.
- Avoid changing global preference variables in modules and reusable functions.
- Do not store credentials or API tokens as plain strings in scripts. Prefer `PSCredential`, SecretManagement, environment-provided secrets, or platform-appropriate secret stores.
- Do not use `Clear-Host` in scripts. It hides useful diagnostic information from users and logs.
- Do not use `Pause` or prompt for input in automation code unless the script is explicitly interactive.
- Prefer explicit idempotent operations over pre-check / action patterns when the cmdlet already supports idempotency.



## Linting and automatic formatting<a id="linting-and-automatic-formatting"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

PowerShell code MUST be linted with [`PSScriptAnalyzer`](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview). Formatting SHOULD be performed with `Invoke-Formatter`, which is provided by the same module.

`PSScriptAnalyzer` is not built into PowerShell. It must be installed separately before `Invoke-ScriptAnalyzer` and `Invoke-Formatter` are available.

**You MUST:**

- Lint all PowerShell files with following command (or a script doing the same):
  ```powershell
  if (-not (Get-Module -ListAvailable -Name 'PSScriptAnalyzer')) {
      throw 'PSScriptAnalyzer is required. Install it with: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser'
  }

  Import-Module -Name 'PSScriptAnalyzer'

  $formatterSettings = @{
      IncludeRules = @(
          'PSPlaceOpenBrace'
          'PSPlaceCloseBrace'
          'PSUseConsistentWhitespace'
          'PSUseConsistentIndentation'
          'PSAlignAssignmentStatement'
          'PSUseCorrectCasing'
      )

      Rules = @{
          PSPlaceOpenBrace = @{
              Enable             = $true
              OnSameLine         = $true
              NewLineAfter       = $true
              IgnoreOneLineBlock = $true
          }

          PSPlaceCloseBrace = @{
              Enable             = $true
              NewLineAfter       = $true
              IgnoreOneLineBlock = $true
              NoEmptyLineBefore  = $true
          }

          PSUseConsistentIndentation = @{
              Enable              = $true
              Kind                = 'space'
              IndentationSize     = 4
              PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
          }

          PSUseConsistentWhitespace = @{
              Enable                                  = $true
              CheckInnerBrace                         = $true
              CheckOpenBrace                          = $true
              CheckOpenParen                          = $true
              CheckOperator                           = $true
              CheckPipe                               = $true
              CheckPipeForRedundantWhitespace         = $false
              CheckSeparator                          = $true
              CheckParameter                          = $true
              IgnoreAssignmentOperatorInsideHashTable = $true
          }

          # ugly and diff-hostile with long hashtable keys or values.
          PSAlignAssignmentStatement = @{
              Enable         = $false
              CheckHashtable = $false
          }

          PSUseCorrectCasing = @{
              Enable = $true
          }
      }
  }

  $analyzerSettings = @{
      Severity = @(
          'Error'
          'Warning'
      )

      ExcludeRules = @(
          # Add explicit exceptions here, if any.
      )

      Rules = $formatterSettings['Rules']
  }

  Invoke-ScriptAnalyzer `
      -Path . `
      -Recurse `
      -Settings $analyzerSettings
  ```
- Fix all errors and warnings reported by `PSScriptAnalyzer`. If a warning must be suppressed, suppress it narrowly and include a justification. Example:
  ```powershell
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
      'PSAvoidUsingWriteHost',
      '',
      Justification = 'This function intentionally renders interactive console UI.'
  )]
  param ()
  Write-Host 'Deployment started' -ForegroundColor Green
  ```


**You MAY:**

- Format files with `Invoke-Formatter` with following command (or a script doing the same):
  ```powershell
  if (-not (Get-Module -ListAvailable -Name 'PSScriptAnalyzer')) {
      throw 'PSScriptAnalyzer is required. Install it with: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser'
  }

  Import-Module -Name 'PSScriptAnalyzer'

  $formatterSettings = @{
      IncludeRules = @(
          'PSPlaceOpenBrace'
          'PSPlaceCloseBrace'
          'PSUseConsistentWhitespace'
          'PSUseConsistentIndentation'
          'PSAlignAssignmentStatement'
          'PSUseCorrectCasing'
      )

      Rules = @{
          PSPlaceOpenBrace = @{
              Enable             = $true
              OnSameLine         = $true
              NewLineAfter       = $true
              IgnoreOneLineBlock = $true
          }

          PSPlaceCloseBrace = @{
              Enable             = $true
              NewLineAfter       = $true
              IgnoreOneLineBlock = $true
              NoEmptyLineBefore  = $true
          }

          PSUseConsistentIndentation = @{
              Enable              = $true
              Kind                = 'space'
              IndentationSize     = 4
              PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
          }

          PSUseConsistentWhitespace = @{
              Enable                                  = $true
              CheckInnerBrace                         = $true
              CheckOpenBrace                          = $true
              CheckOpenParen                          = $true
              CheckOperator                           = $true
              CheckPipe                               = $true
              CheckPipeForRedundantWhitespace         = $false
              CheckSeparator                          = $true
              CheckParameter                          = $true
              IgnoreAssignmentOperatorInsideHashTable = $true
          }

          PSAlignAssignmentStatement = @{
              Enable         = $false
              CheckHashtable = $false
          }

          PSUseCorrectCasing = @{
              Enable = $true
          }
      }
  }

  $powerShellFiles = Get-ChildItem `
      -Path . `
      -Recurse `
      -File `
      -Include '*.ps1', '*.psm1', '*.psd1'

  foreach ($powerShellFile in $powerShellFiles) {
      $scriptDefinition = [System.IO.File]::ReadAllText($powerShellFile.FullName)

      if ([string]::IsNullOrWhiteSpace($scriptDefinition)) {
          Write-Verbose -Message "Skipping empty file: $($powerShellFile.FullName)"
          continue
      }

      try {
          $formattedScript = Invoke-Formatter `
              -ScriptDefinition $scriptDefinition `
              -Settings $formatterSettings `
              -ErrorAction Stop
      } catch {
          Write-Warning -Message "Formatting failed, leaving file unchanged: $($powerShellFile.FullName)"
          Write-Warning -Message $_.Exception.Message
          continue
      }

      if ([string]::IsNullOrWhiteSpace($formattedScript)) {
          Write-Warning -Message "Formatter returned empty output, leaving file unchanged: $($powerShellFile.FullName)"
          continue
      }

      [System.IO.File]::WriteAllText(
          $powerShellFile.FullName,
          $formattedScript,
          [System.Text.UTF8Encoding]::new($true)
      )
  }
  ```
  Always Review formatting changes before committing them:
  ```powershell
  git diff -- '*.ps1' '*.psm1' '*.psd1'
  ```
- Use a project-level `.editorconfig` entry for PowerShell files:
  ```editorconfig
  [*.{ps1,psm1,psd1}]
  charset = utf-8-bom
  end_of_line = crlf
  insert_final_newline = true
  trim_trailing_whitespace = true
  indent_style = space
  indent_size = 4
  ```
- Add a matching `.gitattributes` entry to normalize PowerShell files in Git:
  ```gitattributes
  *.ps1  text working-tree-encoding=UTF-8-BOM eol=crlf
  *.psm1 text working-tree-encoding=UTF-8-BOM eol=crlf
  *.psd1 text working-tree-encoding=UTF-8-BOM eol=crlf
  ```

**Reasoning:**

- [`PSScriptAnalyzer`](https://learn.microsoft.com/en-us/powershell/utility-modules/psscriptanalyzer/overview) is the established PowerShell linter. It detects common code defects, style issues, compatibility problems, and security-sensitive patterns.
- [`Invoke-Formatter`](https://learn.microsoft.com/en-us/powershell/module/psscriptanalyzer/invoke-formatter) is provided by `PSScriptAnalyzer` and applies formatting rules from the same settings file used for linting. Please note that this formatting method is not perfect and not as advanced as built-in formatters of other languages, therefore the corresponding rule is a MAY and not a SHOULD. Using a good editor config matters more.
- Some rules in this guide cannot be fully enforced by `PSScriptAnalyzer` alone, such as an exact first line, CRLF line endings, or a mandatory `Set-StrictMode` statement. You can enforce these rules with `.editorconfig`, `.gitattributes`, and small CI checks where needed



## Appendix: PowerShell edition requirements<a id="appendix-powershell-edition-requirements"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

PowerShell has two relevant editions:

| Edition | Runtime | Typical executable | Notes |
|---------|---------|--------------------|-------|
| `Desktop` | Windows PowerShell 5.1 | `powershell.exe` | Built into Windows and based on .NET Framework. |
| `Core` | PowerShell 6/7+ | `pwsh.exe` | Cross-platform and based on modern .NET. |

The default project requirement is compatibility with both Windows PowerShell 5.1 and PowerShell 7+. Therefore, scripts MUST NOT use a `#Requires -PSEdition` statement unless they intentionally support only one edition.


### When to use `#Requires -PSEdition Desktop`

Use `Desktop` only when the script intentionally requires Windows PowerShell:

```powershell
#Requires -Version 5.1
#Requires -PSEdition Desktop
Set-StrictMode -Version Latest
```

Typical reasons include:

- The script depends on a module that only works in Windows PowerShell.
- The script depends on full .NET Framework APIs.
- The script uses Windows PowerShell-only snap-ins.
- The script depends on behavior that is not compatible with PowerShell 7+.
- The script intentionally blocks execution under `pwsh`.


### When to use `#Requires -PSEdition Core`

Use `Core` only when the script intentionally requires PowerShell 6/7+:

```powershell
#Requires -Version 7.2
#Requires -PSEdition Core
Set-StrictMode -Version Latest
```

Typical reasons include:

- The script uses PowerShell 7-only language features.
- The script depends on PowerShell 7-specific module behavior.
- The script is cross-platform and must not run in Windows PowerShell.
- The script intentionally blocks execution under `powershell.exe`.


**Reasoning:**

- [`#Requires -PSEdition`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires) supports `Desktop` for Windows PowerShell and `Core` for PowerShell. [`about_PowerShell_Editions`](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_powershell_editions) documents edition compatibility and the `CompatiblePSEditions` module manifest field. Our standard header uses only `#Requires -Version 5.1` because that allows both Windows PowerShell 5.1 and PowerShell 7+.


## Author information

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) to produce robust, readable, and consistent PowerShell scripts. It incorporates lessons learned from Windows administration and PowerShell automation, as well as public Microsoft documentation and PSScriptAnalyzer recommendations.
