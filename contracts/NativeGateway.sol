pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/INillaLendingPool.sol";
import "../interfaces/IWNative.sol";

contract NativeGateway {
    using SafeERC20 for IERC20;
    IWNative wNative;

    constructor(IWNative _wNative) {
        wNative = wNative;
    }

    function deposit(INillaLendingPool _lendingPool) external payable {
        wNative.deposit{ value: msg.value }();
        _ensureApprove(address(_lendingPool));
        _lendingPool.deposit(msg.value, msg.sender);
    }

    function redeem(INillaLendingPool _lendingPool, uint256 _shares) external {
        IERC20(address(_lendingPool)).safeTransferFrom(msg.sender, address(this), _shares);
        uint256 wNativeBalanceBefore = wNative.balanceOf(address(this));
        _lendingPool.redeem(_shares, address(this));
        uint256 receivedAmount = wNative.balanceOf(address(this)) - wNativeBalanceBefore;
        wNative.withdraw(receivedAmount);
        (bool success, ) = msg.sender.call{ value: receivedAmount }(new bytes(0));
        require(success, "!withdraw");
    }

    function _ensureApprove(address _spender) internal {
        if (wNative.allowance(address(this), _spender) == 0) {
            IERC20(address(wNative)).safeApprove(_spender, type(uint256).max);
        }
    }

    receive() external payable {
        require(msg.sender == address(wNative), "!native");
    }
}
