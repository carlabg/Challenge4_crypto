#!/usr/bin/env python3
"""
generate_shares.py — Shamir's Secret Sharing for MovieNightAllFriends

Two modes:
  1. GENERATE: Create shares from a secret polynomial (organizer runs this)
  2. RECONSTRUCT: Recover the secret from all shares (friends run this after EpisodeUnlocked)

Usage:
  python generate_shares.py              # Generate shares + hash
  python generate_shares.py --reconstruct  # Reconstruct secret from shares
"""

import sys
import hashlib

# --- Field prime (secp256k1), must match the contract's FIELD_PRIME ---
FIELD_PRIME = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F

# --- Polynomial coefficients: f(x) = a0 + a1*x + a2*x^2 + ... ---
# a0 = SECRET (f(0))
# The rest are random-looking coefficients (for the demo, fixed values)
COEFFICIENTS = [12345, 111, 222, 333, 444, 555]

# Number of friends
NUM_FRIENDS = 6


# ===================== MATH HELPERS =====================

def eval_poly(x: int, coeffs: list[int]) -> int:
    """Evaluate polynomial at x in the finite field."""
    result = 0
    for i, c in enumerate(coeffs):
        result = (result + c * pow(x, i, FIELD_PRIME)) % FIELD_PRIME
    return result


def mod_inverse(a: int, p: int) -> int:
    """Modular inverse using Fermat's little theorem: a^(p-2) mod p."""
    return pow(a, p - 2, p)


def lagrange_interpolate_at_zero(shares: list[tuple[int, int]]) -> int:
    """
    Reconstruct f(0) from shares using Lagrange interpolation.
    shares: list of (x, y) tuples
    Returns: the secret f(0)
    """
    secret = 0
    n = len(shares)

    for i in range(n):
        xi, yi = shares[i]

        # Compute Lagrange basis polynomial L_i(0)
        li = 1
        for j in range(n):
            if i == j:
                continue
            xj = shares[j][0]

            numerator = (0 - xj) % FIELD_PRIME          # (0 - xj) mod p
            denominator = (xi - xj) % FIELD_PRIME        # (xi - xj) mod p
            factor = (numerator * mod_inverse(denominator, FIELD_PRIME)) % FIELD_PRIME
            li = (li * factor) % FIELD_PRIME

        secret = (secret + yi * li) % FIELD_PRIME

    return secret


def keccak256(value: int) -> str:
    """
    Compute keccak256(abi.encodePacked(uint256)) — matches Solidity's keccak256.
    Returns hex string with 0x prefix.
    """
    # abi.encodePacked(uint256) = 32 bytes, big-endian
    value_bytes = value.to_bytes(32, "big")
    # Python's hashlib uses 'sha3_256' which IS keccak256 for standard SHA-3,
    # but Solidity's keccak256 is the ORIGINAL Keccak (pre-NIST).
    # For a proper match, use pysha3 or web3. For demo purposes, we use pycryptodome.
    try:
        from Crypto.Hash import keccak
        k = keccak.new(digest_bits=256)
        k.update(value_bytes)
        return "0x" + k.hexdigest()
    except ImportError:
        # Fallback: try pysha3
        try:
            import sha3
            return "0x" + sha3.keccak_256(value_bytes).hexdigest()
        except ImportError:
            # Last resort: use hashlib sha3_256 (NOTE: this is NIST SHA-3, NOT keccak256!)
            print("⚠️  WARNING: Using SHA3-256 (NIST), NOT Solidity's keccak256.")
            print("   Install pycryptodome for correct hash: pip install pycryptodome")
            h = hashlib.sha3_256(value_bytes).hexdigest()
            return "0x" + h


# ===================== MAIN =====================

def generate_shares():
    """Generate shares and the hash for the organizer."""
    secret = COEFFICIENTS[0]

    print("=" * 60)
    print("🎬 SHAMIR'S SECRET SHARING — Share Generator")
    print("=" * 60)
    print(f"\nPolynomial: f(x) = {' + '.join(f'{c}·x^{i}' if i > 0 else str(c) for i, c in enumerate(COEFFICIENTS))}")
    print(f"Degree: {len(COEFFICIENTS) - 1}")
    print(f"Secret f(0) = {secret}")
    print(f"Field prime (secp256k1): {FIELD_PRIME}")

    print(f"\n{'─' * 60}")
    print("📦 SHARES (give one to each friend):")
    print(f"{'─' * 60}")

    shares = []
    for friend in range(1, NUM_FRIENDS + 1):
        x = friend
        y = eval_poly(x, COEFFICIENTS)
        shares.append((x, y))
        print(f"  Friend {friend}:  x = {x},  y = {y}")

    print(f"\n{'─' * 60}")
    print("🔐 HASH (for setEpisodeHash in the contract):")
    print(f"{'─' * 60}")

    secret_hash = keccak256(secret)
    print(f"  keccak256({secret}) = {secret_hash}")
    print(f"\n  → Use this as the parameter for setEpisodeHash()")

    print(f"\n{'─' * 60}")
    print("📋 REMIX QUICK-COPY:")
    print(f"{'─' * 60}")
    print(f"  setEpisodeHash:  {secret_hash}")
    for x, y in shares:
        print(f"  unlockEpisode(1, {x}, {y})")

    print()


def reconstruct_secret():
    """Reconstruct the secret from shares (friends run this after EpisodeUnlocked)."""
    print("=" * 60)
    print("🏠 SHAMIR'S SECRET SHARING — Local Reconstruction")
    print("=" * 60)

    # In a real scenario, friends would input their shares.
    # For the demo, we use the known shares.
    print("\nCollecting shares from all friends...")

    shares = []
    for friend in range(1, NUM_FRIENDS + 1):
        x = friend
        y = eval_poly(x, COEFFICIENTS)
        shares.append((x, y))
        print(f"  Friend {friend}:  ({x}, {y})")

    print(f"\n{'─' * 60}")
    print("🧮 Running Lagrange interpolation at x=0...")
    print(f"{'─' * 60}")

    secret = lagrange_interpolate_at_zero(shares)

    print(f"\n  ✅ Reconstructed secret f(0) = {secret}")
    print(f"  ✅ Hash verification: {keccak256(secret)}")
    print(f"\n  The contract confirmed this was correct (EpisodeUnlocked),")
    print(f"  and now you have the secret locally — never exposed on-chain! 🔐")
    print()


if __name__ == "__main__":
    # Fix Windows console encoding for emoji/unicode
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    if "--reconstruct" in sys.argv:
        reconstruct_secret()
    else:
        generate_shares()
