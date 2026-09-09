# OCI container image build and release guide

This guide defines how foundata builds and publishes Linux
[OCI container images](https://github.com/opencontainers/image-spec) from
[Containerfiles](https://github.com/containers/common/blob/main/docs/Containerfile.5.md).
It is for application developers, infrastructure engineers and reviewers who
already understand containers.

The image is the release artifact. The guide covers its Containerfile, build
context, registry references, platforms, runtime contract,
[software bill of materials (SBOM)](https://spdx.dev/use/specifications/),
scans, provenance, signatures and verification. [Reasoning](#reasoning) explains
the contested rules.

[ConClear](#terminology) enforces automatable rules. Its conformance
documentation maps each check to the
[requirement identifiers](#requirement-identifiers) it covers. Review covers the
remaining rules.

The terms MUST, SHOULD, and other key words are used as defined in
[RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) and
[RFC 8174](https://datatracker.ietf.org/doc/html/rfc8174).


## Table of contents

- [Goals and scope](#goals-and-scope)
- [Terminology](#terminology)
- [Requirement identifiers](#requirement-identifiers)
- [Release workflow](#release-workflow)
  - [First release from a workstation](#first-release-from-a-workstation)
  - [Operating supported releases](#operating-supported-releases)
- [Supported tools, syntax and platforms](#supported-tools-syntax-and-platforms)
  - [ConClear version identity](#conclear-version-identity)
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
    - [Retaining the referenced bytes](#retaining-the-referenced-bytes)
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
- Minimal in installed functionality without optimizing for byte count at the
  expense of supportability.
- Suitable for an unprivileged, read-only runtime where the application permits
  it.
- Accompanied by machine-readable inventory, provenance and cryptographic
  identity.
- Rebuilt and rescanned through automation.


This guide covers Linux images built from Containerfiles for services, one-shot
tasks and OS/integration-test targets. It also covers intermediate stages that
affect the final artifact.

It is foundata's release policy for public container images, and it binds its
toolset deliberately: ConClear, Buildah, Podman, Skopeo, Hadolint, Trivy,
Cosign, Quay and the public Sigstore transparency log are requirements, not
examples. Another organization can adopt the guide and the toolset as a whole
with its own source repositories, Quay organization and repositories; where the
text names foundata, the adopting organization takes its place. Tool-neutral or
provider-neutral variants are not a goal.

**The following are explicitly out of scope:**

- Windows containers.
- Private images. Their transparency and disclosure rules differ from the public
  rules stated here and are not defined by this guide.
- GitHub container actions.
- Docker compatibility testing and Docker-specific build extensions.
- Orchestrator-specific deployment policy except where it verifies the image
  release contract.
- A complete application-language build policy; use the relevant foundata
  language guide for that code.
- Release-environment configuration, registry retention, scheduling and
  deployment authorization. The release and deployment environments own these
  controls; this guide states their required properties.


## Terminology<a id="terminology"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- An **[OCI](https://opencontainers.org/) image** is the content-addressed
  collection of manifests,
  [configuration](https://github.com/opencontainers/image-spec/blob/main/config.md)
  and filesystem layers defined by the OCI Image Specification.
- A **Containerfile** is the declarative build recipe consumed by
  [Buildah](https://github.com/containers/buildah/blob/main/docs/buildah-build.1.md)
  or
  [`podman build`](https://docs.podman.io/en/stable/markdown/podman-build.1.html).
  OCI standardizes the resulting image format, not the Containerfile language.
- An **image index**, also commonly called a manifest list, selects a
  platform-specific image manifest for each supported operating-system and
  architecture pair.
- A **tag** is a mutable human-readable registry reference such as `:1.4`. A
  **digest** is an immutable content identity such as `@sha256:...`.
- A **base image** is an external image named by a `FROM` instruction. External
  images used by `COPY --from` or a build mount are supply-chain inputs too,
  even when they are not called base images.
- **`scratch`** is a reserved empty base, not an image pulled from a registry. A
  `FROM scratch` stage contains only files and configuration added by later
  instructions. The application must provide every executable, shared library,
  certificate, timezone file and other runtime dependency it needs.
- An **attestation** is signed metadata about an image, such as an SBOM or
  provenance statement.
- **Release provenance**<a id="release-provenance"></a> is machine-readable
  evidence of how and where an image was built and which source code and
  dependencies were used.
- A **release image** is an image manifest or image index that has passed the
  required tests and policy gates and has been published by the release process.
- **ConClear** is the foundata command-line tool that implements this guide's
  automatable rules. Each release identifies its guide revision and maps its
  checks to the guide's requirement identifiers.
- **Repository configuration** is the version-controlled `conclear.toml` file
  containing project facts and permitted exceptions. It may narrow built-in
  rules but cannot relax an unconditional `MUST` or `MUST NOT` or extend a
  built-in maximum.
- A **platform qualification** is the per-image, per-platform record of
  observations, evidence digests and the platform verdict produced by
  qualification on one build worker, one record per target platform.
- A **release candidate** is the aggregate record produced by assembly from one
  or more accepted platform qualifications. It identifies the exact image
  manifest or image index eligible for publication.
- A **candidate reference** is a reserved, single-use tag for one publication
  attempt of an accepted digest. Its `-candidate.` suffix follows the release
  version or source revision so related tags sort together.
- **Evidence** is the machine-readable, digest-bound output of the release
  process, including SBOMs, scans, qualifications and verification results.
  Signed registry attestations are the authoritative retained evidence.
- A **trust root** is the approved set of public signing keys or managed-key
  identities against which signatures and attestations are verified. It is
  supplied through maintainer-controlled release configuration or protected
  deployment configuration, not by the repository being verified.
- A **builder identity** is a stable HTTPS URI naming one build-platform trust
  domain. Its documentation defines the people, systems and software trusted to
  run the build and record its provenance.
- An **authorized release environment** is a maintainer-controlled Linux
  workstation or protected CI job. It runs ConClear on a reviewed commit and
  obtains trust configuration and signing authority outside the repository and
  arbitrary command-line input.


## Requirement identifiers<a id="requirement-identifiers"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Every normative statement in this guide is a list item that ends with a stable
requirement identifier, for example `IG0042`. An identifier names the rule, not
its position: a statement keeps its identifier when it moves or is reworded, and
an identifier is never reused. ConClear owns the identifiers of its checks and
maps each check to the requirements it covers; its conformance documentation
states, for every identifier at the implemented guide revision, whether ConClear
automates the requirement, lists it for human review, leaves it to an external
control or does not support it. Control notes beside the rules distinguish a
ConClear check from manual review or an external control. A check can observe
part of an external control without taking over its operation; the conformance
documentation identifies the coverage of the selected ConClear release.

**When editing this guide:**

- Write every normative statement as a list item that contains an RFC 2119
  keyword or follows a lead-in that carries one, and give it the next unused
  identifier regardless of its position in the document.
- Keep the identifier when rewording a statement without changing its
  obligation, its subject or when it applies.
- Retire the identifier and issue new ones when an edit changes what the
  statement requires, whom it binds or when it applies, including a split into
  several statements or a merge into one.
- Record every retired identifier under
  [Retired requirement identifiers](#retired-requirement-identifiers) with its
  successors or the reason for removal.
- Run `scripts/check-requirement-identifiers.py` before publishing; its `--fix`
  option assigns identifiers to new statements and `--list` prints the inventory
  ConClear consumes.


### Retired requirement identifiers<a id="retired-requirement-identifiers"></a>

No identifiers are retired.


## Release workflow<a id="release-workflow"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Every image repository owner MUST automate the repository's release-security
  controls; a release assembled by hand is not a release.
  `IG0001`<a id="ig0001"></a>
- A release MUST run through ConClear in an authorized release environment,
  using a clean release checkout of a reviewed, committed source revision.
  `IG0002`<a id="ig0002"></a>
- The complete release workflow through promotion MUST be runnable on a secure,
  maintainer-controlled Linux workstation. CI MAY invoke the same workflow but
  MUST NOT be the only implementation of release logic.
  `IG0003`<a id="ig0003"></a>
- For every release, ConClear MUST build from an isolated checkout or detached
  worktree of the selected application commit. This repository contains the
  Containerfile, `conclear.toml`, build scripts and dependency declarations. The
  ordinary worktree may be dirty, but uncommitted or untracked files MUST NOT
  enter the release. `IG0004`<a id="ig0004"></a>

Control: manual review establishes that the selected commit is approved.
ConClear checks the checkout's identity and bytes; a matching Git revision does
not establish who reviewed its contents.

**The release workflow MUST execute these steps in order.** ConClear orders its
steps; the authorized release environment orders external steps. The links
define each step's requirements:

1. Run source, dependency-lock, [Containerfile](#linting-and-testing),
   [context](#build-context) and repository checks. `IG0005`<a id="ig0005"></a>
2. Validate declared container-image dependency and
   [base-image pins](#pinning-image-references). `IG0006`<a id="ig0006"></a>
3. First build, import, re-verify and [test](#linting-and-testing) `linux/amd64`
   in a [recorded execution mode](#multi-platform-images); every release
   requires this platform. `IG0007`<a id="ig0007"></a>
4. Repeat the build, import, re-verification and test sequence on every other
   required platform worker. `IG0008`<a id="ig0008"></a>
5. Generate each platform [SBOM](#sboms), run the local
   [release scan gate](#vulnerability-and-configuration-scanning), and emit a
   platform qualification binding the layout, SBOM, scan results and verdict by
   digest. `IG0009`<a id="ig0009"></a>
6. When transport is needed,
   [verify the recorded digests](#multi-platform-images) of layouts, evidence
   and qualifications before assembly. Assemble an OCI image index for a
   multi-platform release. `IG0010`<a id="ig0010"></a>
7. Aggregate the accepted platform qualifications into one release-candidate
   record and generate the [SLSA provenance predicate](#provenance) in the
   authorized release environment. `IG0011`<a id="ig0011"></a>
8. Publish the exact accepted manifest or index to a unique
   [candidate reference](#registries-and-image-names) in the final release
   repository. `IG0012`<a id="ig0012"></a>
9. Resolve the remote reference and compare its digest with the accepted local
   digest. `IG0013`<a id="ig0013"></a>
10. Attach [SBOM](#sboms) and [provenance](#provenance) attestations and
    [sign](#signing-and-verification) the index digest and every
    platform-manifest digest. `IG0014`<a id="ig0014"></a>
11. Verify digest coverage, signatures, attestations, identities and guide
    compliance, then retain a signed
    [release-verification result](#release-evidence-and-retention).
    `IG0015`<a id="ig0015"></a>
12. Promote only the verified digest according to the
    [release-tag model](#registries-and-image-names).
    `IG0016`<a id="ig0016"></a>
13. Retain verifiable [evidence](#release-evidence-and-retention) and arrange
    the organization's scheduled [rescans](#rescans-and-remediation) and
    [rebuilds](#rebuildability-and-reproducibility). `IG0017`<a id="ig0017"></a>


- The release workflow MUST NOT sign before the image has its final registry
  digest. ConClear refuses subjects not resolved and digest-checked at the
  registry. `IG0018`<a id="ig0018"></a>
- The release workflow MUST NOT promote by rebuilding; promotion copies or
  retags the already verified digest so the artifact that passed policy remains
  the artifact consumers receive, enforced by ConClear.
  `IG0019`<a id="ig0019"></a>


### First release from a workstation<a id="first-release-from-a-workstation"></a>

A native Linux workstation or ordinary Linux VM can run the complete workflow
in `IG0003`. An x86-64 host provides native execution for the required
`linux/amd64` platform; additional platforms follow the
[execution and transport rules](#multi-platform-images). The host needs access
to source and image registries, scanner databases and public Sigstore services.
No ConClear container image, CI runner, KMS or new platform service is needed.

The initial setup is:

1. Install a supported Python version and the host tools listed by the selected
   ConClear release: Git, Buildah, Podman, Skopeo, Hadolint, Trivy and Cosign.
   Configure rootless Buildah and Podman for the release user.
2. Install a ConClear wheel whose source revision and checksum the release
   maintainer has approved. Check its installed source and guide identity with
   `conclear version --format json`. Before a published wheel is available,
   ConClear's
   [distribution release gate](https://github.com/foundata/conclear/blob/main/DEVELOPMENT.md#release-procedure)
   builds and retains an identified wheel from a clean, reviewed ConClear
   checkout. That gate runs locally and does not need a container release.
3. Commit and review the image's Containerfile, build inputs and
   `conclear.toml`, including the required platforms, runtime tests and release
   tags. A moving tag such as `latest` belongs in `release.moving_tags`.
4. Reuse the organization's protected release profile for this build trust
   domain, or create it once outside the image repository, with
   `ci_context = "omit"`, the documented builder identity, an encrypted local
   Cosign key and its approved public key. Keep the passphrase and Quay
   credentials in protected files outside the repository as well.
   Scope writer permissions to the intended repositories where the registry
   supports it. A new image repository does not need a new builder identity or
   another copy of the signing keys.
5. Prepare the destination Quay repository. Prefer selective version-tag
   protection; where it is unavailable, record the reason and owner in the
   protected profile. Declare a candidate-cleanup owner, procedure and mode.
   Native expiration or auto-pruning is recommended; manual cleanup is an
   accepted fallback. Grant the permissions needed by the selected controls,
   following the
   [ConClear quick start](https://github.com/foundata/conclear/blob/main/docs/quickstart.md#5-prepare-release-access).

With the profile named `foundata` and the release image named `app`, run from
the image repository:

```sh
conclear doctor --config conclear.toml --profile foundata
conclear release --source . --revision v1.2.3 --image app \
  --version 1.2.3 --profile foundata
```

When exactly one release image is configured, `--image app` may be omitted;
test-only dependencies do not count as release images. Platforms remain
explicit. `conclear config show --version 1.2.3` reports effective defaults,
runtime-profile mounts, pin limits and decision reasons without building or
contacting registries. It also checks the rendered tags. An unused tag class or
optional table need not be declared, but every release needs at least one final
tag. Keep resource measurements and reviewed privilege requirements explicit.
`adopt` leaves these owner decisions unresolved and validation reports them
together; a generated draft is not evidence that the decisions were made.

`doctor` diagnoses prerequisites without publishing or signing; the `release`
command performs qualification through verified promotion. The
[quick start](https://github.com/foundata/conclear/blob/main/docs/quickstart.md)
contains the installation and configuration details. CI can later call the
same command with its own protected release profile and documented builder
identity. It does not need a second implementation of the release steps.


### Operating supported releases<a id="operating-supported-releases"></a>

The first release provisions the workstation, credentials and registry policy.
Supported releases also need continuing operation. These duties can belong to
one maintainer and run on an existing managed host.

- The organization MUST name an owner for credential and signing-key custody,
  registry writer permissions, candidate and release retention, the supported
  release inventory, scheduled rescans, vulnerability triage and rebuilds.
  Record the owners and procedures in a maintained operating document outside
  the public evidence bundle; one person may own several duties.
  `IG0424`<a id="ig0424"></a>
- The release owner MUST maintain a supported-release inventory keyed by
  repository and immutable digest. Each entry MUST identify its platforms,
  support status, owner, source revision, exact repository-configuration digest
  and retained checkout, evidence location, trusted signer, latest verified
  authoritative rescan digest when one exists, completed-assessment time and
  next due time.
  Operational failures or missed jobs MUST NOT advance the completed-assessment
  time. `IG0425`<a id="ig0425"></a>
- The scheduling owner MUST provide an available execution host, protected
  persistent state and credentials, monitoring for failed or overdue work, and
  an owned recovery procedure. Preserve pin observations and rescan history
  across jobs and host replacement; verify recovery without resetting an
  existing remediation clock. `IG0426`<a id="ig0426"></a>

Control: external (release and scheduling owners). ConClear runs a requested
release or rescan and records its outcome. It does not maintain the supported
release inventory, schedule the next invocation, alert an owner or perform a
remediating rebuild by itself.

Before the first rescan, record the qualifying release assessment and leave
the rescan history head empty. A verified authoritative rescan that rejects an
image is still a completed assessment. Its result advances the signed history;
the scheduling owner alerts the triage owner. An operational failure produces
no such assessment.

The operating document can be short:

|              Duty               | Operator's continuing check |
| ------------------------------- | --------------------------- |
| Credentials and keys            | Review authorized access; test backup, rotation and revocation procedures. |
| Registry writers                | Limit who can publish, change policies or delete supported content; review permission changes. |
| Candidate retention             | Remove abandoned candidates through the declared procedure; monitor automated expiry or pruning when configured. |
| Supported releases and evidence | Keep the digest inventory current; check that retained files and registry attestations remain retrievable. |
| Rescans                         | Run every due supported digest, record the result and notify its owner on failure or a rejecting verdict. |
| Triage and rebuilds             | Assign findings, track their deadlines, release corrected digests and record superseded or ended support. |

A systemd timer or cron job on an existing managed host can invoke
`conclear rescan --authoritative` for each due digest using its retained
configuration and protected release profile. A timer definition alone does not
provide monitoring or availability. The owner checks missed runs, preserves
state and arranges recovery after downtime. CI is another possible caller of
the same commands. The [retention recipe](#retaining-the-referenced-bytes)
describes the files needed for later rescans.


## Supported tools, syntax and platforms<a id="supported-tools-syntax-and-platforms"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[Buildah](https://buildah.io/) is the normative image builder.
[Podman](https://podman.io/) is the normative local runtime and may invoke the
Buildah build implementation through `podman build`.
[Skopeo](https://github.com/containers/skopeo) is the normative tool for
inspecting and
[copying registry content](https://github.com/containers/skopeo/blob/main/docs/skopeo-copy.1.md)
without running it.

**You MUST:**

- Make the Containerfile build successfully with a Buildah version supported by
  the selected ConClear release in rootless mode. `IG0020`<a id="ig0020"></a>
- Produce OCI image format. This is Buildah and Podman's default; specify
  `--format oci` when a surrounding tool or configuration could change the
  default. `IG0021`<a id="ig0021"></a>
- Test the image with Podman. `IG0022`<a id="ig0022"></a>
- Build and publish `linux/amd64` images. `IG0023`<a id="ig0023"></a>
- Use syntax documented by the
  [Containerfile manual](https://github.com/containers/common/blob/main/docs/Containerfile.5.md).
  `IG0024`<a id="ig0024"></a>
- Use a ConClear release that implements the selected guide revision. At release
  start, it resolves and records host-tool versions and tool-image digests,
  rejects unsupported versions and holds the toolchain constant.
  `IG0025`<a id="ig0025"></a>

**You SHOULD:**

- Build and test each platform natively or under
  [QEMU user-mode emulation](https://www.qemu.org/docs/master/user/). Prefer a
  native worker when the image compiles or ships architecture-specific native
  code or depends on kernel or CPU features that emulation does not reproduce.
  `IG0026`<a id="ig0026"></a>
- Keep local and continuous-integration tool versions aligned.
  `IG0027`<a id="ig0027"></a>
- Pin supporting tools when predictable upgrades or reconstruction justify it.
  Supported, recorded tool upgrades between releases are permitted.
  `IG0028`<a id="ig0028"></a>

**You MAY:**

- Build and publish `linux/arm64` images. `IG0029`<a id="ig0029"></a>

**You MUST NOT:**

- Require a Docker daemon or Docker BuildKit to build, test or release the
  image. `IG0030`<a id="ig0030"></a>
- Add Docker BuildKit parser directives or Docker-only Containerfile extensions.
  `IG0031`<a id="ig0031"></a>
- Claim Docker compatibility unless a project separately builds and tests the
  image with explicitly supported Docker versions. `IG0032`<a id="ig0032"></a>


The recommended supporting tools are:

|          Concern          |                                                            Tool                                                            |                                                      Role                                                       | License |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- | ------- |
| Build                     | [Buildah](https://github.com/containers/buildah)                                                                           | Rootless OCI image and image-index construction                                                                 | Apache-2.0 |
| Run and smoke-test        | [Podman](https://github.com/containers/podman)                                                                             | Daemonless container runtime                                                                                    | Apache-2.0 |
| Inspect and copy          | [Skopeo](https://github.com/containers/skopeo)                                                                             | Registry inspection, digest resolution and transport                                                            | Apache-2.0 |
| Guide enforcement         | ConClear                                                                                                                   | Deterministic checks, qualification, publication and verification per this guide                                | GPL-3.0-or-later |
| Dependency pin updates    | ConClear                                                                                                                   | Non-mutating pin proposals and verified, all-or-nothing local application                                       | GPL-3.0-or-later |
| Update review delivery    | [Renovate](https://docs.renovatebot.com/modules/manager/dockerfile/) or equivalent                                         | Optional branch and pull-request delivery of conforming proposals                                               | Tool-specific |
| Static linting            | [Hadolint](https://github.com/hadolint/hadolint)                                                                           | Containerfile correctness and maintainability checks                                                            | GPL-3.0-only |
| Smoke and structure tests | [Testinfra](https://testinfra.readthedocs.io/)                                                                             | pytest-based assertions against a running container                                                             | Apache-2.0 |
| SBOM and scanning         | [Trivy](https://trivy.dev/docs/latest/target/container_image/)                                                             | [SPDX SBOM](https://trivy.dev/docs/latest/supply-chain/sbom/), vulnerability, secret and configuration scanning | Apache-2.0 |
| Signing and attestations  | [Cosign](https://docs.sigstore.dev/cosign/)                                                                                | Sigstore-compatible image signatures and attestations                                                           | Apache-2.0 |
| Provenance format         | [in-toto Attestation](https://github.com/in-toto/attestation) and [SLSA Provenance](https://slsa.dev/spec/v1.0/provenance) | Standard statement and predicate formats                                                                        | Apache-2.0 and Community Specification License 1.0 |
| Pull-time trust           | [`containers-policy.json`](https://github.com/containers/image/blob/main/docs/containers-policy.json.5.md)                 | Signature policy enforcement for containers/image consumers                                                     | Apache-2.0 |


### ConClear version identity<a id="conclear-version-identity"></a>

**Every ConClear release MUST:**

- Expose human-readable and machine-readable version information that includes
  the tool version, its full source revision, and the title, repository, path
  and full revision of the implemented guide. `IG0033`<a id="ig0033"></a>
- Embed these values at build time, not read them from the repository under
  test. `IG0034`<a id="ig0034"></a>
- Expose the machine-readable identity through stable fields defined by
  ConClear's record schemas, so release evidence names the implemented ruleset.
  `IG0035`<a id="ig0035"></a>
- Map every check to the requirement identifiers it covers and state, for every
  identifier of the implemented guide revision, whether it is automated, needs
  human review, is left to an external control or is unsupported.
  `IG0036`<a id="ig0036"></a>
- State the release's built-in limits and defaults in its conformance
  documentation. `IG0037`<a id="ig0037"></a>

**ConClear MUST NOT:**

- Claim to implement a rule that requires human review.
  `IG0038`<a id="ig0038"></a>

The human-readable output looks like this:

```text
$ conclear version
ConClear <version> (commit <conclear-source-revision>)
Implements the automatable rules of foundata "OCI container image build and release guide", oci-container-image-guide.md at commit <guide-revision>
```

`conclear version --format json` exposes the same identity; ConClear's schemas
define the exact fields:

```json
{
  "name": "conclear",
  "version": "<version>",
  "sourceRevision": "<conclear-source-revision>",
  "guide": {
    "title": "OCI container image build and release guide",
    "repository": "https://github.com/foundata/guidelines",
    "path": "oci-container-image-guide.md",
    "revision": "<guide-revision>"
  }
}
```

## When to create a container image<a id="when-to-create-a-container-image"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You SHOULD create an image when:**

- The application and its runtime dependencies need to be released and promoted
  as one content-addressed artifact. `IG0039`<a id="ig0039"></a>
- The target platform runs OCI containers and benefits from an explicit
  filesystem, user and process contract. `IG0040`<a id="ig0040"></a>
- The release pipeline can rebuild, scan, sign and maintain the image for its
  supported lifetime. `IG0041`<a id="ig0041"></a>

**You SHOULD NOT create an image when:**

- A native package, static executable, library or archive is the actual
  interface consumers require. `IG0042`<a id="ig0042"></a>
- Containerization would conceal unsupported host dependencies or privileged
  behavior instead of removing them. `IG0043`<a id="ig0043"></a>
- No owner can maintain the base image, dependencies and vulnerability response
  after initial publication. `IG0044`<a id="ig0044"></a>


## Files and layout<a id="files-and-layout"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Name a new build recipe `Containerfile`. `IG0045`<a id="ig0045"></a>
- Store the Containerfile in the smallest directory that contains its intended
  build context, or pass an explicit narrower context from automation.
  `IG0046`<a id="ig0046"></a>
- Use UTF-8 without a [BOM](https://en.wikipedia.org/wiki/Byte_order_mark), Unix
  line endings and one final newline. `IG0047`<a id="ig0047"></a>
- Write instruction keywords in uppercase. `IG0048`<a id="ig0048"></a>
- Give every named stage a short lowercase name that describes its purpose, such
  as `build`, `test` or `runtime`. `IG0049`<a id="ig0049"></a>
- Keep comments focused on constraints and non-obvious decisions.
  `IG0050`<a id="ig0050"></a>

**You SHOULD:**

- Order instructions from relatively stable inputs to frequently changing inputs
  so that local caching remains useful. `IG0051`<a id="ig0051"></a>
- Put one logical operation in each instruction while combining commands that
  must share a layer, such as package installation and cache cleanup.
  `IG0052`<a id="ig0052"></a>
- Put small supporting scripts in a version-controlled `scripts/` directory
  beside the Containerfile and `COPY` them instead of embedding large shell
  programs in `RUN`. Another documented location is permitted when the
  repository layout requires it. `IG0053`<a id="ig0053"></a>
- Follow the [shell scripting style guide](./shell-scripting-style-guide.md) for
  non-trivial shell code executed during a build or used as an entrypoint.
  `IG0054`<a id="ig0054"></a>

**You MAY:**

- Retain the conventional `Dockerfile` filename in an inherited repository when
  renaming it would cause disproportionate disruption.
  `IG0055`<a id="ig0055"></a>
- Use a dedicated filename such as `Containerfile.integration` for a genuinely
  different build purpose. `IG0056`<a id="ig0056"></a>

**You MUST NOT:**

- Add a `# syntax=...` directive that requires Docker BuildKit.
  `IG0057`<a id="ig0057"></a>
- Generate a Containerfile dynamically when ordinary build arguments or separate
  explicit Containerfiles express the variants clearly.
  `IG0058`<a id="ig0058"></a>
- Hide release behavior in undocumented wrapper scripts.
  `IG0059`<a id="ig0059"></a>
- Create Containerfile suffix variants for differences that belong in runtime
  configuration. `IG0060`<a id="ig0060"></a>


## Registries and image names<a id="registries-and-image-names"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

[Quay.io](https://docs.projectquay.io/quay_io.html) (`quay.io`) is the release
registry for public images; foundata publishes under its
[foundata](https://quay.io/organization/foundata) organization. This rule
chooses where the organization publishes images; it does not prohibit consuming
upstream images from their authoritative registries. ConClear separates standard
OCI image transport from provider-specific registry controls and uses one
explicitly configured backend from its compiled support matrix. Quay.io is
currently the only implemented release-registry backend.

**You MUST:**

- Publish public images under the organization's approved `quay.io` organization
  and repository. ConClear verifies the registry and configured release
  repository. `IG0061`<a id="ig0061"></a>
- Use fully qualified registry and repository names for every image reference.
  `IG0062`<a id="ig0062"></a>
- Verify the publisher and pin every external image input by digest as described
  in [Pinning image references](#pinning-image-references).
  `IG0063`<a id="ig0063"></a>
- Use lowercase repository names consisting of stable product or component
  names. `IG0064`<a id="ig0064"></a>
- Treat repository deletion, renaming and tag mutation as controlled operations
  because consumers may depend on them. `IG0065`<a id="ig0065"></a>
- Configure automated registry retention so it does not delete release digests,
  signatures, SBOMs or attestations that remain supported; the organization owns
  registry retention configuration. `IG0066`<a id="ig0066"></a>
- Use a release-registry backend supported by the selected ConClear release for
  `publish` through `promote`. ConClear MUST reject an unsupported destination
  before remote mutation. Checks, builds, tests, qualification, evidence
  generation, assembly and provenance generation remain available for other
  fully qualified repositories. `IG0067`<a id="ig0067"></a>
- A mirror owner MUST record the upstream repository and digest, preserve
  required index membership, scan the content, apply the organization's trust
  policy and automate reviewed refreshes. `IG0068`<a id="ig0068"></a>

**You SHOULD:**

- Prefer an equivalent image on Quay over Docker Hub when the same trusted
  publisher maintains both with the required platforms, lifecycle and update
  cadence. `IG0069`<a id="ig0069"></a>
- Consume an image from its authoritative upstream registry when no equivalent
  Quay source exists. This includes fully qualified Docker Official Image
  references such as `docker.io/library/debian`. `IG0070`<a id="ig0070"></a>
- Mirror an upstream image when the organization needs additional availability,
  retention or policy control. `IG0071`<a id="ig0071"></a>

**You MUST NOT:**

- Use short names such as `fedora`, `alpine` or `my-image` in a Containerfile or
  release command. `IG0072`<a id="ig0072"></a>
- Substitute an unrelated Quay repackaging solely to avoid an authoritative
  upstream registry. `IG0073`<a id="ig0073"></a>
- Depend on an engineer's local `registries.conf` search list or short-name
  alias resolution. `IG0074`<a id="ig0074"></a>
- Publish credentials, private source references or internal hostnames in public
  labels or attestations. `IG0075`<a id="ig0075"></a>


**Supported release-registry contract.** A supported backend and its operator
have these responsibilities:

- The backend MUST preserve the complete OCI manifest, index, configuration and
  blob graph without digest transformation. `IG0076`<a id="ig0076"></a>
- The backend MUST resolve exact tags and digests without treating ambiguous
  remote state as absence. `IG0077`<a id="ig0077"></a>
- The backend MUST store and retrieve Cosign signatures and attestations for
  image indexes and platform manifests in the released subject's repository.
  `IG0078`<a id="ig0078"></a>
- The release owner MUST declare an owner and procedure for removing abandoned
  candidates in the protected release profile. Manual cleanup is an accepted
  fallback and requires retained ownership records.
  `IG0079`<a id="ig0079"></a>
- The registry SHOULD enforce selective version-tag immutability while leaving
  candidate and declared moving tags mutable. `IG0080`<a id="ig0080"></a>
- The backend MUST assign release tags only to the verified digest and permit an
  exact post-write observation. `IG0081`<a id="ig0081"></a>
- The backend MUST delete an owned candidate reference and permit conclusive
  verification of its removal. `IG0082`<a id="ig0082"></a>
- The backend MUST expose enough remote state for ConClear to recover safely
  from interrupted or ambiguous writes. `IG0083`<a id="ig0083"></a>
- The backend MUST use externally supplied, narrowly scoped credentials without
  placing secret values in repository configuration or release evidence.
  `IG0084`<a id="ig0084"></a>
- The release owner SHOULD automate candidate cleanup through native tag
  expiration, a candidate-only pruning policy or a scheduled cleanup command.
  Automation does not require CI or a new platform service.
  `IG0085`<a id="ig0085"></a>

Control: ConClear refuses conflicting version-tag writes and verifies each
assignment. Registry enforcement, where required by the protected profile,
adds protection against other writers. Without it, the operator owns tag
stability, narrow writer permissions and release serialization. ConClear cannot
prevent concurrent or later writes by another client or an administrator.

Candidate authorization expires independently of cleanup. ConClear records the
original deadline before upload and refuses promotion after it, even if the tag
still exists. Selected native expiration and pruning controls are verified;
unavailable controls are not silently treated as successful. A manual profile
does not require these APIs. An interrupted upload may leave an orphaned tag,
which the cleanup owner removes. Automatic pruning survives loss of the local
run state, but its availability is not a prerequisite for a qualified release.
Pruning and garbage collection remain asynchronous and do not promise erasure
of published bytes at an exact instant.


**Release-tag model.** Tags communicate a release channel or human-readable
version; digests identify content.

- A project with versions MUST publish a version tag such as `:1.8.2` and MUST
  NOT repoint it to different content. Registry enforcement is a separate
  control; the repository declares these names in `release.version_tags`.
  `IG0086`<a id="ig0086"></a>
- Moving convenience tags such as `:1`, `:stable` or `:latest` MAY exist.
  `IG0087`<a id="ig0087"></a>
- Deployment environment owners MUST configure digest-only admission and
  deployment controls so every moving convenience tag is resolved to a digest
  and authorization operates on that digest. `IG0088`<a id="ig0088"></a>


**Candidate references.** A candidate reference makes an accepted digest
addressable for attestation and verification before promotion. It is not a
release tag and receives no release-retention guarantee.

- By default, a publication attempt MUST use a version-first candidate tag in
  the final repository. A versioned release uses
  `<version>-candidate.<run-id>.g<source-revision-short>`, for example
  `1.8.2-candidate.01k3z8h6v4n7c2m9p5q1r0s8tx.g7ac94d12`. An unversioned project
  uses `g<source-revision-short>-candidate.<run-id>`. ConClear generates and
  validates the tag. `IG0089`<a id="ig0089"></a>
- A candidate reference MUST NOT be intentionally reused for a different
  publication attempt; every attempt, including a rebuild of the same source
  revision, uses a new reference. `IG0090`<a id="ig0090"></a>
- Candidate content and evidence MUST be safe to disclose publicly. Deleting or
  expiring a tag may leave unreferenced manifests and blobs until registry
  garbage collection. `IG0091`<a id="ig0091"></a>
- The protected release profile MUST explicitly require registry tag protection
  or record its reviewed absence with a rationale and owner. Required protection
  MUST be verified before upload and promotion, including protection on final
  tag assignment and exclusion of candidate and moving tags. Missing or
  unreadable required protection MUST stop the operation. ConClear MUST record
  the selected policy and observed protection without claiming enforcement in
  the reviewed-absence mode. `IG0092`<a id="ig0092"></a>
- ConClear MUST record a finite candidate-authorization deadline before upload
  and enforce it before and during promotion, including resume. Repository
  configuration MAY shorten but MUST NOT extend or disable the maximum.
  Retries and registry expiration settings MUST NOT extend the recorded
  authorization. Registry cleanup metadata is separate from this deadline.
  `IG0093`<a id="ig0093"></a>
- A workflow MUST NOT use a separate candidate repository unless it copies or
  recreates every signature and attestation in the final repository, then
  verifies the subjects and identities before promotion.
  [OCI referrers](https://github.com/opencontainers/distribution-spec/blob/main/spec.md#listing-referrers),
  Cosign signatures and attestations are repository-scoped; `skopeo copy --all`
  does not move them. `IG0094`<a id="ig0094"></a>
- The run identifier MUST be a lowercase [ULID](https://github.com/ulid/spec)
  generated by ConClear as its release-run identity. It sorts by time and
  prevents reference collisions. Each rebuild gets a new identifier, locally or
  in CI. `IG0095`<a id="ig0095"></a>
- After writing a release or convenience tag, promotion MUST compare it with the
  verified digest and record the result. A missing or different tag is an
  operational failure. `IG0096`<a id="ig0096"></a>
- After successful promotion, ConClear MUST attempt to delete the temporary
  candidate tag and verify its removal. Cleanup failure MUST be reported
  separately without revoking the completed release. The cleanup owner MUST
  remove rejected or abandoned candidates through the declared procedure.
  Delayed garbage collection is not a release failure, and cleanup MUST NOT
  delete supported release tags or their required evidence.
  `IG0097`<a id="ig0097"></a>


## Base images and digest pinning<a id="base-images-and-digest-pinning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)


### Choosing a base image<a id="choosing-a-base-image"></a>

This guide does not mandate one base distribution for every application.

**You MUST evaluate:**

- Publisher and registry trust; whether upstream support covers the
  application's release lifetime; `linux/amd64` and any required `linux/arm64`;
  compatibility with the runtime, native libraries and C library; required
  certificate, timezone, locale and user lookup data; the quality and timeliness
  of advisories, package metadata and scanner support; tools needed to build,
  operate and diagnose; upstream rebuild cadence; and the project's ability to
  update promptly. `IG0098`<a id="ig0098"></a>

**You SHOULD:**

- Start evaluation with an
  [official Fedora Minimal image](https://fedoraproject.org/everything/download/)
  from Quay for a general-purpose Linux runtime when Fedora's lifecycle and
  update cadence suit the application. `IG0099`<a id="ig0099"></a>
- Prefer a base already maintained and understood by the operating team when it
  satisfies the preceding criteria. `IG0100`<a id="ig0100"></a>
- Remove unused packages, files and privileges based on measured runtime
  requirements. `IG0101`<a id="ig0101"></a>
- Use `scratch` only for a genuinely static executable after testing
  certificate, timezone, user lookup and diagnostic requirements.
  `IG0102`<a id="ig0102"></a>

**You MUST NOT:**

- Choose Alpine, a distroless image or `scratch` solely because it has fewer
  bytes. `IG0103`<a id="ig0103"></a>
- Assume a smaller image has fewer exploitable vulnerabilities.
  `IG0104`<a id="ig0104"></a>
- Introduce a musl-based runtime without testing software that was developed or
  distributed for glibc. `IG0105`<a id="ig0105"></a>
- Use an unsupported distribution release merely to avoid an upgrade.
  `IG0106`<a id="ig0106"></a>


### Pinning image references<a id="pinning-image-references"></a>

- All external image inputs to a release build MUST be pinned by digest. This
  includes production and build stages: a compromised or unexpectedly changed
  builder can alter the final artifact even when the final base is pinned.
  `IG0107`<a id="ig0107"></a>

Use a readable tag together with the digest of the image index:

```dockerfile
FROM quay.io/fedora/fedora-minimal:<version>@sha256:<image-index-digest> AS runtime
```

The tag documents the release line; the digest selects the bytes. For a
multi-platform image, pin the index digest so the builder can select each
platform manifest. Some containers/image transports accept only
`repository@digest`; use that form where required.

**You MUST pin:**

- Every external `FROM` reference. `IG0108`<a id="ig0108"></a>
- Every external image used by `COPY --from`. `IG0109`<a id="ig0109"></a>
- Every external image used by a `RUN --mount=from` build mount.
  `IG0110`<a id="ig0110"></a>
- Tool or helper images invoked around the build, scan, signing or release
  process. `IG0111`<a id="ig0111"></a>


The literal `scratch` base and a stage name declared earlier in the same
Containerfile are not external references and do not have a registry digest.

Resolve the current index digest with Skopeo and review the result before
changing the Containerfile:

```sh
image='quay.io/fedora/fedora-minimal:<version>'
digest="$(skopeo inspect --format '{{.Digest}}' "docker://${image}")"
printf '%s@%s\n' "${image}" "${digest}"
```

**You MUST NOT:**

- Pin only a mutable tag for a release build. `IG0112`<a id="ig0112"></a>
- Remove the tag and leave an unexplained bare digest when a meaningful upstream
  tag exists. `IG0113`<a id="ig0113"></a>
- Resolve a tag to a digest in one job and silently use a later tag resolution
  in another job. `IG0114`<a id="ig0114"></a>
- Assume digest pinning alone makes a build reproducible.
  `IG0115`<a id="ig0115"></a>


**Pin intent and freshness.** Every pin declares what its tag is expected to do
so that divergence between tag and digest becomes measurable.

The Containerfile is ConClear's authoritative source of each pinned digest.
Its `conclear.toml` pin entry names the readable tag, for example
`reference = "quay.io/fedora/fedora-minimal:43"`, and the tag intent below.
ConClear derives the full digest-bearing reference from the matching external
inputs. It requires exact coverage, rejects a tag with more than one digest in
the same Containerfile, and does not ask maintainers to repeat the digest in
TOML. `pins propose/apply` updates the verified Containerfile occurrences while
binding the unchanged intent declarations through the configuration digest.

- Every pinned reference declared in `conclear.toml` MUST declare
  `tag_intent = "immutable-version"` or `tag_intent = "moving-release-line"`;
  ConClear's pin gate rejects a declaration without a valid intent.
  `IG0116`<a id="ig0116"></a>
- Evidence MUST record, for every pinned reference, the tag, the pinned digest,
  the resolved digest, the resolution time and the first-observed divergence
  time. `IG0117`<a id="ig0117"></a>
- ConClear MUST define and enforce both the maximum permitted time since
  successful resolution and the maximum permitted divergence interval for pinned
  references; repository configuration MAY shorten but MUST NOT extend or
  disable these limits. `IG0118`<a id="ig0118"></a>
- The `pins check` operation MUST apply the effective freshness and divergence
  limits and emit a result; it MUST NOT edit files. Pin proposal and application
  are separate, explicit operations. `IG0119`<a id="ig0119"></a>
- The `pins check` operation MUST fail when the declared `tag_intent` set and
  the Containerfile's actual pinned references diverge; an undeclared pin and an
  orphaned declaration are both policy failures. `IG0120`<a id="ig0120"></a>
- A digest change under an `immutable-version` tag MUST be reviewed by the
  repository owner as a supply-chain event. `IG0121`<a id="ig0121"></a>
- A changed digest under a `moving-release-line` tag is a normal update proposal
  but becomes stale according to the effective divergence limit; the repository
  owner reviews the verified proposal.
- Pin-update and repository merge controls MUST NOT automatically accept a
  digest change under an `immutable-version` tag into a protected branch; the
  proposal remains blocked until the required human review of the supply-chain
  event completes. `IG0122`<a id="ig0122"></a>


### Updating pinned references<a id="updating-pinned-references"></a>

**You MUST:**

- Generate a machine-readable, non-mutating pin proposal with ConClear or a
  version- or digest-pinned updater that implements the same contract.
  `IG0123`<a id="ig0123"></a>
- Record in the proposal the updater name and version or artifact digest; the
  repository source revision and configuration digest; the image declaration,
  tag intent, old digest, resolved digest and resolution time; and every exact
  repository path, input-file digest, old bytes and occurrence expected to
  change. `IG0124`<a id="ig0124"></a>
- Resolve one digest for each proposed tag and use that result for every bound
  occurrence. Preserve the declared tag, registry and repository spelling; a
  digest refresh MUST NOT silently change image-selection intent.
  `IG0125`<a id="ig0125"></a>
- Apply a proposal only through ConClear or an updater that first verifies the
  proposal against the current repository state, including its expected old
  bytes, input-file digests, complete path set and exact occurrence count. On
  any detected error, application MUST leave every file unchanged.
  `IG0126`<a id="ig0126"></a>
- Keep proposal generation, application and acceptance distinct. Proposal
  generation MUST NOT edit files. Application MAY edit the local worktree or an
  updater-owned review branch but MUST NOT commit to a protected branch, merge,
  or publish a release. A repository owner reviews the complete resulting diff
  before acceptance. `IG0127`<a id="ig0127"></a>
- Run `conclear pins check` after application and reject a result that does not
  exactly match the proposal. A proposal or application is not release evidence.
  `IG0128`<a id="ig0128"></a>
- Rebuild, test, scan and sign after an image input changes.
  `IG0129`<a id="ig0129"></a>
- Review an unexpected digest change under an unchanged immutable-version tag as
  a supply-chain event. `IG0130`<a id="ig0130"></a>
- Keep supported release branches receiving relevant base-image and toolchain
  updates. `IG0131`<a id="ig0131"></a>
- Pin and verify any external updater used to generate or apply proposals. Do
  not grant a hosted update service write access to the organization's
  repositories. `IG0132`<a id="ig0132"></a>
- When an updater opens branches or pull requests, give it credentials that can
  create only those review resources and cannot merge or push to protected
  branches. Branch and pull-request delivery MUST NOT be required for an
  authorized local maintainer workflow. `IG0133`<a id="ig0133"></a>

**You SHOULD:**

- Use a pinned, self-hosted updater such as Renovate for scheduled branch and
  pull-request delivery when the organization operates the required runner and
  least-privileged credentials. `IG0134`<a id="ig0134"></a>
- Configure an external updater's Containerfile digest behavior and custom
  managers so its proposal covers every declaration and bound occurrence.
  `IG0135`<a id="ig0135"></a>
- Group routine digest refreshes where this does not obscure a high-risk or
  breaking update. `IG0136`<a id="ig0136"></a>
- Set a repository-specific update schedule that is shorter than the effective
  vulnerability remediation deadline enforced by ConClear.
  `IG0137`<a id="ig0137"></a>
- Maintain one organization-level updater policy that repositories extend, so
  schedule, grouping and digest policy are decided once instead of per
  repository. `IG0138`<a id="ig0138"></a>


## Build context<a id="build-context"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Add a
  [`.containerignore`](https://github.com/containers/common/blob/main/docs/containerignore.5.md)
  file at the root of the build context. `IG0139`<a id="ig0139"></a>
- Exclude `.git`, editor state, test output, local caches, credentials,
  environment files, private keys, signing material and unrelated build
  artifacts. `IG0140`<a id="ig0140"></a>
- Pass the narrowest practical directory as the build context.
  `IG0141`<a id="ig0141"></a>
- Review negated ignore patterns because the last matching pattern determines
  inclusion. `IG0142`<a id="ig0142"></a>
- Keep all required build input in version control or fetch it through an
  authenticated, integrity-checked dependency mechanism.
  `IG0143`<a id="ig0143"></a>

**You SHOULD:**

- Start from excluding broadly and add back only the files required by the
  build. `IG0144`<a id="ig0144"></a>
- Give dependency manifests their own early `COPY` instruction when the package
  manager can cache dependency resolution independently of source changes.
  `IG0145`<a id="ig0145"></a>
- Inspect the effective context when adding a broad `COPY . ...` instruction.
  `IG0146`<a id="ig0146"></a>

**You MUST NOT:**

- Rely on `.gitignore` to define the build context. `IG0147`<a id="ig0147"></a>
- Include a secret and assume it is safe because no final `COPY` references it.
  `IG0148`<a id="ig0148"></a>
- Use the filesystem root or a developer's home directory as the build context.
  `IG0149`<a id="ig0149"></a>


The containers/common manual defines `.containerignore` syntax and precedence.
New projects use `.containerignore`, not `.dockerignore`. The
[reference](#reference-containerfile) includes a minimal allowlist.


## Stages and dependencies<a id="stages-and-dependencies"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Name every stage referenced by another instruction.
  `IG0150`<a id="ig0150"></a>
- Copy artifacts from an explicit named stage, not a numeric stage position.
  `IG0151`<a id="ig0151"></a>
- Keep compilers, package managers, source trees and test data out of the final
  stage unless they are runtime requirements. `IG0152`<a id="ig0152"></a>
- Verify artifacts fetched from outside the package manager or source repository
  with a cryptographic digest or signature. `IG0153`<a id="ig0153"></a>
- Pin external stage images as described in
  [Pinning image references](#pinning-image-references).
  `IG0154`<a id="ig0154"></a>

**You SHOULD:**

- Use separate `build`, `test` and `runtime` stages when doing so makes
  promotion boundaries clear. `IG0155`<a id="ig0155"></a>
- Make a target used by CI fail unless its test stage completes.
  `IG0156`<a id="ig0156"></a>
- Copy a small, explicit artifact set into the runtime stage.
  `IG0157`<a id="ig0157"></a>
- Keep build dependency declarations close to the application dependency
  manifests they consume. `IG0158`<a id="ig0158"></a>

**You MAY:**

- Use build mounts for transient caches and secrets when supported by the
  documented Buildah version. `IG0159`<a id="ig0159"></a>

**You MUST NOT:**

- Copy an entire build stage filesystem into the runtime stage.
  `IG0160`<a id="ig0160"></a>
- Fetch an executable through `curl | sh`, an unauthenticated URL or a mutable
  latest-release URL. `IG0161`<a id="ig0161"></a>
- Assume that deleting a secret or large file in a later instruction removes it
  from an earlier layer. `IG0162`<a id="ig0162"></a>
- Require a cache mount for correctness; a cache improves speed but is not an
  input identity. `IG0163`<a id="ig0163"></a>


## RUN instructions and package installation<a id="run-instructions-and-package-installation"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use non-interactive package-manager options. `IG0164`<a id="ig0164"></a>
- Install only packages required by that stage. `IG0165`<a id="ig0165"></a>
- Refresh package metadata, install packages and remove package-manager caches
  in the same `RUN` instruction when the package manager stores them in the
  layer. `IG0166`<a id="ig0166"></a>
- Make shell command failures stop the build. `IG0167`<a id="ig0167"></a>
- Use HTTPS and verify an expected digest or signature when downloading a file
  outside a package manager. `IG0168`<a id="ig0168"></a>
- Keep repository trust configuration explicit and scoped.
  `IG0169`<a id="ig0169"></a>

**You SHOULD:**

- Use the base distribution's package manager instead of downloading manually
  assembled filesystem archives. `IG0170`<a id="ig0170"></a>
- Sort package names lexicographically when installing several packages.
  `IG0171`<a id="ig0171"></a>
- Use `RUN --mount=type=cache` for disposable package or compiler caches where
  it measurably improves build time. `IG0172`<a id="ig0172"></a>
- Use `RUN --network=none` for steps that should be independent of the network.
  `IG0173`<a id="ig0173"></a>
- Move non-trivial shell logic to a checked and linted script.
  `IG0174`<a id="ig0174"></a>

**You MAY:**

- Add an exact package version constraint when compatibility requires it;
  document how the version remains available and receives security maintenance.
  `IG0175`<a id="ig0175"></a>

**You MUST NOT:**

- Use `curl ... | sh` or an equivalent network-to-interpreter pipeline.
  `IG0176`<a id="ig0176"></a>
- Disable TLS certificate validation or package signature verification.
  `IG0177`<a id="ig0177"></a>
- Run a full distribution upgrade as a substitute for updating the pinned base
  image. `IG0178`<a id="ig0178"></a>
- Keep package indexes, compiler caches or downloaded archives in the final
  filesystem without a runtime need. `IG0179`<a id="ig0179"></a>
- Put a long application installer into a quoted `RUN` string when it can be a
  tested source file. `IG0180`<a id="ig0180"></a>
- Require exact distribution package versions by default.
  `IG0181`<a id="ig0181"></a>


Example pattern for a POSIX shell stage:

```dockerfile
RUN set -eu; \
    package-manager install --non-interactive \
      ca-certificates \
      timezone-data; \
    package-manager clean
```

The command names are intentionally generic; use the exact supported commands of
the chosen distribution. Do not paste package-manager flags from another
distribution or release.


## Files, ownership and permissions<a id="files-ownership-and-permissions"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

**You MUST:**

- Use `COPY` for local files. `IG0182`<a id="ig0182"></a>
- Copy only the files needed by the stage. `IG0183`<a id="ig0183"></a>
- Set ownership during `COPY` with `--chown` when the builder supports the
  required semantics. `IG0184`<a id="ig0184"></a>
- Make executables, configuration and data no more permissive than their runtime
  use requires. `IG0185`<a id="ig0185"></a>
- Ensure unprivileged runtime identities cannot directly change executable code
  or immutable configuration, including by changing their permission modes.
  Document intentional administration of those files by an authorized root or
  sudo identity; unrestricted root access can change them on a writable root
  filesystem.
  `IG0186`<a id="ig0186"></a>
- Preserve executable bits in version control for source-controlled executable
  files. `IG0187`<a id="ig0187"></a>

**You SHOULD:**

- Use absolute destination paths. `IG0188`<a id="ig0188"></a>
- Use `COPY --from=<stage>` for build outputs. `IG0189`<a id="ig0189"></a>
- Separate stable dependency input from frequently changing source input to
  preserve useful build cache entries. `IG0190`<a id="ig0190"></a>
- Keep executable code and immutable configuration owned by container UID/GID 0
  and non-writable by the runtime identity. Use mode `0555` for executables and
  `0444` for non-secret data readable by every runtime user.
  `IG0191`<a id="ig0191"></a>
- Give the runtime identity ownership only of explicitly mutable directories and
  files, with the narrowest required modes. `IG0192`<a id="ig0192"></a>

**You MUST NOT:**

- Use remote-URL `ADD`. `IG0193`<a id="ig0193"></a>
- Depend on `ADD` archive auto-extraction when an explicit extraction command
  would make validation and ownership clearer. `IG0194`<a id="ig0194"></a>
- Use `chmod -R 777` or world-writable application directories.
  `IG0195`<a id="ig0195"></a>
- Include setuid/setgid executables without a reviewed requirement naming each
  executable, its purpose, owner and review trigger. Check inherited executables
  as well as files added by the image. Protect each executable and its parent
  directories against modification by unprivileged callers; a sudo requirement
  covers only the sudo executable paths it declares.
  `IG0420`<a id="ig0420"></a>
- Copy a complete repository merely for convenience. `IG0196`<a id="ig0196"></a>
- Change ownership recursively in a later layer when ownership can be assigned
  during `COPY`. `IG0197`<a id="ig0197"></a>


Example:

```dockerfile
COPY --from=build --chown=0:0 --chmod=0555 /workspace/bin/example /usr/local/bin/example
```


## Build arguments, configuration and secrets<a id="build-arguments-configuration-and-secrets"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

Build arguments select non-secret build behavior. Environment variables define
image defaults visible at runtime. Secrets are neither and require a secret
mount or an external runtime secret provider.

**You MUST:**

- Declare every build argument with `ARG` before use.
  `IG0198`<a id="ig0198"></a>
- Give a non-secret build argument a safe default or require and validate it
  explicitly in the build automation. `IG0199`<a id="ig0199"></a>
- Use `ENV` only for values that are appropriate defaults in every container
  created from the image. `IG0200`<a id="ig0200"></a>
- Supply build secrets with Buildah's secret mechanism and consume them through
  `RUN --mount=type=secret`. `IG0201`<a id="ig0201"></a>
- Supply runtime secrets at runtime through the deployment platform.
  `IG0202`<a id="ig0202"></a>

**You MUST NOT:**

- Pass passwords, tokens, private keys or signing material through `ARG`, `ENV`,
  labels, command-line literals or ordinary `COPY`. `IG0203`<a id="ig0203"></a>
- Bake environment-specific service addresses, credentials or deployment
  configuration into a reusable release image. `IG0204`<a id="ig0204"></a>
- Assume that an unset build argument reliably fails without explicit
  validation. `IG0205`<a id="ig0205"></a>
- Log secret values or commands that expand them. `IG0206`<a id="ig0206"></a>


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

- Set `USER` to a numeric, non-zero UID in the final stage unless the configured
  startup identity has a documented, reviewed requirement for UID 0. Record the
  rationale, owner and review trigger in `runtime.root_requirement`; declare
  `USER 0` explicitly when it applies.
  `IG0207`<a id="ig0207"></a>
- Use a stable UID and GID that do not collide with identities already defined
  by the selected base. `IG0208`<a id="ig0208"></a>
- Make required writable paths explicit. `IG0209`<a id="ig0209"></a>
- Ensure ordinary application startup does not need to change file ownership,
  install packages or rewrite its executable or static configuration. For an
  image whose purpose includes those administration tasks, document and test the
  intended operations and required writable paths. A writable root filesystem
  needs its own rationale, owner and review trigger in
  `runtime.writable_root_requirement`.
  `IG0210`<a id="ig0210"></a>
- Document and review every required Linux capability, device, host namespace,
  privileged mode or writable host path. `IG0211`<a id="ig0211"></a>

**You SHOULD:**

- Use a dedicated identity per application image. `IG0212`<a id="ig0212"></a>
- Make the root filesystem read-only in runtime tests.
  `IG0213`<a id="ig0213"></a>
- Mount an explicit temporary filesystem for `/tmp` or another required scratch
  path. `IG0214`<a id="ig0214"></a>
- Drop all capabilities and enable `no-new-privileges` in smoke tests. Add back
  only declared capabilities required by the tested operation. Omit
  `no-new-privileges` from a functional sudo test only when the reviewed sudo
  requirement declares escalation. `IG0215`<a id="ig0215"></a>
- Define and test memory, CPU, PID and `nofile` limits in deployment
  configuration, using per-image measured values from representative startup and
  load tests recorded in repository configuration; runtime evidence records the
  limits actually applied. `IG0216`<a id="ig0216"></a>
- Listen on an unprivileged port greater than or equal to 1024.
  `IG0217`<a id="ig0217"></a>

**You MUST NOT:**

- Include or use `sudo` in the final image without a documented, reviewed
  `runtime.sudo_requirement` giving its rationale, owner, review trigger and
  authorization scope. State whether the requirement is `presence-only` or
  `escalation`; installing the package alone does not authorize escalation.
  `IG0218`<a id="ig0218"></a>
- Run as root merely to bind a low port, write application files or avoid
  setting ownership during the build. `IG0219`<a id="ig0219"></a>
- Declare a broad writable directory when one narrow cache or temporary path is
  sufficient. `IG0220`<a id="ig0220"></a>
- Assume a named user resolves in a `scratch` image without supplying the
  required user database files. `IG0221`<a id="ig0221"></a>

Rootless execution describes the container manager's host privileges. A
rootless container can start as container UID 0 or support sudo without running
the manager as host root. Neither requirement authorizes `--privileged`, host
namespaces, extra capabilities or writable host mounts.

Root and sudo requirements are independent of lifecycle profiles. A systemd
image that starts as UID 0 and tests sudo from another account needs both. A
non-root image that supports sudo needs only the sudo requirement. Keep the
actual authorization in sudoers and retain the policy used by the tests with
their evidence. Identify intended callers, target identities and permitted
operations in the scope; explain passwordless or unrestricted access when
required. For a disposable OS test target, unrestricted sudo may be appropriate,
but it gives that account root-equivalent access within the container.

- Repository owners MUST review sudo authorization and set-ID requirements when
  their declared review triggers occur. A reviewed repository change with a
  named owner is sufficient; a separate approval service is not required.
  `IG0421`<a id="ig0421"></a>


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

- Use JSON exec form for `ENTRYPOINT` and `CMD`. `IG0222`<a id="ig0222"></a>
- Make the long-running application process become PID 1 by using `exec` in an
  entrypoint script, unless a documented supervisor is part of the product's
  lifecycle contract. `IG0223`<a id="ig0223"></a>
- When a supervisor is PID 1, require it to forward relevant signals, reap child
  processes, terminate managed processes within the deployment grace period, and
  propagate or deliberately map their exit statuses according to the documented
  contract. `IG0224`<a id="ig0224"></a>
- Ensure the application handles signals received directly or forwarded by its
  supervisor and exits within the deployment grace period.
  `IG0225`<a id="ig0225"></a>
- Propagate the application exit status from a wrapper unless the documented
  lifecycle contract defines a deliberate status mapping.
  `IG0226`<a id="ig0226"></a>
- Keep deployment-specific flags outside the immutable entrypoint.
  `IG0227`<a id="ig0227"></a>

**You SHOULD:**

- Use `ENTRYPOINT` for the stable executable and `CMD` for overridable default
  arguments. `IG0228`<a id="ig0228"></a>
- Run exactly one service process and avoid a supervisor unless the product
  contract requires supervision, child-process management or another explicit
  lifecycle policy. `IG0229`<a id="ig0229"></a>
- Test termination and child-process reaping behavior.
  `IG0230`<a id="ig0230"></a>
- Set `STOPSIGNAL` only when the application requires a signal other than the
  runtime default. `IG0231`<a id="ig0231"></a>

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

Use the standard
[`org.opencontainers.image.*` annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
as image labels. Labels describe the exact build and provide discovery
information; they do not replace provenance.

**A published image MUST include:**

- `org.opencontainers.image.source` with the canonical source repository URL.
  `IG0232`<a id="ig0232"></a>
- `org.opencontainers.image.revision` with the complete source revision used for
  the build. `IG0233`<a id="ig0233"></a>
- `org.opencontainers.image.licenses` with an SPDX license expression for the
  packaged project. `IG0234`<a id="ig0234"></a>
- `org.opencontainers.image.title` with a concise human-readable name.
  `IG0235`<a id="ig0235"></a>
- `org.opencontainers.image.version` when the project has a release version.
  `IG0236`<a id="ig0236"></a>

**A published image SHOULD include:**

- `org.opencontainers.image.description`. `IG0237`<a id="ig0237"></a>
- `org.opencontainers.image.documentation`. `IG0238`<a id="ig0238"></a>
- `org.opencontainers.image.url`. `IG0239`<a id="ig0239"></a>
- `org.opencontainers.image.vendor`. `IG0240`<a id="ig0240"></a>
- `org.opencontainers.image.created` as an RFC 3339 timestamp when the build
  system supplies a controlled value. `IG0241`<a id="ig0241"></a>

**You MUST NOT:**

- Put credentials, internal infrastructure names or personal data in labels.
  `IG0242`<a id="ig0242"></a>
- Claim a source revision, version or creation time that the release pipeline
  did not verify. `IG0243`<a id="ig0243"></a>
- Use a changing build timestamp when a reproducible build is required; derive
  it from controlled source metadata instead. `IG0244`<a id="ig0244"></a>
- Invent project-specific labels when a standard OCI annotation has the required
  meaning. `IG0245`<a id="ig0245"></a>


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

- Use `EXPOSE` to document each stable network port and transport expected by
  the application. `IG0246`<a id="ig0246"></a>
- Prefer an unprivileged port. `IG0247`<a id="ig0247"></a>
- Keep durable data and mutable configuration outside the image.
  `IG0248`<a id="ig0248"></a>
- Implement a lightweight application health endpoint when service health cannot
  be established from process state. `IG0249`<a id="ig0249"></a>
- Put the health command, timing, thresholds and failure action in deployment
  configuration for OCI images. `IG0250`<a id="ig0250"></a>
- Keep a lightweight health command in the image when deployment configuration
  invokes it, and make it run successfully as the configured runtime user.
  `IG0251`<a id="ig0251"></a>

**You MUST NOT:**

- Assume `EXPOSE` publishes a port or creates a firewall rule.
  `IG0252`<a id="ig0252"></a>
- Declare `VOLUME` without a stable data contract and a documented reason it
  belongs in the image. `IG0253`<a id="ig0253"></a>
- Store durable state in an anonymous runtime layer. `IG0254`<a id="ig0254"></a>
- Add a health check that requires a large diagnostic client solely for the
  check. `IG0255`<a id="ig0255"></a>
- Make a liveness check depend on an unrelated external service.
  `IG0256`<a id="ig0256"></a>
- Add or rely on a Containerfile `HEALTHCHECK` instruction in an OCI-format
  image. `IG0257`<a id="ig0257"></a>


OCI has no health-check field, so Buildah drops `HEALTHCHECK` from OCI-format
output. Define health checks through Quadlet, a systemd unit or another
deployment interface. A Docker-format image retaining the instruction requires a
documented exception to the OCI-format rule.


## Multi-platform images<a id="multi-platform-images"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Every public release MUST include a `linux/amd64` image.
  `IG0258`<a id="ig0258"></a>
- Public releases MAY include `linux/arm64`. `IG0259`<a id="ig0259"></a>

**You MUST:**

- Publish one image index when a release supports more than one platform.
  `IG0260`<a id="ig0260"></a>
- Build every platform from the same reviewed source revision and release
  configuration. `IG0261`<a id="ig0261"></a>
- Test each platform-specific image, not only the index name on one build host.
  `IG0262`<a id="ig0262"></a>
- Inspect the published index and verify the expected operating system,
  architecture and digest entries. `IG0263`<a id="ig0263"></a>
- Generate and scan the SBOM for each platform-specific manifest.
  `IG0264`<a id="ig0264"></a>

**You SHOULD:**

- Use the same execution mode to build and test one platform.
  `IG0265`<a id="ig0265"></a>
- Keep platform-independent build steps identical. `IG0266`<a id="ig0266"></a>
- Test the index through Podman's normal platform selection after publication.
  `IG0267`<a id="ig0267"></a>

**You MUST NOT:**

- Label an `amd64` filesystem as `arm64` or otherwise override platform metadata
  to conceal a cross-build failure. `IG0268`<a id="ig0268"></a>
- Download an architecture-specific artifact based only on the build host's
  `uname -m`. `IG0269`<a id="ig0269"></a>
- Publish an index entry that has not passed the platform's required tests.
  `IG0270`<a id="ig0270"></a>


**Platform transport.** Platform builds may run on separate workers. The
environment may transport their layouts and records through a CI artifact
service, object store or local directory, subject to these rules:

- Each build execution MUST record the digest of every exported layout, evidence
  payload and platform-qualification record in its output.
  `IG0271`<a id="ig0271"></a>
- The platform qualification MUST include the target platform, manifest digest,
  OCI layout descriptor, SBOM digest and scan-result digest.
  `IG0272`<a id="ig0272"></a>
- Before use, assembly MUST verify every transported layout, evidence payload
  and record by digest, reject unsafe archive paths and compare the imported
  manifest digest with the recorded digest. `IG0273`<a id="ig0273"></a>
- Index assembly MUST use only verified platform layouts and MUST record every
  platform-manifest digest and the index digest. `IG0274`<a id="ig0274"></a>
- Before producing a candidate, assembly MUST have exactly one accepted
  qualification per required platform, reject missing, duplicate or unexpected
  records, and match each target to its OCI descriptor and image-configuration
  metadata. `IG0275`<a id="ig0275"></a>


**Build and test execution modes.**

- Per-platform evidence and provenance MUST record the target, host and
  execution architectures, plus any emulation or cross-build mechanism, for both
  build and test. A single `uname` value is insufficient.
  `IG0276`<a id="ig0276"></a>
- Native and QEMU-emulated build and runtime tests both satisfy the platform
  requirement when the execution mode is recorded. Repository configuration MAY
  require native execution for a platform. `IG0277`<a id="ig0277"></a>
- KVM accelerates a guest only when the host can execute the guest architecture
  and does not replace QEMU for cross-architecture emulation.


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

In a distributed release, each platform worker exports an OCI layout. The
authorized release environment verifies the layouts and assembles the accepted
manifests into an index. A local single-platform release uses the same
qualification and assembly steps without transport.


## Rebuildability and reproducibility<a id="rebuildability-and-reproducibility"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Rebuildability is mandatory: the project MUST be able to create a working
  replacement from documented inputs. `IG0278`<a id="ig0278"></a>
- Bit-for-bit reproducibility is strongly desirable, but it MUST be measured and
  claimed precisely rather than assumed. `IG0279`<a id="ig0279"></a>

**You MUST:**

- Record the source revision, Containerfile, build arguments, builder identity,
  builder version and resolved external materials in provenance.
  `IG0280`<a id="ig0280"></a>
- Use lock files and checksum verification provided by the application
  language's dependency system. `IG0281`<a id="ig0281"></a>
- Record the ConClear version, host-tool versions and tool-image digests, and
  keep them unchanged until the release completes. `IG0282`<a id="ig0282"></a>
- Make release builds independent of a developer's local image store,
  environment and uncommitted files. `IG0283`<a id="ig0283"></a>
- Pull and verify required external images instead of accepting an unreviewed
  local substitute. `IG0284`<a id="ig0284"></a>

**You SHOULD:**

- Set `SOURCE_DATE_EPOCH` from the source revision when supported by the build
  system. `IG0285`<a id="ig0285"></a>
- Use Buildah timestamp controls such as `--source-date-epoch` or
  `--rewrite-timestamp` only after testing the resolved version. Apply them
  during the build, never after runtime tests. `IG0286`<a id="ig0286"></a>
- Normalize generated archive metadata and application build identifiers.
  `IG0287`<a id="ig0287"></a>
- Test whether two clean builds from the same declared input produce the same
  platform manifest digest. `IG0288`<a id="ig0288"></a>
- Document remaining sources of nondeterminism. `IG0289`<a id="ig0289"></a>

**You MUST NOT:**

- Describe an image as reproducible merely because it can be rebuilt
  successfully. `IG0290`<a id="ig0290"></a>
- Depend on a warm build cache for correctness. `IG0291`<a id="ig0291"></a>
- Embed an uncontrolled current timestamp, random identifier or host path in
  release output. `IG0292`<a id="ig0292"></a>
- Weaken update policy solely to preserve an old digest; a secure rebuild may
  intentionally produce new content. `IG0293`<a id="ig0293"></a>


## Security, SBOMs, provenance and signing<a id="security-sboms-provenance-and-signing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- The release pipeline MUST evaluate, scan, attest and sign the exact digests it
  publishes. A local-tag scan, source-directory SBOM or moving-tag signature
  does not describe the released image. `IG0294`<a id="ig0294"></a>


### Vulnerability and configuration scanning<a id="vulnerability-and-configuration-scanning"></a>

Trivy is the standard scanner.

- Before public upload, the release pipeline MUST scan each final platform image
  from a local OCI layout with a recorded manifest digest, or an equivalently
  digest-addressed private location. Every rejecting content gate must run
  without public disclosure. `IG0295`<a id="ig0295"></a>
- After these gates pass, the workflow MUST copy the scanned artifact with
  unchanged manifest and blob digests. Use Skopeo `--preserve-digests`, plus
  `--all` for an index, and compare every registry digest with its local digest.
  Failure to preserve or match a digest fails the release. Signature and
  attestation verification remain publication steps because they use registry
  objects. `IG0296`<a id="ig0296"></a>

**You MUST:**

- Scan operating-system and application packages in every platform-specific
  image. `IG0297`<a id="ig0297"></a>
- Scan the Containerfile and image configuration for insecure settings.
  `IG0298`<a id="ig0298"></a>
- Enable secret scanning for the build context and final image.
  `IG0299`<a id="ig0299"></a>
- Fail a release for a fixable `HIGH` or `CRITICAL` vulnerability unless an
  approved, unexpired exception exists in repository configuration; this guide
  owns the authoritative severity threshold. `IG0300`<a id="ig0300"></a>
- Store the scanner version, vulnerability database version or timestamp, image
  digest and result with the release evidence. `IG0301`<a id="ig0301"></a>
- Record the local manifest digest before scanning and verify the same digest
  after upload. `IG0302`<a id="ig0302"></a>
- Arrange scheduled organization rescans from a digest-bound inventory of
  supported releases because vulnerability data changes without image changes.
  Mutable tags MUST NOT define this inventory. Scheduling and remediation
  ownership are external; [Rescans and remediation](#rescans-and-remediation)
  defines the procedure. `IG0303`<a id="ig0303"></a>
- Use exactly one scanner stack as the authoritative release gate.
  `IG0304`<a id="ig0304"></a>
- Cache the vulnerability database between runs, record the database version or
  timestamp with each scan result, and refresh a stale or corrupted cache
  instead of trusting it. `IG0305`<a id="ig0305"></a>
- ConClear MUST define a finite qualification window beginning with selection
  of a fresh common database snapshot. Distributed workers MUST use that exact
  snapshot within the original window. Qualification completion, assembly,
  publication and promotion MUST reject expired approval, including on resume.
  The deadline MUST be recorded with the evidence and MUST NOT outlive pin
  freshness, permitted pin divergence or applied vulnerability exceptions.
  Expiry requires renewed qualification; it does not invalidate historical
  evidence. Rescans MUST assess the unchanged released subject with a fresh
  database. `IG0423`<a id="ig0423"></a>

Control: ConClear checks evidence age at release authorization boundaries. The
current qualification maximum is 24 hours from the original fresh database
selection; `freshness.QUALIFICATION_WINDOW` defines it in code. Earlier pin
freshness, pin-divergence or applied-exception deadlines shorten it. The start
and effective expiry are recorded with the qualification and signed release
verification. Clocks on the participating hosts are an external responsibility.

|                    Boundary                    | Freshness decision |
| ---------------------------------------------- | ------------------ |
| New qualification                              | Both Trivy database components are fresh at the original start: updated by then and not yet at their next-update time. |
| Later worker                                   | The exact pinned snapshot and original start are reused within the same window; pinning never silently substitutes a database. |
| Completion through promotion, including resume | The recorded window remains current. A delayed phase cannot renew approval. |
| Historical inspection                          | Age does not invalidate what the evidence records about the past release. |
| New rescan                                     | The original signed release evidence is verified and a fresh database supplies the new vulnerability assessment. |

The configured candidate lifetime, currently at most seven days, is a separate
deadline and does not extend qualification approval. A previously passing scan
also says nothing about advisories published since that scan.

**You SHOULD:**

- Scan the digest pulled from the registry after upload as a non-gating
  defense-in-depth check. `IG0306`<a id="ig0306"></a>

**You MAY:**

- Run a non-gating second-opinion scan for audits. `IG0307`<a id="ig0307"></a>

**You MUST NOT:**

- Run two scanners as parallel release gates. `IG0308`<a id="ig0308"></a>

**A vulnerability exception MUST:**

- Be stored in `conclear.toml` on the protected, reviewed source revision and
  receive the required security-owner review before merge.
  `IG0309`<a id="ig0309"></a>
- Identify the image, component and advisory; explain the lack of remediation;
  assess reachability and exposure; list compensating controls; and name the
  accountable owner, expiry and review trigger. `IG0310`<a id="ig0310"></a>
- Be rejected by ConClear when it is malformed, expired or does not match the
  finding; ConClear records every applied exception in evidence.
  `IG0311`<a id="ig0311"></a>

Control: manual review (security owner) establishes the exception's rationale,
reachability and compensating controls. ConClear validates its fields, match
and expiry; it does not determine whether the human assessment is correct.


Example local vulnerability gate:

```sh
trivy image \
  --input './build/example-linux-amd64.oci' \
  --exit-code 1 \
  --ignore-unfixed \
  --severity HIGH,CRITICAL
```

Trivy can also scan a retained SBOM directly without pulling the image:

```sh
trivy sbom \
  --exit-code 1 \
  --ignore-unfixed \
  --severity HIGH,CRITICAL \
  'example-linux-amd64.spdx.json'
```

An SBOM rescan matches vulnerabilities against the retained package inventory.
It does not repeat the image filesystem's secret and configuration scans; see
[Rescans and remediation](#rescans-and-remediation) for the scope rules.
The direct Trivy command above is a diagnostic. ConClear's authoritative rescan
also verifies registry evidence and currently retrieves the released image
graph even for SBOM-only vulnerability matching; it is not an offline command.


### Rescans and remediation<a id="rescans-and-remediation"></a>

These rules apply when a supported digest gains a finding above the release
threshold. The organization owns scheduling, triage and remediation; this
section defines the required project output and evidence.

- The remediation clock MUST start when the authoritative rescan result is
  recorded; it MUST NOT start from an informal local scanner invocation.
  `IG0312`<a id="ig0312"></a>
- A finding MUST be treated as fixable when the scanner reports a fixed version
  or other concrete remediation, unless triage shows it does not apply.
  `IG0313`<a id="ig0313"></a>
- ConClear MUST define and enforce a non-disableable maximum remediation
  deadline; repository configuration MAY shorten but MUST NOT extend it.
  `IG0314`<a id="ig0314"></a>
- Within the effective remediation deadline, the project owner MUST either
  release a newly qualified remediated digest or obtain and record an approved
  exception as defined above. `IG0315`<a id="ig0315"></a>
- Version and release tags MUST NOT be repointed for remediation. The
  release owner maintains their stability; ConClear refuses a different existing
  digest and reports observed repointing as a policy failure.
  `IG0316`<a id="ig0316"></a>
- A convenience tag MUST advance only through ConClear's verified promotion,
  never as an unrecorded scan response. `IG0317`<a id="ig0317"></a>
- Evidence MUST identify the affected digest and the remediating digest or the
  applied exception. `IG0318`<a id="ig0318"></a>
- The project owner SHOULD publish an advisory when consumers are affected,
  identifying the affected digest and the remediating digest or exception.
  `IG0319`<a id="ig0319"></a>

Control: ConClear records the first authoritative observation, preserves the
linked history and rejects findings that exceed the effective deadline. The
project owner performs triage, publishes advisories and delivers remediation.
Those are manual and external controls: no ConClear invocation means no new
observation, and a rejecting result does not itself rebuild or withdraw an
image. Scheduling and alert delivery follow
[Operating supported releases](#operating-supported-releases).


**Rescan scope.**

- An SBOM-based rescan MUST be recorded as covering vulnerability matching
  against the retained package inventory only; it does not repeat the image
  filesystem's secret and configuration scans. `IG0320`<a id="ig0320"></a>
- When rescan configuration requires new secret or configuration scans, the
  rescan MUST fetch the image by digest and scan its content. An SBOM rescan is
  insufficient. `IG0321`<a id="ig0321"></a>
- The project triage owner MUST record each triage decision with the affected
  subject, the decision, its rationale, the accountable owner and the decision
  time. `IG0322`<a id="ig0322"></a>
- A changed triage state, remediating digest or approved exception MUST be
  recorded as a new rescan result that references the previous one; earlier
  results are never rewritten. `IG0323`<a id="ig0323"></a>


### SBOMs<a id="sboms"></a>

- Each platform release manifest MUST have an SBOM in a finalized SPDX JSON
  format supported by the release toolchain. SPDX 2.3 JSON is the
  interoperability baseline. Generate it from the final local OCI layout so it
  describes the published filesystem and packages. `IG0324`<a id="ig0324"></a>

```sh
trivy image \
  --input './build/example-linux-amd64.oci' \
  --format spdx-json \
  --output example-linux-amd64.spdx.json
```

**You MUST:**

- Generate one SBOM for each platform-specific manifest digest.
  `IG0325`<a id="ig0325"></a>
- Record the actual SPDX specification version in the SBOM and release evidence.
  `IG0326`<a id="ig0326"></a>
- Validate that the SBOM names or associates the exact subject digest.
  `IG0327`<a id="ig0327"></a>
- Retain the SBOM for the supported lifetime of the release; the organization
  owns the retention configuration described in
  [Release evidence and retention](#release-evidence-and-retention).
  `IG0328`<a id="ig0328"></a>
- Attach the SBOM to the registry as a signed Cosign attestation.
  `IG0329`<a id="ig0329"></a>
- Make the SBOM available to consumers without requiring access to the build
  workspace. `IG0330`<a id="ig0330"></a>

**You SHOULD:**

- Also publish the raw SPDX JSON as a release artifact for tools that do not
  discover registry attestations. `IG0331`<a id="ig0331"></a>
- Include application-language dependencies and files not owned by a
  distribution package. `IG0332`<a id="ig0332"></a>
- Compare SBOM coverage with application dependency lock files.
  `IG0333`<a id="ig0333"></a>

**You MAY:**

- Use a later finalized SPDX version when all release tools and required
  consumers support it. The workflow must generate, validate, rescan, attach,
  retrieve and interpret it without lossy conversion.
  `IG0334`<a id="ig0334"></a>


After local content gates pass, upload and compare the digest with a unique
[candidate reference](#registries-and-image-names):

```sh
source_image='oci:./build/example.oci:candidate'
destination_image='docker://quay.io/foundata/example:<version>-candidate.<run-id>.g<source-revision-short>'

local_digest="$(skopeo inspect --format '{{.Digest}}' "${source_image}")"
skopeo copy --all --preserve-digests "${source_image}" "${destination_image}"
remote_digest="$(skopeo inspect --format '{{.Digest}}' "${destination_image}")"
test "${local_digest}" = "${remote_digest}"
```

`<run-id>` is the attempt's lowercase ULID. It sorts attempts by time and
prevents reuse across builds of the same revision. The candidate becomes public
at upload, after all rejecting content gates pass. Promotion and deployment
still require verified registry signatures and attestations. Unpromoted
candidates expire.


### Provenance<a id="provenance"></a>

- [Release provenance](#release-provenance) MUST use an in-toto Statement with a
  SLSA Provenance v1 predicate. `IG0335`<a id="ig0335"></a>
- The authorized release environment MUST generate provenance from observed
  build data, not unchecked caller input. A qualification or release tool there
  MAY generate the predicate from the accepted candidate record.
  `IG0336`<a id="ig0336"></a>
- Provenance MUST be generated from the accepted candidate record before
  publication, then validated and attached when the registry subject digest is
  known. `IG0337`<a id="ig0337"></a>
- A project MUST document its provenance generator integration. The trust root
  comes from maintainer-controlled release configuration and protected
  deployment configuration, not the project repository.
  `IG0338`<a id="ig0338"></a>

**The provenance MUST identify:**

- Every platform-specific subject digest and, where supported by the generator,
  the image-index digest. `IG0339`<a id="ig0339"></a>
- The canonical source repository and complete source revision.
  `IG0340`<a id="ig0340"></a>
- The Containerfile and relevant build configuration.
  `IG0341`<a id="ig0341"></a>
- External image materials by digest. `IG0342`<a id="ig0342"></a>
- The release-profile-selected builder identity, the embedded ConClear version
  and source revision, and the release-run identity. `IG0343`<a id="ig0343"></a>
- Relevant build parameters without secret values. `IG0344`<a id="ig0344"></a>
- The reviewed source revision. `IG0345`<a id="ig0345"></a>


**Identity separation.** Three identity families appear in a release and must
never be conflated or accepted from untrusted input:

- The SLSA `runDetails.builder.id` identifies the complete build-platform trust
  domain and comes from maintainer-controlled release configuration. It MUST be
  a public, credential-free HTTPS URI without a query or fragment.
  `IG0346`<a id="ig0346"></a>
- The builder URI SHOULD resolve to documentation defining its scope, claimed
  SLSA Build level, provenance accuracy and completeness guarantees,
  tenant-controlled fields and any extension fields. `IG0347`<a id="ig0347"></a>
- Security-significant execution modes with different trust boundaries or SLSA
  Build levels MUST use different builder identities. Ordinary CI environment
  variables MUST NOT select or override the builder identity.
  `IG0348`<a id="ig0348"></a>
- The SLSA `runDetails.builder.version` records the embedded ConClear version
  and full source revision. A ConClear upgrade changes this version data without
  changing the builder identity's documented trust domain.
- The Cosign signing-key identity identifies the signing authority and comes
  from the approved public key or KMS/HSM key identity.
- The source repository, revision and release event identify the input and
  invocation that caused the build.
- Builder, signer and source or release-event identities MUST remain distinct
  and come from their authoritative sources; ConClear refuses to conflate them.
  `IG0349`<a id="ig0349"></a>
- ConClear MUST reject these identities when supplied by repository
  configuration, arbitrary command-line flags or ordinary environment overrides.
  `IG0350`<a id="ig0350"></a>
- Consumers MUST accept only explicitly trusted signer and builder identity
  pairs. `IG0351`<a id="ig0351"></a>

ConClear-generated provenance claims SLSA Build L1 only. Running ConClear inside
a hosted CI job does not establish Build L2 because ConClear, rather than the
hosted platform's trusted control plane, generates and signs the provenance.
Any higher-level claim requires separately implemented and audited platform
controls and provenance.

Control: ConClear emits the Build L1 claim. Manual review establishes the
documented builder trust domain; external platform controls would have to
establish any higher level. CI environment variables and execution of the same
commands do not supply those controls.

**You MUST:**

- Attach provenance to the registry as a signed Cosign attestation.
  `IG0352`<a id="ig0352"></a>
- Verify subject digests and trusted builder identity before deployment or
  promotion. `IG0353`<a id="ig0353"></a>
- Keep secret values out of provenance parameters and environment data.
  `IG0354`<a id="ig0354"></a>
- Describe the actual build; do not claim a SLSA build level unless every
  requirement of that level is implemented and audited.
  `IG0355`<a id="ig0355"></a>


### Signing and verification<a id="signing-and-verification"></a>

Cosign is the standard signing and attestation client. Command examples in this
section use Cosign 3.x syntax; ConClear's supported-version matrix defines the
exact accepted versions. The baseline signing model is an organization-managed
key pair. Generate the initial key material in a controlled environment:

```sh
umask 077
cosign generate-key-pair
```

Cosign writes the encrypted private key to `cosign.key` and public key to
`cosign.pub`. Immediately move the private key to secret storage, delete the
working copy and distribute the public key through maintainer-controlled release
and protected deployment configuration. The authorized release environment
obtains the key and passphrase through a protected secret mechanism. Neither
belongs in repository files, command-line literals, logs or ordinary environment
variables.

Sign immutable digests after uploading all image content. Upload makes the
subject digest available to Cosign but does not promote the candidate. Registry
and deployment policy reject it until signatures and required attestations pass
verification.

- Release signatures and signed attestations MUST use Cosign's supported default
  public
  [Sigstore transparency service](https://docs.sigstore.dev/logging/overview/)
  (Rekor). `IG0356`<a id="ig0356"></a>
- Signing MUST fail if log inclusion cannot be obtained, and release
  verification MUST verify that inclusion. `IG0357`<a id="ig0357"></a>
- Release commands MUST NOT disable transparency-log upload, use a no-log
  signing configuration or ignore transparency-log verification.
  `IG0358`<a id="ig0358"></a>
- ConClear MUST NOT sign during checks, builds, tests, evidence generation or
  qualification; a workflow that does not publish a candidate therefore creates
  no transparency-log entry. `IG0359`<a id="ig0359"></a>

Candidate signatures are the release signatures because promotion assigns tags
to the same verified digest; the candidate and its evidence are already public
by construction.

**You MUST:**

- Sign the image-index digest and every platform-manifest digest in a
  multi-platform release. `IG0360`<a id="ig0360"></a>
- Sign attestations and associate them with the exact subject digest.
  `IG0361`<a id="ig0361"></a>
- Encrypt the private key at rest, restrict access to the authorized release
  process and maintain a tested backup, rotation and revocation procedure.
  `IG0362`<a id="ig0362"></a>
- Verify signatures and attestations against the exact approved public key or
  managed-key identity. `IG0363`<a id="ig0363"></a>
- Verify the signature, SBOM attestation, provenance attestation and their
  transparency-log inclusion before promotion or deployment.
  `IG0364`<a id="ig0364"></a>
- Configure `containers-policy.json` or an equivalent admission policy to reject
  unsigned or untrusted production images; deployment environment owners enforce
  it. `IG0365`<a id="ig0365"></a>
- Test trust-policy changes with both a trusted image and an intentionally
  untrusted image. `IG0366`<a id="ig0366"></a>

**You SHOULD:**

- Move private-key operations to a KMS or HSM when that infrastructure is
  operationally available, so the release process receives permission to sign
  without receiving exportable private-key material. `IG0367`<a id="ig0367"></a>

**You MUST NOT:**

- Sign a tag as though the tag were immutable. `IG0368`<a id="ig0368"></a>
- Treat successful cryptographic verification as authorization without checking
  repository, digest, signer identity and attestation predicate.
  `IG0369`<a id="ig0369"></a>
- Use the same long-lived signing key across unrelated trust domains.
  `IG0370`<a id="ig0370"></a>

Control: external (key custodian and deployment owner), with manual review of
their procedures. ConClear checks configured key files and verifies signatures
against the approved public key. It does not establish who can read every copy
of the private key, operate backups or enforce consumer admission policies.


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

[Cosign verification](https://docs.sigstore.dev/cosign/verifying/verify/)
requires the approved public key:

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

- Manual signing experiments are outside ConClear and SHOULD use a disposable
  test key, never the release key, and SHOULD stay out of the public log.
  `IG0371`<a id="ig0371"></a>

With Cosign 3.x, create a test-only
[signing configuration](https://docs.sigstore.dev/cosign/system_config/custom_components/)
without Fulcio, an OpenID Connect provider, Rekor or a timestamp authority.
Store the signature in a Sigstore bundle and explicitly allow verification
without transparency-log evidence:

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

- These opt-outs are test-only and MUST NOT be used for a release.
  `IG0372`<a id="ig0372"></a>
- The approved public key or KMS/HSM identity MUST come from
  maintainer-controlled release configuration for release verification and
  protected deployment configuration for admission. It MUST NOT come from the
  signature or repository under review. `IG0373`<a id="ig0373"></a>
- The private key or KMS/HSM signing permission MUST be available only to the
  authorized release process through a protected secret facility. Signing
  credentials MUST NOT be stored in repository files or ordinary environment
  configuration. `IG0374`<a id="ig0374"></a>
- Registry and deployment policy MUST reject a candidate until its signatures
  and required attestations have been verified; deployment environment owners
  enforce admission. `IG0375`<a id="ig0375"></a>

Podman, Buildah and Skopeo consumers use the `sigstoreSigned` type in
`containers-policy.json` when the deployed containers/image version supports the
required identity model. Keep the registry namespace narrow and use
`matchRepository` only for repository-level matching.


### Release evidence and retention<a id="release-evidence-and-retention"></a>

Signed registry attestations are the authoritative release evidence: each
platform SBOM, SLSA provenance for the index and platforms, and the
release-verification result. Workspace and CI artifacts are convenience copies.
The signature authenticates the statement and its digest references; it does
not retain the bytes behind every reference. Registry retention is an external
control, and a local SHA-256 value is not an archive.

- After final verification, ConClear MUST generate a release-verification
  predicate for the signed release-verification attestation; it is not a source
  comment or committed file. `IG0376`<a id="ig0376"></a>

**The release-verification predicate MUST contain:**

- Released repository, digest and verdict. `IG0377`<a id="ig0377"></a>
- ConClear version and source revision. `IG0378`<a id="ig0378"></a>
- Guide title, repository, path and revision. `IG0379`<a id="ig0379"></a>
- SHA-256 digest of `conclear.toml`. `IG0380`<a id="ig0380"></a>
- Host architecture, ConClear run identity, builder identity and optional
  observed CI context. `IG0381`<a id="ig0381"></a>
- Signer mode and identity. `IG0382`<a id="ig0382"></a>
- Digests of verified evidence. `IG0383`<a id="ig0383"></a>

**Identities and CI context.** Observed CI context is correlation metadata, not
proof of authorization or provider identity.

- Identities MUST come from protected release configuration, embedded ConClear
  data and observations by the authorized release environment, not
  caller-supplied values. `IG0384`<a id="ig0384"></a>
- ConClear's release behavior MUST be independent of the command's caller.
  `IG0385`<a id="ig0385"></a>
- A protected release profile MAY configure CI context handling as `omit`,
  `observe` or `require`. `omit` does not inspect CI environment metadata.
  `observe` records context from a recognized provider when the observation is
  complete and agrees with the isolated checkout, but absence, malformed values
  or disagreement only produce a local diagnostic. `require` treats those
  conditions as an operational failure. `IG0386`<a id="ig0386"></a>
- Observed CI context MUST NOT override the isolated source repository or
  revision, ConClear run identity, builder identity, signing authority, artifact
  digest or release verdict. `IG0387`<a id="ig0387"></a>
- Repository configuration and arbitrary command-line input MUST NOT supply CI
  context. `IG0388`<a id="ig0388"></a>
- Provider environment variables are ordinary process inputs and MUST be
  identified as such in public evidence. `IG0389`<a id="ig0389"></a>
- When present, public CI context MUST contain only a normalized provider
  identifier, `provider-environment` as its source, repository name, full source
  revision and provider run identifier. `IG0390`<a id="ig0390"></a>
- ConClear MUST verify that the repository and revision agree with the isolated
  checkout before including the context. `IG0391`<a id="ig0391"></a>
- Internal service origins and provider-specific details MAY appear in local
  diagnostics but MUST NOT enter signed public evidence.
  `IG0392`<a id="ig0392"></a>

An illustrative predicate has this shape; ConClear's record schemas define the
exact envelope and fields, and the release-specific facts live in `payload`:

```json
{
  "schemaVersion": 1,
  "recordType": "releaseVerification",
  "createdAt": "2026-09-06T12:00:00Z",
  "runId": "<conclear-generated-run-id>",
  "ruleset": {
    "conclearVersion": "<version>",
    "conclearRevision": "<conclear-source-revision>",
    "guideTitle": "OCI container image build and release guide",
    "guideRepository": "https://github.com/foundata/guidelines",
    "guidePath": "oci-container-image-guide.md",
    "guideRevision": "<guide-revision>"
  },
  "source": {
    "repository": "https://github.com/foundata/example",
    "revision": "<full-source-revision>"
  },
  "repositoryConfiguration": {
    "path": "conclear.toml",
    "sha256": "sha256:<configuration-digest>"
  },
  "tools": [
    {"name": "cosign", "version": "<version>", "executableDigest": "sha256:<digest>"}
  ],
  "verdict": "accepted",
  "payload": {
    "qualificationWindow": {
      "startedAt": "2026-09-06T10:00:00Z",
      "expiresAt": "2026-09-07T09:00:00Z"
    },
    "subject": {
      "repository": "quay.io/foundata/example",
      "digest": "sha256:<release-digest>"
    },
    "platformDigests": {
      "linux/amd64": "sha256:<platform-manifest-digest>"
    },
    "releaseEnvironment": {
      "hostArchitecture": "x86_64",
      "runId": "<conclear-generated-run-id>",
      "ciContext": {
        "provider": "gitlab-ci",
        "source": "provider-environment",
        "repository": "foundata/example",
        "revision": "<full-source-revision>",
        "runId": "<provider-run-id>"
      }
    },
    "builder": {"id": "<builder-identity-uri>"},
    "signer": {
      "mode": "managed-key",
      "keyId": "<approved-public-key-identifier>"
    },
    "evidence": {
      "platformQualifications": ["sha256:<qualification-digest>"],
      "scanResults": ["sha256:<scan-result-digest>"],
      "sboms": ["sha256:<sbom-digest>"],
      "provenance": "sha256:<provenance-digest>",
      "candidateRecord": "sha256:<candidate-record-digest>"
    }
  }
}
```

Cosign wraps the predicate in an in-toto Statement and attaches it to the
released digest as a signed attestation.

- The release environment MAY retain the predicate file for diagnostics, but the
  registry attestation is authoritative. `IG0393`<a id="ig0393"></a>
- Release-time verification MUST retain the signed release-verification
  attestation before promotion. `IG0394`<a id="ig0394"></a>
- The organization SHOULD export or back up release evidence so it survives
  registry migration or loss for the supported release lifetime.
  `IG0395`<a id="ig0395"></a>


**Scheduled rescans.**

- A scheduled rescan MUST resolve the subject by digest, enumerate every
  platform in an index, retrieve each SBOM attestation from the registry and
  verify its subject, signer and transparency-log inclusion against the trust
  root before scanning. `IG0396`<a id="ig0396"></a>
- An authoritative rescan result MUST record the scanner version; vulnerability
  database version or timestamp; guide revision; ConClear version and source
  revision; repository-configuration digest; rescan-job identity; subject
  digest; per-platform findings; triage state; and verdict.
  `IG0397`<a id="ig0397"></a>
- An informal local rescan is a useful diagnostic but is not release evidence
  and does not start or satisfy remediation duties.

#### Retaining the referenced bytes<a id="retaining-the-referenced-bytes"></a>

- The release owner MUST retain the exact non-secret qualification records,
  scan reports, SBOMs, test evidence, candidate record and provenance and
  verification predicates for the supported release lifetime. Retain the exact
  `conclear.toml` and the source checkout needed to load it. Check their digests
  against the signed evidence and test retrieval from the retention location
  before discarding the working copies. `IG0427`<a id="ig0427"></a>
- The release owner MUST keep protected command logs, credentials, release
  profiles, secret test inputs and raw diagnostic output outside the shareable
  evidence bundle. Review the selected files for disclosure before making a
  bundle accessible to consumers. `IG0428`<a id="ig0428"></a>

Control: external (release owner), with manual disclosure review. ConClear's
qualification transport exports the recorded payload bytes and their digests;
it does not archive the complete release, publish a bundle or operate backups.

The
[ConClear evidence-retention recipe](https://github.com/foundata/conclear/blob/main/docs/evidence-retention.md)
uses one `transport export` per platform, copies an explicit set of release
records and preserves the reviewed source checkout. It keeps command logs out of
the bundle and records checksums for the retained files. These files support
inspection; the local verification predicate alone is not a signed attestation
or a complete registry backup. Backup of registry signatures and attestations
follows `IG0395` and includes every platform and the released index.

ConClear rescans load repository configuration and require its byte digest to
match the original signed release verification. A current `conclear.toml` that
has changed cannot stand in for the release's copy, even when it still names
the same image. A retained checkout supplies any Containerfiles, contexts and
test files that configuration loading also needs. The rescan uses current
scanner data and verifies registry evidence; it does not rebuild or run the
historical source. A fresh rescan remains possible after the original
qualification window expires.


## Linting and testing<a id="linting-and-testing"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- Every image repository owner MUST automate linting, clean builds and runtime
  tests. A locally successful build is not release evidence.
  `IG0398`<a id="ig0398"></a>

**You MUST:**

- Run Hadolint against every maintained Containerfile.
  `IG0399`<a id="ig0399"></a>
- Document each disabled Hadolint rule next to the narrowest applicable
  configuration or suppression. `IG0400`<a id="ig0400"></a>
- Build with a clean, rootless Buildah environment and pull the declared inputs.
  `IG0401`<a id="ig0401"></a>
- Run application tests before constructing a release image.
  `IG0402`<a id="ig0402"></a>
- Run a container smoke test as the configured user for every supported
  platform. `IG0403`<a id="ig0403"></a>
- Test startup, readiness where applicable, graceful termination and expected
  exit status. `IG0404`<a id="ig0404"></a>
- Test the declared functional runtime contract. When it permits sudo
  escalation, a writable root filesystem or additional capabilities, also run a
  separate restrictive test of the same gated artifact with a read-only root
  filesystem, all capabilities dropped and `no-new-privileges`. In that test,
  privilege escalation is expected to fail; the image need not complete
  administration tasks that the restrictions deliberately prevent.
  `IG0405`<a id="ig0405"></a>
- For a sudo escalation requirement, test a permitted operation from an actual
  non-root caller and denial for an unauthorized caller or operation. Repeat the
  permitted operation under `no-new-privileges` and require escalation to fail.
  Validate sudoers with the installed implementation's validator. Record the
  caller identities, policy, commands, outcomes and observed runtime controls.
  A presence-only requirement does not claim working escalation.
  `IG0422`<a id="ig0422"></a>
- Run with measured memory, CPU, PID and `nofile` limits during a
  resource-control test. `IG0406`<a id="ig0406"></a>
- Inspect the final image configuration, layers, labels, user, entrypoint and
  platform metadata. `IG0407`<a id="ig0407"></a>


**Tests use the exact gated artifact.**

- Runtime tests MUST use the manifest imported from the gated OCI layout through
  a digest-preserving path. `IG0408`<a id="ig0408"></a>
- Before tests, the harness MUST recursively validate the layout's OCI
  descriptors and blobs, resolve the manifest from the runtime's
  containers-storage and compare it with the accepted layout digest.
  `IG0409`<a id="ig0409"></a>
- Any digest mismatch during test preparation MUST be treated as an operational
  failure, never as a policy pass or a skipped check.
  `IG0410`<a id="ig0410"></a>

**You SHOULD:**

- Use a dedicated smoke and structure test harness instead of unstructured
  shell. [Testinfra](https://testinfra.readthedocs.io/) is the default;
  [Goss](https://github.com/goss-org/goss) suits projects that prefer one Go
  binary and YAML over Python. `IG0411`<a id="ig0411"></a>
- Test a clean no-cache build periodically in addition to ordinary cached
  builds. `IG0412`<a id="ig0412"></a>
- Enforce a maximum image-size or layer regression threshold derived from the
  application, not a universal byte limit. `IG0413`<a id="ig0413"></a>
- Test the published digest after pulling it from the registry.
  `IG0414`<a id="ig0414"></a>
- Run scheduled rebuilds even when application source has not changed so base
  and package security updates are consumed; the organization owns the
  scheduling. `IG0415`<a id="ig0415"></a>

**You MUST NOT:**

- Add a Containerfile formatting tool to the pipeline.
  `IG0416`<a id="ig0416"></a>


Run Hadolint through the resolved release toolchain. Keep policy decisions in
committed configuration, not flags. Use inline suppression only for a narrow,
single-instruction exception. Buildah-supported syntax may occasionally produce
false positives:

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

In-container Testinfra assertions require a shell because its Podman backend
uses `podman exec`. Test shell-less `scratch` images from outside: use
`podman inspect` for configuration and the network or health interface for
behavior.


## Reference Containerfile<a id="reference-containerfile"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This example packages a prebuilt static executable with `scratch`. Most
applications need a maintained base for certificate, timezone, user or
shared-library data. Replace placeholders through the authorized release process
and use `scratch` only after testing the
[base-image requirements](#choosing-a-base-image).

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

- An application that compiles inside the Containerfile SHOULD add a pinned,
  approved `build` stage and copy only its verified output into this runtime
  stage. `IG0417`<a id="ig0417"></a>
- A dynamically linked application MUST instead use a compatible runtime base
  containing its required loader, libraries and runtime data.
  `IG0418`<a id="ig0418"></a>
- The repository owner MUST document how `build/example` is produced, tested and
  associated with the source revision recorded in the labels and provenance.
  `IG0419`<a id="ig0419"></a>

The corresponding minimal `.containerignore` for an externally built artifact
is:

```gitignore
**
!build/
!build/example
!Containerfile
```

The example is a structural reference, not a universal base-image choice.


## Reasoning<a id="reasoning"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

- **Toolchain and Docker.** Buildah, Podman and Skopeo are rootless, daemonless
  and open source. Docker compatibility is incidental, untested and unsupported.
  Although based on open-source software, Quay.io and Sigstore's public
  infrastructure are hosted services with separate terms. Distributing tools may
  create license obligations even when their licenses do not cover generated
  images.
- **Release environments.** CI automates releases but is not the trust boundary.
  A maintainer workstation can run the same gates: ConClear builds an isolated
  reviewed revision, obtains external signing authority and records the
  environment. Host administration and key custody remain trusted external
  controls. Provider-neutral release behavior avoids dependence on one CI
  service. Optional observed CI context helps correlate public evidence with
  provider records, but ordinary provider environment variables do not
  authenticate that context.
- **Release tool versions.** Tool changes during a release make its evidence
  inconsistent. ConClear therefore resolves compatible versions once, records
  them and holds them constant. Global pins would impede upgrades without adding
  release identity: evidence identifies the tools, and the ConClear version
  identifies the rules.
- **Image purpose and privileges.** An OS test target may need package
  installation or Ansible privilege escalation; those operations explain a
  writable-root or sudo requirement. A service or one-shot task can also have
  justified requirements. Lifecycle profiles select process tests, and each
  permission is reviewed separately. An image category does not grant
  privileges or relax digest, provenance, scanner, signature or source-integrity
  controls. Functional tests exercise the intended operations; restrictive
  tests check behavior when escalation and writes are denied.
- **Requirement identifiers.** A stable identifier per statement lets a guide
  revision be reviewed as a list of added, retired and reworded requirements,
  lets ConClear state coverage for every requirement instead of every section,
  and gives findings, exceptions and reviews something exact to cite. Sequential
  numbering keeps an identifier independent of the statement's position.
- **Tool-owned rule identifiers.** ConClear needs stable check identifiers for
  precise findings and suppressions. Like Hadolint's `DL` codes, they belong to
  the tool, not this guide. Its conformance documentation maps them to the
  guide's requirement identifiers.
- **Versioned ruleset.** Embedding the guide revision identifies ConClear's
  implemented rules without a separate policy artifact. Recording both revisions
  distinguishes guide changes from implementation changes.
- **Candidate references.** One source revision can rebuild to different
  digests, so the revision alone cannot identify an attempt. A version or
  revision prefix groups related tags; the sortable, collision-resistant run
  identifier distinguishes attempts. Candidates stay in the final repository
  because OCI referrers, Cosign signatures and attestations are
  repository-scoped and `skopeo copy --all` does not move them. A separate
  repository requires explicit recreation and verification of that evidence at
  the final location.
- **Platform transport.** Records claim but do not prove their origin. Digest
  verification before assembly keeps qualification meaningful without separate
  transport authentication.
- **Registries.** OCI image transport is portable, but control APIs and
  conclusive mutation recovery depend on the deployment. A compiled backend
  alone does not establish a tested complete release path. Consume from the
  authoritative upstream registry because a similarly named repackaging is not
  equivalent. Use mirrors only for specific availability or policy needs; an
  unmaintained mirror becomes stale and unscanned.
- **Version-tag protection.** Registry-side tag protection is not uniformly
  available, so version-tag stability remains mandatory while provider
  enforcement is recommended.
- **Candidate cleanup.** Automatic cleanup limits abandoned artifacts, while
  ConClear independently enforces release-authorization deadlines.
- **Base images.** One mandatory distribution would sacrifice compatibility,
  lifecycle fit and diagnostic knowledge for superficial consistency. Image size
  is an incomplete measure of attack surface, which depends on reachable
  behavior, configuration and privileges. A smaller base also does not help a
  team that cannot patch or debug it. musl remains a compatibility boundary for
  glibc-targeted software.
- **Digest pinning and updates.** Tags document intent; digests select bytes.
  Pinning transfers change control to the repository and creates an update duty.
  A forgotten digest freezes its vulnerabilities, and pinning alone does not
  ensure reproducibility. ConClear therefore separates a non-mutating,
  identity-bearing proposal from verified, all-or-nothing application. A pinned
  self-hosted updater may deliver the same proposal through a review branch, but
  a forge, branch and bot credential are not prerequisites for an authorized
  local maintainer workflow.
- **Pin intent and freshness.** Divergence under an immutable-version tag may be
  a supply-chain event; under a moving release line it is routine. Declared
  intent tells the pin check which applies. Checking only reports; explicit
  proposal and application operations preserve review boundaries while avoiding
  partial or opportunistic edits.
- **Build context.** The context is builder input and may be transferred, cached
  or inspected even when never copied into the image, so it is bounded with an
  allowlist.
- **Packages and caches.** Exact package pins block security updates and may
  become unavailable after repository rotation. The base digest and SBOM record
  installed packages. Caches improve speed but are not build inputs.
- **File ownership.** Mode `0555` does not protect a file owned by its executor,
  who can change the mode and rewrite it. Root ownership prevents this; a
  read-only root filesystem adds a second control.
- **Build arguments and environment.** `ARG` and `ENV` values appear in image
  configuration, logs, caches and provenance. Treat them as public unless the
  documented secret channel protects them end to end.
- **Users and resource limits.** A container user is not a complete security
  boundary but still limits compromise. Measure resource limits because
  applications size internal data from them. For example, an inherited `nofile`
  limit in the millions has created a connection table hundreds of megabytes
  large at idle.
- **Entrypoint.** The shell form inserts a shell that changes argument handling
  and can block signal delivery. Supervisors are limited to documented product
  contracts because each extra process obscures the signal path and exit status
  that deployment tooling depends on.
- **Health checks.** The OCI image format has no health-check field, and health
  policy is an environment decision, so the deployment layer owns it.
- **Multi-platform.** Emulation runs a platform's real binaries but not its CPU
  features or kernel interfaces, so the execution mode is recorded and native
  workers remain the preference for architecture-specific native code.
- **Execution modes.** A single `uname` value cannot distinguish native,
  emulated and cross-built execution. Recording target, host, execution
  architecture and mechanism for build and test gives ConClear the evidence
  needed to apply its rules.
- **Reproducibility.** Rebuildability is what an incident requires: a working
  replacement from documented inputs. Bit-for-bit equivalence is desirable
  evidence but must be measured, not assumed.
- **Exact-digest releases.** Security statements bind to digests. Local OCI
  layouts allow content gates before publication; Skopeo's digest-preserving
  copy and recursive comparison prove that the registry received the accepted
  manifest and blobs. Rebuilding or transforming the upload breaks that link.
  Registries lack portable compare-and-swap and multi-tag transactions, so
  pre-write checks, post-write comparisons and failure records provide detection
  and fail-closed continuation, not atomicity.
- **One scanner stack.** Scanner databases and matching differ, so parallel
  gates create conflicting findings and duplicate exceptions. Second opinions
  remain non-gating. Trivy also supplies the required secret and configuration
  scans. Registry scanning adds defense but cannot replace the release gate, and
  an empty result does not prove security. Busy CI runners can hit Trivy's
  public database rate limits. Cache it, configure `--db-repository` or host a
  mirror. Rescan retained SBOMs to reduce cost.
- **Rescan scope.** An SBOM rescan matches known vulnerabilities against
  retained inventory. It cannot scan secrets or configuration without the
  filesystem. Evidence therefore states the scope; configurations requiring
  those scans must fetch the immutable image.
- **Remediation clocks.** Starting at an informal scan allows resets; starting
  at publication penalizes later discoveries. The authoritative rescan result
  provides a fixed start. Record later triage and exceptions as new results.
  Never repoint a version tag, which would change content already verified by
  consumers.
- **Provenance and signing.** Correct SLSA fields alone do not establish trust.
  The generator must run in the authorized release environment, and verification
  must use the approved signing key. The managed key pair keeps key custody
  under the organization's control; the public transparency log makes release
  signing auditable. Manual experiments use disposable keys without log upload
  to avoid permanent test entries and release-key associations. KMS or HSM
  protection can later reduce exposure of exportable keys. Keep builder, signer
  and source identities separate so one compromise cannot impersonate all three.
- **Evidence retention.** Registry attestations are authoritative only while
  they remain fetchable and verifiable. A registry migration can orphan them, so
  exports or backups should match the release support lifetime.
- **Formatting and test harness.** No Containerfile formatter has ecosystem
  authority, and Hadolint does not format. Lint rules and review enforce layout.
  Testinfra reuses the [Python style guide's](./python-style-guide.md) pytest
  stack; Goss offers one Go binary with YAML assertions.


## Author information<a id="author-information"></a>

[*⇑ Back to TOC ⇑*](#table-of-contents)

This guide was written by [foundata](https://foundata.com/) for OCI container
images maintained in source repositories.
