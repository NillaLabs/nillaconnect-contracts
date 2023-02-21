// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../lending_pools/AaveV3NillaBase.sol";

import "../../interfaces/IATokenV3.sol";
import "../../interfaces/IAaveV3LendingPool.sol";

import 'forge-std/console.sol';

contract AaveV3NillaLendingPool is AaveV3NillaBase {
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
    
    function deposit(uint256 _amount, address _receiver) external nonReentrant {
        // gas saving
        IERC20 _baseToken = baseToken;
        IATokenV3 _aToken = aToken;
        // transfer fund.
        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        _baseToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
        // supply to Aave V3, using share instead.
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        lendingPool.supply(address(_baseToken), receivedBaseToken, address(this), 0);
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
        IAaveV3LendingPool _lendingPool = lendingPool;
        address _baseToken = address(baseToken);
        IATokenV3 _aToken = aToken;
        // set msgSender for cross chain tx.
        address msgSender = _msgSender(_receiver);
        // burn user's shares
        _burn(msgSender, _shares);
        // collect protocol's fee.
        uint256 withdrawFee = _shares.mulDiv(withdrawFeeBPS, BPS);
        uint256 shareAfterFee = _shares - withdrawFee;
        // withdraw user's fund.
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        uint256 receivedBaseToken = _lendingPool.withdraw(
            _baseToken,
            shareAfterFee.mulDiv(
                _lendingPool.getReserveNormalizedIncome(_baseToken),
                RAY,
                Math.Rounding.Down
            ), // aToken amount rounding down
            msg.sender == executor ? address(this) : _receiver
        );
        uint256 burnedATokenShare = aTokenShareBefore - _aToken.scaledBalanceOf(address(this));
        // dust after burn rounding.
        uint256 dust = shareAfterFee - burnedATokenShare;
        reserves[address(aToken)] += (withdrawFee + dust);
        totalAssets -= receivedBaseToken;
        // bridge token back if cross chain tx.
        if (msg.sender == executor) {
            _bridgeTokenBack(_receiver, receivedBaseToken);
            emit Withdraw(msg.sender, bridge, receivedBaseToken);
        }
        // else transfer fund to user.
        else emit Withdraw(msg.sender, _receiver, receivedBaseToken);
    }

    // Only available in Avalanche chain.
    function reinvest(uint16 _amountOutMin, address[] calldata _path, uint256 _deadline) external {
        require(msg.sender == worker, "only worker is allowed");
        // gas saving
        IATokenV3 _aToken = aToken;
        IWNative _WETH = IWNative(WETH);
        uint256 protocolReserves = reserves[address(_aToken)];
        // claim rewards from rewardController
        uint256 WAVAXBefore = _WETH.balanceOf(address(this));
        console.log("WAVAX Before:", WAVAXBefore);
        {
            address[] memory assets = new address[](1);
            assets[0] = address(_aToken);
            rewardsController.claimRewards(assets, type(uint256).max, address(this), address(_WETH)); // amount = MAX_UINT to claim all
            console.log("WAVAX After:", _WETH.balanceOf(address(this)));
        }
        uint256 receivedWAVAX = _WETH.balanceOf(address(this)) - WAVAXBefore;
        require(receivedWAVAX > 0, "No rewards to harvest");
        // Calculate worker's fee before swapping
        uint256 workerFee = receivedWAVAX * harvestFeeBPS / BPS;
        _WETH.withdraw(workerFee);
        (bool _success, ) = payable(worker).call{value: workerFee}("");
        require(_success, "Failed to send Ethers to worker");
        // swap WAVAX -> baseToken
        uint256 baseTokenBefore = baseToken.balanceOf(address(this));
        swapRouter.swapExactTokensForTokens(receivedWAVAX - workerFee, _amountOutMin, _path, address(this), _deadline);
        uint256 receivedBase = baseToken.balanceOf(address(this)) - baseTokenBefore;
        emit Swap(receivedWAVAX - workerFee, _amountOutMin, _path, _deadline);
        // re-supply into pool.
        {
            uint256 aTokenBefore = _aToken.scaledBalanceOf(address(this));
            lendingPool.supply(address(baseToken), receivedBase, address(this), 0);
            uint256 receivedAToken = _aToken.scaledBalanceOf(address(this)) - aTokenBefore;
            // calculate protocol reward.
            uint256 protocolReward = protocolReserves.mulDiv(receivedAToken, (totalAssets + protocolReserves));
            reserves[address(_aToken)] += protocolReward;
        }
        emit Reinvest(address(lendingPool), receivedBase);
    }
}
