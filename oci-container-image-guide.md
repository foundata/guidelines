# OCI container image build and release guide

This guide defines how foundata builds and publishes Linux [OCI container images](https://github.com/opencontainers/image-spec) from [Containerfiles](https://github.com/containers/common/blob/main/docs/Containerfile.5.md). It is for application developers, infrastructure engineers and reviewers who already understand containers.

The image is the release artifact. The guide covers its Containerfile, build context, registry references, platforms, runtime contract, [software bill of materials (SBOM)](https://spdx.dev/use/specifications/), scans, provenance, signatures and verification. [Reasoning](#reasoning) explains the contested rules.

[ContainerWright](#terminology) enforces automatable rules. Its conformance documentation maps each check to its guide section. Review covers the remaining rules.

The terms MUST, SHOULD, and other key words are used as defined in [RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and [RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [Goals and scope](#goals-and-scope)
- [Terminology](#terminology)
- [Release workflow](#release-workflow)
- [Supported tools, syntax and platforms](#supported-tools-syntax-and-platforms)
  - [ContainerWright version identity](#containerwright-version-identity)
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
  - [Rescans and remediation](#rescans-and-remediation)
  - [SBOMs](#sboms)
  - [Provenance](#provenance)
  - [Signing and verification](#signing-and-verification)
  - [Release evidence and retention](#release-evidence-and-retention)
- [Linting and testing](#linting-and-testing)
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


This guide covers Linux application and service images built from Containerfiles, including intermediate stages that affect the final artifact.


**The following are explicitly out of scope:**

- Windows containers.
- GitHub container actions.
- Docker compatibility testing and Docker-specific build extensions.
- Orchestrator-specific deployment policy except where it verifies the image release contract.
- A complete application-language build policy; use the relevant foundata language guide for that code.
- Release-environment configuration, registry retention, scheduling and deployment authorization. The release and deployment environments own these controls; this guide states their required properties.



## Terminology<a id="terminology"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- An **[OCI](https://opencontainers.org/) image** is the content-addressed collection of manifests, [configuration](https://github.com/opencontainers/image-spec/blob/main/config.md) and filesystem layers defined by the OCI Image Specification.
- A **Containerfile** is the declarative build recipe consumed by [Buildah](https://github.com/containers/buildah/blob/main/docs/buildah-build.1.md) or [`podman build`](https://docs.podman.io/en/stable/markdown/podman-build.1.html). OCI standardizes the resulting image format, not the Containerfile language.
- An **image index**, also commonly called a manifest list, selects a platform-specific image manifest for each supported operating-system and architecture pair.
- A **tag** is a mutable human-readable registry reference such as `:1.4`. A **digest** is an immutable content identity such as `@sha256:...`.
- A **base image** is an external image named by a `FROM` instruction. External images used by `COPY --from` or a build mount are supply-chain inputs too, even when they are not called base images.
- **`scratch`** is a reserved empty base, not an image pulled from a registry. A `FROM scratch` stage contains only files and configuration added by later instructions. The application must provide every executable, shared library, certificate, timezone file and other runtime dependency it needs.
- An **attestation** is signed metadata about an image, such as an SBOM or provenance statement.
- **Release provenance**<a id="release-provenance"></a> is machine-readable evidence of how and where an image was built and which source code and dependencies were used.
- A **release image** is an image manifest or image index that has passed the required tests and policy gates and has been published by the release process.
- **ContainerWright** is the foundata command-line tool that implements this guide's automatable rules. Each release identifies its guide revision and maps its checks to guide sections.
- **Repository configuration** is the version-controlled `containerwright.toml` file containing project facts and permitted exceptions. It may narrow built-in rules but cannot relax an unconditional `MUST` or `MUST NOT` or extend a built-in maximum.
- A **platform qualification** is the per-image, per-platform record (`platform-qualification.json`) of observations, evidence digests and the platform verdict produced by qualification on one build worker.
- A **release candidate** is the aggregate record (`release-candidate.json`) produced by assembly from one or more accepted platform qualifications. It identifies the exact image manifest or image index eligible for publication.
- A **candidate reference** is a reserved, single-use tag for one publication attempt of an accepted digest. Its `-candidate.` suffix follows the release version or source revision so related tags sort together.
- **Evidence** is the machine-readable, digest-bound output of the release process, including SBOMs, scans, qualifications and verification results. Signed registry attestations are the authoritative retained evidence.
- A **trust root** is the approved set of public signing keys or managed-key identities against which signatures and attestations are verified. It is supplied through maintainer-controlled release configuration or protected deployment configuration, not by the repository being verified.
- An **authorized release environment** is a maintainer-controlled Linux workstation or protected CI job. It runs ContainerWright on a reviewed commit and obtains trust configuration and signing authority outside the repository and arbitrary command-line input.



## Release workflow<a id="release-workflow"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Every image repository owner MUST automate the repository's release-security controls; a release assembled by hand is not a release.
- A release MUST run through ContainerWright in an authorized release environment, using a clean release checkout of a reviewed, committed source revision.
- The complete release workflow through promotion MUST be runnable on a secure, maintainer-controlled Linux workstation. CI MAY invoke the same workflow but MUST NOT be the only implementation of release logic.
- For a local release, ContainerWright MUST build from an isolated checkout or detached worktree of the selected application commit. This repository contains the Containerfile, `containerwright.toml`, build scripts and dependency declarations. The ordinary worktree may be dirty, but uncommitted or untracked files MUST NOT enter the release.
- The release workflow MUST execute these steps in order. ContainerWright orders its steps; the authorized release environment orders external steps.

The links define each step's requirements.

1. Run source, dependency-lock, [Containerfile](#linting-and-testing), [context](#build-context) and repository checks.
2. Validate declared container-image dependency and [base-image pins](#pinning-image-references).
3. First build, import, re-verify and [test](#linting-and-testing) `linux/amd64` natively or with the documented [emulation fallback](#multi-platform-images); every release requires this platform.
4. Repeat the build, import, re-verification and test sequence on every other required platform worker.
5. Generate each platform [SBOM](#sboms), run the local [release scan gate](#vulnerability-and-configuration-scanning), and emit a platform qualification binding the layout, SBOM, scan results and verdict by digest.
6. When transport is needed, [verify the recorded digests](#multi-platform-images) of layouts, evidence and qualifications before assembly. Assemble an OCI image index for a multi-platform release.
7. Aggregate the accepted platform qualifications into one release-candidate record and generate the [SLSA provenance predicate](#provenance) in the authorized release environment.
8. Publish the exact accepted manifest or index to a unique [candidate reference](#registries-and-image-names) in the final release repository.
9. Resolve the remote reference and compare its digest with the accepted local digest.
10. Attach [SBOM](#sboms) and [provenance](#provenance) attestations and [sign](#signing-and-verification) the index digest and every platform-manifest digest.
11. Verify digest coverage, signatures, attestations, identities and guide compliance, then retain a signed [release-verification result](#release-evidence-and-retention).
12. Promote only the verified digest according to the [release-tag model](#registries-and-image-names).
13. Retain verifiable [evidence](#release-evidence-and-retention) and arrange the organization's scheduled [rescans](#rescans-and-remediation) and [rebuilds](#rebuildability-and-reproducibility).


- The release workflow MUST NOT sign before the image has its final registry digest. ContainerWright refuses subjects not resolved and digest-checked at the registry.
- The release workflow MUST NOT promote by rebuilding; promotion copies or retags the already verified digest so the artifact that passed policy remains the artifact consumers receive, enforced by ContainerWright.



## Supported tools, syntax and platforms<a id="supported-tools-syntax-and-platforms"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[Buildah](https://buildah.io/) is the normative image builder. [Podman](https://podman.io/) is the normative local runtime and may invoke the Buildah build implementation through `podman build`. [Skopeo](https://github.com/containers/skopeo) is the normative tool for inspecting and [copying registry content](https://github.com/containers/skopeo/blob/main/docs/skopeo-copy.1.md) without running it.


**You MUST:**

- Make the Containerfile build successfully with a Buildah version supported by the selected ContainerWright release in rootless mode.
- Produce OCI image format. This is Buildah and Podman's default; specify `--format oci` when a surrounding tool or configuration could change the default.
- Test the image with Podman.
- Build and publish `linux/amd64` images.
- Use syntax documented by the [Containerfile manual](https://github.com/containers/common/blob/main/docs/Containerfile.5.md).
- Use a ContainerWright release that implements the selected guide revision. At release start, it resolves and records host-tool versions and tool-image digests, rejects unsupported versions and holds the toolchain constant.


**You SHOULD:**

- Build and publish `linux/arm64` images.
- Run architecture-dependent build steps on native workers. Use [QEMU user-mode emulation](https://www.qemu.org/docs/master/user/) only when a native worker is not practical and test the resulting image on real target hardware before release; the [recorded execution modes](#multi-platform-images) make the combination visible.
- Keep local and continuous-integration tool versions aligned.
- Pin supporting tools when predictable upgrades or reconstruction justify it. Supported, recorded tool upgrades between releases are permitted.


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
| Guide enforcement | ContainerWright | Deterministic checks, qualification, publication and verification per this guide | To be released |
| Dependency updates | [Renovate](https://docs.renovatebot.com/modules/manager/dockerfile/) | Reviewable tag and digest updates; the sole pin write path | AGPL-3.0-only |
| Static linting | [Hadolint](https://github.com/hadolint/hadolint) | Containerfile correctness and maintainability checks | GPL-3.0-only |
| Smoke and structure tests | [Testinfra](https://testinfra.readthedocs.io/) | pytest-based assertions against a running container | Apache-2.0 |
| SBOM and scanning | [Trivy](https://trivy.dev/docs/latest/target/container_image/) | [SPDX SBOM](https://trivy.dev/docs/latest/supply-chain/sbom/), vulnerability, secret and configuration scanning | Apache-2.0 |
| Signing and attestations | [Cosign](https://docs.sigstore.dev/cosign/) | Sigstore-compatible image signatures and attestations | Apache-2.0 |
| Provenance format | [in-toto Attestation](https://github.com/in-toto/attestation) and [SLSA Provenance](https://slsa.dev/spec/v1.0/provenance) | Standard statement and predicate formats | Apache-2.0 and Community Specification License 1.0 |
| Pull-time trust | [`containers-policy.json`](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md) | Signature policy enforcement for containers/image consumers | Apache-2.0 |



### ContainerWright version identity<a id="containerwright-version-identity"></a>

Every ContainerWright release MUST expose human-readable and machine-readable version information. It MUST include the tool version and full source revision, plus the title, repository, path and full revision of the implemented guide. These values must be embedded at build time, not read from the repository under test.

Human-readable output should use this form:

```text
$ containerwright version
ContainerWright <version> (commit <containerwright-source-revision>)
Implements the automatable rules of foundata "OCI container image build and release guide", oci-container-image-guide.md at commit <guide-revision>
```

`containerwright version --format json` MUST expose the same identity through stable fields for release evidence:

```json
{
  "name": "containerwright",
  "version": "<version>",
  "sourceRevision": "<containerwright-source-revision>",
  "guide": {
    "title": "OCI container image build and release guide",
    "repository": "https://github.com/foundata/guidelines",
    "path": "oci-container-image-guide.md",
    "revision": "<guide-revision>"
  }
}
```

ContainerWright MUST NOT claim to implement rules that require human review. Its conformance documentation MUST state the release's built-in limits and defaults.



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
- Use UTF-8 without a [BOM](https://en.wikipedia.org/wiki/Byte_order_mark), Unix line endings and one final newline.
- Write instruction keywords in uppercase.
- Give every named stage a short lowercase name that describes its purpose, such as `build`, `test` or `runtime`.
- Keep comments focused on constraints and non-obvious decisions.


**You SHOULD:**

- Order instructions from relatively stable inputs to frequently changing inputs so that local caching remains useful.
- Put one logical operation in each instruction while combining commands that must share a layer, such as package installation and cache cleanup.
- Put small supporting scripts in a version-controlled `scripts/` directory beside the Containerfile and `COPY` them instead of embedding large shell programs in `RUN`. Another documented location is permitted when the repository layout requires it.
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

The approved registry for publishing public foundata images is currently [Quay.io](https://docs.projectquay.io/quay_io.html) (`quay.io`). This rule chooses where foundata publishes images; it does not prohibit consuming upstream images from their authoritative registries.


**You MUST:**

- Publish public foundata images under an approved `quay.io` organization and repository, usually [foundata](https://quay.io/organization/foundata). ContainerWright verifies the registry and configured release repository.
- Use fully qualified registry and repository names for every image reference.
- Verify the publisher and pin every external image input by digest as described in [Pinning image references](#pinning-image-references).
- Use lowercase repository names consisting of stable product or component names.
- Treat repository deletion, renaming and tag mutation as controlled operations because consumers may depend on them.
- Configure automated registry retention so it does not delete release digests, signatures, SBOMs or attestations that remain supported; the organization owns registry retention configuration.


**You SHOULD:**

- Prefer an equivalent image on Quay over Docker Hub when the same trusted publisher maintains both with the required platforms, lifecycle and update cadence.
- Consume an image from its authoritative upstream registry when no equivalent Quay source exists. This includes fully qualified Docker Official Image references such as `docker.io/library/debian`.
- Mirror an upstream image when foundata needs additional availability, retention or policy control.


**You MUST NOT:**

- Use short names such as `fedora`, `alpine` or `my-image` in a Containerfile or release command.
- Substitute an unrelated Quay repackaging solely to avoid an authoritative upstream registry.
- Depend on an engineer's local `registries.conf` search list or short-name alias resolution.
- Publish credentials, private source references or internal hostnames in public labels or attestations.


- A mirror owner MUST record the upstream repository and digest, preserve required index membership, scan the content, apply foundata trust policy and automate reviewed refreshes.


**Release-tag model.** Tags communicate a release channel or human-readable version; digests identify content.

- Publish an immutable version tag such as `:1.8.2` when the project has versions.
- Moving convenience tags such as `:1`, `:stable` or `:latest` MAY exist.
- Deployment environment owners MUST configure digest-only admission and deployment controls so every moving convenience tag is resolved to a digest and authorization operates on that digest.


**Candidate references.** A candidate reference makes an accepted digest addressable for attestation and verification before promotion. It is not a release tag and receives no release-retention guarantee.

- By default, a publication attempt MUST use a version-first candidate tag in the final repository. A versioned release uses `<version>-candidate.<run-id>.g<source-revision-short>`, for example `1.8.2-candidate.01k3z8h6v4n7c2m9p5q1r0s8tx.g7ac94d12`. An unversioned project uses `g<source-revision-short>-candidate.<run-id>`. ContainerWright generates and validates the tag.
- A candidate reference MUST NOT be intentionally reused for a different publication attempt; every attempt, including a rebuild of the same source revision, uses a new reference.
- Candidate content and evidence MUST be safe to disclose publicly. Deleting or expiring a Quay tag may leave unreferenced manifests and blobs until garbage collection.
- Where the registry supports tag immutability, the release workflow SHOULD enable it for candidate and release tags.
- ContainerWright MUST set a [bounded default candidate lifetime](https://docs.redhat.com/en/documentation/red_hat_quay/3.15/html/use_red_hat_quay/image-tags-overview) and refuse promotion after expiry. Repository configuration MAY shorten but MUST NOT extend or disable it. Immediately after publication, ContainerWright MUST set the expiration through the [Quay tag API](https://docs.redhat.com/en/documentation/red_hat_quay/3/html/red_hat_quay_api_reference/tag).
- A workflow MUST NOT use a separate candidate repository unless it copies or recreates every signature and attestation in the final repository, then verifies the subjects and identities before promotion. [OCI referrers](https://docs.redhat.com/en/documentation/red_hat_quay/3.15/html/red_hat_quay_api_reference/referrers), Cosign signatures and attestations are repository-scoped; `skopeo copy --all` does not move them.
- The run identifier MUST be a lowercase [ULID](https://github.com/ulid/spec) generated by ContainerWright as its release-run identity. It sorts by time and prevents reference collisions. Each rebuild gets a new identifier, locally or in CI.
- After writing a release or convenience tag, promotion MUST compare it with the verified digest and record the result. A missing or different tag is an operational failure.
- After successful promotion, ContainerWright MUST delete the temporary candidate tag. A rejected or abandoned candidate MUST be deleted explicitly or left to its configured expiration. Delayed removal of unreferenced manifests and blobs by [Quay garbage collection](https://docs.redhat.com/en/documentation/red_hat_quay/3.15/html/manage_red_hat_quay/garbage-collection) is not a release failure.



## Base images and digest pinning<a id="base-images-and-digest-pinning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


### Choosing a base image<a id="choosing-a-base-image"></a>

foundata does not mandate one base distribution for every application.


**You MUST evaluate:**

- Publisher and registry trust; whether upstream support covers the application's release lifetime; `linux/amd64` and any required `linux/arm64`; compatibility with the runtime, native libraries and C library; required certificate, timezone, locale and user lookup data; the quality and timeliness of advisories, package metadata and scanner support; tools needed to build, operate and diagnose; upstream rebuild cadence; and the project's ability to update promptly.


**You SHOULD:**

- Start evaluation with an [official Fedora Minimal image](https://fedoraproject.org/everything/download/) from Quay for a general-purpose Linux runtime when Fedora's lifecycle and update cadence suit the application.
- Prefer a base already maintained and understood by the operating team when it satisfies the preceding criteria.
- Remove unused packages, files and privileges based on measured runtime requirements.
- Use `scratch` only for a genuinely static executable after testing certificate, timezone, user lookup and diagnostic requirements.


**You MUST NOT:**

- Choose Alpine, a distroless image or `scratch` solely because it has fewer bytes.
- Assume a smaller image has fewer exploitable vulnerabilities.
- Introduce a musl-based runtime without testing software that was developed or distributed for glibc.
- Use an unsupported distribution release merely to avoid an upgrade.


### Pinning image references<a id="pinning-image-references"></a>

- All external image inputs to a release build MUST be pinned by digest. This includes production and build stages: a compromised or unexpectedly changed builder can alter the final artifact even when the final base is pinned.

Use a readable tag together with the digest of the image index:

```dockerfile
FROM quay.io/fedora/fedora-minimal:<version>@sha256:<image-index-digest> AS runtime
```

The tag documents the release line; the digest selects the bytes. For a multi-platform image, pin the index digest so the builder can select each platform manifest. Some containers/image transports accept only `repository@digest`; use that form where required.


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


**Pin intent and freshness.** Every pin declares what its tag is expected to do so that divergence between tag and digest becomes measurable.

- Every pinned reference declared in `containerwright.toml` MUST declare `tag_intent = "immutable-version"` or `tag_intent = "moving-release-line"`; ContainerWright's pin gate rejects a declaration without a valid intent.
- Evidence MUST record, for every pinned reference, the tag, the pinned digest, the resolved digest, the resolution time and the first-observed divergence time.
- ContainerWright MUST define and enforce both the maximum permitted time since successful resolution and the maximum permitted divergence interval for pinned references; repository configuration MAY shorten but MUST NOT extend or disable these limits.
- The pin gate MUST apply the effective freshness and divergence limits and emit a result; it MUST NOT edit files.
- The pin gate MUST fail when the declared `tag_intent` set and the Containerfile's actual pinned references diverge; an undeclared pin and an orphaned declaration are both policy failures.
- A digest change under an `immutable-version` tag MUST be reviewed by the repository owner as a supply-chain event.
- A changed digest under a `moving-release-line` tag is a normal update proposal but becomes stale according to the effective divergence limit; Renovate proposes the update and the repository owner reviews it.
- Renovate and repository merge controls MUST NOT auto-apply a digest change under an `immutable-version` tag; the proposal remains blocked until the required human review of the supply-chain event completes.


### Updating pinned references<a id="updating-pinned-references"></a>

**You MUST:**

- Use reviewable automation to propose base-image digest updates; self-hosted Renovate is the sole proposal and write path for tag or digest updates, and ContainerWright checks declared pins but does not edit them.
- Rebuild, test, scan and sign after an image input changes.
- Review an unexpected digest change under an unchanged immutable-version tag as a supply-chain event.
- Keep supported release branches receiving relevant base-image and toolchain updates.
- Run Renovate self-hosted from a version- or digest-pinned image or package. Do not grant a hosted update service write access to foundata repositories.
- Give the update job credentials that can open pull requests but cannot merge them or push to protected branches.


**You SHOULD:**

- Configure Renovate's Containerfile manager and `docker:pinDigests` behavior for image references.
- Group routine digest refreshes where this does not obscure a high-risk or breaking update.
- Set a repository-specific update schedule that is shorter than the effective vulnerability remediation deadline enforced by ContainerWright.
- Maintain one organization-level Renovate preset that repositories extend, so schedule, grouping and digest policy are decided once instead of per repository.
- Use Renovate custom managers to update digest pins embedded outside Containerfiles, such as pinned tool digests in scripts and deployment files.



## Build context<a id="build-context"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Add a [`.containerignore`](https://github.com/containers/common/blob/main/docs/containerignore.5.md) file at the root of the build context.
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


The containers/common manual defines `.containerignore` syntax and precedence. New projects use `.containerignore`, not `.dockerignore`. The [reference](#reference-containerfile) includes a minimal allowlist.



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
- Keep executable code and immutable configuration owned by container UID/GID 0 and non-writable by the runtime identity. Use mode `0555` for executables and `0444` for non-secret data readable by every runtime user.
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
- Define and test memory, CPU, PID and `nofile` limits in deployment configuration, using per-image measured values from representative startup and load tests recorded in repository configuration; runtime evidence records the limits actually applied.
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


Pass revision, version and creation time from the authorized release process:

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


OCI has no health-check field, so Buildah drops `HEALTHCHECK` from OCI-format output. Define health checks through Quadlet, a systemd unit or another deployment interface. A Docker-format image retaining the instruction requires a documented exception to the OCI-format rule.



## Multi-platform images<a id="multi-platform-images"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Every public release MUST include a `linux/amd64` image.
- Public releases SHOULD include `linux/arm64` unless an application dependency, runtime requirement or support constraint prevents it.


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


**Platform transport.** Platform builds may run on separate workers. The environment may transport their layouts and records through a CI artifact service, object store or local directory, subject to these rules:

- Each build execution MUST record the digest of every exported layout, evidence payload and platform-qualification record in its output.
- The platform qualification MUST include the target platform, manifest digest, OCI layout descriptor, SBOM digest and scan-result digest.
- Before use, assembly MUST verify every transported layout, evidence payload and record by digest, reject unsafe archive paths and compare the imported manifest digest with the recorded digest.
- Index assembly MUST use only verified platform layouts and MUST record every platform-manifest digest and the index digest.
- Before producing a candidate, assembly MUST have exactly one accepted qualification per required platform, reject missing, duplicate or unexpected records, and match each target to its OCI descriptor and image-configuration metadata.
- When a public release omits the recommended `linux/arm64` image, the repository owner SHOULD maintain a documented issue that identifies the blocking constraint and tracks its removal.


**Build and test execution modes.**

- Per-platform evidence and provenance MUST record the target, host and execution architectures, plus any emulation or cross-build mechanism, for both build and test. A single `uname` value is insufficient.
- Native build and runtime tests satisfy the platform requirement. Without native target hardware, QEMU-emulated build and runtime tests MAY qualify if ContainerWright records the emulation and the repository explains why native testing was impractical. Repository configuration MAY still require native testing.
- KVM accelerates a guest only when the host can execute the guest architecture and does not replace QEMU for cross-architecture emulation.


Example Buildah workflow:

```sh
manifest='localhost/example-release'
layout='./build/example-release.oci'
candidate='<version>-candidate.<run-id>.g<source-revision-short>'

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
  "oci:${layout}:candidate"

# After per-platform tests, SBOMs, scans and qualification:
skopeo copy --all --preserve-digests \
  "oci:${layout}:candidate" \
  "docker://quay.io/foundata/example:${candidate}"
```

In a distributed release, each platform worker exports an OCI layout. The authorized release environment verifies the layouts and assembles the accepted manifests into an index. A local single-platform release uses the same qualification and assembly steps without transport.



## Rebuildability and reproducibility<a id="rebuildability-and-reproducibility"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Rebuildability is mandatory: the project can create a working replacement from documented inputs. Bit-for-bit reproducibility is strongly desirable, but must be measured and claimed precisely rather than assumed.


**You MUST:**

- Record the source revision, Containerfile, build arguments, builder identity, builder version and resolved external materials in provenance.
- Use lock files and checksum verification provided by the application language's dependency system.
- Record the ContainerWright version, host-tool versions and tool-image digests, and keep them unchanged until the release completes.
- Make release builds independent of a developer's local image store, environment and uncommitted files.
- Pull and verify required external images instead of accepting an unreviewed local substitute.


**You SHOULD:**

- Set `SOURCE_DATE_EPOCH` from the source revision when supported by the build system.
- Use Buildah timestamp controls such as `--source-date-epoch` or `--rewrite-timestamp` only after testing the resolved version. Apply them during the build, never after runtime tests.
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

- The release pipeline MUST evaluate, scan, attest and sign the exact digests it publishes. A local-tag scan, source-directory SBOM or moving-tag signature does not describe the released image.


### Vulnerability and configuration scanning<a id="vulnerability-and-configuration-scanning"></a>

Trivy is the standard scanner.

- Before public upload, the release pipeline MUST scan each final platform image from a local OCI layout with a recorded manifest digest, or an equivalently digest-addressed private location. Every rejecting content gate must run without public disclosure.
- After these gates pass, the workflow MUST copy the scanned artifact with unchanged manifest and blob digests. Use Skopeo `--preserve-digests`, plus `--all` for an index, and compare every registry digest with its local digest. Failure to preserve or match a digest fails the release. Signature and attestation verification remain publication steps because they use registry objects.


**You MUST:**

- Scan operating-system and application packages in every platform-specific image.
- Scan the Containerfile and image configuration for insecure settings.
- Enable secret scanning for the build context and final image.
- Fail a release for a fixable `HIGH` or `CRITICAL` vulnerability unless an approved, unexpired exception exists in repository configuration; this guide owns the authoritative severity threshold.
- Store the scanner version, vulnerability database version or timestamp, image digest and result with the release evidence.
- Record the local manifest digest before scanning and verify the same digest after upload.
- Arrange scheduled organization rescans from a digest-bound inventory of supported releases because vulnerability data changes without image changes. Mutable tags MUST NOT define this inventory. Scheduling and remediation ownership are external; [Rescans and remediation](#rescans-and-remediation) defines the procedure.
- Use exactly one scanner stack as the authoritative release gate.
- Cache the vulnerability database between runs, record the database version or timestamp with each scan result, and refresh a stale or corrupted cache instead of trusting it.


**You SHOULD:**

- Scan the digest pulled from the registry after upload as a non-gating defense-in-depth check.


**You MAY:**

- Replace Trivy SBOM and vulnerability scanning with [Syft](https://github.com/anchore/syft) and [Grype](https://github.com/anchore/grype) when a project documents a concrete benefit. Secret and configuration scanning remain required, which normally still requires Trivy.
- Run a non-gating second-opinion scan for audits.


**You MUST NOT:**

- Run two scanners as parallel release gates.


**A vulnerability exception MUST:**

- Be stored in `containerwright.toml` on the protected, reviewed source revision and receive the required security-owner review before merge.
- Identify the image, component and advisory; explain the lack of remediation; assess reachability and exposure; list compensating controls; and name the accountable owner, expiry and review trigger.
- Be rejected by ContainerWright when it is malformed, expired or does not match the finding; ContainerWright records every applied exception in evidence.


Example local vulnerability gate:

```sh
trivy image \
  --input './build/example-linux-amd64.oci' \
  --exit-code 1 \
  --ignore-unfixed \
  --severity HIGH,CRITICAL
```

Trivy can also scan a retained SBOM directly, which keeps the required scheduled rescans cheap because the released image does not have to be pulled again:

```sh
trivy sbom \
  --exit-code 1 \
  --ignore-unfixed \
  --severity HIGH,CRITICAL \
  'example-linux-amd64.spdx.json'
```

An SBOM rescan matches vulnerabilities against the retained package inventory. It does not repeat the image filesystem's secret and configuration scans; see [Rescans and remediation](#rescans-and-remediation) for the scope rules.


### Rescans and remediation<a id="rescans-and-remediation"></a>

These rules apply when a supported digest gains a finding above the release threshold. The organization owns scheduling, triage and remediation; this section defines the required project output and evidence.

- The remediation clock MUST start when the authoritative rescan result is recorded; it MUST NOT start from an informal local scanner invocation.
- A finding MUST be treated as fixable when the scanner reports a fixed version or other concrete remediation, unless triage shows it does not apply.
- ContainerWright MUST define and enforce a non-disableable maximum remediation deadline; repository configuration MAY shorten but MUST NOT extend it.
- Within the effective remediation deadline, the project owner MUST either release a newly qualified remediated digest or obtain and record an approved exception as defined above.
- Immutable version and release tags MUST NOT be repointed for remediation. The registry owner enforces immutability; ContainerWright refuses a different existing digest and reports observed repointing as a policy failure.
- A convenience tag MUST advance only through ContainerWright's verified promotion, never as an unrecorded scan response.
- Evidence MUST identify the affected digest and the remediating digest or the applied exception.
- The project owner SHOULD publish an advisory when consumers are affected, identifying the affected digest and the remediating digest or exception.


**Rescan scope.**

- An SBOM-based rescan MUST be recorded as covering vulnerability matching against the retained package inventory only; it does not repeat the image filesystem's secret and configuration scans.
- When rescan configuration requires new secret or configuration scans, the rescan MUST fetch the image by digest and scan its content. An SBOM rescan is insufficient.
- The project triage owner MUST record each triage decision with the affected subject, the decision, its rationale, the accountable owner and the decision time.
- A changed triage state, remediating digest or approved exception MUST be recorded as a new rescan result that references the previous one; earlier results are never rewritten.



### SBOMs<a id="sboms"></a>

- Each platform release manifest MUST have an SBOM in a finalized SPDX JSON format supported by the release toolchain. SPDX 2.3 JSON is the interoperability baseline. Generate it from the final local OCI layout so it describes the published filesystem and packages.

```sh
trivy image \
  --input './build/example-linux-amd64.oci' \
  --format spdx-json \
  --output example-linux-amd64.spdx.json
```


**You MUST:**

- Generate one SBOM for each platform-specific manifest digest.
- Record the actual SPDX specification version in the SBOM and release evidence.
- Validate that the SBOM names or associates the exact subject digest.
- Retain the SBOM for the supported lifetime of the release; the organization owns the retention configuration described in [Release evidence and retention](#release-evidence-and-retention).
- Attach the SBOM to the registry as a signed Cosign attestation.
- Make the SBOM available to consumers without requiring access to the build workspace.


**You SHOULD:**

- Also publish the raw SPDX JSON as a release artifact for tools that do not discover registry attestations.
- Include application-language dependencies and files not owned by a distribution package.
- Compare SBOM coverage with application dependency lock files.


**You MAY:**

- Use a later finalized SPDX version when all release tools and required consumers support it. The workflow must generate, validate, rescan, attach, retrieve and interpret it without lossy conversion.


After local content gates pass, upload and compare the digest with a unique [candidate reference](#registries-and-image-names):

```sh
source_image='oci:./build/example.oci:candidate'
destination_image='docker://quay.io/foundata/example:<version>-candidate.<run-id>.g<source-revision-short>'

local_digest="$(skopeo inspect --format '{{.Digest}}' "${source_image}")"
skopeo copy --all --preserve-digests "${source_image}" "${destination_image}"
remote_digest="$(skopeo inspect --format '{{.Digest}}' "${destination_image}")"
test "${local_digest}" = "${remote_digest}"
```

`<run-id>` is the attempt's lowercase ULID. It sorts attempts by time and prevents reuse across builds of the same revision. The candidate becomes public at upload, after all rejecting content gates pass. Promotion and deployment still require verified registry signatures and attestations. Unpromoted candidates expire.


### Provenance<a id="provenance"></a>

- [Release provenance](#release-provenance) MUST use an in-toto Statement with a SLSA Provenance v1 predicate.
- The authorized release environment MUST generate provenance from observed build data, not unchecked caller input. A qualification or release tool there MAY generate the predicate from the accepted candidate record.
- Provenance MUST be generated from the accepted candidate record before publication, then validated and attached when the registry subject digest is known.
- A project MUST document its provenance generator integration. The trust root comes from maintainer-controlled release configuration and protected deployment configuration, not the project repository.


**The provenance MUST identify:**

- Every platform-specific subject digest and, where supported by the generator, the image-index digest.
- The canonical source repository and complete source revision.
- The Containerfile and relevant build configuration.
- External image materials by digest.
- The ContainerWright builder identity, release-environment mode and release-run identity, derived from embedded tool information and observed execution data.
- Relevant build parameters without secret values.
- Whether the build started locally or in CI, and its reviewed source revision.


**Identity separation.** Three identity families appear in a release and must never be conflated or accepted from untrusted input:

- The SLSA `runDetails.builder.id` identifies the ContainerWright builder implementation and comes from ContainerWright's embedded version information.
- The Cosign signing-key identity identifies the signing authority and comes from the approved public key or KMS/HSM key identity.
- The source repository, revision and release event identify the input and invocation that caused the build.

- Builder, signer and source or release-event identities MUST remain distinct and come from their authoritative sources; ContainerWright refuses to conflate them.
- ContainerWright MUST reject these identities when supplied by repository configuration, arbitrary command-line flags or ordinary environment overrides.


**You MUST:**

- Attach provenance to the registry as a signed Cosign attestation.
- Verify subject digests and trusted builder identity before deployment or promotion.
- Keep secret values out of provenance parameters and environment data.
- Describe the actual build; do not claim a SLSA build level unless every requirement of that level is implemented and audited.


### Signing and verification<a id="signing-and-verification"></a>

Cosign is the standard signing and attestation client. Command examples in this section use Cosign 3.x syntax; ContainerWright's supported-version matrix defines the exact accepted versions. The baseline signing model is a foundata-managed key pair. Generate the initial key material in a controlled environment:

```sh
umask 077
cosign generate-key-pair
```

Cosign writes the encrypted private key to `cosign.key` and public key to `cosign.pub`. Immediately move the private key to secret storage, delete the working copy and distribute the public key through maintainer-controlled release and protected deployment configuration. The authorized release environment obtains the key and passphrase through a protected secret mechanism. Neither belongs in repository files, command-line literals, logs or ordinary environment variables.

Sign immutable digests after uploading all image content. Upload makes the subject digest available to Cosign but does not promote the candidate. Registry and deployment policy reject it until signatures and required attestations pass verification.

Release signatures and signed attestations MUST use Cosign's supported default public [Sigstore transparency service](https://docs.sigstore.dev/logging/overview/) (Rekor). Signing MUST fail if log inclusion cannot be obtained, and release verification MUST verify that inclusion. Release commands MUST NOT disable transparency-log upload, use a no-log signing configuration or ignore transparency-log verification. Candidate signatures are the release signatures because promotion assigns tags to the same verified digest; the candidate and its evidence are already public by construction.

ContainerWright MUST NOT sign during checks, builds, tests, evidence generation or qualification. A workflow that does not publish a candidate therefore creates no transparency-log entry.


**You MUST:**

- Sign the image-index digest and every platform-manifest digest in a multi-platform release.
- Sign attestations and associate them with the exact subject digest.
- Encrypt the private key at rest, restrict access to the authorized release process and maintain a tested backup, rotation and revocation procedure.
- Verify signatures and attestations against the exact approved public key or managed-key identity.
- Verify the signature, SBOM attestation, provenance attestation and their transparency-log inclusion before promotion or deployment.
- Configure `containers-policy.json` or an equivalent admission policy to reject unsigned or untrusted production images; deployment environment owners enforce it.
- Test trust-policy changes with both a trusted image and an intentionally untrusted image.


**You SHOULD:**

- Move private-key operations to a KMS or HSM when that infrastructure is operationally available, so the release process receives permission to sign without receiving exportable private-key material.


**You MUST NOT:**

- Sign a tag as though the tag were immutable.
- Treat successful cryptographic verification as authorization without checking repository, digest, signer identity and attestation predicate.
- Use the same long-lived signing key across unrelated trust domains.


Signing and attestation:

```sh
cosign sign --yes \
  --key '/run/secrets/foundata-container-signing.key' \
  'quay.io/foundata/example@sha256:<image-index-digest>'

cosign attest --yes \
  --key '/run/secrets/foundata-container-signing.key' \
  --type spdxjson \
  --predicate example-linux-amd64.spdx.json \
  'quay.io/foundata/example@sha256:<platform-manifest-digest>'

cosign attest --yes \
  --key '/run/secrets/foundata-container-signing.key' \
  --type slsaprovenance1 \
  --predicate provenance.json \
  'quay.io/foundata/example@sha256:<image-index-digest>'
```

[Cosign verification](https://docs.sigstore.dev/cosign/verifying/verify/) requires the approved public key:

```sh
cosign verify \
  --key '/etc/foundata/trust/container-signing.pub' \
  'quay.io/foundata/example@sha256:<image-index-digest>'

cosign verify-attestation \
  --type spdxjson \
  --key '/etc/foundata/trust/container-signing.pub' \
  'quay.io/foundata/example@sha256:<platform-manifest-digest>'

cosign verify-attestation \
  --type slsaprovenance1 \
  --key '/etc/foundata/trust/container-signing.pub' \
  'quay.io/foundata/example@sha256:<image-index-digest>'
```

Manual signing experiments are outside ContainerWright and SHOULD use a disposable test key, never the release key. Keep them out of the public log. With Cosign 3.x, create a test-only [signing configuration](https://docs.sigstore.dev/cosign/system_config/custom_components/) without Fulcio, an OpenID Connect provider, Rekor or a timestamp authority. Store the signature in a Sigstore bundle and explicitly allow verification without transparency-log evidence:

```sh
cosign signing-config create \
  --no-default-fulcio \
  --no-default-oidc \
  --no-default-rekor \
  --no-default-tsa \
  --out './cosign-test-no-log.json'

cosign sign-blob --yes \
  --key './cosign-test.key' \
  --signing-config './cosign-test-no-log.json' \
  --bundle './test-artifact.sigstore.json' \
  './test-artifact'

cosign verify-blob \
  --key './cosign-test.pub' \
  --bundle './test-artifact.sigstore.json' \
  --insecure-ignore-tlog=true \
  './test-artifact'
```

These opt-outs are test-only and MUST NOT be used for a release.

- The approved public key or KMS/HSM identity MUST come from maintainer-controlled release configuration for release verification and protected deployment configuration for admission. It MUST NOT come from the signature or repository under review.
- The private key or KMS/HSM signing permission MUST be available only to the authorized release process through a protected secret facility. Signing credentials MUST NOT be stored in repository files or ordinary environment configuration.
- Registry and deployment policy MUST reject a candidate until its signatures and required attestations have been verified; deployment environment owners enforce admission.

Podman, Buildah and Skopeo consumers use the `sigstoreSigned` type in `containers-policy.json` when the deployed containers/image version supports the required identity model. Keep the registry namespace narrow and use `matchRepository` only for repository-level matching.



### Release evidence and retention<a id="release-evidence-and-retention"></a>

Signed registry attestations are the authoritative release evidence: each platform SBOM, SLSA provenance for the index and platforms, and the release-verification result. Workspace and CI artifacts are convenience copies.

After final verification, ContainerWright MUST generate the intermediate predicate `release-verification.json`. It is not a source comment or committed file. It MUST contain:

- Released repository, digest and verdict.
- ContainerWright version and source revision.
- Guide title, repository, path and revision.
- SHA-256 digest of `containerwright.toml`.
- Release-environment mode, host architecture and ContainerWright run identity.
- Signer mode and identity.
- Digests of verified evidence.

Identities MUST come from embedded ContainerWright data and observations by the authorized release environment, not caller-supplied values.

Release-environment mode MUST be `local` or `ci`. `local` identifies a release run on a maintainer-controlled workstation.

An illustrative predicate has this shape:

```json
{
  "schemaVersion": 1,
  "subject": {
    "repository": "quay.io/foundata/example",
    "digest": "sha256:<release-digest>"
  },
  "ruleset": {
    "containerwrightVersion": "<version>",
    "containerwrightRevision": "<containerwright-source-revision>",
    "guideTitle": "OCI container image build and release guide",
    "guideRepository": "https://github.com/foundata/guidelines",
    "guidePath": "oci-container-image-guide.md",
    "guideRevision": "<guide-revision>"
  },
  "repositoryConfiguration": {
    "path": "containerwright.toml",
    "sha256": "<configuration-digest>"
  },
  "releaseEnvironment": {
    "mode": "local",
    "hostArchitecture": "amd64",
    "runId": "<containerwright-generated-run-id>"
  },
  "signer": {
    "mode": "managed-key",
    "keyId": "<approved-public-key-identifier>"
  },
  "evidence": {
    "platformQualifications": ["sha256:<qualification-digest>"],
    "scanResults": ["sha256:<scan-result-digest>"],
    "sboms": ["sha256:<sbom-digest>"],
    "provenance": "sha256:<provenance-digest>"
  },
  "verdict": "pass"
}
```

Cosign wraps the predicate in an in-toto Statement and attaches it to the released digest as a signed attestation. The release environment MAY retain the JSON file for diagnostics, but the registry attestation is authoritative.

- Release-time verification MUST retain the signed release-verification attestation before promotion.
- The organization SHOULD export or back up release evidence so it survives registry migration or loss for the supported release lifetime.


**Scheduled rescans.**

- A scheduled rescan MUST resolve the subject by digest, enumerate every platform in an index, retrieve each SBOM attestation from the registry and verify its subject, signer and transparency-log inclusion against the trust root before scanning.
- An authoritative rescan result MUST record the scanner version; vulnerability database version or timestamp; guide revision; ContainerWright version and source revision; repository-configuration digest; rescan-job identity; subject digest; per-platform findings; triage state; and verdict.
- An informal local rescan is a useful diagnostic but is not release evidence and does not start or satisfy remediation duties.



## Linting and testing<a id="linting-and-testing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Every image repository owner MUST automate linting, clean builds and runtime tests. A locally successful build is not release evidence.


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


**Tests use the exact gated artifact.**

- Runtime tests MUST use the manifest imported from the gated OCI layout through a digest-preserving path.
- Before tests, the harness MUST recursively validate the layout's OCI descriptors and blobs, resolve the manifest from the runtime's containers-storage and compare it with the accepted layout digest.
- Any digest mismatch during test preparation MUST be treated as an operational failure, never as a policy pass or a skipped check.


**You SHOULD:**

- Use a dedicated smoke and structure test harness instead of unstructured shell. [Testinfra](https://testinfra.readthedocs.io/) is the default; [Goss](https://github.com/goss-org/goss) suits projects that prefer one Go binary and YAML over Python.
- Test a clean no-cache build periodically in addition to ordinary cached builds.
- Enforce a maximum image-size or layer regression threshold derived from the application, not a universal byte limit.
- Test the published digest after pulling it from the registry.
- Run scheduled rebuilds even when application source has not changed so base and package security updates are consumed; the organization owns the scheduling.


**You MUST NOT:**

- Add a Containerfile formatting tool to the pipeline.


Run Hadolint through the resolved release toolchain. Keep policy decisions in committed configuration, not flags. Use inline suppression only for a narrow, single-instruction exception. Buildah-supported syntax may occasionally produce false positives:

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

In-container Testinfra assertions require a shell because its Podman backend uses `podman exec`. Test shell-less `scratch` images from outside: use `podman inspect` for configuration and the network or health interface for behavior.



## Reference Containerfile<a id="reference-containerfile"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This example packages a prebuilt static executable with `scratch`. Most applications need a maintained base for certificate, timezone, user or shared-library data. Replace placeholders through the authorized release process and use `scratch` only after testing the [base-image requirements](#choosing-a-base-image).

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

- An application that compiles inside the Containerfile SHOULD add a pinned, approved `build` stage and copy only its verified output into this runtime stage.
- A dynamically linked application MUST instead use a compatible runtime base containing its required loader, libraries and runtime data.
- The repository owner MUST document how `build/example` is produced, tested and associated with the source revision recorded in the labels and provenance.

The corresponding minimal `.containerignore` for an externally built artifact is:

```gitignore
**
!build/
!build/example
!Containerfile
```

The example is a structural reference, not a universal base-image choice.



## Reasoning<a id="reasoning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- **Toolchain and Docker.** Buildah, Podman and Skopeo are rootless, daemonless and open source. Docker compatibility is incidental, untested and unsupported. Although based on open-source software, Quay.io and Sigstore's public infrastructure are hosted services with separate terms. Distributing tools may create license obligations even when their licenses do not cover generated images.
- **Local releases.** CI automates releases but is not the trust boundary. A maintainer workstation is safe when ContainerWright builds an isolated reviewed revision, runs the same gates, obtains external signing authority and records the environment. A local workflow also avoids dependence on one CI service.
- **Release tool versions.** Tool changes during a release make its evidence inconsistent. ContainerWright therefore resolves compatible versions once, records them and holds them constant. Global pins would impede upgrades without adding release identity: evidence identifies the tools, and the ContainerWright version identifies the rules.
- **Tool-owned rule identifiers.** ContainerWright needs stable check identifiers for precise findings and suppressions. Like Hadolint's `DL` codes, they belong to the tool, not this guide. Its conformance documentation maps them to stable guide anchors.
- **Versioned ruleset.** Embedding the guide revision identifies ContainerWright's implemented rules without a separate policy artifact. Recording both revisions distinguishes guide changes from implementation changes.
- **Candidate references.** One source revision can rebuild to different digests, so the revision alone cannot identify an attempt. A version or revision prefix groups related tags; the sortable, collision-resistant run identifier distinguishes attempts. Candidates stay in the final repository because OCI referrers, Cosign signatures and attestations are repository-scoped and `skopeo copy --all` does not move them. A separate repository requires explicit recreation and verification of that evidence at the final location.
- **Platform transport.** Records claim but do not prove their origin. Digest verification before assembly keeps qualification meaningful without separate transport authentication.
- **Registries.** Quay centralizes publishing, retention and tag mutation. Consume from the authoritative upstream registry because a similarly named repackaging is not equivalent. Use mirrors only for specific availability or policy needs; an unmaintained mirror becomes stale and unscanned.
- **Base images.** One mandatory distribution would sacrifice compatibility, lifecycle fit and diagnostic knowledge for superficial consistency. Image size is an incomplete measure of attack surface, which depends on reachable behavior, configuration and privileges. A smaller base also does not help a team that cannot patch or debug it. musl remains a compatibility boundary for glibc-targeted software.
- **Digest pinning and updates.** Tags document intent; digests select bytes. Pinning transfers change control to the repository and creates an update duty. A forgotten digest freezes its vulnerabilities, and pinning alone does not ensure reproducibility. Renovate therefore proposes, but cannot merge, trusted digest changes. It runs self-hosted and pinned; its AGPL-3.0-only license covers the tool, not updated repositories or images.
- **Pin intent and freshness.** Divergence under an immutable-version tag may be a supply-chain event; under a moving release line it is routine. Declared intent tells the pin gate which applies. The gate only reports, while Renovate remains the sole writer.
- **Build context.** The context is builder input and may be transferred, cached or inspected even when never copied into the image, so it is bounded with an allowlist.
- **Packages and caches.** Exact package pins block security updates and may become unavailable after repository rotation. The base digest and SBOM record installed packages. Caches improve speed but are not build inputs.
- **File ownership.** Mode `0555` does not protect a file owned by its executor, who can change the mode and rewrite it. Root ownership prevents this; a read-only root filesystem adds a second control.
- **Build arguments and environment.** `ARG` and `ENV` values appear in image configuration, logs, caches and provenance. Treat them as public unless the documented secret channel protects them end to end.
- **Users and resource limits.** A container user is not a complete security boundary but still limits compromise. Measure resource limits because applications size internal data from them. For example, an inherited `nofile` limit in the millions has created a connection table hundreds of megabytes large at idle.
- **Entrypoint.** The shell form inserts a shell that changes argument handling and can block signal delivery. Supervisors are limited to documented product contracts because each extra process obscures the signal path and exit status that deployment tooling depends on.
- **Health checks.** The OCI image format has no health-check field, and health policy is an environment decision, so the deployment layer owns it.
- **Multi-platform.** Emulated builds can hide target-architecture defects; cross-compiling is fine for the build but never replaces an on-target runtime test.
- **Execution modes.** A single `uname` value cannot distinguish native, emulated and cross-built execution. Recording target, host, execution architecture and mechanism for build and test gives ContainerWright the evidence needed to apply its rules.
- **Reproducibility.** Rebuildability is what an incident requires: a working replacement from documented inputs. Bit-for-bit equivalence is desirable evidence but must be measured, not assumed.
- **Exact-digest releases.** Security statements bind to digests. Local OCI layouts allow content gates before publication; Skopeo's digest-preserving copy and recursive comparison prove that Quay received the accepted manifest and blobs. Rebuilding or transforming the upload breaks that link. Registries lack portable compare-and-swap and multi-tag transactions, so pre-write checks, post-write comparisons and failure records provide detection and fail-closed continuation, not atomicity.
- **One scanner stack.** Scanner databases and matching differ, so parallel gates create conflicting findings and duplicate exceptions. Second opinions remain non-gating. Trivy also supplies the required secret and configuration scans. Registry scanning adds defense but cannot replace the release gate, and an empty result does not prove security. Busy CI runners can hit Trivy's public database rate limits. Cache it, configure `--db-repository` or host a mirror. Rescan retained SBOMs to reduce cost.
- **Rescan scope.** An SBOM rescan matches known vulnerabilities against retained inventory. It cannot scan secrets or configuration without the filesystem. Evidence therefore states the scope; configurations requiring those scans must fetch the immutable image.
- **Remediation clocks.** Starting at an informal scan allows resets; starting at publication penalizes later discoveries. The authoritative rescan result provides a fixed start. Record later triage and exceptions as new results. Never repoint a version tag, which would change content already verified by consumers.
- **Provenance and signing.** Correct SLSA fields alone do not establish trust. The generator must run in the authorized release environment, and verification must use the approved signing key. The managed key pair keeps key custody under foundata's control; the public transparency log makes release signing auditable. Manual experiments use disposable keys without log upload to avoid permanent test entries and release-key associations. KMS or HSM protection can later reduce exposure of exportable keys. Keep builder, signer and source identities separate so one compromise cannot impersonate all three.
- **Evidence retention.** Registry attestations are authoritative only while they remain fetchable and verifiable. A registry migration can orphan them, so exports or backups should match the release support lifetime.
- **Formatting and test harness.** No Containerfile formatter has ecosystem authority, and Hadolint does not format. Lint rules and review enforce layout. Testinfra reuses the [Python style guide's](./python-style-guide.md) pytest stack; Goss offers one Go binary with YAML assertions.



## Author information<a id="author-information"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) for OCI container images maintained in source repositories.
