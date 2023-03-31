// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

interface INativeGatewayVault {
    function deposit(address lendingPool) external payable;

    function redeem(address lendingPool, uint256 shares, uint256 maxLoss) external;
}
