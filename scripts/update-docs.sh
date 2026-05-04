#!/usr/bin/env bash
# Manually regenerate everything the `update-docs` pre-commit hook produces.
# Invocations mirror parts/_build/git-hooks.nix exactly — pure `nix eval`,
# no `nix-build` (the .nix files return strings, not derivations).
set -euo pipefail
cd "$(dirname "$0")/.."

emit() {
  local target="$1"
  shift 1
  local tmp
  tmp=$(mktemp)
  if printf '%s' "$(nix eval "$@")" >"$tmp"; then
    chmod +w "$target" 2>/dev/null || true
    mv "$tmp" "$target"
    echo "  $target updated ($(wc -l <"$target") lines)"
  else
    rm -f "$tmp"
    echo "ERROR: $target generation failed." >&2
    exit 1
  fi
}

splice_section() {
  local marker="$1"
  local tmp content_tmp
  tmp=$(mktemp)
  content_tmp=$(mktemp)
  if ! nix eval --raw --impure --file scripts/generate-readme-sections.nix "$marker" >"$content_tmp"; then
    echo "ERROR: README section '$marker' generation failed." >&2
    rm -f "$tmp" "$content_tmp"
    exit 1
  fi
  awk -v marker="$marker" -v content_file="$content_tmp" '
    $0 ~ ("<!-- BEGIN generated:" marker " -->") {
      print; print ""
      while ((getline line < content_file) > 0) print line
      close(content_file)
      print ""
      skip = 1
      next
    }
    $0 ~ ("<!-- END generated:" marker " -->") {
      print; skip = 0; next
    }
    !skip { print }
  ' README.md >"$tmp" && mv "$tmp" README.md
  rm -f "$content_tmp"
  echo "  README.md section '$marker' regenerated."
}

echo "Generating module documentation..."

# OPTIONS.md — pure eval
emit docs/OPTIONS.md \
  --raw --impure --file scripts/generate-docs.nix markdown

# options.json — pure eval
emit docs/options.json \
  --json --impure --file scripts/generate-docs.nix json

# Host templates — pure eval
emit docs/host-template.nix.example \
  --raw --impure --file scripts/generate-host-template.nix text

emit docs/hm-host-template.nix.example \
  --raw --impure --file scripts/generate-hm-template.nix text

# README sections — splice between BEGIN/END markers.
splice_section moduleReference
splice_section directoryLayout
splice_section flakeInputs

# Reformat README so its post-splice form matches prettier's canonical
# output. Otherwise standalone `nix fmt` would re-flow the spliced
# sections and produce a different size, causing
# `nix fmt --fail-on-change` to oscillate against the manual regen.
nix fmt -- README.md >/dev/null 2>&1 || true

echo "All documentation updated."
