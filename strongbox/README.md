# Strongbox

Multisig team treasuries on gno.land.

A team creates a vault with its signers and a threshold, for example 2-of-3. Anyone can fund the vault with GNOT. Any signer can propose a payout, and the realm sends it as soon as enough signers approve. No single person can move the money, and every deposit, approval and payout is public on the realm's page.

Who it's for: hackathon teams splitting a prize, DAOs and guilds holding a shared budget, grant recipients paying contributors.

- Realm path: `gno.land/r/g1sjzvhjx4u4cnd92yk5g0jv68j3j302f4fwzd0z/strongbox/v1`
- Live realm (Onyx testnet): https://onyx.testnets.gno.land/r/g1sjzvhjx4u4cnd92yk5g0jv68j3j302f4fwzd0z/strongbox/v1
- Demo video: _link after recording_

## How it differs from other multisig options on gno.land

- **Native multisig accounts** (`gnokey` multisig keys, and apps built on them such as Memba) collect signatures off-chain and need every signer to coordinate around one transaction. Strongbox keeps proposals and approvals on chain: each signer approves on their own time, from gnokey or the gnoweb page, and anyone can audit who approved what.
- **No backend or frontend to run.** The realm is the whole app; its pages render in gnoweb.
- **Composable.** Any address can be a signer, including another realm, so a DAO can co-sign a team's vault. Other realms can read `VaultBalance`, `IsSigner` and `VaultThreshold`.
- **Many vaults, one realm.** Creating a vault is one transaction; nobody has to deploy code.

## How it works

| Function | Who can call it | What it does |
| --- | --- | --- |
| `CreateVault(name, signers, threshold)` | anyone | Creates a vault. `signers` is a comma-separated list of addresses; the caller is always added. Returns the vault id. |
| `Deposit(vaultID)` | anyone, with `-send` | Adds the attached ugnot to the vault. Must be a direct `gnokey maketx call`. |
| `Propose(vaultID, to, amount, memo)` | signers | Proposes a payout in ugnot. The proposer's approval counts. |
| `Approve(vaultID, proposalID)` | signers | Adds an approval. When the threshold is reached and the vault has the funds, the payout is sent in the same transaction. |
| `Revoke(vaultID, proposalID)` | signers | Withdraws your approval while the proposal is pending. |
| `Execute(vaultID, proposalID)` | signers | Sends an approved payout that was waiting for funds. |
| `Cancel(vaultID, proposalID)` | the proposer | Closes a pending proposal. |
| `VaultBalance`, `VaultThreshold`, `IsSigner`, `VaultCount` | anyone (read-only) | For other realms and scripts. |

### Pages

- `/r/<path>`: all vaults, with balance, rule and open proposals
- `/r/<path>:vault/1`: one vault: signers, pending proposals with who has approved, payout history, deposits
- `/r/<path>:signer/g1...`: the vaults an address signs for, and how many are waiting for its approval

The pages link to gnoweb's transaction forms (`$help`), so you can approve from the browser with a wallet such as Adena.

## Try it with gnokey

Replace `REALM` with the deployed path and `mykey` with your key name.

```bash
REALM=gno.land/r/g1sjzvhjx4u4cnd92yk5g0jv68j3j302f4fwzd0z/strongbox/v1
NET="-chainid onyx-1 -remote https://rpc.onyx.testnets.gno.land:443"

# 1. Create a 2-of-3 vault with two teammates
gnokey maketx call -pkgpath $REALM -func CreateVault \
  -args "Team Tavern" -args "g1bob...,g1carol..." -args 2 \
  -gas-fee 1000000ugnot -gas-wanted 20000000 -broadcast $NET mykey

# 2. Fund it with 10 GNOT
gnokey maketx call -pkgpath $REALM -func Deposit -args 1 -send 10000000ugnot \
  -gas-fee 1000000ugnot -gas-wanted 20000000 -broadcast $NET mykey

# 3. Propose paying 4 GNOT to someone
gnokey maketx call -pkgpath $REALM -func Propose \
  -args 1 -args g1payee... -args 4000000 -args "Design work" \
  -gas-fee 1000000ugnot -gas-wanted 20000000 -broadcast $NET mykey

# 4. A second signer approves, and the 4 GNOT is sent
gnokey maketx call -pkgpath $REALM -func Approve -args 1 -args 1 \
  -gas-fee 1000000ugnot -gas-wanted 20000000 -broadcast $NET bobkey
```

## Run the tests

Needs the gno toolchain at v1.8.0 (the version Onyx runs). 27 tests cover the full payout flow and the attack cases listed under Security.

```bash
gno test -v .
gno lint .
gnodev .   # local chain + gnoweb at http://localhost:8888
```

## Security

Audited by hand in several passes before deployment. Each protection below has a unit test, except the gas figures, which come from a benchmark on a local chain.

- **Vault isolation:** a payout can only spend its own vault's balance, even though all vaults share one bank account.
- **No double payouts:** a proposal is marked paid before coins move, and closed proposals cannot be approved, executed or cancelled.
- **No impersonated approvals:** the approver is always the direct caller. A realm you call cannot approve on your behalf.
- **No double-counted deposits:** `Deposit` accepts only a direct user call, so an intermediary realm cannot replay the same attached coins.
- **No lost coins:** every call except `Deposit` refuses attached coins, so the transaction reverts and the sender keeps them.
- **No payout to the realm itself**, which would strand coins outside every vault, and the realm cannot be a signer, since it could never approve.
- **One address, one signer:** addresses are lowercased, so the uppercase form bech32 also accepts cannot become a second, unreachable signer.
- **No locked funds from a growing history:** proposals, deposits and the signer index are stored in AVL trees, so each call touches a few tree nodes, not the whole history. Measured on a local chain: a proposal costs 7.7M gas on a fresh vault and 15.3M on one with 3,000 past proposals. With plain slices it had cost 258M at 1,500 and kept growing, which would have let a hostile signer make the vault too expensive to use.
- **Flood limits:** at most 20 signers per vault and 20 open proposals per signer per vault. Pages read only the newest items, so their cost stays flat.
- **Safe pages:** names, memos and URL input are escaped or validated, and gnoweb renders them as plain text. Control, invisible and direction-changing characters are refused, so a name or memo cannot display as something it is not.

Known risks, by design:

- **Lost keys can lock funds.** Signers and the threshold cannot change. If more than (signers − threshold) keys are lost, the vault's coins stay stuck. Choose a threshold that leaves room for a lost key, for example 2-of-3.
- **An approved payout waits for funds.** If a payout reaches its threshold while the vault is short, any signer can execute it later, once the vault holds enough, even from deposits meant for something else. The page flags such payouts; revoke your approval or cancel the proposal if it should not be paid any more.
- **1-of-N means any signer can pay out alone.** The page shows the rule as "1-of-N".
- **Anyone can name you as a signer.** The vault then shows up on your signer page. It cannot move your money or act for you; check the vault's name and id before approving anything.
- **Coins sent straight to the realm address**, not through `Deposit`, belong to no vault and cannot be recovered.

## Design notes and limits

- All vaults share the realm's bank account. Each vault's share is tracked in its balance, and a payout can only spend its own vault's balance.
- `Deposit` only accepts a direct user call. That stops another realm from calling it several times in one transaction and counting the same coins twice.
- State changes before coins move.
- Only ugnot is supported for now. Coins sent straight to the realm address without `Deposit` belong to no vault and cannot be paid out.
- Signers and the threshold are fixed when the vault is created. To change them, create a new vault and move the funds with a payout.
- User text (vault names, memos) is escaped before it is rendered.
- Pages list the newest 25 items per section and the newest 50 vaults, so rendering stays far below the 3B query gas limit.

## License

MIT
