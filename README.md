# Challenge 4_crypto — Movie Night Secret Sharing

## Scenario: Secure Group Viewing for Game of Thrones

Six friends are tired of agreeing to wait and watch the new episodes of *Game of Thrones* together, only for someone to secretly watch them early. They decide to use a special app that locks each episode and can only unlock it when **everyone is present and agrees at the same time**. Each episode is encrypted, and the decryption key is the secret locked in the contract.

### How It Works

When a new episode is available, the app asks each friend to approve the viewing by submitting a **digital private share** from their own device. Unlike a shared password, no single friend's share reveals anything about the key, only when all six combine them can the episode be unlocked. Key points:

- No one can enter another person’s code.
- Only after the app verifies that **all six people’s private shares** have been submitted for that specific episode, it unlocks the video.
- The episode can then be played.

This solves the problem of early watching in a group where no single friend is fully trusted, and a central platform could be bribed or pressured. The adversary is any one of the six friends who might watch early if given the chance.
This is exactly why a blockchain makes sense here, because the app provides a **shared, tamper-resistant source of truth**. We are protecting the decryption key from being revealed unless everyone agrees, and ensuring that nobody, not even your hacker friend, can change or bypass that rule

## Actors and Assumptions

**Actors:**

1. The six friends
2. One friend acts as the Dealer and is assumed to be honest during setup. We acknowledge this is a trusted role. A malicious Dealer could distribute incorrect shares, preventing the episode from ever being unlocked 

**Assumptions:**

- Any friend could be potentially malicious and try to unlock early or submit shares on behalf of others.  
- No friend can forge another friend’s private share. *Shares are tied to a wallet's private key, and breaking that is computationally infeasible*.
- Each friend controls their device and private key.  
- The blockchain works as intended, any friend can always submit their transaction and it will be recorded.
- The smart contract is a trusted executor: it runs exactly as coded and cannot be bribed or pressured
- All submitted shares and the commitment hash are **publicly visible** on-chain. The secret itself is revealed publicly via an event when unlocked.

## Protocol
### Setup (Off-chain)
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

### Happy Path (Normal Operation)
1.  **Gathering**: All 6 friends assemble online to watch the show.
2.  **Submission**: Each friend interacts with the smart contract via the `unlockEpisode` function, providing their $(i, f(i))$ values.
3.  **On-chain Reconstruction**: The contract executes **Lagrange Interpolation** to solve for $f(0)$.
4.  **Verification**: The contract hashes the result. If `keccak256(Result) == StoredHash`, the secret is emitted via a `SecretRevealed` event.
5.  **Access**: The group uses the revealed secret to decrypt the video stream. The contract automatically increments the `currentEpisode` counter.

### System Failures (Unintentional Issues)
| Failure Scenario | Impact | Mitigation |
| :--- | :--- | :--- |
| **Availability Loss** | A friend loses their phone/key. | Current design requires $n/n$. Future work: implement a $t$-out-of-$n$ threshold. |
| **Initialization Error** | Dealer forgets to set the hash. | The `unlock` function requires a non-zero hash to be set before execution. |

## Threat Model (Intentional Attacks)
**Wrong Share Attack**: A malicious friend submits a deliberately wrong share hoping to either block the group or test if the contract accepts bad input. The impact would be a failed unlock for everyone. The contract mitigates this by hashing the reconstructed secret and comparing it against the stored commitment, a wrong share corrupts the reconstruction, the hash won't match, and the transaction reverts. The episode remains locked for everyone until the malicious friend submits a correct share or is identified.

**Replay Attack**: On a blockchain, all transactions are public. So when friend 1 submits their share, everyone can see the transaction, including the share value inside it. A replay attack means friend 2 takes that exact transaction from friend 1 and resubmits it as if it were their own, trying to count as two friends at once.
The reason this doesn't work is that blockchain transactions are cryptographically signed by the sender's wallet. So even if friend 2 copies the transaction data, the contract knows it was sent by friend 2's address, not friend 1's. You registered friend 1's address for share 1, so the contract rejects it.

**Excluding A Friend**: A subset of friends tries to unlock the show early. Mathematically, $n$ points are required for a degree $n$ polynomial. $n-1$ points provide zero information.

**Known Limitation**: One attack we do not protect against is a malicious Dealer and a friend. If the Dealer teams up with friend 1, together they could create a completely fake set of shares, ones that reconstruct to a different secret than the real episode key. They distribute these fake shares to everyone. Everyone submits honestly, the contract accepts it, but the revealed secret decrypts nothing. Only the Dealer knows whether the commitment (of the hash) is genuine.

## Primitives
* **Shamir’s Secret Sharing (SSS)**: Used to distribute the secret key. It ensures that no single person knows the key. A subset of fewer than n shares reveals zero information about the secret.
* **Keccak-256 Hashing**: Is a cryptographic hash function. In this protocol, it serves as a Commitment Scheme. It takes the secret episode key and produces a unique 32-byte "fingerprint". It is preimage resistant (you can't recover the secret from the hash), and collision resistance (you can't find a different secret that produces the same hash).

### Implementation details, not cryptographic primitives
* **Lagrange Interpolation**: The mechanism used to implement Shamir Secret Sharing reconstruction of the polynomial and find the value at $x=0$.
* **Modular Inverse (Fermat's Little Theorem)**: Used to perform division within the finite field $\mathbb{Z}_q$ in Solidity, which is essential for the Lagrange formula.

## How to reproduce the demo
