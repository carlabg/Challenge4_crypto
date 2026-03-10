// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MovieNightAllFriends {
    uint256 public constant FIELD_PRIME =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;

    address public immutable organizer;
    uint256 public immutable totalFriends;
    uint256 public currentEpisode;
    address[] public friendList;
    mapping(address => uint256) public friendX;

    struct Episode {
        bytes32 secretHash;
        uint256 submissions;
        bool secretRevealed;
        bool initialized;
    }

    mapping(uint256 => Episode) public episodes;

    mapping(address => bool) public isFriend;
    mapping(uint256 => mapping(address => bool)) public hasSubmitted;
    mapping(uint256 => mapping(address => uint256)) public submittedY;

    event EpisodeHashSet(
        uint256 indexed episodeId,
        bytes32 indexed secretHash
    );
    event ShareSubmitted(
        uint256 indexed episodeId,
        address indexed friend,
        uint256 x,
        uint256 y,
        uint256 submissions
    );
    event ShareUpdated(
        uint256 indexed episodeId,
        address indexed friend,
        uint256 x,
        uint256 previousY,
        uint256 newY
    );
    event EpisodeUnlocked(uint256 indexed episodeId);

    error NotOrganizer();
    error NotFriend();
    error DuplicateFriend();
    error ZeroAddressFriend();
    error LengthMismatch();
    error EpisodeStillActive();
    error NoActiveEpisode();
    error InvalidFieldElement();
    error InvalidXForFriend();
    error ReconstructionMismatch();
    error AlreadyFinalized();
    error EpisodeMismatch();
    error NotEnoughShares();

    modifier onlyOrganizer() {
        if (msg.sender != organizer) revert NotOrganizer();
        _;
    }

    modifier onlyFriend() {
        if (!isFriend[msg.sender]) revert NotFriend();
        _;
    }

    modifier activeEpisode(uint256 episodeId) {
        if (currentEpisode == 0) revert NoActiveEpisode();
        if (episodeId != currentEpisode) revert EpisodeMismatch();
        Episode storage episode = episodes[episodeId];
        if (!episode.initialized || episode.secretRevealed) revert AlreadyFinalized();
        _;
    }

    constructor(address[] memory friends) {
        if (friends.length == 0) revert LengthMismatch();

        organizer = msg.sender;
        totalFriends = friends.length;

        for (uint256 i = 0; i < friends.length; i++) {
            address friend = friends[i];
            if (friend == address(0)) revert ZeroAddressFriend();
            if (isFriend[friend]) revert DuplicateFriend();

            isFriend[friend] = true;
            friendList.push(friend);
            friendX[friend] = i + 1;
        }
    }

    function setEpisodeHash(bytes32 secretHash) external onlyOrganizer {
        if (secretHash == bytes32(0)) revert InvalidFieldElement();

        if (currentEpisode != 0) {
            Episode storage previous = episodes[currentEpisode];
            if (previous.initialized && !previous.secretRevealed) {
                revert EpisodeStillActive();
            }
        }

        currentEpisode += 1;
        Episode storage episode = episodes[currentEpisode];
        episode.secretHash = secretHash;
        episode.initialized = true;
        episode.submissions = 0;
        episode.secretRevealed = false;

        emit EpisodeHashSet(currentEpisode, secretHash);
    }

    function unlockEpisode(
        uint256 episodeId,
        uint256 x,
        uint256 y
    ) external onlyFriend activeEpisode(episodeId) {
        _submitShare(episodeId, x, y);
    }

    function finalizeEpisode(uint256 episodeId) external activeEpisode(episodeId) {
        Episode storage episode = episodes[episodeId];
        if (episode.submissions < totalFriends) revert NotEnoughShares();
        _finalizeEpisode(episodeId);
    }

    function _submitShare(uint256 episodeId, uint256 x, uint256 y) internal {
        Episode storage episode = episodes[episodeId];
        if (!episode.initialized || episode.secretRevealed) revert AlreadyFinalized();
        if (x != friendX[msg.sender]) revert InvalidXForFriend();
        if (x == 0 || x >= FIELD_PRIME || y >= FIELD_PRIME) {
            revert InvalidFieldElement();
        }

        bool firstSubmission = !hasSubmitted[episodeId][msg.sender];
        uint256 previousY = submittedY[episodeId][msg.sender];
        hasSubmitted[episodeId][msg.sender] = true;
        submittedY[episodeId][msg.sender] = y;

        if (firstSubmission) {
            episode.submissions += 1;
        }

        emit ShareSubmitted(
            episodeId,
            msg.sender,
            x,
            y,
            episode.submissions
        );

        if (!firstSubmission) {
            emit ShareUpdated(
                episodeId,
                msg.sender,
                x,
                previousY,
                y
            );
        }
    }

    function canWatchEpisode(uint256 episodeId) external view returns (bool) {
        return episodes[episodeId].secretRevealed;
    }

    function getEpisodeStatus(
        uint256 episodeId
    )
        external
        view
        returns (
            uint256 submissions,
            bool secretRevealed,
            bytes32 secretHash
        )
    {
        Episode storage episode = episodes[episodeId];
        return (
            episode.submissions,
            episode.secretRevealed,
            episode.secretHash
        );
    }

    function _finalizeEpisode(uint256 episodeId) internal {
        Episode storage episode = episodes[episodeId];
        uint256 secret = _reconstructAtZero(episodeId);

        if (keccak256(abi.encodePacked(secret)) != episode.secretHash) {
            revert ReconstructionMismatch();
        }

        // Only store that verification passed — secret never saved on-chain
        episode.secretRevealed = true;
        emit EpisodeUnlocked(episodeId);
    }

    function _reconstructAtZero(uint256 episodeId) internal view returns (uint256) {
        uint256 secret = 0;

        for (uint256 i = 0; i < totalFriends; i++) {
            address friendI = friendList[i];
            uint256 xi = friendX[friendI];
            uint256 yi = submittedY[episodeId][friendI];

            uint256 li = 1;
            for (uint256 j = 0; j < totalFriends; j++) {
                if (i == j) continue;

                address friendJ = friendList[j];
                uint256 xj = friendX[friendJ];

                uint256 numerator = _subMod(0, xj);
                uint256 denominator = _subMod(xi, xj);
                uint256 factor = _mulMod(numerator, _invMod(denominator));
                li = _mulMod(li, factor);
            }

            secret = _addMod(secret, _mulMod(yi, li));
        }

        return secret;
    }

    function _addMod(uint256 a, uint256 b) internal pure returns (uint256) {
        return addmod(a, b, FIELD_PRIME);
    }

    function _subMod(uint256 a, uint256 b) internal pure returns (uint256) {
        return addmod(a, FIELD_PRIME - (b % FIELD_PRIME), FIELD_PRIME);
    }

    function _mulMod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mulmod(a, b, FIELD_PRIME);
    }

    function _invMod(uint256 a) internal pure returns (uint256) {
        if (a == 0) revert InvalidFieldElement();
        return _powMod(a, FIELD_PRIME - 2);
    }

    function _powMod(
        uint256 base,
        uint256 exponent
    ) internal pure returns (uint256) {
        uint256 result = 1;
        uint256 current = base % FIELD_PRIME;
        uint256 e = exponent;

        while (e > 0) {
            if (e & 1 == 1) {
                result = mulmod(result, current, FIELD_PRIME);
            }
            current = mulmod(current, current, FIELD_PRIME);
            e >>= 1;
        }

        return result;
    }
}
