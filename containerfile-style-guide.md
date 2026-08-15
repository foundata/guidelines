# OCI container image build guide (Containerfiles)

This document defines how foundata builds and publishes Linux [OCI container images](https://github.com/opencontainers/image-spec) from Containerfiles. It is intended for application developers, infrastructure engineers and reviewers who already understand containers and need a consistent, supportable and verifiable build process.

The resulting image is the release artifact. This guide therefore covers the Containerfile, its build context, registry references, supported platforms, runtime contract, software bill of materials (SBOM), vulnerability scan, provenance, signature and release verification. The [Reasoning](#reasoning) section records why the contested rules are the way they are.

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [Goals and scope](#goals-and-scope)
- [Terminology](#terminology)
- [Supported tools, syntax and platforms](#supported-tools-syntax-and-platforms)
- [When to create a container image](#when-to-create-a-container-image)
- [Files and layout](#files-and-layout)
- [Registries and image names](#registries-and-image-names)
- [Base images and digest pinning](#base-images-and-digest-pinning)
  - [Choosing a base image](#choosing-a-base-image)
  - [Pinning image references](#pinning-image-references)
  - [Updating pinned references](#updating-pinned-references)
- [Build context](#build-context)
- [Stages and dependencies](#stages-and-dependencies)
- [RUN instructions and package installation](#run-instructions-and-package-installation)
- [Files, ownership and permissions](#files-ownership-and-permissions)
- [Build arguments, configuration and secrets](#build-arguments-configuration-and-secrets)
- [Users and runtime filesystem](#users-and-runtime-filesystem)
- [Entrypoint, command and signal handling](#entrypoint-command-and-signal-handling)
- [Image metadata](#image-metadata)
- [Ports, volumes and health checks](#ports-volumes-and-health-checks)
- [Multi-platform images](#multi-platform-images)
- [Rebuildability and reproducibility](#rebuildability-and-reproducibility)
- [Security, SBOMs, provenance and signing](#security-sboms-provenance-and-signing)
  - [Vulnerability and configuration scanning](#vulnerability-and-configuration-scanning)
  - [SBOMs](#sboms)
  - [Provenance](#provenance)
  - [Signing and verification](#signing-and-verification)
- [Linting, testing and release workflow](#linting-testing-and-release-workflow)
- [Reference Containerfile](#reference-containerfile)
- [Reasoning](#reasoning)
- [Author information](#author-information)



## Goals and scope<a id="goals-and-scope"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**This guide aims to produce images that are:**

- Built with a rootless, daemonless and open-source toolchain.
- Based on explicit, reviewable inputs.
- Portable across the required Linux platforms.
- Minimal in installed functionality without optimizing for byte count at the expense of supportability.
- Suitable for an unprivileged, read-only runtime where the application permits it.
- Accompanied by machine-readable inventory, provenance and cryptographic identity.
- Rebuilt and rescanned through automation.


This guide covers Linux application and service images built from Containerfiles and published as OCI images. It also covers intermediate build stages because they influence the final artifact.


**The following are explicitly out of scope:**

- Windows containers.
- GitHub container actions.
- Docker compatibility testing and Docker-specific build extensions.
- Orchestrator-specific deployment policy except where it verifies the image release contract.
- A complete application-language build policy; use the relevant foundata language guide for that code.



## Terminology<a id="terminology"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- An **[OCI](https://opencontainers.org/) image** is the content-addressed collection of manifests, configuration and filesystem layers defined by the OCI Image Specification.
- A **Containerfile** is the declarative build recipe consumed by [Buildah](https://buildah.io/) or [`podman build`](https://docs.podman.io/en/stable/markdown/podman-build.1.html). OCI standardizes the resulting image format, not the Containerfile language.
- An **image index**, also commonly called a manifest list, selects a platform-specific image manifest for each supported operating-system and architecture pair.
- A **tag** is a mutable human-readable registry reference such as `:1.4`. A **digest** is an immutable content identity such as `@sha256:...`.
- A **base image** is an external image named by a `FROM` instruction. External images used by `COPY --from` or a build mount are supply-chain inputs too, even when they are not called base images.
- An **attestation** is signed metadata about an image, such as an [SBOM](https://en.wikipedia.org/wiki/Software_supply_chain#Software_Bill_of_Materials) or a provenance statement.
- A **release image** is an image manifest or image index that has passed the required tests and policy gates and has been published by the release process.



## Supported tools, syntax and platforms<a id="supported-tools-syntax-and-platforms"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[Buildah](https://buildah.io/) is the normative image builder. [Podman](https://podman.io/) is the normative local runtime and may invoke the Buildah build implementation through `podman build`. [Skopeo](https://github.com/containers/skopeo) is the normative tool for inspecting and copying registry content without running it.


**You MUST:**

- Make the Containerfile build successfully with a supported, pinned version of Buildah in rootless mode.
- Produce OCI image format. This is Buildah and Podman's default; specify `--format oci` when a surrounding tool or configuration could change the default.
- Test the image with Podman.
- Build and publish `linux/amd64` images.
- Use syntax documented by the [Containerfile manual](https://github.com/containers/common/blob/main/docs/Containerfile.5.md).
- Pin the versions of Buildah, Podman, Skopeo and release-security tools in continuous integration.


**You SHOULD:**

- Build and publish `linux/arm64` images.
- Run architecture-dependent build steps on native workers. Use QEMU emulation only when a native worker is not practical and test the resulting image on real target hardware before release.
- Keep local and continuous-integration tool versions aligned.


**You MUST NOT:**

- Require a Docker daemon or Docker BuildKit to build, test or release the image.
- Add Docker BuildKit parser directives or Docker-only Containerfile extensions.
- Claim Docker compatibility unless a project separately builds and tests the image with explicitly supported Docker versions.


The recommended supporting tools are:

| Concern | Tool | Role | License |
|---|---|---|---|
| Build | [Buildah](https://github.com/containers/buildah) | Rootless OCI image and image-index construction | Apache-2.0 |
| Run and smoke-test | [Podman](https://github.com/containers/podman) | Daemonless container runtime | Apache-2.0 |
| Inspect and copy | [Skopeo](https://github.com/containers/skopeo) | Registry inspection, digest resolution and transport | Apache-2.0 |
| Dependency updates | [Renovate](https://docs.renovatebot.com/modules/manager/dockerfile/) | Reviewable tag and digest updates | AGPL-3.0-only |
| Static linting | [Hadolint](https://github.com/hadolint/hadolint) | Containerfile correctness and maintainability checks | GPL-3.0-only |
| Smoke and structure tests | [Testinfra](https://testinfra.readthedocs.io/) | pytest-based assertions against a running container | Apache-2.0 |
| SBOM and scanning | [Trivy](https://trivy.dev/docs/latest/target/container_image/) | SPDX SBOM, vulnerability, secret and configuration scanning | Apache-2.0 |
| Signing and attestations | [Cosign](https://github.com/sigstore/cosign) | Sigstore-compatible image signatures and attestations | Apache-2.0 |
| Provenance format | [in-toto Attestation](https://github.com/in-toto/attestation) and [SLSA Provenance](https://slsa.dev/spec/v1.0/provenance) | Standard statement and predicate formats | Apache-2.0 and Community Specification License 1.0 |
| Pull-time trust | [`containers-policy.json`](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md) | Signature policy enforcement for containers/image consumers | Apache-2.0 |



## When to create a container image<a id="when-to-create-a-container-image"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD create an image when:**

- The application and its runtime dependencies need to be released and promoted as one content-addressed artifact.
- The target platform runs OCI containers and benefits from an explicit filesystem, user and process contract.
- The release pipeline can rebuild, scan, sign and maintain the image for its supported lifetime.


**You SHOULD NOT create an image when:**

- A native package, static executable, library or archive is the actual interface consumers require.
- Containerization would conceal unsupported host dependencies or privileged behavior instead of removing them.
- No owner can maintain the base image, dependencies and vulnerability response after initial publication.



## Files and layout<a id="files-and-layout"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


**You MUST:**

- Name a new build recipe `Containerfile`.
- Store the Containerfile in the smallest directory that contains its intended build context, or pass an explicit narrower context from automation.
- Use UTF-8 without a BOM, Unix line endings and one final newline.
- Write instruction keywords in uppercase.
- Give every named stage a short lowercase name that describes its purpose, such as `build`, `test` or `runtime`.
- Keep comments focused on constraints and non-obvious decisions.


**You SHOULD:**

- Order instructions from relatively stable inputs to frequently changing inputs so that local caching remains useful.
- Put one logical operation in each instruction while combining commands that must share a layer, such as package installation and cache cleanup.
- Place small supporting scripts in version-controlled files and `COPY` them into the image instead of embedding large shell programs in `RUN` instructions. FIXME in which subdir?
- Follow the [shell scripting style guide](./shell-scripting-style-guide.md) for non-trivial shell code executed during a build or used as an entrypoint.


**You MAY:**

- Retain the conventional `Dockerfile` filename in an inherited repository when renaming it would cause disproportionate disruption.
- Use a dedicated filename such as `Containerfile.integration` for a genuinely different build purpose.


**You MUST NOT:**

- Add a `# syntax=...` directive that requires Docker BuildKit.
- Generate a Containerfile dynamically when ordinary build arguments or separate explicit Containerfiles express the variants clearly.
- Hide release behavior in undocumented wrapper scripts.
- Create Containerfile suffix variants for differences that belong in runtime configuration.



## Registries and image names<a id="registries-and-image-names"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

The currently approved registry for publishing public foundata images is `quay.io`. This policy chooses where foundata publishes images; it does not prohibit consuming upstream images from their authoritative registries.


**You MUST:**

- Publish public foundata images under an approved `quay.io` organization and repository, usually [foundata](https://quay.io/organization/foundata).
- Use fully qualified registry and repository names for every image reference.
- Verify the publisher and pin every external image input by digest as described in [Pinning image references](#pinning-image-references).
- Use lowercase repository names consisting of stable product or component names.
- Treat repository deletion, renaming and tag mutation as controlled operations because consumers may depend on them.
- Configure automated registry retention so it does not delete release digests, signatures, SBOMs or attestations that remain supported.


**You SHOULD:**

- Prefer an equivalent image on Quay over Docker Hub when the same trusted publisher maintains both with the required platforms, lifecycle and update cadence.
- Consume an image from its authoritative upstream registry when no equivalent Quay source exists. This includes fully qualified Docker Official Image references such as `docker.io/library/debian`.
- Mirror an upstream image when foundata needs additional availability, retention or policy control.


**You MUST NOT:**

- Use short names such as `fedora`, `alpine` or `my-image` in a Containerfile or release command.
- Substitute an unrelated Quay repackaging solely to avoid an authoritative upstream registry.
- Depend on an engineer's local `registries.conf` search list or short-name alias resolution.
- Publish credentials, private source references or internal hostnames in public labels or attestations.


When an upstream image is mirrored, the mirroring process MUST record the upstream repository and digest, preserve multi-platform index membership where required, scan the mirrored content, apply foundata trust policy, and refresh it through reviewable automation.

Tags communicate a release channel or human-readable version; digests identify content. Publish an immutable version tag such as `:1.8.2` when the project has versions. Moving convenience tags such as `:1`, `:stable` or `:latest` MAY exist, but deployment and verification policy MUST resolve them to and operate on a digest.



## Base images and digest pinning<a id="base-images-and-digest-pinning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


### Choosing a base image<a id="choosing-a-base-image"></a>

foundata does not mandate one base distribution for every application.


**You MUST evaluate:**

- Whether the image comes from its trusted publisher through an authoritative or deliberately controlled mirror registry.
- The upstream support period and whether it covers the application's release lifetime.
- Availability for `linux/amd64` and, when supported by the project, `linux/arm64`.
- Compatibility with the application runtime, native libraries and expected C library.
- Availability of certificate authorities, timezone data, locale data and user lookup facilities the application actually needs.
- The quality and timeliness of upstream security advisories, package metadata and scanner support.
- The package and debugging tools needed to build, operate and diagnose the application.
- The upstream rebuild cadence and the project's ability to consume updates promptly.


**You SHOULD:**

- Start evaluation with an official Fedora Minimal image from Quay for a general-purpose Linux runtime when Fedora's lifecycle and update cadence suit the application.
- Prefer a base already maintained and understood by the operating team when it satisfies the preceding criteria.
- Remove unused packages, files and privileges based on measured runtime requirements.
- Use `scratch` only for a genuinely static executable after testing certificate, timezone, user lookup and diagnostic requirements.


**You MUST NOT:**

- Choose Alpine, a distroless image or `scratch` solely because it has fewer bytes.
- Assume a smaller image has fewer exploitable vulnerabilities.
- Introduce a musl-based runtime without testing software that was developed or distributed for glibc.
- Use an unsupported distribution release merely to avoid an upgrade.


### Pinning image references<a id="pinning-image-references"></a>

All external image inputs to a release build MUST be pinned by digest. This includes production and build stages: a compromised or unexpectedly changed builder can alter the final artifact even when the final base is pinned.

Use a readable tag together with the digest of the image index:

```dockerfile
FROM quay.io/fedora/fedora-minimal:<version>@sha256:<image-index-digest> AS runtime
```

The tag documents the intended release line; the digest, not the tag, selects the bytes. For a multi-platform image, pin the image-index digest rather than an architecture-specific child manifest so the builder can select the correct child per platform. Some containers/image command-line transports accept only `repository@digest` without the tag; use that form in Skopeo, Podman and release commands where required.


**You MUST pin:**

- Every external `FROM` reference.
- Every external image used by `COPY --from`.
- Every external image used by a `RUN --mount=from` build mount.
- Tool or helper images invoked around the build, scan, signing or release process.


The literal `scratch` base and a stage name declared earlier in the same Containerfile are not external references and do not have a registry digest.

Resolve the current index digest with Skopeo and review the result before changing the Containerfile:

```sh
image='quay.io/fedora/fedora-minimal:<version>'
digest="$(skopeo inspect --format '{{.Digest}}' "docker://${image}")"
printf '%s@%s\n' "${image}" "${digest}"
```


**You MUST NOT:**

- Pin only a mutable tag for a release build.
- Remove the tag and leave an unexplained bare digest when a meaningful upstream tag exists.
- Resolve a tag to a digest in one job and silently use a later tag resolution in another job.
- Assume digest pinning alone makes a build reproducible.


### Updating pinned references<a id="updating-pinned-references"></a>

**You MUST:**

- Use reviewable automation to propose base-image digest updates.
- Rebuild, test, scan and sign after an image input changes.
- Review an unexpected digest change under an unchanged immutable-version tag as a supply-chain event.
- Keep supported release branches receiving relevant base-image and toolchain updates.
- Run Renovate self-hosted from a version- or digest-pinned image or package. Do not grant a hosted update service write access to foundata repositories.
- Give the update job credentials that can open pull requests but cannot merge them or push to protected branches.


**You SHOULD:**

- Configure Renovate's Containerfile manager and `docker:pinDigests` behavior for image references.
- Group routine digest refreshes where this does not obscure a high-risk or breaking update.
- Set a repository-specific update schedule that is shorter than the vulnerability remediation deadline.
- Maintain one organization-level Renovate preset that repositories extend, so schedule, grouping and digest policy are decided once instead of per repository.
- Use Renovate custom managers to update digest pins embedded outside Containerfiles, such as pinned tool digests in scripts and deployment files.



## Build context<a id="build-context"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Add a `.containerignore` file at the root of the build context.
- Exclude `.git`, editor state, test output, local caches, credentials, environment files, private keys, signing material and unrelated build artifacts.
- Pass the narrowest practical directory as the build context.
- Review negated ignore patterns because the last matching pattern determines inclusion.
- Keep all required build input in version control or fetch it through an authenticated, integrity-checked dependency mechanism.


**You SHOULD:**

- Start from excluding broadly and add back only the files required by the build.
- Give dependency manifests their own early `COPY` instruction when the package manager can cache dependency resolution independently of source changes.
- Inspect the effective context when adding a broad `COPY . ...` instruction.


**You MUST NOT:**

- Rely on `.gitignore` to define the build context.
- Include a secret and assume it is safe because no final `COPY` references it.
- Use the filesystem root or a developer's home directory as the build context.


The `.containerignore` syntax and precedence are defined by the [containers/common manual](https://github.com/containers/common/blob/main/docs/containerignore.5.md). Use `.containerignore`, not `.dockerignore`, for new projects. See the [Reference Containerfile](#reference-containerfile) for a minimal allowlist example.



## Stages and dependencies<a id="stages-and-dependencies"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Name every stage referenced by another instruction.
- Copy artifacts from an explicit named stage, not a numeric stage position.
- Keep compilers, package managers, source trees and test data out of the final stage unless they are runtime requirements.
- Verify artifacts fetched from outside the package manager or source repository with a cryptographic digest or signature.
- Pin external stage images as described in [Pinning image references](#pinning-image-references).


**You SHOULD:**

- Use separate `build`, `test` and `runtime` stages when doing so makes promotion boundaries clear.
- Make a target used by CI fail unless its test stage completes.
- Copy a small, explicit artifact set into the runtime stage.
- Keep build dependency declarations close to the application dependency manifests they consume.


**You MAY:**

- Use build mounts for transient caches and secrets when supported by the documented Buildah version.


**You MUST NOT:**

- Copy an entire build stage filesystem into the runtime stage.
- Fetch an executable through `curl | sh`, an unauthenticated URL or a mutable latest-release URL.
- Assume that deleting a secret or large file in a later instruction removes it from an earlier layer.
- Require a cache mount for correctness; a cache improves speed but is not an input identity.



## RUN instructions and package installation<a id="run-instructions-and-package-installation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use non-interactive package-manager options.
- Install only packages required by that stage.
- Refresh package metadata, install packages and remove package-manager caches in the same `RUN` instruction when the package manager stores them in the layer.
- Make shell command failures stop the build.
- Use HTTPS and verify an expected digest or signature when downloading a file outside a package manager.
- Keep repository trust configuration explicit and scoped.


**You SHOULD:**

- Use the base distribution's package manager instead of downloading manually assembled filesystem archives.
- Sort package names lexicographically when installing several packages.
- Use `RUN --mount=type=cache` for disposable package or compiler caches where it measurably improves build time.
- Use `RUN --network=none` for steps that should be independent of the network.
- Move non-trivial shell logic to a checked and linted script.


**You MAY:**

- Add an exact package version constraint when compatibility requires it; document how the version remains available and receives security maintenance.


**You MUST NOT:**

- Use `curl ... | sh` or an equivalent network-to-interpreter pipeline.
- Disable TLS certificate validation or package signature verification.
- Run a full distribution upgrade as a substitute for updating the pinned base image.
- Keep package indexes, compiler caches or downloaded archives in the final filesystem without a runtime need.
- Put a long application installer into a quoted `RUN` string when it can be a tested source file.
- Require exact distribution package versions by default.


Example pattern for a POSIX shell stage:

```dockerfile
RUN set -eu; \
    package-manager install --non-interactive \
      ca-certificates \
      timezone-data; \
    package-manager clean
```

The command names are intentionally generic; use the exact supported commands of the chosen distribution. Do not paste package-manager flags from another distribution or release.



## Files, ownership and permissions<a id="files-ownership-and-permissions"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `COPY` for local files.
- Copy only the files needed by the stage.
- Set ownership during `COPY` with `--chown` when the builder supports the required semantics.
- Make executables, configuration and data no more permissive than their runtime use requires.
- Ensure the runtime identity cannot change executable code or immutable configuration, including by changing their permission modes.
- Preserve executable bits in version control for source-controlled executable files.


**You SHOULD:**

- Use absolute destination paths.
- Use `COPY --from=<stage>` for build outputs.
- Separate stable dependency input from frequently changing source input to preserve useful build cache entries.
- Keep executable code and immutable configuration owned by container UID/GID 0 and non-writable by the runtime identity. Mode `0555` is a suitable default for executables and `0444` for non-secret read-only data when every runtime user may read it.
- Give the runtime identity ownership only of explicitly mutable directories and files, with the narrowest required modes.


**You MUST NOT:**

- Use remote-URL `ADD`.
- Depend on `ADD` archive auto-extraction when an explicit extraction command would make validation and ownership clearer.
- Use `chmod -R 777`, world-writable application directories or setuid/setgid executables.
- Copy a complete repository merely for convenience.
- Change ownership recursively in a later layer when ownership can be assigned during `COPY`.


Example:

```dockerfile
COPY --from=build --chown=0:0 --chmod=0555 /workspace/bin/example /usr/local/bin/example
```



## Build arguments, configuration and secrets<a id="build-arguments-configuration-and-secrets"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Build arguments select non-secret build behavior. Environment variables define image defaults visible at runtime. Secrets are neither and require a secret mount or an external runtime secret provider.


**You MUST:**

- Declare every build argument with `ARG` before use.
- Give a non-secret build argument a safe default or require and validate it explicitly in the build automation.
- Use `ENV` only for values that are appropriate defaults in every container created from the image.
- Supply build secrets with Buildah's secret mechanism and consume them through `RUN --mount=type=secret`.
- Supply runtime secrets at runtime through the deployment platform.


**You MUST NOT:**

- Pass passwords, tokens, private keys or signing material through `ARG`, `ENV`, labels, command-line literals or ordinary `COPY`.
- Bake environment-specific service addresses, credentials or deployment configuration into a reusable release image.
- Assume that an unset build argument reliably fails without explicit validation.
- Log secret values or commands that expand them.


Example:

```dockerfile
RUN --mount=type=secret,id=repository_token \
    set -eu; \
    token="$(cat /run/secrets/repository_token)"; \
    authenticated-fetch --token "${token}"
```

```sh
buildah build \
  --secret id=repository_token,src=/secure/path/repository-token \
  --tag localhost/example:build \
  .
```



## Users and runtime filesystem<a id="users-and-runtime-filesystem"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Set `USER` to a numeric, non-zero UID in the final stage unless the application has a documented, reviewed requirement for root.
- Use a stable UID and GID that do not collide with identities already defined by the selected base.
- Make required writable paths explicit.
- Ensure application startup does not need to change file ownership, install packages or rewrite its executable or static configuration.
- Document and review every required Linux capability, device, host namespace, privileged mode or writable host path.


**You SHOULD:**

- Use a dedicated identity per application image.
- Make the root filesystem read-only in runtime tests.
- Mount an explicit temporary filesystem for `/tmp` or another required scratch path.
- Drop all capabilities and enable `no-new-privileges` in smoke tests, adding back only a documented capability when required.
- Define and test memory, CPU, PID and `nofile` limits in deployment configuration, using measurements from representative startup and load tests.
- Listen on an unprivileged port greater than or equal to 1024.


**You MUST NOT:**

- Install or use `sudo` in the final image.
- Run as root merely to bind a low port, write application files or avoid setting ownership during the build.
- Declare a broad writable directory when one narrow cache or temporary path is sufficient.
- Assume a named user resolves in a `scratch` image without supplying the required user database files.


Example hardening smoke test with illustrative resource values:

```sh
podman run --rm \
  --read-only \
  --cap-drop=all \
  --security-opt=no-new-privileges \
  --memory=256m \
  --cpus=1 \
  --pids-limit=128 \
  --ulimit=nofile=1024:1024 \
  --tmpfs /tmp:rw,noexec,nosuid,nodev \
  quay.io/foundata/example@sha256:<platform-manifest-digest>
```



## Entrypoint, command and signal handling<a id="entrypoint-command-and-signal-handling"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use JSON exec form for `ENTRYPOINT` and `CMD`.
- Make the long-running application process become PID 1 by using `exec` in an entrypoint script, unless a documented supervisor is part of the product's lifecycle contract.
- When a supervisor is PID 1, require it to forward relevant signals, reap child processes, terminate managed processes within the deployment grace period, and propagate or deliberately map their exit statuses according to the documented contract.
- Ensure the application handles signals received directly or forwarded by its supervisor and exits within the deployment grace period.
- Propagate the application exit status from a wrapper unless the documented lifecycle contract defines a deliberate status mapping.
- Keep deployment-specific flags outside the immutable entrypoint.


**You SHOULD:**

- Use `ENTRYPOINT` for the stable executable and `CMD` for overridable default arguments.
- Run exactly one service process and avoid a supervisor unless the product contract requires supervision, child-process management or another explicit lifecycle policy.
- Test termination and child-process reaping behavior.
- Set `STOPSIGNAL` only when the application requires a signal other than the runtime default.


**Good example:**

```dockerfile
ENTRYPOINT ["/usr/local/bin/example"]
CMD ["serve"]
```


**Bad example (shell form):**

```dockerfile
ENTRYPOINT /usr/local/bin/example serve
```



## Image metadata<a id="image-metadata"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Use the standard [`org.opencontainers.image.*` annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md) as image labels. Labels describe the exact build and provide discovery information; they do not replace provenance.


**A published image MUST include:**

- `org.opencontainers.image.source` with the canonical source repository URL.
- `org.opencontainers.image.revision` with the complete source revision used for the build.
- `org.opencontainers.image.licenses` with an SPDX license expression for the packaged project.
- `org.opencontainers.image.title` with a concise human-readable name.
- `org.opencontainers.image.version` when the project has a release version.


**A published image SHOULD include:**

- `org.opencontainers.image.description`.
- `org.opencontainers.image.documentation`.
- `org.opencontainers.image.url`.
- `org.opencontainers.image.vendor`.
- `org.opencontainers.image.created` as an RFC 3339 timestamp when the build system supplies a controlled value.


**You MUST NOT:**

- Put credentials, internal infrastructure names or personal data in labels.
- Claim a source revision, version or creation time that the release pipeline did not verify.
- Use a changing build timestamp when a reproducible build is required; derive it from controlled source metadata instead.
- Invent project-specific labels when a standard OCI annotation has the required meaning.


Pass revision, version and creation time from trusted release automation:

```dockerfile
ARG IMAGE_CREATED
ARG IMAGE_REVISION
ARG IMAGE_VERSION

LABEL org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.version="${IMAGE_VERSION}"
```



## Ports, volumes and health checks<a id="ports-volumes-and-health-checks"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD:**

- Use `EXPOSE` to document each stable network port and transport expected by the application.
- Prefer an unprivileged port.
- Keep durable data and mutable configuration outside the image.
- Implement a lightweight application health endpoint when service health cannot be established from process state.
- Put the health command, timing, thresholds and failure action in deployment configuration for OCI images.
- Keep a lightweight health command in the image when deployment configuration invokes it, and make it run successfully as the configured runtime user.


**You MUST NOT:**

- Assume `EXPOSE` publishes a port or creates a firewall rule.
- Declare `VOLUME` without a stable data contract and a documented reason it belongs in the image.
- Store durable state in an anonymous runtime layer.
- Add a health check that requires a large diagnostic client solely for the check.
- Make a liveness check depend on an unrelated external service.
- Add or rely on a Containerfile `HEALTHCHECK` instruction in an OCI-format image.


The OCI Image Specification has no health-check field, so Buildah drops `HEALTHCHECK` from OCI-format output. Define the health check through Quadlet, a systemd unit or the equivalent deployment interface. Retaining the instruction in a Docker-format image requires a documented exception to this guide's OCI-format requirement.



## Multi-platform images<a id="multi-platform-images"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Every public release MUST include a `linux/amd64` image. Public releases SHOULD include `linux/arm64` unless an application dependency, runtime requirement or support constraint prevents it. A documented issue should track removal of that constraint.


**You MUST:**

- Publish one image index when a release supports more than one platform.
- Build every platform from the same reviewed source revision and release configuration.
- Test each platform-specific image, not only the index name on one build host.
- Inspect the published index and verify the expected operating system, architecture and digest entries.
- Generate and scan the SBOM for each platform-specific manifest.


**You SHOULD:**

- Use native `linux/amd64` and `linux/arm64` workers.
- Keep platform-independent build steps identical.
- Test the index through Podman's normal platform selection after publication.


**You MUST NOT:**

- Label an `amd64` filesystem as `arm64` or otherwise override platform metadata to conceal a cross-build failure.
- Download an architecture-specific artifact based only on the build host's `uname -m`.
- Publish an index entry that has not passed the platform's required tests.


Example Buildah workflow:

```sh
manifest='localhost/example-release'

buildah manifest create "${manifest}"
buildah build \
  --platform linux/amd64 \
  --manifest "${manifest}" \
  .
buildah build \
  --platform linux/arm64 \
  --manifest "${manifest}" \
  .
buildah manifest push --all \
  "${manifest}" \
  'docker://quay.io/foundata/example:<version>'
```



## Rebuildability and reproducibility<a id="rebuildability-and-reproducibility"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Rebuildability is mandatory: the project can create a working replacement from documented inputs. Bit-for-bit reproducibility is strongly desirable, but must be measured and claimed precisely rather than assumed.


**You MUST:**

- Record the source revision, Containerfile, build arguments, builder identity, builder version and resolved external materials in provenance.
- Use lock files and checksum verification provided by the application language's dependency system.
- Pin the release toolchain through the repository's normal dependency mechanism.
- Make release builds independent of a developer's local image store, environment and uncommitted files.
- Pull and verify required external images instead of accepting an unreviewed local substitute.


**You SHOULD:**

- Set `SOURCE_DATE_EPOCH` from the source revision when supported by the build system.
- Use Buildah's timestamp controls such as `--source-date-epoch` or `--rewrite-timestamp` after confirming their behavior with the pinned version.
- Normalize generated archive metadata and application build identifiers.
- Test whether two clean builds from the same declared input produce the same platform manifest digest.
- Document remaining sources of nondeterminism.


**You MUST NOT:**

- Describe an image as reproducible merely because it can be rebuilt successfully.
- Depend on a warm build cache for correctness.
- Embed an uncontrolled current timestamp, random identifier or host path in release output.
- Weaken update policy solely to preserve an old digest; a secure rebuild may intentionally produce new content.



## Security, SBOMs, provenance and signing<a id="security-sboms-provenance-and-signing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

The release pipeline MUST evaluate, scan, attest and sign the exact digests it publishes. A scan result for a local tag, an SBOM for the source directory or a signature over a moving tag does not establish the state of the released image. The subsections below all follow from this rule.


### Vulnerability and configuration scanning<a id="vulnerability-and-configuration-scanning"></a>

Trivy is the standard scanner. The release pipeline MUST scan the final image pulled by digest from Quay after publication or from an equivalently immutable pre-publication registry location.


**You MUST:**

- Scan operating-system and application packages in every platform-specific image.
- Scan the Containerfile and image configuration for insecure settings.
- Enable secret scanning for the build context and final image.
- Fail a release for a fixable `HIGH` or `CRITICAL` vulnerability unless an approved exception exists.
- Store the scanner version, vulnerability database version or timestamp, image digest and result with the release evidence.
- Rescan supported release digests on a schedule because vulnerability knowledge changes without image content changing.
- Use exactly one scanner stack as the authoritative release gate.


**You MAY:**

- Replace Trivy with [Syft](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype) for SBOM generation and vulnerability matching when a project documents a concrete benefit; the required secret and configuration scanning must then still be covered, in practice by keeping Trivy anyway.
- Run a non-gating second-opinion scan for audits.


**You MUST NOT:**

- Run two scanners as parallel release gates.


**A vulnerability exception MUST include:**

- The affected image, component and advisory identifier.
- The reason the finding is not currently remediated.
- An assessment of reachability and exposure.
- Compensating controls.
- An accountable owner.
- An expiry date and review trigger.


Example release gate:

```sh
trivy image \
  --exit-code 1 \
  --ignore-unfixed \
  --severity HIGH,CRITICAL \
  'quay.io/foundata/example@sha256:<platform-manifest-digest>'
```

Trivy can also scan a retained SBOM directly, which keeps the required scheduled rescans cheap because the released image does not have to be pulled again:

```sh
trivy sbom \
  --exit-code 1 \
  --ignore-unfixed \
  --severity HIGH,CRITICAL \
  'example-linux-amd64.spdx.json'
```


### SBOMs<a id="sboms"></a>

Each platform-specific release manifest MUST have an SBOM in SPDX 2.3 JSON format. Generate it from the final image so it describes the filesystem and packages consumers receive.

```sh
trivy image \
  --format spdx-json \
  --output example-linux-amd64.spdx.json \
  'quay.io/foundata/example@sha256:<platform-manifest-digest>'
```


**You MUST:**

- Generate one SBOM for each platform-specific manifest digest.
- Validate that the SBOM names or associates the exact subject digest.
- Retain the SBOM for the supported lifetime of the release.
- Attach the SBOM to the registry as a signed Cosign attestation.
- Make the SBOM available to consumers without requiring access to the build workspace.


**You SHOULD:**

- Also publish the raw SPDX JSON as a release artifact for tools that do not discover registry attestations.
- Include application-language dependencies and files not owned by a distribution package.
- Compare SBOM coverage with application dependency lock files.


### Provenance<a id="provenance"></a>

Release provenance MUST use an in-toto Statement with a SLSA Provenance v1 predicate. It must be generated by the trusted release environment from observed build data, not assembled from values supplied unchecked by the caller. A project MUST document its provenance generator integration and trust root.


**The provenance MUST identify:**

- Every platform-specific subject digest and, where supported by the generator, the image-index digest.
- The canonical source repository and complete source revision.
- The Containerfile and relevant build configuration.
- External image materials by digest.
- The builder and workflow identity.
- Relevant build parameters without secret values.
- Whether the build was initiated from an authenticated, reviewed release event.


**You MUST:**

- Attach provenance to the registry as a signed Cosign attestation.
- Verify subject digests and trusted builder identity before deployment or promotion.
- Keep secret values out of provenance parameters and environment data.
- Describe the actual build; do not claim a SLSA build level unless every requirement of that level is implemented and audited.


### Signing and verification<a id="signing-and-verification"></a>

Cosign is the standard signing and attestation client. The preferred identity model is keyless signing with the release job's short-lived OIDC workload identity and Sigstore transparency-log integration. Where a suitable workload identity is unavailable, use a KMS- or HSM-protected key with documented rotation and recovery; do not store a long-lived private key in the repository or an ordinary CI variable.

Sign immutable digests after all image content has been uploaded to its registry location. The upload makes the subject digest available to Cosign; it does not promote the candidate to a release. Registry and deployment policy MUST continue to reject the candidate until its signatures and required attestations have been verified.


**You MUST:**

- Sign the image-index digest and every platform-manifest digest in a multi-platform release.
- Sign attestations and associate them with the exact subject digest.
- Verify the expected certificate issuer and exact or narrowly matched workflow identity for keyless signatures.
- Verify the signature, SBOM attestation and provenance attestation before promotion or deployment.
- Configure `containers-policy.json` or an equivalent admission policy to reject unsigned or untrusted production images.
- Test trust-policy changes with both a trusted image and an intentionally untrusted image.


**You MUST NOT:**

- Sign a tag as though the tag were immutable.
- Accept any identity from a broadly trusted OIDC issuer.
- Treat successful cryptographic verification as authorization without checking repository, digest, signer identity and attestation predicate.
- Use the same long-lived signing key across unrelated trust domains.


Signing and attestation:

```sh
cosign sign --yes \
  'quay.io/foundata/example@sha256:<image-index-digest>'

cosign attest --yes \
  --type spdxjson \
  --predicate example-linux-amd64.spdx.json \
  'quay.io/foundata/example@sha256:<platform-manifest-digest>'

cosign attest --yes \
  --type slsaprovenance1 \
  --predicate provenance.json \
  'quay.io/foundata/example@sha256:<image-index-digest>'
```

Verification requires identity constraints:

```sh
cosign verify \
  --certificate-oidc-issuer '<trusted-issuer>' \
  --certificate-identity '<exact-release-workflow-identity>' \
  'quay.io/foundata/example@sha256:<image-index-digest>'

cosign verify-attestation \
  --type spdxjson \
  --certificate-oidc-issuer '<trusted-issuer>' \
  --certificate-identity '<exact-release-workflow-identity>' \
  'quay.io/foundata/example@sha256:<platform-manifest-digest>'

cosign verify-attestation \
  --type slsaprovenance1 \
  --certificate-oidc-issuer '<trusted-issuer>' \
  --certificate-identity '<exact-release-workflow-identity>' \
  'quay.io/foundata/example@sha256:<image-index-digest>'
```

The release repository MUST contain the expected issuer and identity policy, not derive them from the signature being checked. For Podman, Buildah and Skopeo consumers, use the `sigstoreSigned` policy type in `containers-policy.json` where the deployed containers/image version supports the required identity model. Keep the allowed registry namespace narrow and use `matchRepository` only when repository-level identity matching is intended.



## Linting, testing and release workflow<a id="linting-testing-and-release-workflow"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Every image repository MUST automate linting, clean builds, runtime tests and release-security controls. A locally successful build is not release evidence.


**You MUST:**

- Run Hadolint against every maintained Containerfile.
- Document each disabled Hadolint rule next to the narrowest applicable configuration or suppression.
- Build with a clean, rootless Buildah environment and pull the declared inputs.
- Run application tests before constructing a release image.
- Run a container smoke test as the configured user for every supported platform.
- Test startup, readiness where applicable, graceful termination and expected exit status.
- Run with a read-only root filesystem, all capabilities dropped and `no-new-privileges` during a hardening test.
- Run with measured memory, CPU, PID and `nofile` limits during a resource-control test.
- Inspect the final image configuration, layers, labels, user, entrypoint and platform metadata.
- Release only from a protected, reviewed source revision through trusted CI.


**You SHOULD:**

- Write smoke and structure tests with a dedicated harness instead of accumulating unstructured shell. [Testinfra](https://testinfra.readthedocs.io/) is the default recommendation; [Goss](https://github.com/goss-org/goss) is a suitable alternative when a single Go binary with YAML assertions is preferred over a Python toolchain.
- Test a clean no-cache build periodically in addition to ordinary cached builds.
- Enforce a maximum image-size or layer regression threshold derived from the application, not a universal byte limit.
- Test the published digest after pulling it from Quay.
- Run scheduled rebuilds even when application source has not changed so base and package security updates are consumed.


**You MUST NOT:**

- Add a Containerfile formatting tool to the pipeline.


Run Hadolint with a pinned version and keep policy-level rule decisions in a committed configuration file rather than in flags. Use an inline suppression only for a narrow, single-instruction exception, and expect occasional false positives on Buildah-supported syntax that Docker popularized later:

```sh
hadolint Containerfile
```

```yaml
# .hadolint.yaml: keep close to defaults; document every deviation.
ignored:
  # Exact distribution package versions are intentionally not pinned; see
  # "RUN instructions and package installation" in the foundata build guide.
  - DL3041
```

```dockerfile
# hadolint ignore=DL3003
RUN cd /workspace/example && ./generate.sh
```

Example Testinfra smoke test:

```python
"""Smoke test for the candidate image. Run with: pytest"""

import subprocess
from collections.abc import Iterator

import pytest
import testinfra
import testinfra.host

IMAGE = "quay.io/foundata/example@sha256:<platform-manifest-digest>"


@pytest.fixture(scope="session")
def host() -> Iterator[testinfra.host.Host]:
    """Start the candidate image once and return a Testinfra host for it."""
    container_id = subprocess.run(
        ["podman", "run", "--detach", "--read-only", IMAGE],
        capture_output=True,
        check=True,
        text=True,
        timeout=60,
    ).stdout.strip()
    yield testinfra.get_host(f"podman://{container_id}")
    subprocess.run(["podman", "rm", "--force", container_id], check=True, timeout=60)


def test_runs_as_configured_user(host: testinfra.host.Host) -> None:
    assert host.check_output("id -u") == "10001"


def test_application_binary(host: testinfra.host.Host) -> None:
    binary = host.file("/usr/local/bin/example")
    assert binary.exists
    assert binary.uid == 0
    assert binary.gid == 0
    assert binary.mode == 0o555
```

Harness-based in-container assertions require a shell in the image because the Podman backend executes commands through `podman exec`. For shell-less images built from `scratch`, test from the outside instead: `podman inspect` for configuration, and the application's network or health interface for behavior.


The release workflow should use this order:

1. Check source state, dependency locks, Containerfile lint and `.containerignore`.
2. Resolve and policy-check every external image digest.
3. Build and test the `linux/amd64` image on an `amd64` worker.
4. Build and test the `linux/arm64` image on an `arm64` worker when supported.
5. Push the platform manifests and image index to a non-promoted candidate reference in Quay.
6. Resolve the registry-reported platform and index digests and compare them with the build outputs.
7. Generate an SPDX 2.3 JSON SBOM and run the vulnerability gate for every platform digest.
8. Generate trusted in-toto SLSA provenance.
9. Attach signed SBOM and provenance attestations and sign every platform-manifest digest and the image-index digest.
10. Verify signatures, attestations, identity policy, platform coverage and a clean pull from Quay.
11. Promote the verified digest by adding its immutable release tag and any moving convenience tags.
12. Store release evidence and schedule rescans and rebuilds.


Do not sign before the image has its final registry digest. Do not promote by rebuilding: copy or retag the already verified digest so the artifact that passed policy remains the artifact consumers receive.



## Reference Containerfile<a id="reference-containerfile"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This example packages a prebuilt static executable. It deliberately uses `scratch`; most applications need a maintained runtime base with certificate, timezone, user or shared-library data. Replace every placeholder through trusted release automation and choose `scratch` only after the requirements in [Choosing a base image](#choosing-a-base-image) have been tested.

```dockerfile
FROM scratch AS runtime

ARG IMAGE_CREATED
ARG IMAGE_REVISION
ARG IMAGE_VERSION

LABEL org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.description="Example service" \
      org.opencontainers.image.documentation="https://example.invalid/docs" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.source="https://example.invalid/source" \
      org.opencontainers.image.title="Example service" \
      org.opencontainers.image.url="https://example.invalid/" \
      org.opencontainers.image.vendor="foundata GmbH" \
      org.opencontainers.image.version="${IMAGE_VERSION}"

COPY --chown=0:0 --chmod=0555 build/example /usr/local/bin/example

USER 10001:10001

EXPOSE 8080/tcp

ENTRYPOINT ["/usr/local/bin/example"]
CMD ["serve", "--listen=:8080"]
```

An application that compiles inside the Containerfile SHOULD add a pinned, approved `build` stage and copy only its verified output into this runtime stage. A dynamically linked application MUST instead use a compatible runtime base containing its required loader, libraries and runtime data.

The corresponding minimal `.containerignore` for an externally built artifact is:

```gitignore
**
!build/
!build/example
!Containerfile
```

The example is a structural reference, not a universal base-image choice. Project documentation must state how `build/example` is produced, tested and associated with the source revision recorded in the labels and provenance.



## Reasoning<a id="reasoning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**Toolchain and Docker.** The Buildah, Podman and Skopeo toolchain is rootless, daemonless and open source. Docker's acceptance of a conforming Containerfile is incidental, so it is neither tested nor promised. Hosted services built from open-source software, including Quay.io and Sigstore's public infrastructure, remain external services with their own terms, and distributing pinned tools can create license obligations even when a tool's license does not cover the images it produces.

**Registries.** Publishing is centralized on Quay so retention and tag mutation stay controlled operations. Consumption prefers the authoritative upstream registry because a similarly named repackaging elsewhere is not evidence of equivalence. Mirrors are reserved for concrete availability or policy needs; an unmaintained mirror becomes a stale, unscanned trust anchor.

**Base images.** A single mandated distribution would trade compatibility, lifecycle fit and diagnostic knowledge for superficial consistency. Image size is an incomplete security metric: attack surface depends on reachable behavior, configuration and privileges, and saved megabytes do not help a team that cannot patch or debug the base during an incident. musl is a real compatibility surface for glibc-targeted software.

**Digest pinning and updates.** The tag documents intent; the digest selects the bytes. A pin transfers change control to the repository and creates an update obligation, because a forgotten digest is a frozen vulnerability set. Pinning alone is not reproducibility. Renovate proposes the digests every other control trusts, so it runs self-hosted and pinned, able to propose but not merge; its AGPL-3.0-only license covers the tool, not the repositories or images it updates.

**Build context.** The context is builder input and may be transferred, cached or inspected even when never copied into the image, so it is bounded with an allowlist.

**Packages and caches.** Exact package pins block security updates and become uninstallable after repository rotation; the base digest plus the SBOM records what was installed. Caches are speed, not input identity.

**File ownership.** Mode `0555` is not immutability when the executing user owns the file: an owner can re-permission and rewrite it. Root ownership blocks that, and a read-only root filesystem is an independent second control.

**Build arguments and environment.** `ARG` and `ENV` values surface in image configuration, logs, cache metadata and provenance, so they are public unless the documented secret channel is used end to end.

**Users and resource limits.** A container user is a process identity, not a boundary, but it shrinks compromise impact. Limits need measurement because applications derive internal sizing from them; an inherited `nofile` limit in the millions has produced a connection table hundreds of megabytes large at idle.

**Entrypoint.** The shell form inserts a shell that changes argument handling and can block signal delivery. Supervisors are limited to documented product contracts because each extra process obscures the signal path and exit status that deployment tooling depends on.

**Health checks.** The OCI image format has no health-check field, and health policy is an environment decision, so the deployment layer owns it.

**Multi-platform.** Emulated builds can hide target-architecture defects; cross-compiling is fine for the build but never replaces an on-target runtime test.

**Reproducibility.** Rebuildability is what an incident requires: a working replacement from documented inputs. Bit-for-bit equivalence is desirable evidence but must be measured, not assumed.

**Exact-digest releases.** Every security statement binds to a digest. A scan of a local tag or a signature over a moving tag can describe different bytes than consumers pull, so the workflow pushes a candidate, verifies the registry-reported digest and promotes by retagging; a rebuild would reopen the gap the gates closed.

**One scanner stack.** Scanner databases and matching differ by design, so parallel gates yield conflicting findings and duplicated exceptions instead of safety; second opinions stay non-gating. Trivy is the default because it also covers the required secret and configuration scanning. Registry-side scanning is defense in depth, not the gate, and an empty result does not prove security. Trivy's public database has rate-limited busy CI runners: cache it, set `--db-repository` or self-host a mirror, and scan the retained SBOM to keep scheduled rescans cheap.

**Provenance and signing.** Correct SLSA field names are not trusted provenance; trust comes from a generator running in the release environment under an attested workload identity. Keyless signing removes long-lived key custody, and verification must constrain issuer and identity because "signed by somebody" is not a trust statement.

**Formatting and test harness.** No Containerfile formatter has ecosystem authority and Hadolint does not format, so layout is enforced by lint rules and review. Testinfra reuses the pytest stack of the [Python style guide](./python-style-guide.md); Goss suits teams preferring one Go binary with YAML assertions.



## Author information<a id="author-information"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) for OCI container images maintained in source repositories. It draws on the following specifications and tool documentation:

- [OCI Image Specification](https://github.com/opencontainers/image-spec)
- [OCI Image Configuration](https://github.com/opencontainers/image-spec/blob/main/config.md)
- [OCI Pre-Defined Annotation Keys](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
- [Containerfile manual](https://github.com/containers/common/blob/main/docs/Containerfile.5.md)
- [`.containerignore` manual](https://github.com/containers/common/blob/main/docs/containerignore.5.md)
- [Buildah build manual](https://github.com/containers/buildah/blob/main/docs/buildah-build.1.md)
- [Podman build manual](https://docs.podman.io/en/stable/markdown/podman-build.1.html)
- [Skopeo documentation](https://github.com/containers/skopeo)
- [containers image signature policy](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md)
- [Trivy container-image documentation](https://trivy.dev/docs/latest/target/container_image/)
- [Testinfra documentation](https://testinfra.readthedocs.io/)
- [Cosign documentation](https://docs.sigstore.dev/cosign/verifying/verify/)
- [in-toto Attestation Framework](https://github.com/in-toto/attestation)
- [SLSA Provenance](https://slsa.dev/spec/v1.0/provenance)
- [Project Quay documentation](https://docs.projectquay.io/quay_io.html)
- [Fedora container downloads](https://fedoraproject.org/everything/download/)
- [Renovate Containerfile manager](https://docs.renovatebot.com/modules/manager/dockerfile/)
- [Hadolint](https://github.com/hadolint/hadolint)
- [RFC 2119: Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119)
- [RFC 8174: Ambiguity of Uppercase vs Lowercase in RFC 2119 Key Words](https://datatracker.ietf.org/doc/html/rfc8174)
