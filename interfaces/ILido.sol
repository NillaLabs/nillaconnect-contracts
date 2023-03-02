// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface ILido is IERC20 {
    /**
    *  @notice Adds eth to the pool
    *  @return StETH Amount of StETH generated
    */
    function submit(address _referral) external payable returns (uint256 StETH);

    function totalSupply() external view returns (uint256);

    function getTotalShares() external view returns (uint256);
}