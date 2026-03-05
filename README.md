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
# Challenge 4: Social Recovery Vault – "The Watch Party Protocol"

## 1. Project Overview
This project adapts the concept of a **Social Recovery Vault** to a synchronized social experience. Instead of recovering a lost wallet, a group of 6 friends must "recover" a secret decryption key to watch a TV episode together. The key is mathematically hidden across the group and can only be revealed if all participants submit their specific cryptographic shares to the blockchain.

## 2. The Protocol
### Step 1: Setup (Off-chain)
The **Dealer** prepares the "lock" for the upcoming episode:

1.  **Security Parameter**: Choose a 256-bit prime $q$.
2.  **Generate Coefficients**: 
    * The Dealer chooses $a_1, \dots, a_{n-1}$ randomly from the field $\mathbb{Z}_q$.
    * The Dealer computes $a_n$ based on the Secret (Episode Key) and the sum of the other coefficients to satisfy the required variant:
        $$a_n = (\text{Secret} - \sum_{i=1}^{n-1} a_i) \pmod q$$
3.  **Construct Polynomial**: A polynomial $f(x)$ is defined where the $y$-intercept ($x=0$) is the secret:
    $$f(x) = a_n x^n + a_{n-1} x^{n-1} + \dots + a_1 x + \text{Secret}$$
4.  **Distribute Shares**: Friend $i$ receives their private share: $(i, f(i))$.
5.  **Commitment**: The Host uploads `keccak256(Secret)` to the smart contract. This "locks" the episode requirements without revealing the actual key to the public.



### Step 2: Happy Path (Normal Operation)
1.  **Gathering**: All 6 friends assemble online to watch the show.
2.  **Submission**: Each friend interacts with the smart contract via the `unlockEpisode` function, providing their $(x, y)$ values.
3.  **On-chain Reconstruction**: The contract executes **Lagrange Interpolation** to solve for $f(0)$.
4.  **Verification**: The contract hashes the result. If `keccak256(Result) == StoredHash`, the secret is emitted via a `SecretRevealed` event.
5.  **Access**: The group uses the revealed secret to decrypt the video stream. The contract automatically increments the `currentEpisode` counter.

## 3. Threat Model (Failure Cases)

| Attack Scenario | Design Mitigation |
| :--- | :--- |
| **The "Traitor" Friend** (Submits a wrong share) | The contract performs a `keccak256` check. If even one bit of one share is incorrect, the result won't match the hash and the transaction reverts. |
| **The "Early Bird"** (Fewer than 6 people try to unlock) | Mathematically, $n$ points are required to solve a degree $n$ polynomial. With only $n-1$ points, the secret remains perfectly hidden (Information-Theoretic Security). |
| **Replay Attack** (Using Episode 1 shares for Episode 2) | The contract tracks the `currentEpisode` state. Each episode requires a new commitment hash and a new set of shares from the Host. |
| **Public Eavesdropping** (Hacker reading the contract) | Since only the **hash** is stored on-chain, the secret is never visible on the blockchain until the friends intentionally reconstruct it. |

## 4. Cryptographic Primitives

* **Shamir’s Secret Sharing (SSS)**: Used to distribute the secret key. It ensures that no single person knows the key.
* **Lagrange Interpolation**: The algebraic method used on-chain to reconstruct the polynomial and find the value at $x=0$.
* **Keccak-256 Hashing**: Acts as a **Commitment Scheme**. It allows the contract to verify the reconstruction result without having the secret pre-stored in plain text.

* **Modular Inverse (Fermat's Little Theorem)**: Used to perform division within the finite field $\mathbb{Z}_q$ in Solidity, which is essential for the Lagrange formula.

## 5. Implementation Details (Solidity)
The contract is deployed on the **Sepolia Testnet**. Key features include:
* `setEpisodeHash()`: Restricted to the Host to define the next goal.
* `reconstructSecret()`: An optimized function implementing the summation of Lagrange basis polynomials.
* **Modular Arithmetic**: Custom internal functions for `addMod`, `subMod`, and `mulMod` to handle 256-bit numbers within the prime field $Q$.

---

### **Demo Instructions**
1.  **Deployment**: Show the contract on Remix and confirm it is connected to Sepolia.
2.  **Locking**: Call `setEpisodeHash` with the hash of a secret (e.g., `777`).
3.  **Unlocking (Happy Path)**: Input the 6 correct shares and show the event logs revealing the secret.
4.  **Attack Scenario**: Attempt to unlock with one incorrect share to demonstrate the contract's revert mechanism.

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
