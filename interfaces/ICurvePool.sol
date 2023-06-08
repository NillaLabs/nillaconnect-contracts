// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

interface ICurvePool {
    function exchange(
        int128 i,
        int128 j,
        uint256 amount,
        uint256 minAmount
    ) external payable returns (uint256);
}
