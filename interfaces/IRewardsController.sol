// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.17;

interface IRewardsController {
    function handleAction(
        address user,
        uint256 totalSupply,
        uint256 userBalance
    ) external;

    function claimAllRewardsToSelf(address[] calldata assets)
    external
    returns (address[] memory rewardsList, uint256[] memory claimedAmounts);
}