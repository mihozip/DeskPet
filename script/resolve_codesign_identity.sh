#!/usr/bin/env bash

# Resolve a stable signing identity for local builds and in-app source updates.
# Explicit CODESIGN_IDENTITY always wins. Otherwise prefer Developer ID, then
# Apple Development. Fall back to ad-hoc only when the Mac has no usable identity.
deskpet_resolve_codesign_identity() {
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    printf '%s\n' "$CODESIGN_IDENTITY"
    return 0
  fi

  if [[ -x /usr/bin/security ]]; then
    local identities
    identities="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null || true)"

    local match
    match="$(printf '%s\n' "$identities" | grep -m1 '"Developer ID Application:' || true)"
    if [[ -z "$match" ]]; then
      match="$(printf '%s\n' "$identities" | grep -m1 '"Apple Development:' || true)"
    fi

    if [[ -n "$match" ]]; then
      printf '%s\n' "$match" | sed -E 's/^[^"]*"([^"]+)".*$/\1/'
      return 0
    fi
  fi

  printf '%s\n' '-'
}
