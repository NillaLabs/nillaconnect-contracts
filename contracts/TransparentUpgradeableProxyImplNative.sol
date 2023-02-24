// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract TransparentUpgradeableProxyImplNative is TransparentUpgradeableProxy {

    address immutable public WETH;

    constructor(
        address _logic,
        address _admin,
        bytes memory _data,
        address _weth
    ) payable TransparentUpgradeableProxy(_logic, _admin, _data) {
        WETH = _weth;
    }

    receive() external payable override {
        require(msg.sender == address(WETH), 'Receive not allowed');
    }
}