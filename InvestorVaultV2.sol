/**
 *Submitted for verification at Arbiscan.io on 2025-06-02
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract InvestorVaultV2 is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    address public kernel;

    uint256 public totalShares;
    uint256 public totalDeposits;
    uint256 public totalYieldDistributed;
    uint256 public constant LOCKUP_PERIOD = 30 days;

    mapping(address => uint256) public shares;
    mapping(address => uint256) public claimedYield;
    mapping(address => uint256) public depositTimestamps;

    event Deposited(address indexed investor, uint256 amount, uint256 sharesMinted);
    event Withdrawn(address indexed investor, uint256 amount, uint256 sharesBurned);
    event YieldClaimed(address indexed investor, uint256 amount);
    event YieldCompounded(address indexed investor, uint256 amount, uint256 newShares);
    event KernelUpdated(address indexed oldKernel, address indexed newKernel);

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
    }

    function setKernel(address _kernel) external onlyOwner {
        emit KernelUpdated(kernel, _kernel);
        kernel = _kernel;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Zero deposit");
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        uint256 sharesToMint = totalShares == 0 ? amount : (amount * totalShares) / totalDeposits;

        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        totalDeposits += amount;
        depositTimestamps[msg.sender] = block.timestamp;

        emit Deposited(msg.sender, amount, sharesToMint);
    }

    function withdraw(uint256 shareAmount) external {
        require(shares[msg.sender] >= shareAmount, "Not enough shares");
        require(block.timestamp >= depositTimestamps[msg.sender] + LOCKUP_PERIOD, "Funds are locked");

        uint256 withdrawAmount = (shareAmount * totalDeposits) / totalShares;

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;
        totalDeposits -= withdrawAmount;

        usdc.safeTransfer(msg.sender, withdrawAmount);
        emit Withdrawn(msg.sender, withdrawAmount, shareAmount);
    }

    function batchWithdraw(address[] calldata investors) external onlyOwner {
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 shareAmount = shares[investor];
            if (shareAmount > 0 && block.timestamp >= depositTimestamps[investor] + LOCKUP_PERIOD) {
                uint256 withdrawAmount = (shareAmount * totalDeposits) / totalShares;
                shares[investor] = 0;
                totalShares -= shareAmount;
                totalDeposits -= withdrawAmount;
                usdc.safeTransfer(investor, withdrawAmount);
                emit Withdrawn(investor, withdrawAmount, shareAmount);
            }
        }
    }

    function receiveYield(uint256 amount) external {
        require(msg.sender == kernel, "Only kernel can send yield");
        usdc.safeTransferFrom(msg.sender, address(this), amount);
        totalDeposits += amount;
        totalYieldDistributed += amount;
    }

    function claimableYield(address investor) public view returns (uint256) {
        uint256 totalEarned = (shares[investor] * totalDeposits) / totalShares;
        uint256 totalInitial = (shares[investor] * (totalDeposits - totalYieldDistributed)) / totalShares;
        return totalEarned > totalInitial ? totalEarned - totalInitial - claimedYield[investor] : 0;
    }

    function claimYield() external {
        uint256 amount = claimableYield(msg.sender);
        require(amount > 0, "No yield");
        claimedYield[msg.sender] += amount;
        usdc.safeTransfer(msg.sender, amount);
        emit YieldClaimed(msg.sender, amount);
    }

    function batchClaimYield(address[] calldata investors) external {
        for (uint256 i = 0; i < investors.length; i++) {
            address investor = investors[i];
            uint256 amount = claimableYield(investor);
            if (amount > 0) {
                claimedYield[investor] += amount;
                usdc.safeTransfer(investor, amount);
                emit YieldClaimed(investor, amount);
            }
        }
    }

    function compoundYield() external {
        uint256 amount = claimableYield(msg.sender);
        require(amount > 0, "No yield");

        uint256 sharesToMint = (amount * totalShares) / totalDeposits;
        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;
        claimedYield[msg.sender] += amount;
        totalDeposits += amount;

        emit YieldCompounded(msg.sender, amount, sharesToMint);
    }

    function getInvestorInfo(address investor) external view returns (
        uint256 share,
        uint256 claimable,
        uint256 claimed,
        uint256 unlockTime
    ) {
        return (
            shares[investor],
            claimableYield(investor),
            claimedYield[investor],
            depositTimestamps[investor] + LOCKUP_PERIOD
        );
    }

    function getVaultTotals() external view returns (
        uint256 totalUSDC,
        uint256 totalSharesMinted,
        uint256 totalYield
    ) {
        return (totalDeposits, totalShares, totalYieldDistributed);
    }

    function fundKernel(uint256 amount) external onlyOwner {
        require(kernel != address(0), "Kernel not set");
        require(amount <= usdc.balanceOf(address(this)), "Insufficient balance");
        usdc.safeTransfer(kernel, amount);
    }
}