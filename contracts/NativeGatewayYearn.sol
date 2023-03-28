// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/INillaVault.sol";
import "../interfaces/IWNative.sol";

contract NativeGatewayYearn {
    using SafeERC20 for IERC20;
    IWNative immutable wNative;

    constructor(address _wNative) {
        wNative = IWNative(_wNative);
    }

    function deposit(address _lendingPool) external payable {
        wNative.deposit{ value: msg.value }();
        _ensureApprove(_lendingPool);
        INillaVault(_lendingPool).deposit(msg.value, msg.sender);
    }

    function redeem(address _lendingPool, uint256 _shares, uint256 _maxLoss) external {
        IWNative _wNative = wNative;
        IERC20(_lendingPool).safeTransferFrom(msg.sender, address(this), _shares);
        uint256 wNativeBalanceBefore = _wNative.balanceOf(address(this));
        INillaVault(_lendingPool).redeem(_shares, address(this), _maxLoss);
        uint256 receivedAmount = _wNative.balanceOf(address(this)) - wNativeBalanceBefore;
        _wNative.withdraw(receivedAmount);
        (bool success, ) = msg.sender.call{ value: receivedAmount }(new bytes(0));
        require(success, "!withdraw");
    }

    function _ensureApprove(address _spender) internal {
        IWNative _wNative = wNative;
        if (_wNative.allowance(address(this), _spender) == 0) {
            IERC20(address(_wNative)).safeApprove(_spender, type(uint256).max);
        }
    }

    receive() external payable {
        require(msg.sender == address(wNative), "!native");
    }
}
