// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface ILido {
    /**
    *  @notice Adds eth to the pool
    *  @return StETH Amount of StETH generated
    */
    function submit(address _referral) external payable returns (uint256 StETH);

    function totalSupply() external view returns (uint256);
    
    function getTotalShares() external view returns (uint256);
}