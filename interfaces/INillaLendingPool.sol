// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface INillaLendingPool is IERC20 {
    function decimals() external view returns (uint8);
    function baseToken() external view returns (IERC20);

    function deposit(
        uint256 amount,
        address receiver
    ) external returns (uint256);

    // deposit in Lido
    // No need for the `amount` to be specified
    function deposit(
        address receiver
    ) external payable returns (uint256);

    function redeem(
        uint256 shares,
        address receiver
    ) external returns (uint256);

    // redeem in Yearn's vault or Lido's Staking Pool
    function redeem(
        uint256 shares,
        address receiver,
        uint256 maxLoss // NOTE: Could be `minAmount` when calling in Lido's pool
    ) external returns (uint256);

    function withdrawReserve(
        address token,
        uint256 amount
    ) external;

    // re-invest in AaveV3
    function reinvest(
        uint16 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external;
}
