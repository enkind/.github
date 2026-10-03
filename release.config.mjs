// Releases this repository itself. Every release also moves its major tag
// (v1, v2, ...), which is the ref plugin repositories pin.
export default {
  branches: ["main"],
  plugins: [
    ["@semantic-release/commit-analyzer", { preset: "conventionalcommits" }],
    ["@semantic-release/release-notes-generator", { preset: "conventionalcommits" }],
    [
      "@semantic-release/github",
      { successComment: false, failComment: false, releasedLabels: false },
    ],
    [
      "@semantic-release/exec",
      {
        successCmd:
          "git tag -f v${nextRelease.version.split('.')[0]} && git push -f origin v${nextRelease.version.split('.')[0]}",
      },
    ],
  ],
};
