// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface IAToken is IERC20 {
    function decimals() external view returns (uint8);

    function scaledBalanceOf(address user) external view returns (uint256);

    function underlyingAssetAddress() external view returns (address);
}
