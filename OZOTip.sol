// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title OZO Tip Protocol
 * @author OZO Team
 * @notice A lightweight decentralized tipping protocol built on Ozone Chain.
 * @dev
 * Features:
 * - Peer-to-peer tipping
 * - Non-custodial withdrawals
 * - Fully on-chain event tracking
 * - Optimized for low gas usage
 *
 * Architecture:
 * - Tips are accumulated per creator
 * - Funds remain in contract until withdrawn
 * - Tip history is emitted through events
 */
contract OZOTip {
    // =============================================================
    // STORAGE
    // =============================================================

    /// @notice Total withdrawable balance per creator
    mapping(address => uint256) public availableTips;

    /// @notice Total lifetime received amount per creator
    mapping(address => uint256) public totalReceived;

    /// @notice Total lifetime withdrawn amount per creator
    mapping(address => uint256) public totalWithdrawn;

    /// @notice Incremental global tip counter
    uint256 public tipCounter;

    // =============================================================
    // EVENTS
    // =============================================================

    /**
     * @notice Emitted whenever a tip is sent
     *
     * @param tipId Unique tip identifier
     * @param from Sender address
     * @param to Receiver address
     * @param amount Amount tipped
     * @param timestamp Block timestamp
     * @param message Tip message
     */
    event Tipped(
        uint256 indexed tipId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp,
        string message
    );

    /**
     * @notice Emitted whenever a creator withdraws tips
     *
     * @param user Creator wallet
     * @param amount Amount withdrawn
     */
    event Withdrawn(address indexed user, uint256 amount);

    // =============================================================
    // ERRORS
    // =============================================================

    error ZeroValue();
    error InvalidAddress();
    error NoBalance();
    error TransferFailed();
    error MessageTooLong();
    error SelfTipNotAllowed();

    // =============================================================
    // TIP
    // =============================================================

    /**
     * @notice Send a tip to a creator
     *
     * @dev
     * - Stores creator balance
     * - Updates lifetime received stats
     * - Emits on-chain event for indexing
     *
     * @param creator Recipient wallet address
     * @param message Optional tip message
     */
    function tip(
        address creator,
        string calldata message
    ) external payable {
        if (msg.value == 0) revert ZeroValue();
        if (creator == address(0)) revert InvalidAddress();
        if (bytes(message).length > 200) revert MessageTooLong();
        if (creator == msg.sender) revert SelfTipNotAllowed();

        unchecked {
            ++tipCounter;
        }

        availableTips[creator] += msg.value;
        totalReceived[creator] += msg.value;

        emit Tipped(
            tipCounter,
            msg.sender,
            creator,
            msg.value,
            block.timestamp,
            message
        );
    }


    // =============================================================
    // WITHDRAW
    // =============================================================

    /**
     * @notice Withdraw accumulated tips
     *
     * @dev
     * Uses checks-effects-interactions pattern
     * to prevent reentrancy attacks.
     */
    function withdraw() external {
        uint256 amount = availableTips[msg.sender];

        if (amount == 0) revert NoBalance();

        // effects
        availableTips[msg.sender] = 0;
        totalWithdrawn[msg.sender] += amount;

        // interaction
        (bool success, ) = msg.sender.call{value: amount}("");

        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, amount);
    }

    // =============================================================
    // VIEW HELPERS
    // =============================================================

    /**
     * @notice Get creator statistics
     *
     * @param user Creator wallet address
     *
     * @return received Total lifetime received
     * @return withdrawn Total lifetime withdrawn
     * @return available Current withdrawable balance
     */
    function getStats(
        address user
    )
        external
        view
        returns (
            uint256 received,
            uint256 withdrawn,
            uint256 available
        )
    {
        return (
            totalReceived[user],
            totalWithdrawn[user],
            availableTips[user]
        );
    }
}
