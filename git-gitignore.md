# Git: `gitignore` configuration

The `gitignore` config is used to specify intentionally untracked files. There are [several places](https://git-scm.com/docs/gitignore#_synopsis) to define it. A `.gitignore` file is the usual, easily accessible per-repository option which is easily shared among all developers as part of the repository itself.

It is primarily every developer's responsibility to avoid pushing unwanted files (like temporary or backup files, logs, previews…) and having a Git config in place to support that (especially if an uncommon toolset is used). But **it still makes sense to define a default for unwanted files of very widespread tools** as it makes everyone's lives easier. This especially prevents common mistakes in Pull Requests from people not working with Git or a certain repository on a regular basis.


## Default starting point for a repository's `.gitignore`<a id="gitignore-file-default"></a>

**Please use <https://www.toptal.com/developers/gitignore/api/git,vim,linux,macos,windows,jetbrains+all,visualstudiocode,visualstudio> as default for a `.gitignore` file**.

We decided to ignore likely unwanted files of the following components by default:

* Git
* Linux and common tools like Thunar or Nautilus
* macOS and common tools like Finder
* Microsoft Windows and common tools like File Explorer
* [Vim](https://www.vim.org/)
* [Microsoft Visual Studio](https://visualstudio.microsoft.com/)
* [Microsoft Visual Studio Code](https://code.visualstudio.com/)
* [JetBrains Toolset (complete suite / all IDEs)](https://www.jetbrains.com/products)


## Project specific / additional files to ignore<a id="gitignore-file-extend"></a>

Extend the `.gitignore` file as needed for your project, based on the tools you use (e.g. Ansible, Chocolatey, certain build tools, …). You can access [Toptal's .gitignore.io WebUI pre-configured with our default](https://www.toptal.com/developers/gitignore?templates=git,vim,linux,macos,windows,jetbrains+all,visualstudiocode,visualstudio) to easily add additional `gitignore`-templates.

Please add any non-template, repository-specific excludes below `# End of https://www.toptal.com/developers/gitignore[...]`. This keeps everything easily maintainable.
