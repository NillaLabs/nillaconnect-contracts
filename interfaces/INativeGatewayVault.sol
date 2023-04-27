// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

interface INativeGatewayVault {
    function deposit(address lendingPool) external payable;

    function redeem(address lendingPool, uint256 shares, uint256 maxLoss) external;
}
