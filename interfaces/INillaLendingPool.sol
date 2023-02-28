// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface INillaLendingPool is IERC20 {
    function decimals() external view returns (uint8);

    function baseToken() external view returns (address);

    function deposit(
        uint256 amount,
        address receiver
    ) external returns (uint256);

    function redeem(
        uint256 amount,
        address receiver
    ) external returns (uint256);

    function redeemWithMaxLoss(
        uint256 amount,
        address receiver,
        uint256 maxLoss
    ) external returns (uint256);
}
