// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../interfaces/IWrappedTokenGatewayV3.sol";

contract TransparentUpgradeableProxyImplAave is TransparentUpgradeableProxy {

    address immutable public gateway;

    constructor(
        address _logic,
        address _admin,
        bytes memory _data,
        address _gateway
    ) payable TransparentUpgradeableProxy(_logic, _admin, _data) {
        gateway = _gateway;
    }

    receive() external payable override {
        require(msg.sender == gateway || msg.sender == IWrappedTokenGatewayV3(gateway).getWETHAddress(), 'Receive not allowed');
    }
}