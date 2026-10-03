# Enkind shared workflows

The release pipeline every Enkind plugin repository uses. A plugin repository calls one reusable workflow and describes itself in `plugin-release.json`; the pipeline, the tooling, and their dependencies live here.

## What a plugin repository gets

| Event | Result |
| --- | --- |
| Pull request | Conventional Commits check, version alignment check, the repository's `check` commands |
| Push to `main` | The checks; a `vX.Y.Z-dev.N` GitHub prerelease when the commits contain a `fix:` or `feat:`; a deploy of the `development` environment and a live probe |
| Manual run on `main` | The checks; the stable version deployed to `production` and probed, then the `vX.Y.Z` GitHub release and the `production` branch published |

Versions come from [Conventional Commits](https://www.conventionalcommits.org) through [semantic-release](https://semantic-release.gitbook.io): `fix:` is a patch, `feat:` a minor, and `feat!:` or a `BREAKING CHANGE:` footer a major. CI writes the version into every file listed in `versionFiles` and commits it back as `chore(release)`. Nobody edits versions by hand.

`main` carries the development plugin. A stable release applies `production.patch` (a JSON merge per file) and `production.remove` to produce the `production` branch, so installing from `production` gives the released plugin. Every release attaches `<archive.name>-<version>.zip`: one top-level plugin folder without `archive.exclude`, the archive to upload when a plugin's metadata, skills, or assets changed.

## Adding a plugin repository

1. `.github/workflows/ci.yml`:

   ```yaml
   name: CI/CD

   on:
     pull_request:
     push:
       branches: [main]
     workflow_dispatch:

   permissions:
     contents: write

   concurrency:
     group: ${{ github.workflow }}-${{ github.event_name == 'pull_request' && github.ref || 'release' }}
     cancel-in-progress: ${{ github.event_name == 'pull_request' }}

   jobs:
     plugin:
       uses: enkind/.github/.github/workflows/plugin.yml@v1
       with:
         check: pnpm typecheck && pnpm build
         probe: node scripts/probe.mjs "$MCP_URL"
       secrets: inherit
   ```

   `deploy` defaults to a remote Vercel build of the repository root; override it when the project builds differently.

2. `plugin-release.json`:

   ```json
   {
     "plugin": "plugins/example",
     "versionFiles": ["package.json", "plugins/example/.codex-plugin/plugin.json"],
     "archive": { "name": "example", "exclude": [".cursor-plugin"] },
     "production": {
       "patch": {
         "plugins/example/.mcp.json": { "mcpServers": { "example": { "url": "https://example.vercel.app/mcp" } } }
       },
       "remove": []
     }
   }
   ```

3. `.nvmrc` with `24`, and `packageManager` in `package.json`.
4. Two Vercel projects, one per environment, and GitHub environments `development` (deployment branch `main`) and `production` (deployment branch `main`). Each holds the `VERCEL_TOKEN` secret and the `VERCEL_PROJECT_ID` and `MCP_URL` variables; `VERCEL_ORG_ID` is a repository variable.
5. A `production` branch and a `v<version>` tag on the commit production serves, so semantic-release counts from it.
6. Branch rules: `main` blocks deletion and force-pushes; `production` blocks deletion. CI force-pushes `production`, so never commit to it.

To release, run `gh workflow run ci.yml --ref main` in the plugin repository.

## Changing this repository

Commits follow Conventional Commits, and every push to `main` releases this repository and moves its major tag. Plugin repositories pin `@v1`, so a `fix:` or `feat:` reaches all of them on their next run. A change that requires plugin repositories to change is a `feat!:`: it releases `v2`, and the same commit must update the `@v1` references inside `.github/workflows/plugin.yml` to `@v2`. Each repository then moves to `@v2` when it is ready.
