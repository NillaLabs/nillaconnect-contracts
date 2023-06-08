// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface IComptroller {
    function claimComp(address holder) external;
}
