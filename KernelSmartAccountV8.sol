/**
 *Submitted for verification at Arbiscan.io on 2025-06-20
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = address(token).call(data);
        require(success, "SafeERC20: low-level call failed");

        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IInvestorVault {
    function receiveYield(uint256 amount) external;
    function fundKernel(uint256 amount) external;
}

/**
 * @title KernelSmartAccountV8
 * @notice SEC-FIX: Uses SafeERC20 and includes a timelock for changing critical addresses.
 */
contract KernelSmartAccountV8 {
    using SafeERC20 for IERC20;

    address public owner;
    address public yieldVaultAddress;
    address public investorVaultAddress;
    IERC20 public capitalToken;

    mapping(address => bool) public whitelistedSolvers;
    mapping(address => uint256) public loanPrincipals;

    uint256 public performanceFeeBps;
    uint256 public totalCapitalDeployed;
    uint256 public totalFeesProcessedViaKernel;

    // --- Timelock State Variables ---
    uint256 public constant TIMELOCK_DELAY = 48 hours;

    address public pendingYieldVaultAddress;
    uint256 public yieldVaultChangeTimestamp;

    address public pendingInvestorVaultAddress;
    uint256 public investorVaultChangeTimestamp;


    event LoanDisbursed(address indexed solver, uint256 amount);
    event CapitalDeposited(address indexed funder, uint256 amount);
    event FeesForwardedToVault(address indexed vault, uint256 amount);
    event YieldDistributedToInvestors(address indexed vault, uint256 amount);
    event KernelFundsWithdrawn(address indexed recipient, uint256 amount);
    event LoanPrincipalRepaid(address indexed solver, uint256 amount);
    event LoanFeesPaid(address indexed solver, uint256 amount);
    event SolverAddressUpdated(address indexed solver, bool isWhitelisted);
    event YieldVaultChangeProposed(address indexed pendingAddress, uint256 effectiveTimestamp);
    event YieldVaultAddressUpdated(address indexed oldVault, address indexed newVault);
    event InvestorVaultChangeProposed(address indexed pendingAddress, uint256 effectiveTimestamp);
    event InvestorVaultAddressUpdated(address indexed oldVault, address indexed newVault);
    event PerformanceFeeUpdated(uint256 newFeeBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event LoanNoteLogged(address indexed operator, string note, uint256 timestamp);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _governance,
        address _initialSolver,
        address _yieldVault,
        address _investorVault,
        address _token
    ) {
        owner = _governance;
        whitelistedSolvers[_initialSolver] = true;
        yieldVaultAddress = _yieldVault;
        investorVaultAddress = _investorVault;
        capitalToken = IERC20(_token);
        performanceFeeBps = 2000; // Default 20%
    }

    function depositCapital(uint256 _amount) external onlyOwner {
        capitalToken.safeTransferFrom(msg.sender, address(this), _amount);
        emit CapitalDeposited(msg.sender, _amount);
    }

    function deployCapitalFromVault(uint256 _amount) external onlyOwner {
        IInvestorVault(investorVaultAddress).fundKernel(_amount);
        emit CapitalDeposited(investorVaultAddress, _amount);
    }

    function disburseLoan(address solver, uint256 _loanAmount) external onlyOwner {
        require(whitelistedSolvers[solver], "Solver not whitelisted");
        require(loanPrincipals[solver] == 0, "Solver has an existing loan");
        require(capitalToken.balanceOf(address(this)) >= _loanAmount, "Insufficient capital in Kernel");
        
        loanPrincipals[solver] = _loanAmount;
        totalCapitalDeployed += _loanAmount;
        
        capitalToken.safeTransfer(solver, _loanAmount);
        emit LoanDisbursed(solver, _loanAmount);
    }

    function settleLoanFromBalance(uint256 _principalAmount, uint256 _feeAmount) external {
        require(whitelistedSolvers[msg.sender], "Only solvers can settle loans");
        require(loanPrincipals[msg.sender] == _principalAmount, "Repayment amount does not match loan principal");

        uint256 totalRepayment = _principalAmount + _feeAmount;
        require(capitalToken.balanceOf(address(this)) >= totalRepayment, "Insufficient balance in contract to settle");

        loanPrincipals[msg.sender] = 0;
        totalCapitalDeployed -= _principalAmount;
        emit LoanPrincipalRepaid(msg.sender, _principalAmount);
        
        if (_feeAmount > 0) {
            totalFeesProcessedViaKernel += _feeAmount;
            
            uint256 daoShare = (_feeAmount * performanceFeeBps) / 10000;
            uint256 investorShare = _feeAmount - daoShare;

            if (daoShare > 0) {
                capitalToken.safeTransfer(yieldVaultAddress, daoShare);
                emit FeesForwardedToVault(yieldVaultAddress, daoShare);
            }

            if (investorShare > 0) {
                capitalToken.safeApprove(investorVaultAddress, investorShare); 
                IInvestorVault(investorVaultAddress).receiveYield(investorShare);
                emit YieldDistributedToInvestors(investorVaultAddress, investorShare);
            }
            emit LoanFeesPaid(msg.sender, _feeAmount);
        }
    }

    function withdrawSurplusCapital(uint256 _amount, address _recipient) external onlyOwner {
        uint256 currentBalance = capitalToken.balanceOf(address(this));
        uint256 surplus = currentBalance - totalCapitalDeployed;
        require(_amount <= surplus, "Withdrawal exceeds surplus capital");
        
        capitalToken.safeTransfer(_recipient, _amount);
        emit KernelFundsWithdrawn(_recipient, _amount);
    }

    function setSolverAddress(address _solver, bool _whitelisted) external onlyOwner {
        whitelistedSolvers[_solver] = _whitelisted;
        emit SolverAddressUpdated(_solver, _whitelisted);
    }

    function proposeNewYieldVaultAddress(address _newYieldVault) external onlyOwner {
        require(_newYieldVault != address(0), "Zero address");
        pendingYieldVaultAddress = _newYieldVault;
        yieldVaultChangeTimestamp = block.timestamp + TIMELOCK_DELAY;
        emit YieldVaultChangeProposed(_newYieldVault, yieldVaultChangeTimestamp);
    }

    function finalizeYieldVaultChange() external onlyOwner {
        require(pendingYieldVaultAddress != address(0), "No pending change");
        require(block.timestamp >= yieldVaultChangeTimestamp, "Timelock active");
        
        emit YieldVaultAddressUpdated(yieldVaultAddress, pendingYieldVaultAddress);
        yieldVaultAddress = pendingYieldVaultAddress;
        
        pendingYieldVaultAddress = address(0);
        yieldVaultChangeTimestamp = 0;
    }

    function proposeNewInvestorVaultAddress(address _newInvestorVault) external onlyOwner {
        require(_newInvestorVault != address(0), "Zero address");
        pendingInvestorVaultAddress = _newInvestorVault;
        investorVaultChangeTimestamp = block.timestamp + TIMELOCK_DELAY;
        emit InvestorVaultChangeProposed(_newInvestorVault, investorVaultChangeTimestamp);
    }

    function finalizeInvestorVaultChange() external onlyOwner {
        require(pendingInvestorVaultAddress != address(0), "No pending change");
        require(block.timestamp >= investorVaultChangeTimestamp, "Timelock active");

        emit InvestorVaultAddressUpdated(investorVaultAddress, pendingInvestorVaultAddress);
        investorVaultAddress = pendingInvestorVaultAddress;
        
        pendingInvestorVaultAddress = address(0);
        investorVaultChangeTimestamp = 0;
    }

    function setPerformanceFee(uint256 _newFeeBps) external onlyOwner {
        require(_newFeeBps <= 10000, "Fee cannot exceed 100%");
        performanceFeeBps = _newFeeBps;
        emit PerformanceFeeUpdated(_newFeeBps);
    }

    function logLoanNote(string calldata note) external onlyOwner {
        emit LoanNoteLogged(msg.sender, note, block.timestamp);
    }

    function getKernelBalance() external view returns (uint256) {
        return capitalToken.balanceOf(address(this));
    }
    
    function getLoanPrincipal(address _solver) external view returns (uint256) {
        return loanPrincipals[_solver];
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}