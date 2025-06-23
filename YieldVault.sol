/**
 *Submitted for verification at Arbiscan.io on 2025-06-02
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Minimal OpenZeppelin Ownable and SafeERC20 inlined
 */

// -------------------- Context --------------------
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

// -------------------- Ownable --------------------
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

// -------------------- IERC20 --------------------
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// -------------------- SafeERC20 --------------------
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        require(token.transfer(to, value), "SafeERC20: transfer failed");
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        require(token.transferFrom(from, to, value), "SafeERC20: transferFrom failed");
    }
}

// -------------------- IYieldVault Interface --------------------
interface IYieldVault {
    function recordFeeDeposit(uint256 amount) external;
}

// -------------------- KernelSmartAccount --------------------
contract KernelSmartAccount is Ownable {
    using SafeERC20 for IERC20;

    address public solverAddress;
    address public yieldVaultAddress;
    IERC20 public capitalToken;

    uint256 public totalCapitalDeployed;
    uint256 public totalFeesProcessedViaKernel;
    bool public isLoanActive;

    event CapitalDeposited(address indexed funder, uint256 amount);
    event LoanDisbursed(address indexed solver, uint256 amount);
    event LoanPrincipalRepaid(address indexed solver, uint256 amount);
    event FeesForwardedToVault(address indexed vault, uint256 amount);
    event KernelFundsWithdrawn(address indexed recipient, uint256 amount);
    event SolverAddressUpdated(address indexed oldSolver, address indexed newSolver);
    event YieldVaultAddressUpdated(address indexed oldVault, address indexed newVault);

    constructor(
        address _governance,
        address _solver,
        address _yieldVault,
        address _token
    ) {
        _transferOwnership(_governance);
        solverAddress = _solver;
        yieldVaultAddress = _yieldVault;
        capitalToken = IERC20(_token);
    }

    function setSolverAddress(address _newSolver) external onlyOwner {
        emit SolverAddressUpdated(solverAddress, _newSolver);
        solverAddress = _newSolver;
    }

    function setYieldVaultAddress(address _newYieldVault) external onlyOwner {
        emit YieldVaultAddressUpdated(yieldVaultAddress, _newYieldVault);
        yieldVaultAddress = _newYieldVault;
    }

    function depositCapital(uint256 _amount) external onlyOwner {
        capitalToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit CapitalDeposited(msg.sender, _amount);
    }

    function withdrawSurplusCapital(uint256 _amount, address _recipient) external onlyOwner {
        capitalToken.safeTransfer(_recipient, _amount);
        emit KernelFundsWithdrawn(_recipient, _amount);
    }

    function disburseLoan(uint256 _loanAmount) external onlyOwner {
        require(solverAddress != address(0), "Solver not set");
        require(capitalToken.balanceOf(address(this)) >= _loanAmount, "Insufficient funds");

        capitalToken.safeTransfer(solverAddress, _loanAmount);
        totalCapitalDeployed += _loanAmount;
        isLoanActive = true;

        emit LoanDisbursed(solverAddress, _loanAmount);
    }

    function recordLoanPrincipalRepayment(uint256 _repaidAmount) external onlyOwner {
        totalCapitalDeployed = totalCapitalDeployed > _repaidAmount ? totalCapitalDeployed - _repaidAmount : 0;
        if (totalCapitalDeployed == 0) {
            isLoanActive = false;
        }
        emit LoanPrincipalRepaid(solverAddress, _repaidAmount);
    }

    function processSolverFees(uint256 _feeAmountReceivedByKernel) external {
        require(msg.sender == solverAddress || msg.sender == owner(), "Unauthorized");
        require(yieldVaultAddress != address(0), "Vault not set");

        capitalToken.safeTransfer(yieldVaultAddress, _feeAmountReceivedByKernel);
        IYieldVault(yieldVaultAddress).recordFeeDeposit(_feeAmountReceivedByKernel);
        totalFeesProcessedViaKernel += _feeAmountReceivedByKernel;

        emit FeesForwardedToVault(yieldVaultAddress, _feeAmountReceivedByKernel);
    }

    function getLoanStatus() external view returns (address, uint256, bool) {
        return (solverAddress, totalCapitalDeployed, isLoanActive);
    }

    function getKernelBalance() external view returns (uint256) {
        return capitalToken.balanceOf(address(this));
    }
}

// -------------------- YieldVault --------------------
contract YieldVault is Ownable {
    using SafeERC20 for IERC20;

    address public kernelAddress;
    IERC20 public feeToken;
    address public daoTreasury;
    uint256 public totalFeesAccumulatedInVault;

    event FeesDepositedInVault(address indexed fromKernel, uint256 amount);
    event FeesSweptToTreasury(address indexed treasury, uint256 amount);
    event KernelAddressUpdated(address indexed oldKernel, address indexed newKernel);
    event DaoTreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);

    constructor(address _governance, address _kernel, address _feeToken, address _daoTreasury) {
        _transferOwnership(_governance);
        kernelAddress = _kernel;
        feeToken = IERC20(_feeToken);
        daoTreasury = _daoTreasury;
    }

    function recordFeeDeposit(uint256 _amount) external {
        require(msg.sender == kernelAddress, "Only Kernel can deposit");
        totalFeesAccumulatedInVault += _amount;
        emit FeesDepositedInVault(msg.sender, _amount);
    }

    function setKernelAddress(address _newKernel) external onlyOwner {
        emit KernelAddressUpdated(kernelAddress, _newKernel);
        kernelAddress = _newKernel;
    }

    function setDaoTreasury(address _newTreasury) external onlyOwner {
        emit DaoTreasuryUpdated(daoTreasury, _newTreasury);
        daoTreasury = _newTreasury;
    }

    function sweepToTreasury(uint256 _amount) external onlyOwner {
        require(daoTreasury != address(0), "DAO treasury not set");
        require(feeToken.balanceOf(address(this)) >= _amount, "Insufficient vault balance");
        feeToken.safeTransfer(daoTreasury, _amount);
        emit FeesSweptToTreasury(daoTreasury, _amount);
    }

    function sweepFullBalanceToTreasury() external onlyOwner {
        require(daoTreasury != address(0), "DAO treasury not set");
        uint256 balance = feeToken.balanceOf(address(this));
        if (balance > 0) {
            feeToken.safeTransfer(daoTreasury, balance);
            emit FeesSweptToTreasury(daoTreasury, balance);
        }
    }

    function getVaultBalance() external view returns (uint256) {
        return feeToken.balanceOf(address(this));
    }

    function getTotalFeesAccumulatedInVault() external view returns (uint256) {
        return totalFeesAccumulatedInVault;
    }
}