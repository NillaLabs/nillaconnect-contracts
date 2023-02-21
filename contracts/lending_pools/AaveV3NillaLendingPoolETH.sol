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
        address _lendingPool,
        address _aToken,
        address _gateway,
        address _weth,
        address _rewardsController,
        address _swapRouter,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        uint16 _harvestFeeBPS,
        address _executor,
        address _bridge
    ) external {
        _initialize(_lendingPool, _aToken, _gateway, _weth, _rewardsController, _swapRouter, _name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _harvestFeeBPS, _executor, _bridge);
    }
    
    function deposit(address _receiver) external payable nonReentrant {
        // gas saving
        IWNative _WETH = WETH;
        IATokenV3 _aToken = aToken;
        // supply to Aave V3, using share instead.
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        gateway.depositETH{value: msg.value}(address(lendingPool), address(this), 0);
        uint256 receivedAToken = _aToken.scaledBalanceOf(address(this)) - aTokenShareBefore;
        // collect protocol's fee.
        uint256 depositFee = receivedAToken.mulDiv(depositFeeBPS, BPS);
        reserves[address(_aToken)] += depositFee;
        totalAssets += (receivedAToken - depositFee);
        _mint(_receiver, receivedAToken - depositFee);
        emit Deposit(msg.sender, _receiver, _amount);
    }

    function redeem(uint256 _shares, address _receiver) external nonReentrant {
        // gas saving
        address _baseToken = address(baseToken);
        IATokenV3 _aToken = aToken;
        // set msgSender for cross chain tx.
        address msgSender = _msgSender(_receiver);
        // burn user's shares
        _burn(msgSender, _shares);
        // collect protocol's fee.
        uint256 withdrawFee = _shares.mulDiv(withdrawFeeBPS, BPS);
        uint256 shareAfterFee = _shares - withdrawFee;
        uint256 nativeTokenBefore = address(this).balance;
        // withdraw user's fund.
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        gateway.withdrawETH(address(lendingPool), amount, onBehalfOf);
        uint256 burnedATokenShare = aTokenShareBefore - _aToken.scaledBalanceOf(address(this));
        uint256 receivedNativeToken = address(this).balance - nativeTokenBefore;
        // dust after burn rounding.
        uint256 dust = shareAfterFee - burnedATokenShare;
        reserves[address(aToken)] += (withdrawFee + dust);
        totalAssets -= receivedNativeToken;
        // bridge token back if cross chain tx.
        if (msg.sender == executor) {
            _bridgeTokenBack(_receiver, receivedNativeToken);
            emit Withdraw(msg.sender, bridge, receivedNativeToken);
        }
        // else transfer fund to user.
        else {
            (bool success, ) = payable(_receiver).call{value: receivedNativeToken}("");
            require(success, 'Failed to transfer ETH');
            emit Withdraw(msg.sender, _receiver, receivedNativeToken);
        }
    }

    // Only available in Avalanche chain.
    function reinvest() external {
        require(msg.sender == worker, "only worker is allowed");
        // gas saving
        IATokenV3 _aToken = aToken;
        IERC20 _WAVAX = IERC20(WAVAX);
        uint256 protocolReserves = reserves[address(_aToken)];
        // withdraw rewards from pool
        uint256 WAVAXBefore = _WAVAX.balanceOf(address(this));
        address[] memory assets = new address[](1);
        assets[0] = address(_aToken);
        rewardsController.claimAllRewardsToSelf(assets);
        uint256 receivedWAVAX = _WAVAX.balanceOf(address(this)) - WAVAXBefore;
        // Calculate worker's fee before swapping
        WETH.withdraw(receivedWAVAX);
        uint256 workerFee = receivedWAVAX * harvestFeeBPS / BPS;
        (bool _success, ) = payable(worker).call{value: workerFee}("");
        require(_success, "Failed to send Ethers to worker");
        uint256 receivedNative = address(this).balance - workerFee;
        // re-supply into pool.
        {
            uint256 aTokenBefore = _aToken.scaledBalanceOf(address(this));
            gateway.depositETH{value: receivedNative}(address(lendingPool), address(this), 0);
            uint256 receivedAToken = _aToken.scaledBalanceOf(address(this)) - aTokenBefore;
            // calculate protocol reward.
            uint256 protocolReward = protocolReserves.mulDiv(receivedAToken, (totalAssets + protocolReserves));
            reserves[address(_aToken)] += protocolReward;
        }
        emit Reinvest(address(lendingPool), receivedNative);
    }

    receive() external payable {
        require(msg.sender == address(WETH), 'Receive not allowed');
    }

    fallback() external payable {
        revert('Fallback not allowed');
    }
}
