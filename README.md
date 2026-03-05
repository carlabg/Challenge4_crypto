# Challenge 4_crypto — Movie Night Secret Sharing

## Scenario: Secure Group Viewing for Game of Thrones

Six friends are tired of agreeing to wait and watch the new episodes of *Game of Thrones* together, only for someone to secretly watch them early. They decide to use a special app that locks each episode and can only unlock it when **everyone is present and agrees at the same time**.

### How It Works

When a new episode is available, the app asks each friend to approve the viewing by submitting a **digital private share** from their own device. Key points:

- No one can enter another person’s code.
- Only after the app verifies that **all six people’s private shares** have been submitted for that specific episode, it unlocks the video.
- The episode can then be played.

This solves the problem of early watching in a group with imperfect trust, **without relying on one friend or a centralized server**. The blockchain makes sense because the app provides a **shared, tamper-resistant source of truth**:

- Everyone can verify that the rule is: *“all six must approve.”*
- No single participant can override it.

## Actors and Assumptions

**Actors:**

1. The six friends  
2. The smart contract  
3. The blockchain network  

**Assumptions:**

- Any friend could be potentially malicious and try to unlock early or claim others agreed.  
- No friend can forge another friend’s private share.  
- Each friend controls their device and private key.  
- Blockchain consensus works as intended.
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

