// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IYearnPartnerTracker {
    function refferredBalance(
        address partner,
        address depositer,
        address vault
    ) external view returns(uint256 refferredBalance);

    function deposit(
        address vault,
        address partnerId,
        uint256 amount
    ) external returns(uint256 vaultToken);
}