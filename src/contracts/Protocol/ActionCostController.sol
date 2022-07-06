//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IActionCostController.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../MetricToken.sol";

// TODO we probably want a CostController or something to ensure user locks enough metric
// ^^ price per action, each one is editable
// Basically the QuestionAPI will request the price from this controler and ensure
contract ActionCostController is Ownable, IActionCostController {
    MetricToken private metric;

    uint256 public createCost = 1 * 10**18;

    mapping(address => uint256) lockedPerUser;

    constructor(address _metric) {
        metric = MetricToken(_metric);
    }

    function payForCreateQuestion() public onlyOwner {
        // TODO where do we want to store locked metric?
        lockedPerUser[_msgSender()] = createCost;
        SafeERC20.safeTransferFrom(metric, msg.sender, address(this), createCost);
    }
}
