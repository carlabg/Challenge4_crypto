# Challenge4_crypto — Movie Night Secret Sharing

## Scenario
Our system solves a simple coordination/trust problem: **n friends can only watch content if all n friends are present and participate**.

Instead of trusting one person to hold the full access code, the code is split into secret shares. Each friend receives one share and must reveal it on-chain. An episode is unlocked only when all valid shares are revealed.

The contract is reusable for a full platform flow (e.g., TV series): it uses an **episode counter** so the same friend group can run many rounds (episode 1, episode 2, etc.) without redeploying.

Why blockchain here:
- **Public verifiability**: everyone can verify who revealed and when.
- **No central trusted organizer**: the smart contract enforces the “all friends required” rule.
- **Tamper-resistant logs**: events and state transitions are immutable once mined.

---

## Actors and assumptions
- **Organizer (deployer)**: deploys once with friend addresses, then starts each episode with new commitments/deadline/hash.
- **Friends (participants)**: each one has exactly one secret share and one salt.
- **Adversary**: can read all on-chain data, front-run transactions, or refuse to reveal (griefing/DoS).

Assumptions:
- At setup time, each friend receives the correct `(share, salt)` off-chain via a secure channel.
- Keccak-256 remains collision/preimage resistant in practice.
- Ethereum/Sepolia consensus is honest-majority (standard blockchain assumption).

Public on-chain visibility:
- Friend addresses, episode commitments, reveal transactions, timestamps, and final results are public.
- Revealed shares become public after reveal.

---

## Protocol
Contract file: `MovieNightAllFriends.sol`

### Setup phase (one-time deployment)
1. Organizer deploys contract once with fixed `friends[]`.

### Per-episode setup (repeated for each new round)
1. Organizer chooses episode secret `S_e` (bytes32).
2. Organizer creates `n` shares (`s1...sn`) such that `s1 XOR s2 XOR ... XOR sn = S_e`.
3. For each friend `i`, organizer generates random `salt_i` and computes commitment bound to episode id:
	 `c_i = keccak256(friend_i, episodeId, s_i, salt_i)`.
4. Organizer calls `startEpisode(commitments[], movieCodeHash, revealWindowSeconds)`.

### Happy path (normal operation)
1. Each friend calls `revealShare(share, salt)` for the **current episode** before deadline.
2. Contract verifies commitment match and one-time reveal.
3. Contract updates XOR accumulator and reveal count.
4. When `revealCount == totalFriends`, contract reconstructs `S` and checks `keccak256(S) == movieCodeHash`.
5. If valid, current episode is unlocked and `MovieUnlocked(episodeId, ...)` is emitted.
6. Organizer can then start the next episode (`episodeId + 1`) with fresh commitments.

### Failure cases
- **Late reveal**: rejected (`DeadlinePassed`).
- **Wrong share or wrong salt**: rejected (`InvalidShare`).
- **Double reveal**: rejected (`AlreadyRevealed`).
- **Not a registered friend**: rejected (`NotFriend`).
- **Not everyone reveals before deadline**: current episode can be marked expired via `markExpired()`.
- **All reveal but reconstruction mismatch**: emits `UnlockFailed`, and protocol expires.
- **Organizer starts new episode too early**: rejected while previous episode is still active.

---

## Threats and attacks
### Attack: Front-running share reveal
An attacker observes a friend’s pending reveal transaction in the mempool and tries to copy it first.

Impact if unmitigated:
- Attacker could claim another friend’s share or alter reveal order.

Mitigation in design:
- Commitment binds to **sender address + episode id**: `keccak256(msg.sender, episodeId, share, salt)`.
- A copied transaction from another address fails commitment verification.
- Old reveals also cannot be replayed in later episodes due to the episode id binding.

### Additional realistic threat: Withholding reveal (griefing)
A malicious friend can refuse to reveal and block unlock.

Current mitigation:
- Deadline + explicit expiration (`markExpired`) prevents indefinite waiting.

Future improvement:
- Add collateral/slashing deposits to economically discourage non-reveal behavior.

---

## Cryptographic primitives and security properties
- **Keccak-256 hash (`keccak256`)**
	- Used for commitments and final code verification.
	- Provides integrity and commitment binding (with address + salt).
- **Salted commitment scheme**
	- Hides share value until reveal.
	- Prevents trivial guessing and ties reveal to pre-committed value.
- **Counter / round binding**
	- Binds commitments to a specific `episodeId`.
	- Prevents cross-episode replay of old shares.
- **XOR-based secret reconstruction**
	- Combines all shares into final secret.
	- Enforces n-of-n participation in this design.

---

## How to reproduce the demo (Remix + Sepolia)
1. Open Remix, compile `MovieNightAllFriends.sol` with Solidity `^0.8.24`, and connect MetaMask on Sepolia.
2. Prepare test inputs off-chain:
	 - choose episode secret `S_e` (bytes32),
	 - create shares whose XOR is `S_e`,
	 - read current episode and compute next `episodeId`,
	 - compute commitments `keccak256(friend, episodeId, share, salt)`,
	 - compute `movieCodeHash = keccak256(S_e)`.
3. Deploy contract once with `friends[]`.
4. Call `startEpisode(commitments, movieCodeHash, revealWindowSeconds)` from organizer.
5. From each friend account, call `revealShare(share, salt)` and verify unlock via `canWatchEpisode(episodeId)` and events (`EpisodeStarted`, `ShareRevealed`, `MovieUnlocked`).

---

## AI usage disclosure
AI (GitHub Copilot) was used to:
- draft Solidity scaffolding,
- refine protocol documentation,
- structure threat model and reproducibility steps.

Final verification, scenario design choices, and test/demo execution were performed by the team.

---

## Blockchain technology (brief)
Blockchain is a distributed append-only ledger maintained by many nodes without a central authority. Smart contracts are programs executed deterministically by all nodes, allowing transparent and auditable rule enforcement between parties that do not fully trust each other.
=======
What problem the system solves, who it is designed for, and why using a blockchainbased solution makes sense.

## Actors and assumptions. 
Who the participants are, which actors are assumed to be honest or
potentially malicious, and what information is publicly visible on the blockchain.
## Protocol
A step-by-step explanation of how the system works, including the happy path (normal
operation) and possible failure cases.

## Threats and attacks. 
Describe at least one concrete attack, including its potential impact and how
the system mitigates or prevents it.

## Primitives
List the cryptographic primitives used and their security properties.
How to reproduce the demo. Provide 2–5 steps explaining how to reproduce the demo.

## Scenario
Six friends are tired of deciding that they are going to wait for each other to watch the new episodes of Game Of Thrones, and then, for one person to watch it before the others. They meet one day and decide to download a special App that locks each episode and requires a password to play. The unique feature of the App is that it sends a different code to each friend, and only when all codes are entered together can the password be retrieved. This way, the friends make sure that they can only watch the episodes when they are all together at the same time.
>>>>>>> 53d37e441a40d19fdd693db2d9e4591e65b40de3
