// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface INillaLiquidityStaking is IERC20 {
    function decimals() external view returns (uint8);

    function baseToken() external view returns (IERC20);

    function deposit(address receiver) external payable returns (uint256);

    function redeem(uint256 shares, address receiver, uint256 minAmount) external returns (uint256);
}
