// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title WatchPartyVault
 * @dev Implements Challenge 4: Social Recovery Vault using Shamir's Secret Sharing
 * Scenario: 6 friends unlocking a TV episode key using Lagrange Interpolation.
 */
contract WatchPartyVault {
    // The prime q: Using the alt_bn128 scalar field prime for 256-bit security
    // q = 21888242871839275222246405745257275088548364400416034343698204186575808495617
    uint256 public constant Q = 0x30644e72e131a029b85045b68181585d2833e84879b9709143e1f593f0000001;

    address public dealer;
    uint256 public currentEpisode;
    uint256 public constant N_FRIENDS = 6;

    // Commitment Store: Episode Number => keccak256(Secret)
    mapping(uint256 => bytes32) public episodeCommitments;

    event SecretRevealed(uint256 indexed episode, uint256 secret);
    event EpisodeLocked(uint256 indexed episode, bytes32 commitment);

    constructor() {
        dealer = msg.sender;
        currentEpisode = 1;
    }

    modifier onlyDealer() {
        require(msg.sender == dealer, "Only the Dealer can perform this action");
        _;
    }

    /**
     * @dev Step 1: Setup (Off-chain commitment)
     * Dealer uploads the hash of the secret to "lock" the episode.
     */
    function lockNextEpisode(bytes32 _commitment) external onlyDealer {
        episodeCommitments[currentEpisode] = _commitment;
        emit EpisodeLocked(currentEpisode, _commitment);
    }

    /**
     * @dev Step 2: Happy Path (On-chain reconstruction)
     * @param x The indices of the friends (1, 2, 3, 4, 5, 6)
     * @param y The private shares f(i) held by each friend
     */
    function unlockEpisode(uint256[] calldata x, uint256[] calldata y) external returns (uint256) {
        require(x.length == N_FRIENDS, "All 6 friends must provide their shares");
        require(episodeCommitments[currentEpisode] != bytes32(0), "Episode not initialized by Dealer");

        // 1. Lagrange Interpolation to find f(0)
        uint256 reconstructedSecret = _interpolateAtZero(x, y);

        // 2. Verification using Keccak-256 (Commitment Scheme)
        // We use abi.encodePacked to convert the uint256 secret to bytes for hashing
        require(
            keccak256(abi.encodePacked(reconstructedSecret)) == episodeCommitments[currentEpisode],
            "Verification Failed: Incorrect shares or malicious submission detected"
        );

        // 3. Reveal and Increment
        emit SecretRevealed(currentEpisode, reconstructedSecret);
        currentEpisode++;

        return reconstructedSecret;
    }

    /**
     * @dev Core Primitive: Lagrange Interpolation
     * Calculates f(0) = sum( y_i * L_i(0) ) mod Q
     */
    function _interpolateAtZero(uint256[] calldata x, uint256[] calldata y) internal pure returns (uint256) {
        uint256 secret = 0;

        for (uint256 i = 0; i < N_FRIENDS; i++) {
            uint256 numerator = 1;
            uint256 denominator = 1;

            for (uint256 j = 0; j < N_FRIENDS; j++) {
                if (i != j) {
                    // L_i(0) numerator: (0 - x_j) mod Q
                    numerator = mulmod(numerator, Q - (x[j] % Q), Q);
                    
                    // L_i(0) denominator: (x_i - x_j) mod Q
                    uint256 diff;
                    if (x[i] >= x[j]) {
                        diff = (x[i] - x[j]) % Q;
                    } else {
                        diff = Q - ((x[j] - x[i]) % Q);
                    }
                    denominator = mulmod(denominator, diff, Q);
                }
            }

            // Primitive: Modular Inverse via Fermat's Little Theorem (den^(Q-2) mod Q)
            uint256 invDen = _modInverse(denominator);
            uint256 lagrangeWeight = mulmod(numerator, invDen, Q);
            
            // secret = sum( y_i * lagrangeWeight ) mod Q
            secret = (secret + mulmod(y[i] % Q, lagrangeWeight, Q)) % Q;
        }

        return secret;
    }

    function _modInverse(uint256 n) internal pure returns (uint256) {
        return _expMod(n, Q - 2);
    }

    function _expMod(uint256 base, uint256 exp) internal pure returns (uint256) {
        uint256 res = 1;
        base = base % Q;
        while (exp > 0) {
            if (exp % 2 == 1) res = mulmod(res, base, Q);
            base = mulmod(base, base, Q);
            exp = exp >> 1;
        }
        return res;
    }
}
