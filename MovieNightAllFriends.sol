// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MovieNightAllFriends {
    address public immutable organizer;
    uint256 public immutable totalFriends;
    uint256 public currentEpisode;
    address[] public friendList;

    struct Episode {
        uint256 deadline;
        bytes32 movieCodeHash;
        uint256 revealCount;
        bytes32 xorAccumulator;
        bytes32 reconstructedCode;
        bool movieUnlocked;
        bool expired;
        bool initialized;
    }

    mapping(uint256 => Episode) public episodes;

    mapping(address => bool) public isFriend;
    mapping(uint256 => mapping(address => bytes32)) public shareCommitment;
    mapping(uint256 => mapping(address => bool)) public hasRevealed;
    mapping(uint256 => mapping(address => bytes32)) public revealedShare;

    event EpisodeStarted(
        uint256 indexed episodeId,
        bytes32 movieCodeHash,
        uint256 deadline
    );
    event ShareRevealed(
        uint256 indexed episodeId,
        address indexed friend,
        uint256 revealCount
    );
    event MovieUnlocked(uint256 indexed episodeId, bytes32 reconstructedCode);
    event UnlockFailed(uint256 indexed episodeId, bytes32 reconstructedCode);
    event Expired(uint256 indexed episodeId, uint256 atTimestamp);

    error NotOrganizer();
    error NotFriend();
    error DuplicateFriend();
    error ZeroAddressFriend();
    error LengthMismatch();
    error InvalidDeadline();
    error AlreadyRevealed();
    error InvalidShare();
    error AlreadyFinalized();
    error DeadlinePassed();
    error DeadlineNotPassed();
    error NoEpisode();
    error EpisodeStillActive();

    modifier onlyOrganizer() {
        if (msg.sender != organizer) revert NotOrganizer();
        _;
    }

    modifier onlyFriend() {
        if (!isFriend[msg.sender]) revert NotFriend();
        _;
    }

    modifier activeEpisode(uint256 episodeId) {
        Episode storage episode = episodes[episodeId];
        if (!episode.initialized) revert NoEpisode();
        if (episode.movieUnlocked || episode.expired) revert AlreadyFinalized();
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
        }
    }

    function startEpisode(
        bytes32[] memory commitments,
        bytes32 movieCodeHash,
        uint256 revealWindowSeconds
    ) external onlyOrganizer {
        if (commitments.length != totalFriends) revert LengthMismatch();
        if (revealWindowSeconds == 0) revert InvalidDeadline();

        if (currentEpisode != 0) {
            Episode storage previous = episodes[currentEpisode];
            if (
                previous.initialized &&
                !previous.movieUnlocked &&
                !previous.expired
            ) {
                revert EpisodeStillActive();
            }
        }

        currentEpisode += 1;
        Episode storage episode = episodes[currentEpisode];
        episode.deadline = block.timestamp + revealWindowSeconds;
        episode.movieCodeHash = movieCodeHash;
        episode.initialized = true;

        for (uint256 i = 0; i < totalFriends; i++) {
            shareCommitment[currentEpisode][friendList[i]] = commitments[i];
        }

        emit EpisodeStarted(currentEpisode, movieCodeHash, episode.deadline);
    }

    function revealShare(bytes32 share, bytes32 salt)
        external
        onlyFriend
        activeEpisode(currentEpisode)
    {
        Episode storage episode = episodes[currentEpisode];

        if (block.timestamp > episode.deadline) revert DeadlinePassed();
        if (hasRevealed[currentEpisode][msg.sender]) revert AlreadyRevealed();

        bytes32 expected = keccak256(
            abi.encodePacked(msg.sender, currentEpisode, share, salt)
        );
        if (expected != shareCommitment[currentEpisode][msg.sender]) {
            revert InvalidShare();
        }

        hasRevealed[currentEpisode][msg.sender] = true;
        revealedShare[currentEpisode][msg.sender] = share;
        episode.xorAccumulator ^= share;
        episode.revealCount += 1;

        emit ShareRevealed(currentEpisode, msg.sender, episode.revealCount);

        if (episode.revealCount == totalFriends) {
            _finalizeUnlock(currentEpisode);
        }
    }

    function markExpired() external activeEpisode(currentEpisode) {
        Episode storage episode = episodes[currentEpisode];

        if (block.timestamp <= episode.deadline) revert DeadlineNotPassed();

        episode.expired = true;
        emit Expired(currentEpisode, block.timestamp);
    }

    function canWatchEpisode(uint256 episodeId) external view returns (bool) {
        return episodes[episodeId].movieUnlocked;
    }

    function getEpisodeStatus(
        uint256 episodeId
    )
        external
        view
        returns (
            uint256 deadline,
            uint256 revealCount,
            bool movieUnlocked,
            bool expired,
            bytes32 reconstructedCode
        )
    {
        Episode storage episode = episodes[episodeId];
        return (
            episode.deadline,
            episode.revealCount,
            episode.movieUnlocked,
            episode.expired,
            episode.reconstructedCode
        );
    }

    function _finalizeUnlock(uint256 episodeId) internal {
        Episode storage episode = episodes[episodeId];
        episode.reconstructedCode = episode.xorAccumulator;

        if (
            keccak256(abi.encodePacked(episode.reconstructedCode)) ==
            episode.movieCodeHash
        ) {
            episode.movieUnlocked = true;
            emit MovieUnlocked(episodeId, episode.reconstructedCode);
        } else {
            episode.expired = true;
            emit UnlockFailed(episodeId, episode.reconstructedCode);
        }
    }

}
