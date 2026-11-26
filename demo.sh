#!/usr/bin/env bash
# Demo for the video: a 2-of-2 vault on Onyx, funded, a payout proposed by
# one signer and paid out when the second signer approves.
# Usage: ./demo.sh            (keys: mykey and mykey2)
# Press Enter between steps; keep the vault page open in the browser and
# refresh it after each step.
set -euo pipefail
export PATH="$PATH:$HOME/go/bin"

REALM=gno.land/r/g1sjzvhjx4u4cnd92yk5g0jv68j3j302f4fwzd0z/strongbox/v1
WEB=https://onyx.testnets.gno.land/r/g1sjzvhjx4u4cnd92yk5g0jv68j3j302f4fwzd0z/strongbox/v1
RPC=${RPC:-https://rpc.onyx.testnets.gno.land:443}
CHAIN=${CHAIN:-onyx-1}
KEY1=${KEY1:-mykey}
KEY2=${KEY2:-mykey2}
ADDR2=${ADDR2:-g1ska8n87x9h4ctkvx8gkgh6vhd7p3jk02g0p427}
EXTRA=${EXTRA:-}   # only for local testing
# The payee: a "designer" address that is not a signer.
PAYEE=g1w3jhxap3ta047h6lta047h6lta047h6l4mfnm7

call() { # call <key> <func> [args...]
  local key=$1 fn=$2; shift 2
  local args=()
  for a in "$@"; do args+=(-args "$a"); done
  local cmd=(gnokey maketx call -pkgpath "$REALM" -func "$fn" "${args[@]}" ${SEND:+-send "$SEND"}
    -gas-fee 1000000ugnot -gas-wanted 50000000
    -chainid "$CHAIN" -remote "$RPC" -broadcast $EXTRA "$key")
  if [[ -n $EXTRA ]]; then printf '\n' | "${cmd[@]}"; else "${cmd[@]}"; fi
}
balance() { # prints e.g. "4 GNOT"
  local u
  u=$(gnokey query bank/balances/"$1" -remote "$RPC" | sed -nE 's/^data: "([0-9]*)ugnot.*/\1/p')
  awk -v u="${u:-0}" 'BEGIN { printf "%g GNOT", u / 1000000 }'
}
step() { echo; echo "=== $1"; read -r -p "    press Enter to run..." _; }
refresh() { echo; echo "    >>> now show the browser: $1"; }

echo "Strongbox demo. Open this page in the browser: $WEB"

step "1. $KEY1 creates a 2-of-2 vault with $KEY2 as the second signer"
OUT=$(call "$KEY1" CreateVault "Gnome Tavern team" "$ADDR2" 2 | tee /dev/stderr)
ID=$(echo "$OUT" | sed -nE 's/^\(([0-9]+) int\)$/\1/p' | head -1)
echo "    vault id: $ID"
refresh "open $WEB:vault/$ID"

step "2. Fund the vault with 10 GNOT"
SEND=10000000ugnot call "$KEY1" Deposit "$ID"
refresh "refresh the page: balance is 10 GNOT"

step "3. $KEY1 proposes paying 4 GNOT to the designer (1 of 2 approvals)"
echo "    designer balance before: $(balance $PAYEE)"
call "$KEY1" Propose "$ID" "$PAYEE" 4000000 "Logo and banner design"
echo "    designer balance now:    $(balance $PAYEE)   (nothing sent yet)"
refresh "refresh the page: Approvals 1/2, one checkmark"

step "4. $KEY2 approves: threshold reached, the 4 GNOT is sent in the same transaction"
call "$KEY2" Approve "$ID" 1
echo "    designer balance after:  $(balance $PAYEE)"
refresh "refresh the page: the payout moved to History as paid, balance 6 GNOT"

echo
echo "Done. Show the vault page: $WEB:vault/$ID"
echo "and the signer page:       $WEB:signer/$ADDR2"
