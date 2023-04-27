// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface IstETH is IERC20 {
    /**
     *  @notice Adds eth to the pool
     *  @return StETH Amount of StETH generated
     */
    function submit(address referral) external payable returns (uint256 StETH);

    function getPooledEthByShares(uint256 shares) external view returns (uint256);

    function getSharesByPooledEth(uint256 _ethAmount) external view returns (uint256);

    function sharesOf(address account) external view returns (uint256);

    function decimals() external view returns (uint8);
}
