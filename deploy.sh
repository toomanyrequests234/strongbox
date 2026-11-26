#!/usr/bin/env bash
# Deploys Strongbox to the Onyx testnet.
# Usage: ./deploy.sh <gnokey key name>     (default: mykey)
#
# Only the Gno code and gnomod.toml are uploaded. Everything put on chain is
# permanent, so other files in the folder (notes, editor files) stay local.
set -euo pipefail

KEY="${1:-mykey}"
SRC="$(cd "$(dirname "$0")/strongbox" && pwd)"
PKGPATH="$(sed -nE 's/^module = "(.*)"/\1/p' "$SRC/gnomod.toml")"
export PATH="$PATH:$HOME/go/bin"

echo "Testing before deploy..."
(cd "$SRC" && gno test . && gno lint .)

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp "$SRC"/*.gno "$SRC/gnomod.toml" "$STAGE/"
echo
echo "Uploading to $PKGPATH:"
ls "$STAGE"
echo

gnokey maketx addpkg \
  -pkgdir "$STAGE" \
  -pkgpath "$PKGPATH" \
  -gas-fee 20000000ugnot \
  -gas-wanted 200000000 \
  -max-deposit 20000000ugnot \
  -chainid onyx-1 \
  -remote https://rpc.onyx.testnets.gno.land:443 \
  -broadcast \
  "$KEY"

echo
echo "Submitted. Approval status:"
echo "  https://gpas.onyx.testnets.gno.land/?path=$PKGPATH"
echo "Live page once approved:"
echo "  https://onyx.testnets.gno.land/${PKGPATH#gno.land/}"
