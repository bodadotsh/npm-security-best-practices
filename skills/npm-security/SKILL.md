---
name: npm-security
description: Prevent JavaScript/TypeScript projects from supply-chain attacks across package managers like npm, pnpm, yarn, bun, and deno. Use whenever planning, installing, updating packages or configuring package managers
---

Apply the following security best practices. Never override an explicit user opt-in config (lifecycle scripts, cooldowns, save prefix, etc) unless they ask.

Always check current package manager's verions, and verify against their official documentations. See "References" for links or perfom web searches.

## Environment defaults

For the following best practices, we are using `npm` as example but you should check to see which package manager is available and apply the configurations according.

### Lifecycle scripts

Unless explicitly defined otherwiese, package managers should have lifecycle scripts set as **off**, for example `preinstall` and `postinstall`.

In `.npmrc`, this can be set as `ignore-scripts=true`, or through install command: `npm install --ignore-scripts <package>`.

### Cooldowns / minimum release age

Unless explicitly defined otherwiese, package installations should respect a cooldown period (default to 1 day).

In `.npmrc`, this can be set as `min-release-age=1`, or through install command `npm install --min-release-age=1 <package>`.

### Exact versions

Unless explicitly defined otherwise, package installations should install the expact version instead of a semver range.

In `.npmrc`, this can be set as `save-exact=true`, or through install command `npm install --save-exact <package>`

> Persist these defaults in the project `.npmrc` (or the package manager’s equivalent), merging only keys that are unset; never overwrite existing values unless the user asks.

## Planning stage / package scorer

When planning third-party dependencies, we should score package candidates first. This reduces risk of using greyware (dependencies are not exactly malware, but can be trollware, abandonware, low quality, etc).

A free scorer solution is the Socket MCP server. Can use other package scorers if user configured explicitly.

An example Socket MCP server can be figured as:

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

If any dependencies metrics (quality, supply chain, maintenance, etc) are low (for example <=60), consider other alternatives or let the user know.

## Install stage / package scanner

When time to install third-party dependencies, we should validate them against a package scanner first. This reduces risk of compromises as the scanner will check against a real-time intelligence database.

A free scanner solution is the Socket Firewall Free cli `sfw`. Can use other package scanners if user configured explicitly.

The `sfw` cli can be downloaded first through `npm i -g sfw` or through `npx`: `npx sfw npm install <package>`

If any package got compromised, as soon as the Socket security updated their database, the `sfw` cli can reject the package installations in real-time even before the malicious tarball reaches the user.

## References

Package managers:

- npm: https://docs.npmjs.com/cli/
- pnpm: https://pnpm.io/
- yarn: https://yarnpkg.com/
- bun: https://bun.sh/llms.txt/
- deno: https://docs.deno.com/runtime/

Socket products:

- https://docs.socket.dev/docs/guide-to-socket-mcp
- https://github.com/SocketDev/socket-mcp
- https://docs.socket.dev/docs/socket-firewall-free
