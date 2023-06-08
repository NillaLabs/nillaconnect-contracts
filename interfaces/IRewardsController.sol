// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface IRewardsController {
    function handleAction(address user, uint256 totalSupply, uint256 userBalance) external;

    function claimRewards(
        address[] calldata assets,
        uint256 amount,
        address to,
        address reward
    ) external returns (uint256);

    function getUserRewards(
        address[] calldata assets,
        address user,
        address reward
    ) external view returns (uint256);
}
