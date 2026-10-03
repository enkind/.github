#!/usr/bin/env bash
# Called by semantic-release from a plugin repository's root, driven by its
# plugin-release.json. RELEASE_CHANNEL is "dev" or "stable"; the stable channel
# also runs DEPLOY_COMMAND and PROBE_COMMAND before anything is published.
set -euo pipefail

step=$1
version=$2
config=plugin-release.json

# Applies the production patches and removals under a directory that mirrors
# the repository layout. Main carries the dev values; releases rewrite them.
use_production() {
  jq -r '.production.patch // {} | keys[]' $config | while read -r file; do
    [ -f "$1/$file" ] || continue
    jq --argjson patch "$(jq --arg file "$file" '.production.patch[$file]' $config)" '. * $patch' "$1/$file" > "$1/$file.tmp"
    mv "$1/$file.tmp" "$1/$file"
  done
  jq -r '.production.remove // [] | .[]' $config | while read -r file; do
    rm -f "$1/$file"
  done
}

case $step in
  versions)
    expected=$(jq -r '.versionFiles[0]' $config | xargs jq -r .version)
    jq -r '.versionFiles[]' $config | while read -r file; do
      [ "$(jq -r .version "$file")" = "$expected" ] || { echo "::error file=$file::Expected version $expected"; exit 1; }
    done
    ;;
  prepare)
    jq -r '.versionFiles[]' $config | while read -r file; do
      jq --arg version "$version" '.version = $version' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    done

    if [ "$RELEASE_CHANNEL" = stable ]; then
      bash -c "$DEPLOY_COMMAND"
      bash -c "$PROBE_COMMAND"
    fi

    # The ZIP is the archive the ChatGPT plugin upload expects: one top-level
    # plugin folder, built from the tree this release publishes.
    plugin=$(jq -r .plugin $config)
    name=$(jq -r .archive.name $config)
    root=$(mktemp -d)
    mkdir -p "$root/$(dirname "$plugin")"
    cp -R "$plugin" "$root/$plugin"
    if [ "$RELEASE_CHANNEL" = stable ]; then
      use_production "$root"
    fi
    jq -r '.archive.exclude // [] | .[]' $config | while read -r path; do
      rm -rf "${root:?}/$plugin/$path"
    done
    mkdir -p "$root/archive" .release
    mv "$root/$plugin" "$root/archive/$name"
    (cd "$root/archive" && zip -qr - "$name") > ".release/$name-$version.zip"
    ;;
  publish)
    [ "$RELEASE_CHANNEL" = stable ] || exit 0
    use_production .
    git add -A -- "$(jq -r .plugin $config)" $(jq -r '.production.patch // {} | keys[]' $config)
    git commit -qm "chore(release): publish v$version to production"
    git push --force origin HEAD:refs/heads/production
    ;;
esac
