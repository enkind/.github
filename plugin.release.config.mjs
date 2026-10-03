// semantic-release configuration for Enkind plugin repositories. It runs from
// the plugin repository's root and reads that repository's plugin-release.json.
// Plugins resolve from this checkout, so plugin repositories install nothing.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

const local = (name) => fileURLToPath(import.meta.resolve(name));
const script = fileURLToPath(new URL("./scripts/plugin-release.sh", import.meta.url));
const { versionFiles } = JSON.parse(readFileSync("plugin-release.json", "utf8"));

// A push to main publishes a dev prerelease. The Release run promotes main to a
// stable version; semantic-release needs a release branch either way, and
// production is the one the dev channel counts from.
export default {
  branches:
    process.env.RELEASE_CHANNEL === "stable"
      ? ["main"]
      : ["production", { name: "main", prerelease: "dev" }],
  plugins: [
    [local("@semantic-release/commit-analyzer"), { preset: "conventionalcommits" }],
    [local("@semantic-release/release-notes-generator"), { preset: "conventionalcommits" }],
    [
      local("@semantic-release/exec"),
      {
        prepareCmd: `${script} prepare \${nextRelease.version}`,
        successCmd: `${script} publish \${nextRelease.version}`,
      },
    ],
    [local("@semantic-release/git"), { assets: versionFiles }],
    [
      local("@semantic-release/github"),
      {
        assets: [{ path: ".release/*.zip" }],
        successComment: false,
        failComment: false,
        releasedLabels: false,
      },
    ],
  ],
};
