![npm meme](./npm_meme.png)

# NPM Security Best Practices

> [!NOTE]  
> The NPM ecosystem is no stranger to compromises[^1][^2], supply-chain attacks[^3], malware[^4][^5], spam[^6], phishing[^7], incidents[^8] or even trolls[^9]. In this repository, I have consolidated a list of information you might find useful in securing yourself against these incidents.
>
> Feel free to submit a Pull Request, or reach out to me on [Twitter](https://x.com/bodadotsh)!

> [!TIP]
> This repository covers `npm`, `bun`, `deno`, `pnpm`, `yarn` and more.

<a href="https://news.ycombinator.com/item?id=45326754">
<img src="https://img.shields.io/badge/hacker%20news%20discussion-ff6600" alt="hn discussion"/>
</a>

## Table of Contents

- [Got Compromised?](#got-compromised)
  - [Immediate actions to take](#immediate-actions-to-take)
- [For Developers](#for-developers)
  - [1. Pin dependency versions](#1-pin-dependency-versions)
  - [2. Include lockfiles](#2-include-lockfiles)
  - [3. Disable lifecycle scripts](#3-disable-lifecycle-scripts)
  - [4. Preinstall preventions](#4-preinstall-preventions)
  - [5. Runtime protections](#5-runtime-protections)
  - [6. Reduce external dependencies](#6-reduce-external-dependencies)
- [For Maintainers](#for-maintainers)
  - [7. Enable 2FA](#7-enable-2fa)
  - [8. Create tokens with limited access](#8-create-tokens-with-limited-access)
  - [9. Generate provenance statements](#9-generate-provenance-statements)
  - [10. Review published files](#10-review-published-files)
- [Miscellaneous](#miscellaneous)
  - [11. NPM organization](#11-npm-organization)
  - [12. Alternative registry](#12-alternative-registry)
  - [13. Audit, monitor and security tools](#13-audit-monitor-and-security-tools)
  - [14. Support OSS](#14-support-oss)

## Got Compromised?

### Immediate Actions to take

> [!CAUTION]
> In the case of a npm supply chain compromise, here's what you can do immediately:
> 
> **Identify compromised packages**
> 
> Keep up with the latest updates about the attack from trusted newsfeed[^20][^21][^22][^23].
> 
> Confirm with vulnerability databases like https://security.snyk.io or https://socket.dev/search?e=npm
> 
> **Remove and replace compromised packages**
>
> ```sh
> # remove project cache
> rm -rf node_modules
> yarn cache clean
> pnpm cache delete
>
> # remove global cache
> npm cache clean --force
> yarn cache clean --mirror
> bun pm cache rm
> pnpm store prune
> ```
> 
> Downgrade and pin dependencies to a known clean version, or remove them entirely.
>
> Remove unwanted `node_modules` folders from system: `cd ~ && npx npkill`
> 
> **Restrict or disable automated scripts**
> 
> Disable automated pipelines or restrict them while the investigation is ongoing.
> 
> **Rotate all credentials**
> 
> Supply chain attacks often targets credentials in the system.
> Revoke and regenerate `npm` tokens, GitHub PATs, SSH keys, and cloud provider credentials.
>
> **Monitoring suspicious activities**
> 
> Review and monitor for unauthorized activities in your projects or organizations.
> Limit outbound network access to trusted domains only. Limit or revovke access from outsiders or third-party tools.
> Resume work on a brand new system (_highly recommended!_)

Pick the best practices below based on your needs to strengthen your system against the next attack.

## For Developers

> [!TIP]
> Here's a [sample `.npmrc` file](.npmrc) with the config options mentioned below:
>
> ```
> ignore-scripts=true
> provenance=true
> save-exact=true
> save-prefix=''
> ```
>
> And other configuration files examples are here:
>
> - [`bunfig.toml`](bunfig.toml)
> - [`pnpm-workspace.yaml`](pnpm-workspace.yaml)
> - [`deno.json`](deno.json)
> - [`.yarnrc.yml`](.yarnrc.yml)

### 1. Pin Dependency Versions

> On `npm`, by default, a new dependency will be installed with the Caret `^` operator. This operator installs the most recent `minor` or `patch` releases. E.g., `^1.2.3` will install `1.2.3`, `1.6.2`, etc. See https://docs.npmjs.com/about-semantic-versioning and try out the npm SemVer Calculator (https://semver.npmjs.com).

Here's how to pin exact version in various package managers:

```sh
npm install --save-exact react
pnpm add --save-exact react
yarn add --save-exact react
bun add --exact react
deno add npm:react@19.1.1
```

We can also update this setting in configuration files (e.g., [`.npmrc`](https://docs.npmjs.com/cli/v11/configuring-npm/npmrc)), with either [`save-exact`](https://docs.npmjs.com/cli/v11/using-npm/config#save-exact) or [`save-prefix`](https://docs.npmjs.com/cli/v11/using-npm/config#save-prefix) key and value pairs:

```sh
npm config set save-exact=true
pnpm config set save-exact true
yarn config set defaultSemverRangePrefix ""
```

For `bun`, the config file is `bunfig.toml` and corresponding config is:

```toml
[install]
exact = true
```

#### Override the transitive dependencies

> **_However_**, our direct dependencies also have their own dependencies (_transitive_ dependencies). Even if we pin our direct dependencies, their transitive dependencies might still use broad version range operators (like `^` or `~`). The solution is to override the transitive dependencies: https://docs.npmjs.com/cli/v11/configuring-npm/package-json#overrides

In `package.json`, if we have the following `overrides` field:

```json
{
  "dependencies": {
    "library-a": "^3.0.0"
  },
  "overrides": {
    "lodash": "4.17.21"
  }
}
```

- Let's assume that `⁠library-a`'s `⁠package.json` has a dependency on `"lodash": "^4.17.0"`
- Without the `⁠overrides` section, `⁠npm` might install `⁠lodash@4.17.22` (or any of the latest `⁠4.x.x` versions) as a transitive dependency of `⁠library-a`
- However, by adding `"overrides": { "lodash": "4.17.21" }`, we are telling `⁠npm` that anywhere `⁠lodash` appears in the dependency tree, it must be resolved to exactly version `⁠4.17.21`

For `pnpm`, we can also define the `overrides` field in the `pnpm-workspace.yaml` file: https://pnpm.io/settings#overrides

For `yarn`, the `resolutions` field is introduced before the `overrides` field, and it also offers a similar functionality: https://yarnpkg.com/configuration/manifest#resolutions

```json
{
  "resolutions": {
    "lodash": "4.17.21"
  }
}
```

```sh
# yarn also provide a cli to set the resolution: https://yarnpkg.com/cli/set/resolution
yarn set resolution <descriptor> <resolution>
```

For `bun`, it supports either the `overrides` field or the `resolutions` field: https://bun.com/docs/install/overrides

For `deno`, see https://github.com/denoland/deno/issues/28664 for more details.

### 2. Include Lockfiles

> Ensure to commit package managers lockfiles to `git` and share between different environments[^26]. Different lockfiles are: `package-lock.json` for `npm`, `pnpm-lock.yaml` for `pnpm`, `bun.lock` for `bun`, `yarn.lock` for `yarn` and `deno.lock` for `deno`.
>
> In automated environments such as continuous integration and deployments, we should install the exact dependencies as defined in the lockfile.

```sh
npm ci
bun install --frozen-lockfile
yarn install --frozen-lockfile
pnpm install --frozen-lockfile
deno install --frozen
```

For `deno`, we can also set the following in a `deno.json` file:

```json
{
  "lock": {
    "frozen": true
  }
}
```

> [!TIP]
>
> When dealing with merge conflicts in lockfiles, it is _not_ necessary to delete the lockfile. When dependencies (including transitive) are defined with version range operators (`^`, `~`, etc), re-building the lockfile from scratch can result in unexpected updates.
>
> Modern package managers have built-in conflict resolutions[^18][^19], just [checkout main and re-run `install`](https://github.com/yarnpkg/yarn/issues/1776#issuecomment-269539948). `pnpm` also allows [Git Branch Lockfiles](https://pnpm.io/git_branch_lockfiles) where it creates a new lockfile based on branch name, and automatically merge it back into the main lockfile later.

### 3. Disable Lifecycle Scripts

> Lifecycle scripts are special scripts that happen in addition to the `pre<event>`, `post<event>`, and `<event>` scripts. For instance, `preinstall` is run before `install` is run and `postinstall` is run after `install` is run. See how npm handles the "scripts" field: https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts
>
> Lifecycle scripts are a common strategy from malicious actors. For example, the "Shai-Hulud" worms[^3] edit the `package.json` file to add a `postinstall` script that would then steal credentials.

```sh
npm config set ignore-scripts true --global
yarn config set enableScripts false
```

For `bun`, `deno` and `pnpm`, they are disabled by default.

> [!NOTE]
>
> For `bun`, the [top 500 npm packages](https://github.com/oven-sh/bun/blob/main/src/install/default-trusted-dependencies.txt) with lifecycle scripts are allowed by default.

> [!TIP]
> We can combine many of the flags above. For example, the following `npm` command would install only production dependencies as defined in the lockfile and ignore lifecycle scripts:
>
> `npm ci --omit=dev --ignore-scripts`

### 4. Preinstall Preventions

> How do we know and trust that whenever we do `npm install <package-name>`, everything will be fine? We shouldn't. Here's how we can ensure that the `install` command is safer to run:

#### Preinstall Scanners

> Socket Firewall Free
> https://socket.dev/blog/introducing-socket-firewall

```sh
npm i -g sfw
# works for `npm`, `yarn`, `pnpm`
sfw npm install <package-name>

# example: alias `npm` to `sfw npm` in zsh
# echo "alias npm='sfw npm'" >> ~/.zshrc
```

> Aikido Safe Chain
> https://github.com/AikidoSec/safe-chain

The Aikido Safe Chain wraps around the npm cli, `npx`, `yarn`, `pnpm`, `pnpx`, `bun`, `bunx`, and `pip` to provide extra checks before installing new packages

```sh
npm install -g @aikidosec/safe-chain
```

> https://github.com/lirantal/npq

```sh
npq install express
NPQ_PKG_MGR=pnpm npx npq install fastify
```

With Bun, we can use its [Security Scanner API](https://bun.com/docs/pm/security-scanner-api)

```sh
bun add -d @socketsecurity/bun-security-scanner
```

From Bun v1.3+, you can [integrate Socket with Bun](https://socket.dev/blog/socket-integrates-with-bun-1-3-security-scanner-api)

```toml
# in bunfig.toml
[install.security]
scanner = "@socketsecurity/bun-security-scanner"
```

#### Set Minimal Release Age

> We can set a delay to avoid installing newly published packages. This applies to all dependencies, including transitive ones. For example, `pnpm v10.16` introduced the `minimumReleaseAge` option: https://pnpm.io/settings#minimumreleaseage, which defines the minimum number of minutes that must pass after a version is published before pnpm will install it. If `minimumReleaseAge` is set to `1440`, then pnpm will not install a version that was published less than 24 hours ago.

```sh
npm install --before=2025-10-22
# only install packages published at least 1 day ago
npm install --before="$(date -v -1d)"                               # for Mac or BSD users
npm install --before="$(date -d '1 days ago' +%Y-%m-%dT%H:%M:%S%z)" # for Linux users

# other related flags: minimumReleaseAgeExclude
pnpm config set minimumReleaseAge <minutes>

# other related flags: npmPreapprovedPackages
yarn config set npmMinimalAgeGate <minutes>
```

For `npm`, there is [a proposal](https://github.com/npm/cli/issues/8570) to add `minimumReleaseAge` option and `minimumReleaseAgeExclude` option.

For `bun`, the `minimumReleaseAge` and `minimumReleaseAgeExcludes` options are supported since [`v1.3`](https://bun.com/docs/cli/install#minimum-release-age).

```toml
[install]
minimumReleaseAge = 604800 # 7 days in seconds
```

For `deno`, they will soon ship a similar feature: https://github.com/denoland/deno/pull/30752

Examples of other tools that offer similar functionality:

- `npm-check-updates` (https://github.com/raineorshine/npm-check-updates) has the `--cooldown/-c` flag, for example: `npx npm-check-updates -i --format group -c 7`
- Renovate CLI (https://github.com/renovatebot/renovate) has a [`minimumReleaseAge`](https://docs.renovatebot.com/configuration-options/#minimumreleaseage) config option.
- Step Security (https://www.stepsecurity.io) has a [NPM Package Cooldown Check](https://www.stepsecurity.io/blog/introducing-the-npm-package-cooldown-check) feature.

### 5. Runtime Protections

Most techniques focus on the _install_ and _build_ phases, we can add an extra layer of security during the _runtime_ phase of JavaScript applications.

#### Permission Model

> In the latest LTS version of `nodejs`, we can use the Permission model to control what system resources a process has access to or what actions the process can take with those resources. **_However_**, this does not provide security guarantees in the presence of malicious code. Malicious code can still bypass the permission model and execute arbitrary code without the restrictions imposed by the permission model.

Read about the Node.js permission model: https://nodejs.org/docs/latest/api/permissions.html

```sh
# by default, granted full access
node index.js

# restrict access to all available permissions
node --permission index.js

# enable specific permissions
node --permission --allow-fs-read=* --allow-fs-write=* index.js

# use permission model with `npx`
npx --node-options="--permission" <package-name>
```

Deno disables permissions by default. See https://docs.deno.com/runtime/fundamentals/security/

```sh
# by default, restrict access
deno run script.ts

# enable specific permission
deno run --allow-read script.ts
```

For Bun, the permission model is currently discussed [here](https://github.com/oven-sh/bun/discussions/725) and [here](https://github.com/oven-sh/bun/issues/6617).

#### Hardened JavaScript

Companies like MetaMask and Moddable uses https://www.npmjs.com/package/ses and https://github.com/LavaMoat/LavaMoat to enable runtime protections like prevent modifying JavaScript's primordials (Object, String, Number, Array, ...), and limit access to the platform API (window, document, XHR, etc) per-package. These mechanism are also suggested as TC39 proposals like https://github.com/tc39/proposal-compartments

> Watch [The Attacker is Inside: Javascript Supplychain Security and LavaMoat (~20mins, Nov 2022)](https://youtu.be/Z5Bz0DYga1k) to get a quick high level overview of how this works.

### 6. Reduce External Dependencies

> Because `npm` has a low barrier for publishing packages, the ecosystem quickly grew to be the biggest package registry with over 5 million packages to date[^11]. But not all packages are created equal. There are small utility packages[^8] that are downloaded as dependencies when we could write them ourselves and raise the question of "have we forgotten how to code?[^12]"

Between `nodejs`, `bun` and `deno`, developers can use many of their modern features instead of relying on third-party libraries. The native modules may not provide the same level of functionality, but they should be considered whenever possible. Here are few examples:

| NPM libraries                     | Built-in modules                                                   |
| --------------------------------- | ------------------------------------------------------------------ |
| `axios`, `node-fetch`, `got`, etc | native`fetch` API                                                  |
| `jest`, `mocha`, `ava`, etc       | `node:test`,`node:assert`, `bun test` and `deno test`              |
| `nodemon`, `chokidar`, etc        | `node --watch`, `bun --watch` and `deno --watch`                   |
| `dotenv`, `dotenv-expand`, etc    | `node --env-file`, `bun --env-file` and `deno --env-file`          |
| `typescript`, `ts-node`, etc      | `node --experimental-strip-types`[^10], native to `deno` and `bun` |
| `esbuild`, `rollup`, etc          | `bun build` and `deno bundle`                                      |
| `prettier`, `eslint`, etc         | `deno lint` and `deno fmt`                                         |

Here are some resources that you might find useful:

- https://obsidian.md/blog/less-is-safer
- https://kashw1n.com/blog/nodejs-2025
- https://lyra.horse/blog/2025/08/you-dont-need-js
- https://blog.greenroots.info/10-lesser-known-web-apis-you-may-want-to-use
- https://github.com/you-dont-need/You-Dont-Need-Momentjs
- Visualise library dependencies: https://npmgraph.js.org
- Another tool to visualise dependencies and more: https://node-modules.dev
- Knip (remove unused dependencies): https://github.com/webpro-nl/knip
- Erase unwanted `node_modules` with [`npkill`](https://github.com/voidcosmos/npkill): `cd ~ && npx npkill`

## For Maintainers

### 7. Enable 2FA

https://docs.npmjs.com/about-two-factor-authentication

> Two factor authentication (2FA) adds an extra layer of authentication to your `npm` account. 2FA is not required by default, but from December 2025, when you create a new package, 2FA will be enabled by default in the package settings.

```sh
# ensure that 2FA is enabled for auth and writes (this is the default)
npm profile enable-2fa auth-and-writes
```

| Automation level | Package publishing access                                                                                                                     |
| ---------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Manual           | Set each package access to `Require 2FA` and `Disable Tokens`                                                                                 |
| Automatic        | Set each package access to `Require two-factor authentication` OR `Single factor automation tokens` OR `Single factor granular access tokens` |

> [!IMPORTANT]
>
> It is advised to configure a security-key that support [WebAuthn](https://caniuse.com/?search=webauthn), instead of time-based one-time password (TOTP)[^17]

### 8. Create Tokens with Limited Access

> [!TIP]
>
> Best practice: prefer _trusted publishing_ over tokens if possible! See [the "trusted publishing" section below](#trusted-publishing) for more details.

https://docs.npmjs.com/about-access-tokens#about-granular-access-tokens

> At the end of 2025, NPM announced the [sunset of Legacy Tokens](https://github.blog/changelog/2025-09-29-strengthening-npm-security-important-changes-to-authentication-and-token-management/) to improve security. [Granular Access Tokens](https://docs.npmjs.com/about-access-tokens#about-granular-access-tokens) is the default going forward[^27].

Create granular access tokens via the website: https://docs.npmjs.com/creating-and-viewing-access-tokens#creating-granular-access-tokens-on-the-website or `npm` cli: https://docs.npmjs.com/cli/v11/commands/npm-token

The `npm login` cli command enables a two-hour session token instead of long-lived tokens. During these sessions, 2FA is enforced for publishing operations, adding an extra layer of security.

Here are some best practices when creating tokens:

- Descriptive token names
- Restrict token to specific packages, scopes, and organizations
- Set a token expiration date (e.g., annually)
- Limit token access based on IP address ranges (CIDR notation)
- Select between read-only or read and write access
- Don't use the same token for multiple purposes

### 9. Generate Provenance Statements

https://docs.npmjs.com/generating-provenance-statements

> The _provenance attestation_ is established by publicly providing a link to a package's source code and build instructions from the build environment. This allows developers to verify where and how your package was built before they download it.
>
> The _publish attestations_ are generated by the registry when a package is published by an authorized user. When an npm package is published with provenance, it is signed by Sigstore public good servers and logged in a public transparency ledger, where users can view this information.
>
> For example, here's what a provenance statement look like on the `vue` package page: https://www.npmjs.com/package/vue#provenance

To establish provenance, use a supported CI/CD provider (e.g., GitHub Actions) and publish with the correct flag:

```sh
npm publish --provenance
```

To publish without evoking the `npm publish` command, we can do one of the following:

- Set `NPM_CONFIG_PROVENANCE` to `true` in CI/CD environment
- Add `provenance=true` to `.npmrc` file
- Add `publishConfig` block to `package.json`

```json
"publishConfig": {
  "provenance": true
}
```

> For those interested in [Reproducible Builds](https://reproducible-builds.org), check out OSS Rebuild (https://github.com/google/oss-rebuild) and the Supply-chain Levels for Software Artifacts (SLSA) framework (https://slsa.dev).

#### Trusted Publishing

> Use _trusted publishing_ over tokens whenever possible[^17]

When using OpenID Connect (OIDC) auth, one can publish packages _without_ npm tokens, and get _automatic_ provenance. This is called **trusted publishing** and read the GitHub announcement here: https://github.blog/changelog/2025-07-31-npm-trusted-publishing-with-oidc-is-generally-available/

See https://docs.npmjs.com/trusted-publishers for instructions on how to configure trusted publishing.

Related tools:

- https://github.com/antfu/open-packages-on-npm (CLI to setup Trusted Publisher for monorepo packages)
- https://github.com/sxzz/userscripts/blob/main/src/npm-trusted-publisher.md (Userscript to fill the form for Trusted Publisher on npmjs.com)

### 10. Review Published Files

> Limiting the files in an npm package helps prevent malware by reducing the attack surface, and it avoids accidental leaking of sensitive data

The `files` field in `package.json` is used to specify the files that should be included in the published package. Certain files are always included, see: https://docs.npmjs.com/cli/v11/configuring-npm/package-json#files for more details.

```json
{
  "name": "my-package",
  "version": "1.0.0",
  "main": "dist/index.js",
  "files": ["dist", "LICENSE", "README.md"]
}
```

> [!TIP]
>
> The `.npmignore` file can also be used to exclude files from the published package. It will not override the `"files"` field, but in subdirectories it will.
>
> The `.npmignore` file works just like a `.gitignore`. If there is a `.gitignore` file, and `.npmignore` is missing, `.gitignore`'s contents will be used instead.

Run `npm pack --dry-run` or `npm publish --dry-run` to see what would happen when we run the pack or publish command.

```sh
> npm pack --dry-run
npm notice Tarball Contents
npm notice 1.1kB LICENSE
npm notice 1.9kB README.md
npm notice 108B index.js
npm notice 700B package.json
npm notice Tarball Details
```

In `deno.json`, use the `publish.include` and `publish.exclude` fields to specify the files that should be included or excluded:

```json
{
  "publish": {
    "include": ["dist/", "README.md", "deno.json"],
    "exclude": ["**/*.test.*"]
  }
}
```

## Miscellaneous

### 11. NPM Organization

https://docs.npmjs.com/organizations

At the organization level, best practices are:

- Enable `Require 2FA` at the Organization Level
- Minimise the number of `npm` Organization members
- If multiple package teams in same organization, set the `developers` Team permission for all packages to `READ`
- Create separate Teams to manage permissions for each package

### 12. Alternative Registry

JSR is a modern JavaScript/TypeScript package registry with backwards compatibility with npm.

> [!NOTE]
> Not all npm packages are on JSR!
>
> Visit https://jsr.io to see if the package is available and read the [npm limitations](https://jsr.io/docs/npm-compatibility#limitations) documentation.

```sh
deno add jsr:<package-name>
pnpm add jsr:<package-name> # pnpm 10.9+
yarn add jsr:<package-name> # yarn 4.9+
# npm, bun, and older versions of yarn or pnpm
npx jsr add <package-name> # replace npx with yarn dlx, pnpm dlx, or bunx
```

#### Private Registry

> Private package registries are a great way for organizations to manage their own dependencies, acts as a proxy to the public `npm` registry, and enforce security policies before they are used in a project.

Here are some private registries that you might find useful:

- GitHub Packages https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry
> [!IMPORTANT]
> Currently, GitHub Packages only supports personal access token (classic), but classic PATs can be insecure as it has broad permissions and lacks of granular permissions![^24][^25] 
> For this reason, you may want to pick an alternative package registry from below ⬇️
- Verdaccio https://github.com/verdaccio/verdaccio
  - See Verdaccio best practices: https://verdaccio.org/docs/best/
- Vlt https://www.vlt.sh/
  - [vlt’s Serverless Registry](https://docs.vlt.sh/registry) (VSR) can be deployed to Cloudflare Workers in minutes.
- JFrog Artifactory https://jfrog.com/integrations/npm-registry
- Sonatype: https://help.sonatype.com/en/npm-registry.html

> [!TIP]
>#### No Registry?
>
> If the usage of a public registry like `npm` is a real concern, it is also possible to build and import the library yourself as long as you have access to the source code. 
>
> See https://boda.sh/blog/pnpm-workspace-git-submodules/ for adding packages without `npm` but with `pnpm workspace` and `git submodules`.

### 13. Audit, Monitor and Security Tools

#### Audit

> Many package managers provide audit functionality to scan your project's dependencies for known security vulnerabilities, show a report and recommend the best way to fix them.

```sh
npm audit # audit dependencies
npm audit fix # automatically install any compatible updates
npm audit signatures # verify the signatures of the dependencies

pnpm audit
pnpm audit --fix

bun audit

yarn npm audit
yarn npm audit --recursive # audit transitive dependencies
```

#### GitHub

> https://github.com/security

GitHub offers several services that can help protect against `npm` malwares, including:

- [Dependabot](https://docs.github.com/en/code-security/getting-started/dependabot-quickstart-guide): This tool automatically scans your project's dependencies, including `npm` packages, for known vulnerabilities.
- [Software Bill of Materials (SBOMs)](https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/exporting-a-software-bill-of-materials-for-your-repository): GitHub allows you to export an SBOM for your repository directly from its dependency graph. An SBOM provides a comprehensive list of all your project's dependencies, including transitive ones (dependencies of your dependencies).
- [Code Scanning](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning): Code scanning can also help identify potential vulnerabilities or suspicious patterns that might arise from integrating compromised `npm` packages.

> [!WARNING]
> If you spot vulnerabilities or issues in NPM or Github, please report them using the following links:
>
> - https://docs.npmjs.com/reporting-malware-in-an-npm-package
> - https://docs.github.com/en/communities/maintaining-your-safety-on-github/reporting-abuse-or-spam#reporting-a-repository

#### OpenSSF Scorecard

> https://securityscorecards.dev and https://github.com/ossf/scorecard

Free and open source automated tool that assesses a number of important heuristics ("checks") associated with software security and assigns each check a score of 0-10. Several risks mentioned in this repository are included as part of the checks: Pinned Dependencies, Token Permissions, Packaging, Signed Releases,...

Run the checks:

1. automatically on code you own using the [GitHub Action](https://github.com/marketplace/actions/ossf-scorecard-action)
2. manually on your (or somebody else’s) project via the [Command Line](https://github.com/ossf/scorecard#scorecard-command-line-interface)

#### Socket.dev

> https://socket.dev

Socket.dev is a security platform that protects code from both vulnerable and malicious dependencies. It offers various tools such as a [GitHub App](https://socket.dev/features/github) scans pull requests, [CLI tool](https://socket.dev/features/cli), [web extension](https://socket.dev/features/web-extension), [VSCode extension](https://docs.socket.dev/docs/socket-for-vs-code) and more. Here's their talk on [AI powered malware hunting at scale, Jan 2025](https://youtu.be/cxJPiMwoIyY). Plus the Socket Firewall `sfw` tool in the [Preinstall Scanners section](https://github.com/bodadotsh/npm-security-best-practices/tree/main?tab=readme-ov-file#preinstall-scanners).

#### Snyk

> https://snyk.io

Snyk offers a suite of tools to fix vulnerabilities in open source dependencies, including a CLI to run vulnerability scans on local machine, IDE integrations to embed into development environment, and API to integrate with Snyk programmatically. For example, you can [test public npm packages before use](https://docs.snyk.io/developer-tools/snyk-cli/scan-and-maintain-projects-using-the-cli/test-public-npm-packages-before-use) or [create automatic PRs for known vulnerabilities](https://docs.snyk.io/scan-with-snyk/pull-requests/snyk-pull-or-merge-requests/create-automatic-prs-for-backlog-issues-and-known-vulnerabilities-backlog-prs).

#### FOSSA

> https://fossa.com/ 

FOSSA is a compliance and security platform that helps organizations manage the complexities of their software supply chain. It achieves this by providing visibility into all software components, from [packages and containers to binaries](https://fossa.com/products/scan/). By generating comprehensive SBOMs (Software Bill of Materials), companies reduce legal and IP risk, consolidate vulnerability management across their codebase, and [comply with regulatory reporting requirements](https://fossa.com/solutions/due-diligence/). 

### 14. Support OSS

> Maintainer burnout is a significant problem in the open-source community. Many popular `npm` packages are maintained by volunteers who work in their spare time, often without any compensation. Over time, this can lead to exhaustion and a lack of motivation, making them more susceptible to social engineering where a malicious actor pretends to be a helpful contributor and eventually injects malicious code.

> In 2018, the `event-stream` package was compromised due to the maintainer giving access to a malicious actor[^13]. Another example outside the JavaScript ecosystem is the XZ Utils incident[^14] in 2024 where a malicious actor worked for over three years to attain a position of trust.

> OSS donations also help create a more sustainable model for open-source development. Foundations can help support the business, marketing, legal, technical assistance and direct support behind hundreds of open source projects that so many rely upon[^15][^16].

In the JavaScript ecosystem, the OpenJS Foundation (https://openjsf.org) was founded in 2019 from a merger of JS Foundation and Node.js Foundation to support some of the most important JS projects. And few other platforms are listed below where you can donate and support the OSS you use everyday:

- GitHub Sponsors https://github.com/sponsors
- Open Collective https://opencollective.com
- Thanks.dev https://thanks.dev
- Open Source Pledge https://opensourcepledge.com
- Ecosystem Funds: https://funds.ecosyste.ms

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=bodadotsh/npm-security-best-practices&type=date&legend=top-left)](https://www.star-history.com/#bodadotsh/npm-security-best-practices&type=date&legend=top-left)

[^1]: https://www.aikido.dev/blog/npm-debug-and-chalk-packages-compromised

[^2]: https://socket.dev/blog/nx-packages-compromised

[^3]: https://socket.dev/blog/ongoing-supply-chain-attack-targets-crowdstrike-npm-packages

[^4]: https://www.reversinglabs.com/blog/malicious-npm-patch-delivers-reverse-shell

[^5]: https://socket.dev/blog/north-korean-apt-lazarus-targets-developers-with-malicious-npm-package

[^6]: https://socket.dev/blog/npm-registry-spam-john-wick

[^7]: https://github.com/duckdb/duckdb-node/security/advisories/GHSA-w62p-hx95-gf2c

[^8]: https://en.wikipedia.org/wiki/Npm_left-pad_incident

[^9]: https://socket.dev/blog/when-everything-becomes-too-much

[^10]: https://nodejs.org/en/learn/typescript/run-natively

[^11]: https://libraries.io/npm

[^12]: https://www.theregister.com/2016/03/29/npmgate_followup

[^13]: https://github.com/dominictarr/event-stream/issues/116

[^14]: https://en.wikipedia.org/wiki/XZ_Utils_backdoor

[^15]: https://openssf.org/blog/2024/04/15/open-source-security-openssf-and-openjs-foundations-issue-alert-for-social-engineering-takeovers-of-open-source-projects/

[^16]: https://xkcd.com/2347

[^17]: https://docs.npmjs.com/trusted-publishers#prefer-trusted-publishing-over-tokens

[^18]: https://stackoverflow.com/questions/54124033/deleting-package-lock-json-to-resolve-conflicts-quickly

[^19]: https://pnpm.io/git#merge-conflicts

[^20]: https://news.ycombinator.com

[^21]: https://socket.dev/blog

[^22]: https://www.aikido.dev/blog

[^23]: https://www.wiz.io/blog

[^24]: https://github.com/github/roadmap/issues/558

[^25]: https://docs.github.com/en/packages/learn-github-packages/about-permissions-for-github-packages#about-scopes-and-permissions-for-package-registries

[^26]: https://nesbitt.io/2025/12/06/github-actions-package-manager.html#:~:text=The%20fix%20is%20a%20lockfile

[^27]: https://github.blog/changelog/2025-12-09-npm-classic-tokens-revoked-session-based-auth-and-cli-token-management-now-available/
