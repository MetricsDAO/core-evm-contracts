// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IQuestionAPI {
    function getMetricToken() external view returns (address);

    function getQuestionStateController() external view returns (address);

    function getClaimController() external view returns (address);

    function getCostController() external view returns (address);

    function getBountyQuestion() external view returns (address);
}
