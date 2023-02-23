// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../lending_pools/AaveV3NillaBase.sol";

import "../../interfaces/IWNative.sol";
import "../../interfaces/IATokenV3.sol";

contract AaveV3NillaLendingPoolETH is AaveV3NillaBase {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    function initialize(
        AaveObj memory _aave,
        address _swapRouter,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        uint16 _harvestFeeBPS,
        address _executor,
        address _bridge
    ) external {
        _initialize(_aave, _swapRouter, _name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _harvestFeeBPS, _executor, _bridge);
    }
    
    function deposit(address _receiver) external payable nonReentrant {
        require(msg.value > 0, "Value is 0");
        // gas saving
        IATokenV3 _aToken = aToken;
        // supply to Aave V3, using share instead
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        gateway.depositETH{value: msg.value}(address(lendingPool), address(this), 0);
        uint256 receivedAToken = _aToken.scaledBalanceOf(address(this)) - aTokenShareBefore;
        // collect protocol's fee
        uint256 depositFee = receivedAToken.mulDiv(depositFeeBPS, BPS);
        reserves[address(_aToken)] += depositFee;
        _mint(_receiver, receivedAToken - depositFee);
        emit Deposit(msg.sender, _receiver, msg.value);
    }

    function redeem(uint256 _shares, address _receiver) external nonReentrant {
        require(_receiver != address(0), "Redeem to address 0");
        // gas saving
        address _baseToken = address(baseToken);
        IATokenV3 _aToken = aToken;
        IAaveV3LendingPool _lendingPool = lendingPool;
        {
            // set msgSender for cross chain tx
            address msgSender = _msgSender(_receiver);
            // burn user's shares
            _burn(msgSender, _shares);
        }
        // collect protocol's fee
        uint256 withdrawFee = _shares.mulDiv(withdrawFeeBPS, BPS);
        uint256 shareAfterFee = _shares - withdrawFee;
        uint256 nativeTokenBefore = address(this).balance;
        // withdraw user's fund
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        uint256 amount = shareAfterFee.mulDiv(_lendingPool.getReserveNormalizedIncome(_baseToken),RAY,Math.Rounding.Down);
        gateway.withdrawETH(
            address(_lendingPool),
            shareAfterFee.mulDiv(
                _lendingPool.getReserveNormalizedIncome(_baseToken),
                RAY,
                Math.Rounding.Down
            ), // aToken amount rounding down
            address(this)
        );
        uint256 receivedNativeToken = address(this).balance - nativeTokenBefore;
        {
            uint256 burnedATokenShare = aTokenShareBefore - _aToken.scaledBalanceOf(address(this));
            // dust after burn rounding
            uint256 dust = shareAfterFee - burnedATokenShare;
            reserves[address(aToken)] += (withdrawFee + dust);
        }
        // bridge token back if cross chain tx
        if (msg.sender == executor) {
            _bridgeTokenBack(_receiver, receivedNativeToken);
            emit Withdraw(msg.sender, bridge, receivedNativeToken);
        }
        // else transfer fund to user
        else {
            (bool success, ) = payable(_receiver).call{value: receivedNativeToken}("");
            require(success, 'Failed to transfer ETH');
            emit Withdraw(msg.sender, _receiver, receivedNativeToken);
        }
    }

    // Only available in Avalanche chain
    function reinvest() external {
        require(msg.sender == worker, "only worker is allowed");
        // gas saving
        IATokenV3 _aToken = aToken;
        IWNative _WETH = IWNative(WETH);
        // claim rewards from rewardController
        uint256 receivedWETH = _claimeRewards(_aToken, _WETH);
        require(receivedWETH > 0, "No rewards to harvest");
        // Calculate worker's fee before swapping
        uint256 workerFee = receivedWETH * harvestFeeBPS / BPS;
        _reinvest(_aToken, _WETH, workerFee, receivedWETH - workerFee);
    }
}
