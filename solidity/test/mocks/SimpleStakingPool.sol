// SPDX-License-Identifier: MIT

/// @notice A minimal, self-contained DeFi "core" for use as a Powers governance demo.
///
/// Users stake an ERC20 (`STAKING_TOKEN`) and earn a second ERC20 (`REWARD_TOKEN`) at a
/// governance-settable, per-second linear rate. Rewards are paid out of a reserve that the
/// owner funds. The staking / unstaking / claiming functions are open to anyone; the parameter
/// and treasury functions are `onlyOwner`.
///
/// Governance shape: this contract is `Ownable`, and every privileged knob is guarded by
/// `onlyOwner`. To let a Powers protocol govern it, deploy it from the Powers instance (or call
/// `transferOwnership(powers)` afterwards). Powers then drives the `onlyOwner` functions through a
/// mandate such as `BespokeAction_Simple`. No governance-specific code lives here on purpose.
///
/// This is a demo/mock contract: the reward math is deliberately simple (per-user linear accrual,
/// not a global accumulator) and it is not audited for production use.
///
/// @author 7Cedars,

pragma solidity ^0.8.26;

import { IERC20 } from "@lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import { Ownable } from "@lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract SimpleStakingPool is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error SimpleStakingPool__NoZeroAmount();
    error SimpleStakingPool__InsufficientStake();
    error SimpleStakingPool__Paused();
    error SimpleStakingPool__InsufficientRewardReserve();
    error SimpleStakingPool__CannotSweepStakingPrincipal();

    /// @notice scaling factor for `rewardRatePerTokenPerSecond` (fixed-point 1e18).
    uint256 public constant RATE_PRECISION = 1e18;

    IERC20 public immutable STAKING_TOKEN;
    IERC20 public immutable REWARD_TOKEN;

    /// @notice reward tokens accrued per staked token per second, scaled by RATE_PRECISION.
    /// @dev this is the governable "APR" knob. e.g. a rate of 1e18 pays 1 reward token per staked
    /// token per second; 3.17e9 (== 1e18 / ~365 days) pays ~100% APR.
    uint256 public rewardRatePerTokenPerSecond;

    uint256 public totalStaked;
    bool public paused;

    mapping(address account => uint256 amount) public stakedBalance;
    mapping(address account => uint256 timestamp) public lastUpdate;
    mapping(address account => uint256 amount) public rewards;

    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);
    event Claimed(address indexed account, uint256 amount);
    event RewardRateChanged(uint256 oldRate, uint256 newRate);
    event RewardsFunded(address indexed from, uint256 amount);
    event PausedSet(bool paused);
    event Swept(address indexed token, address indexed to, uint256 amount);

    constructor(IERC20 _stakingToken, IERC20 _rewardToken, uint256 _initialRate) Ownable(msg.sender) {
        STAKING_TOKEN = _stakingToken;
        REWARD_TOKEN = _rewardToken;
        rewardRatePerTokenPerSecond = _initialRate;
    }

    ////////////////////////////////////////////
    //          Public user functions         //
    ////////////////////////////////////////////

    /// @notice Stake `amount` of `STAKING_TOKEN`. Caller must approve this contract first.
    function stake(uint256 amount) external nonReentrant {
        if (paused) revert SimpleStakingPool__Paused();
        if (amount == 0) revert SimpleStakingPool__NoZeroAmount();

        _accrue(msg.sender);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        STAKING_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    /// @notice Withdraw `amount` of staked principal. Allowed even while paused so principal is
    /// never trapped.
    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert SimpleStakingPool__NoZeroAmount();
        if (amount > stakedBalance[msg.sender]) revert SimpleStakingPool__InsufficientStake();

        _accrue(msg.sender);
        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;

        STAKING_TOKEN.safeTransfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    /// @notice Claim all accrued rewards. Reverts if the reward reserve cannot cover them.
    function claim() external nonReentrant {
        _accrue(msg.sender);

        uint256 owed = rewards[msg.sender];
        if (owed == 0) revert SimpleStakingPool__NoZeroAmount();
        if (rewardReserve() < owed) revert SimpleStakingPool__InsufficientRewardReserve();

        rewards[msg.sender] = 0;
        REWARD_TOKEN.safeTransfer(msg.sender, owed);
        emit Claimed(msg.sender, owed);
    }

    ////////////////////////////////////////////
    //             Getter functions           //
    ////////////////////////////////////////////

    /// @notice Total rewards owed to `account`, including not-yet-accrued amounts.
    function earned(address account) external view returns (uint256) {
        return rewards[account] + _pending(account);
    }

    /// @notice Reward tokens currently available to pay out.
    /// @dev when the staking and reward tokens are the same, staked principal is excluded so it is
    /// never handed out as rewards.
    function rewardReserve() public view returns (uint256) {
        uint256 balance = REWARD_TOKEN.balanceOf(address(this));
        if (REWARD_TOKEN == STAKING_TOKEN) {
            return balance > totalStaked ? balance - totalStaked : 0;
        }
        return balance;
    }

    ////////////////////////////////////////////
    //     Governed functions (onlyOwner)     //
    ////////////////////////////////////////////

    /// @notice Set the per-token, per-second reward rate (scaled by RATE_PRECISION).
    function setRewardRate(uint256 newRate) external onlyOwner {
        uint256 oldRate = rewardRatePerTokenPerSecond;
        rewardRatePerTokenPerSecond = newRate;
        emit RewardRateChanged(oldRate, newRate);
    }

    /// @notice Fund the reward reserve. Caller (the owner) must approve this contract first.
    function fundRewards(uint256 amount) external onlyOwner {
        if (amount == 0) revert SimpleStakingPool__NoZeroAmount();
        REWARD_TOKEN.safeTransferFrom(msg.sender, address(this), amount);
        emit RewardsFunded(msg.sender, amount);
    }

    /// @notice Pause or unpause new staking.
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit PausedSet(_paused);
    }

    /// @notice Rescue stray tokens. Cannot dip into staked principal of `STAKING_TOKEN`.
    function sweep(IERC20 token, address to, uint256 amount) external onlyOwner {
        if (amount == 0) revert SimpleStakingPool__NoZeroAmount();
        if (token == STAKING_TOKEN && token.balanceOf(address(this)) - amount < totalStaked) {
            revert SimpleStakingPool__CannotSweepStakingPrincipal();
        }
        token.safeTransfer(to, amount);
        emit Swept(address(token), to, amount);
    }

    ////////////////////////////////////////////
    //            Internal functions          //
    ////////////////////////////////////////////

    /// @dev Move `account`'s pending rewards into storage and reset its accrual clock.
    function _accrue(address account) internal {
        rewards[account] += _pending(account);
        lastUpdate[account] = block.timestamp;
    }

    /// @dev Rewards accrued since `account`'s last update, not yet moved into storage.
    function _pending(address account) internal view returns (uint256) {
        uint256 last = lastUpdate[account];
        if (last == 0 || stakedBalance[account] == 0) {
            return 0;
        }
        uint256 elapsed = block.timestamp - last;
        return (stakedBalance[account] * rewardRatePerTokenPerSecond * elapsed) / RATE_PRECISION;
    }
}
