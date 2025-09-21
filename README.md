![npm meme](./npm_meme.png)

# NPM Security Best Practices

> [!NOTE]  
> The NPM ecosystem is no stranger to compromises[^1][^2], supply-chain attacks[^3], malware[^4][^5], spam[^6], phishing[^7], incidents[^8] or even trolls[^9]. In this repository, I have consolidated a list of information you might find useful in securing yourself against these incidents.
>
> Feel free to submit a Pull Request, or reach out to me on [Twitter](https://x.com/bodadotsh)!

> [!TIP]
> This repository covers `npm`, `bun`, `deno`, `pnpm`, `yarn` and more.

## Table of Contents

- [For Developers](#for-developers)
  - [1. Pin dependency versions](#1-pin-dependency-versions)
  - [2. Include lockfiles](#2-include-lockfiles)
  - [3. Disable lifecycle scripts](#3-disable-lifecycle-scripts)
  - [4. Set minimal release age](#4-set-minimal-release-age)
  - [5. Permission Model](#5-permission-model)
  - [6. Reduce external dependencies](#6-reduce-external-dependencies)
- [For Maintainers](#for-maintainers)
  - [7. Enable 2FA](#7-enable-2fa)
  - [8. Create tokens with limited access](#8-create-tokens-with-limited-access)
  - [8. Generate provenance statements](#8-generate-provenance-statements)
  - [9. Review published files](#9-review-published-files)
- [Miscellaneous](#miscellaneous)
  - [10. Use private registry](#10-use-private-registry)
  - [11. Audit, monitor and security tools](#11-audit-monitor-and-security-tools)
  - [12. Donate to OSS](#12-donate-to-oss)

## For Developers

### 1. Pin Dependency Versions

> On `npm`, by default, a new dependency will be installed with the Caret `^` operator. This operator installs the most recent `minor` or `patch` releases. E.g., `^1.2.3` will install `1.2.3`, `1.2.4`, `1.3.0`, `1.6.2`, etc. Read more: [NPM About semantic versioning](https://docs.npmjs.com/about-semantic-versioning) and try out the [npm SemVer Calculator](https://semver.npmjs.com/)
>
> To avoid installing freshly compromised packages, it is advised of pinning exact versions (e.g., `"my-package": "1.2.3"`). **_However_**, our direct dependencies also have their own dependencies (_transitive_ dependencies). Even if we pin our direct dependencies, their transitive dependencies might still use broad version range operators (like `^` or `~`).

In CLI, use `--save-exact` or `-E` flag to pin exact version during installation: `npm install --save-exact react`

For `bun`, use `--exact/-E` e.g., `bun add --exact react`

For `deno`, manually specify exact version, e.g., `deno add npm:react@19.1.1`

For `pnpm`, use `--save-exact/-E`, e.g., `pnpm add -E react`

For `yarn`, use `--save-exact/-E`, e.g., `yarn add -E react`

We can also update this setting in configuration files (e.g., [`.npmrc`](https://docs.npmjs.com/cli/v11/configuring-npm/npmrc)), with either `save-exact` or [`save-prefix`](https://docs.npmjs.com/cli/v11/using-npm/config#save-prefix) alike key and value pairs:

For `npm`, run `npm config set save-exact=true`

For `pnpm`, run `pnpm config set save-exact true`

For `yarn`, run `yarn config set defaultSemverRangePrefix ""`

For `bun`, the config file is `bunfig.toml` and corresponding config is:

```toml
[install]
exact = true
```

### 2. Include Lockfiles

> Ensure to commit package managers lockfiles to `git` and share between different environments. Different lockfiles are: `package-lock.json` for `npm`, `pnpm-lock.yaml` for `pnpm`, `bun.lock` for `bun`, `yarn.lock` for `yarn` and `deno.lock` for `deno`.
>
> In automated environments such as continuous integration and deployments, we should install the exact dependencies as defined in the lockfile.

For `npm`, run `npm ci`

For `bun`, run `bun install --frozen-lockfile`

For `yarn`, run `yarn install --frozen-lockfile`

For `deno`, run `deno install --frozen` or set the following in a `deno.json` file:

```json
{
  "lock": {
    "frozen": true
  }
}
```

### 3. Disable Lifecycle Scripts

> Lifecycle scripts are special scripts that happen in addition to the `pre<event>`, `post<event>`, and `<event>` scripts. For instance, `preinstall` is run before `install` is run and `postinstall` is run after `install` is run. Read more: [How npm handles the "scripts" field](https://docs.npmjs.com/cli/v11/using-npm/scripts#life-cycle-scripts)
>
> Lifecycle scripts are a common strategy from malicious actors. For example, the "Shai-Hulud" worms[^3] edit the `package.json` file to add a `postinstall` script that would then steal credentials.

For `npm`, run `npm config set ignore-scripts true --global`

For `yarn`, run `yarn config set enableScripts false`

For `bun`, `deno` and `pnpm`, they are disabled by default.

> [!TIP]
> We can combine many of the flags above. For example, the following `npm` command would install only production dependencies as defined in the lockfile and ignore lifecycle scripts:
>
> `npm ci --omit=dev --ignore-scripts`

### 4. Set Minimal Release Age

> We can set a delay to avoid installing newly published packages. This applies to all dependencies, including transitive ones. For example, `pnpm v10.16` introduced the [`minimumReleaseAge` option](https://pnpm.io/settings#minimumreleaseage), which defines the minimum number of minutes that must pass after a version is published before pnpm will install it. If `minimumReleaseAge` is set to `1440`, then pnpm will not install a version that was published less than 24 hours ago.

For `pnpm`, run `pnpm config set minimumReleaseAge <minutes>`. There's also a `minimumReleaseAgeExclude` option to exclude certain packages from the minimum release age.

For `npm`, there is [a proposal](https://github.com/npm/cli/issues/8570) to add `minimumReleaseAge` option and `minimumReleaseAgeExclude` option. But we can already achieve a similar restriction by using the `--before` flag.

```sh
# only install packages published at least 1 day ago
npm install --before="$(date -v -1d)"
```

For `yarn`, config options `npmMinimalAgeGate` and `npmPreapprovedPackages` are implemented since [`v4.10.0`](https://github.com/yarnpkg/berry/releases/tag/%40yarnpkg%2Fcli%2F4.10.0).

For `bun`, it is discussed here: https://github.com/oven-sh/bun/issues/22679

For `deno`, an draft proposal is here: https://github.com/denoland/deno/pull/30752

> [!TIP]
> Renovate CLI (https://github.com/renovatebot/renovate) also provides the [`minimumReleaseAge`](https://docs.renovatebot.com/configuration-options/#minimumreleaseage) config option.

### 5. Permission Model

> In the latest LTS version of `nodejs`, we can use the Permission model to control what system resources a process has access to or what actions the process can take with those resources. **_However_**, this does not provide security guarantees in the presence of malicious code. Malicious code can still bypass the permission model and execute arbitrary code without the restrictions imposed by the permission model.

Read more about the Node.js permission model: https://nodejs.org/docs/latest/api/permissions.html

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

Deno enables permissions by default. Read more: https://docs.deno.com/runtime/fundamentals/security/

```sh
# by default, restrict access
deno run script.ts

# enable specific permission
deno run --allow-read script.ts
```

For Bun, the permission model is currently discussed [here](https://github.com/oven-sh/bun/discussions/725) and [here](https://github.com/oven-sh/bun/issues/6617).

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

## For Maintainers

### 7. Enable 2FA

> Two factor authentication (2FA) adds an extra layer of authentication to your `npm` account. 2FA is not required by default, but it is a good practice to enable it.
>
> Read more: https://docs.npmjs.com/about-two-factor-authentication

```sh
# ensure that 2FA is enabled for auth and writes (this is the default)
npm profile enable-2fa auth-and-writes
```

### 8. Create Tokens with Limited Access

> An access token is a common way to authenticate to `npm` when using the API or the `npm` CLI.
>
> Read more: https://docs.npmjs.com/about-access-tokens#about-granular-access-tokens

```sh
npm token create # for a read and publish token
npm token create --read-only # for a read-only token
npm token create --cidr=[list] # for a CIDR-restricted read and publish token
npm token create --read-only --cidr=[list] # for a CIDR-restricted read-only token
```

> [!TIP]
>
> - Restrict token to specific packages, scopes, and organizations
> - Set a token expiration date
> - Limit token access based on IP address ranges (CIDR notation)
> - Select between read-only or read and write access
> - Don't use the same token for multiple purposes

### 8. Generate Provenance Statements

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

Read more: https://docs.npmjs.com/generating-provenance-statements

### 9. Review Published Files

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
> The `.npmignore` file can also be used to exclude files from the published package.
>
> It will not override the `"files"` field, but in subdirectories it will.
>
> The `.npmignore` file works just like a `.gitignore`. If there is a `.gitignore` file, and `.npmignore` is missing, `.gitignore`'s contents will be used instead.

We can run `npx pack --dry-run` to see the contents that will be included in the published version of the package.

```sh
> npx pack --dry-run
npm notice Tarball Contents
npm notice 1.1kB LICENSE
npm notice 1.9kB README.md
npm notice 108B index.js
npm notice 700B package.json
npm notice Tarball Details
```

Also, run `npm publish --dry-run` to see what would be happen when we run the publish command.

## Miscellaneous

### 10. Use Private Registry

> Private package registries are a great way for organizations to manage their own dependencies, and can acts as a proxy to the public `npm` registry. Organizations can enforce security policies and vet packages before they are used in a project.

Here are some private registries that you might find useful:

- GitHub Packages https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-npm-registry
- Verdaccio https://github.com/verdaccio/verdaccio
- Vlt https://www.vlt.sh/
- JFrog Artifactory https://jfrog.com/artifactory/
- Sonatype: https://help.sonatype.com/en/npm-registry.html

### 11. Audit, Monitor and Security Tools

#### Audit

> Many package managers provide audit functionality to scan your project's dependencies for known security vulnerabilities, show a report and recommend the best way to fix them.

For `npm`, we can use the `npm audit` command: https://docs.npmjs.com/cli/v11/commands/npm-audit

```sh
npm audit # audit dependencies
npm audit fix # automatically install any compatible updates
npm audit signatures # verify the signatures of the dependencies
```

For `pnpm`, we can use the `pnpm audit` command: https://pnpm.io/cli/audit

```sh
pnpm audit
pnpm audit --fix
```

For `bun`, we can use the `bun audit` command: https://bun.com/docs/install/audit

```sh
bun audit
```

For `yarn`, we can use the `yarn npm audit` command: https://yarnpkg.com/cli/npm/audit

```sh
yarn npm audit
yarn npm audit --recursive # audit transitive dependencies
```

#### GitHub

https://github.com/security

GitHub offers several services that can help protect against `npm` malwares, including:

- **Dependabot:** This tool automatically scans your project's dependencies, including `npm` packages, for known vulnerabilities. Read more: https://docs.github.com/en/code-security/getting-started/dependabot-quickstart-guide
- **Software Bill of Materials (SBOMs):** GitHub allows you to export an SBOM for your repository directly from its dependency graph. An SBOM provides a comprehensive list of all your project's dependencies, including transitive ones (dependencies of your dependencies). Read more: https://docs.github.com/en/code-security/supply-chain-security/understanding-your-software-supply-chain/exporting-a-software-bill-of-materials-for-your-repository
- **Code Scanning:** Code scanning can also help identify potential vulnerabilities or suspicious patterns that might arise from integrating compromised `npm` packages. Read more: https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning

> [!WARNING]
> If you spot vulnerabilities or issues in NPM or Github, please report them using the following links:
>
> - https://docs.npmjs.com/reporting-malware-in-an-npm-package
> - https://docs.github.com/en/communities/maintaining-your-safety-on-github/reporting-abuse-or-spam#reporting-a-repository

#### Socket.dev

https://socket.dev/

Socket.dev is a security platform designed to protect JavaScript projects by scanning and securing dependencies from malicious and vulnerable code. It offers various tools such as GitHub App, "Safe NPM" CLI tool, Web Extension, and VSCode Extension. Watch their talk on [AI powered malware hunting at scale, Jan 2025](https://youtu.be/cxJPiMwoIyY) for more details.

### 12. Donate to OSS

> Maintainer burnout is a significant problem in the open-source community. Many popular `npm` packages are maintained by volunteers who work in their spare time, often without any compensation. Over time, this can lead to exhaustion and a lack of motivation, making them more susceptible to social engineering where a malicious actor pretends to be a helpful contributor and eventually injects malicious code.

> In 2018, the `event-stream` package was compromised due to the maintainer giving access to a malicious actor[^13]. Another example outside the JavaScript ecosystem is the XZ Utils incident[^14] in 2024 where a malicious actor worked for over three years to attain a position of trust.

> OSS donations also help create a more sustainable model for open-source development. Foundations can help support the business, marketing, legal, technical assistance and direct support behind hundreds of open source projects that so many rely upon[^15].

In the JavaScript ecosystem, the OpenJS Foundation (https://openjsf.org/) was founded in 2019 from a merger of JS Foundation and Node.js Foundation. But here are few platforms where you can also directly donate to OSS maintainers:

- GitHub Sponsors https://github.com/sponsors
- Open Collective https://opencollective.com
- Thanks.dev https://thanks.dev/home

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
