//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MetricToken.sol";

contract Stake {
    using SafeMath for uint256;
    uint256 public _metricPerBlock;
    uint256 public constant ACC_METRIC_PRECISION = 1e12;

     MetricToken private _metric;

    function setMetricPerBlock(uint256 metricAmount) public {
        _metricPerBlock = metricAmount * 10**18;
    }

    mapping(address => bool) public addressExistence;
    modifier nonDuplicated(address _address) {
        require(addressExistence[_address] == false, "nonDuplicated: duplicated");
        addressExistence[_address] = true;
        _;
    }

    event Harvest(address harvester, uint256 agIndex, uint256 amount);
    event Withdraw(address withdrawer, uint256 agIndex, uint256 amount);

}

//claim(address)

//staker struct {
        // address stakerAddress;
        // uint256 metricAmount;
        // bool autodistribute;
        // uint256 rewardDebt; // keeps track of how much the user is owed or has been credited already
        // uint256 claimable;
        // uint256 startDate;
// }
//payable staking function
//withdrawl function

    // function viewPendingHarvest(uint256 agIndex) public view returns (uint256) {
    //     AllocationGroup storage group = _allocations[agIndex];

    //     return group.shares.mul(_lifetimeShareValue).div(ACC_METRIC_PRECISION).sub(group.rewardDebt);
    // }

    // function viewPendingClaims(uint256 agIndex) public view returns (uint256) {
    //     AllocationGroup storage group = _allocations[agIndex];

    //     return group.claimable;
    // }

    // REFACTOR POSSIBLY

    //     function claim(uint256 agIndex) public {
    //     AllocationGroup storage group = _allocations[agIndex];

    //     require(group.claimable != 0, "No claimable rewards to withdraw");
    //     // TODO do we want a backup in case a group looses access to their wallet
    //     require(group.groupAddress == _msgSender(), "Sender does not represent group");
    //     _metric.transfer(group.groupAddress, group.claimable);
    //     group.claimable = 0;

    //     emit Withdraw(msg.sender, agIndex, group.claimable);
    // }