# Challenge 4_crypto — Movie Night Secret Sharing

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
### Step 1: Setup (Off-chain)
The **Dealer** prepares the "lock" for the upcoming episode:

1.  **Security Parameter**: Choose a 256-bit prime $q$.
2.  **Generate Coefficients**: 
    * The Dealer chooses $a_1, \dots, a_{n-1}$ randomly from the field $\mathbb{Z}_q$.
    * The Dealer computes $a_n$ based on the Secret (Episode Key) and the sum of the other coefficients to satisfy the required variant:
        $$a_n = (\text{Secret} - \sum_{i=1}^{n-1} a_i) \pmod q$$
3.  **Construct Polynomial**: A polynomial $f(x)$ is defined where the $f(0)$ ($i=0$) is the secret:
    $$f(x) = a_n x^n + a_{n-1} x^{n-1} + \dots + a_1 x + \text{Secret}$$
4.  **Distribute Shares**: Friend $i$ receives their private share: $(i, f(i))$.
5.  **Commitment**: The Dealer uploads `keccak256(Secret)` to the smart contract. This "locks" the episode requirements without revealing the actual key to the public.


### Step 2: Happy Path (Normal Operation)
1.  **Gathering**: All 6 friends assemble online to watch the show.
2.  **Submission**: Each friend interacts with the smart contract via the `unlockEpisode` function, providing their $(i, f(i))$ values.
3.  **On-chain Reconstruction**: The contract executes **Lagrange Interpolation** to solve for $f(0)$.
4.  **Verification**: The contract hashes the result. If `keccak256(Result) == StoredHash`, the secret is emitted via a `SecretRevealed` event.
5.  **Access**: The group uses the revealed secret to decrypt the video stream. The contract automatically increments the `currentEpisode` counter.

### Threat Model (Intentional Attacks)
| Attack Scenario | Design Mitigation |
| :--- | :--- |
| **The friend that doesn't want to watch the show** | A malicious friend submits a wrong share. The `keccak256` check fails because the math won't match the Dealer's commitment, causing the transaction to **fail**. |
| **Excluding a friend** | A subset of friends tries to unlock the show early. Mathematically, $n$ points are required for a degree $n$ polynomial. $n-1$ points provide **zero information**. |


### System Failures (Unintentional Issues)
| Failure Scenario | Impact | Mitigation |
| :--- | :--- | :--- |
| **Availability Loss** | A friend loses their phone/key. | Current design requires $n/n$. Future work: implement a $t$-out-of-$n$ threshold. |
| **Initialization Error** | Dealer forgets to set the hash. | The `unlock` function requires a non-zero hash to be set before execution. |

## Primitives

* **Shamir’s Secret Sharing (SSS)**: Used to distribute the secret key. It ensures that no single person knows the key.
* **Lagrange Interpolation**: The algebraic method used on-chain to reconstruct the polynomial and find the value at $x=0$.
* **Keccak-256 Hashing**: Is a cryptographic hash function. In this protocol, it serves as a Commitment Scheme. It takes the secret episode key and produces a unique 32-byte "fingerprint.".
* **Modular Inverse (Fermat's Little Theorem)**: Used to perform division within the finite field $\mathbb{Z}_q$ in Solidity, which is essential for the Lagrange formula.



>>>>>>> 53d37e441a40d19fdd693db2d9e4591e65b40de3
