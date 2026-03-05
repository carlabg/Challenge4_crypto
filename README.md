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

## Threats and attacks

| Attack Scenario | Design Mitigation |
| :--- | :--- |
| **The "Traitor" Friend** (Submits a wrong share) | The contract performs a `keccak256` check. If even one bit of one share is incorrect, the result won't match the hash and the transaction reverts. |
| **The "Early Bird"** (Fewer than 6 people try to unlock) | Mathematically, $n$ points are required to solve a degree $n$ polynomial. With only $n-1$ points, the secret remains perfectly hidden (Information-Theoretic Security). |
| **Replay Attack** (Using Episode 1 shares for Episode 2) | The contract tracks the `currentEpisode` state. Each episode requires a new commitment hash and a new set of shares from the Dealer. |
| **Public Eavesdropping** (Hacker reading the contract) | Since only the **hash** is stored on-chain, the secret is never visible on the blockchain until the friends intentionally reconstruct it. |

## Primitives

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


>>>>>>> 53d37e441a40d19fdd693db2d9e4591e65b40de3
