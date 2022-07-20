//SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Chef.sol";

contract StakingChef is Chef {
    mapping(address => Staker) public staker;

    constructor(address metricTokenAddress) {
        setMetricToken(metricTokenAddress);
        setMetricPerBlock(4);
        toggleRewards(false);
    }

    // --------------------------------------------------------------------- staking functions
    function stakeMetric(uint256 metricAmount) external {
        // Checks
        if (metricAmount <= 0) revert CannotStakeNoMetric();

        // Effects
        Staker storage stake = staker[_msgSender()];

        if (areRewardsActive() && getTotalAllocationShares() > 0) {
            updateAccumulatedStakingRewards();
        }
        staker[_msgSender()] = Staker({
            shares: stake.shares + metricAmount,
            rewardDebt: stake.rewardDebt + (((metricAmount) * _getLifetimeShareValue()) / ACC_METRIC_PRECISION),
            claimable: stake.claimable
        });

        _addTotalAllocShares(metricAmount);

        // Interactions
        SafeERC20.safeTransferFrom(IERC20(getMetricToken()), _msgSender(), address(this), metricAmount);
    }

    function updateAccumulatedStakingRewards() public {
        if (!areRewardsActive()) revert RewardsAreNotActive();
        if (block.number <= getLastRewardBlock()) {
            return;
        }

        setLifetimeShareValue();
    }

    // --------------------------------------------------------------------- Manage rewards and Principal

    function claim() public {
        // Checks
        if (viewPendingHarvest() == 0) revert NoClaimableRewardsToWithdraw();

        // Effects
        Staker storage stake = staker[_msgSender()];
        _harvest();

        uint256 toClaim = stake.claimable;
        stake.claimable = 0;

        // Interactions
        SafeERC20.safeTransfer(IERC20(getMetricToken()), _msgSender(), toClaim);

        emit Claim(_msgSender(), stake, toClaim);
    }

    function unStakeMetric() public {
        // Checks
        Staker storage stake = staker[_msgSender()];
        if (stake.shares == 0) revert NoMetricToWithdraw();

        if (areRewardsActive()) {
            updateAccumulatedStakingRewards();
        }

        // Effects
        _harvest();
        uint256 toClaim = staker[_msgSender()].claimable;
        uint256 toWithdraw = stake.shares;
        _removeAllocShares(staker[_msgSender()].shares);
        stake.shares = 0;

        // Interactions

        if (toWithdraw + toClaim > 0) {
            SafeERC20.safeTransfer(IERC20(getMetricToken()), _msgSender(), toWithdraw + toClaim);
            emit UnStake(_msgSender(), stake, toWithdraw);
        }
        if (toClaim > 0) {
            emit Claim(_msgSender(), stake, toWithdraw);
        }
    }

    function _harvest() internal {
        Staker storage stake = staker[_msgSender()];
        updateAccumulatedStakingRewards();

        uint256 claimable = (stake.shares * _getLifetimeShareValue()) / ACC_METRIC_PRECISION - stake.rewardDebt;

        stake.rewardDebt = stake.rewardDebt + claimable;
        stake.claimable = stake.claimable + claimable;
        emit Claim(_msgSender(), stake, claimable);
    }

    //------------------------------------------------------Getters

    function getStake() public view returns (Staker memory) {
        Staker storage stake = staker[_msgSender()];
        return stake;
    }

    //------------------------------------------------------Distribution

    function viewPendingHarvest() public view returns (uint256) {
        Staker storage stake = staker[_msgSender()];

        return (stake.shares * _getLifetimeShareValue()) / ACC_METRIC_PRECISION - stake.rewardDebt;
    }

    function viewPendingClaims() public view returns (uint256) {
        Staker storage stake = staker[_msgSender()];

        return stake.claimable;
    }

    // --------------------------------------------------------------------- Structs
    struct Staker {
        uint256 shares;
        uint256 rewardDebt;
        uint256 claimable;
    }

    // --------------------------------------------------------------------- Errors
    error RewardsAreNotActive();
    error NoMetricToWithdraw();
    error NoClaimableRewardsToWithdraw();
    error CannotStakeNoMetric();

    // --------------------------------------------------------------------- Events
    event Claim(address harvester, StakingChef.Staker, uint256 amount);
    event UnStake(address withdrawer, StakingChef.Staker, uint256 amount);
}
