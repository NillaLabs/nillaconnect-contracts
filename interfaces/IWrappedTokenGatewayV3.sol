// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IWrappedTokenGatewayV3 {
  function depositETH(
    address pool,
    address onBehalfOf,
    uint16 referralCode
  ) external payable;

  function withdrawETH(
  address pool,
  uint256 amount,
  address onBehalfOf
  ) external;

  function getWETHAddress() external view returns(address);
}
