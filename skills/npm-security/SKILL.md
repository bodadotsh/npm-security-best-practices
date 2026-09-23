---
name: npm-security
description: Prevent JavaScript/TypeScript projects from supply-chain attacks across package managers like npm, pnpm, yarn, bun, and deno. Use whenever planning, installing, updating packages or configuring package managers
---

Apply the following security best practices. NEVER override an explicit user opt-in config (lifecycle scripts, cooldowns, save prefix, etc) unless they ask.
Always check current package manager's verions, and verify against their official documentations. See "References" for links or perfom web searches.

## Best Practices

Best practices are safer and sensible environmental defaults that should be enabled for the agent's runtime, we are using `npm` as example here but you should check to see which package manager is available and apply the configurations according.

### Lifecycle scripts

Unless explicitly defined otherwise, package managers should have lifecycle scripts set as **off**, for example `preinstall` and `postinstall`.

In `.npmrc`, this can be set as `ignore-scripts=true`, or through install command: `npm install --ignore-scripts <package>`.

### Dependency cooldowns / minimum release age

Unless explicitly defined otherwise, dependency installations should respect a cooldown period (default to 3 days).

In `.npmrc`, this can be set as `min-release-age=3`, or through install command `npm install --min-release-age=3 <package>`.

### Exact versions

Unless explicitly defined otherwise, package installations should install the expact version instead of a semver range.

In `.npmrc`, this can be set as `save-exact=true`, or through install command `npm install --save-exact <package>`

> Persist these defaults in the project `.npmrc` (or the package manager’s equivalent), merging only keys that are unset; never overwrite existing values unless the user asks.
> View https://github.com/bodadotsh/npm-security-best-practices for extensive tips with different JavaScript package managers (npm, yarn, pnpm, etc...).

## Planning stage / package scorers

When planning third-party dependencies, we should score package candidates first. This reduces risk of greyware (not malware, but can be trollware, abandonware, low quality, license changes, etc).

Few free and trustworthy scorers are:

- Socket MCP Server: https://github.com/SocketDev/socket-mcp
- https://deps.dev/
- OpenSSF Scorecard: https://github.com/ossf/scorecard

For example, Socket MCP server can be figured as:

```json
{
  "mcpServers": {
    "socket-mcp": {
      "type": "http",
      "url": "https://mcp.socket.dev/"
    }
  }
}
```

Once installed, use the MCP to ask questions like:

- "Check the security score for express version 4.18.2"
- "Analyze the security of my package.json dependencies"
- "What are the vulnerability scores for react, lodash, and axios?"

The user should set a policy of when to reject dependencies based on their health metrics (quality, supply chain, maintenance, etc), else default to a sensible number (e.g., 80).

## Install stage / package scanners

When it is time to install third-party dependencies, we should wrap the installation command with a package scanner first. This reduces risk of compromises as the scanner will check against a real-time intelligence database.

Few free and trustworthy scanners are:

- Socket Firewall Free CLI: https://github.com/SocketDev/sfw-free
- osv-scanner by osv.dev: https://github.com/google/osv-scanner
- Aikido Safe Chain: https://github.com/AikidoSec/safe-chain

FOr example, the `sfw` cli can be downloaded first through `npm i -g sfw` or through `npx`: `npx sfw npm install <package>`

Even as a popular and well-known package passes the planning/scoring stage, the installation/scanning stage can catch it if they get compromised.

## References

- https://boda.sh/blog/supply-chain-security-in-coding-agents/
- https://docs.npmjs.com/cli/
- https://pnpm.io/
- https://yarnpkg.com/
- https://bun.sh/llms.txt/
- https://docs.deno.com/runtime/

