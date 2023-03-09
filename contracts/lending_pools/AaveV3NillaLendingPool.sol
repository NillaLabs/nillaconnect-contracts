// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IWNative.sol";
import "../../interfaces/IATokenV3.sol";
import "../../interfaces/IAaveV3LendingPool.sol";
import "../../interfaces/IRewardsController.sol";
import "../../interfaces/IUniswapRouterV2.sol";

contract AaveV3NillaLendingPool is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IWNative public WETH;

    IUniswapRouterV2 swapRouter;

    IATokenV3 public aToken;
    IERC20 public baseToken;
    uint8 internal _decimals;
    IAaveV3LendingPool public lendingPool;
    IRewardsController public rewardsController;

    uint16 public harvestFeeBPS;
    uint256 internal constant RAY = 1e27;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);
    event Reinvest(address indexed lendingPool, uint256 amount);

    struct ProtocolFee {
        uint16 depositFeeBPS;
        uint16 withdrawFeeBPS;
        uint16 harvestFeeBPS;
    }

    function initialize(
        address _aToken,
        address _rewardsController,
        address _weth,
        address _swapRouter,
        string calldata _name,
        string calldata _symbol,
        ProtocolFee calldata _protocolFee
    ) external {
        __initialize__(_name, _symbol, _protocolFee.depositFeeBPS, _protocolFee.withdrawFeeBPS);
        WETH = IWNative(_weth);
        harvestFeeBPS = _protocolFee.harvestFeeBPS;
        swapRouter = IUniswapRouterV2(_swapRouter);

        rewardsController = IRewardsController(_rewardsController);
        aToken = IATokenV3(_aToken);
        lendingPool = IAaveV3LendingPool(IATokenV3(_aToken).POOL());
        IERC20 _baseToken = IERC20(IATokenV3(_aToken).UNDERLYING_ASSET_ADDRESS());
        baseToken = _baseToken;
        _baseToken.safeApprove(IATokenV3(_aToken).POOL(), type(uint256).max);
        IERC20(_weth).safeApprove(_swapRouter, type(uint256).max);

        _decimals = IATokenV3(_aToken).decimals();  
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
    
    function deposit(uint256 _amount, address _receiver) external nonReentrant returns (uint256) {
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
        _mint(_receiver, receivedAToken - depositFee);
        emit Deposit(msg.sender, _receiver, _amount);
        return (receivedAToken - depositFee);
    }

    function redeem(uint256 _shares, address _receiver) external nonReentrant returns (uint256) {
        // gas saving
        IAaveV3LendingPool _lendingPool = lendingPool;
        address _baseToken = address(baseToken);
        IATokenV3 _aToken = aToken;
        // burn user's shares
        _burn(_receiver, _shares);
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
            _receiver
        );
        {
            uint256 burnedATokenShare = aTokenShareBefore - _aToken.scaledBalanceOf(address(this));
            // dust after burn rounding.
            uint256 dust = shareAfterFee - burnedATokenShare;
            reserves[address(aToken)] += (withdrawFee + dust);
        }
        emit Withdraw(msg.sender, _receiver, receivedBaseToken);
        return receivedBaseToken;
    }

    function withdrawReserve(address _token, uint256 _amount) external override {
        require(msg.sender == worker, "only worker");
        IATokenV3 _aToken = aToken; // gas saving
        if (_token != address(_aToken)) {
            reserves[_token] -= _amount;
            IERC20(_token).safeTransfer(msg.sender, _amount);
            emit WithdrawReserve(msg.sender, _token, _amount);
        } else {
            // using shares for aToken
            uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
            IERC20(_token).safeTransfer(msg.sender, _amount);
            uint256 transferedATokenShare = _aToken.scaledBalanceOf(address(this)) - aTokenShareBefore;
            reserves[_token] -= transferedATokenShare;
            emit WithdrawReserve(msg.sender, _token, transferedATokenShare);
        }
    }
    
    // Only available in Avalanche chain.
    function reinvest(uint16 _amountOutMin, address[] calldata _path, uint256 _deadline) external {
        require(msg.sender == worker, "only worker is allowed");
        require(_path[0] != address(aToken), "Asset to swap should not be aToken");
        // gas saving
        IATokenV3 _aToken = aToken;
        IWNative _WETH = IWNative(WETH);
        // claim rewards from rewardController
        uint256 receivedWETH = _claimeRewards(_aToken, _WETH);
        require(receivedWETH > 0, "No rewards to harvest");
        // Calculate worker's fee before swapping
        uint256 workerFee = receivedWETH * harvestFeeBPS / BPS;
        // swap WAVAX -> baseToken
        uint256 baseTokenBefore = baseToken.balanceOf(address(this));
        swapRouter.swapExactTokensForTokens(receivedWETH - workerFee, _amountOutMin, _path, address(this), _deadline);
        uint256 receivedBase = baseToken.balanceOf(address(this)) - baseTokenBefore;
        _reinvest(_aToken, _WETH, workerFee, receivedBase); // alredy sub workerFee when swap()
    }

    function _claimeRewards(IATokenV3 _aToken, IWNative _WETH) internal returns(uint256 receivedWAVAX) {
        uint256 WAVAXBefore = _WETH.balanceOf(address(this));
        address[] memory assets = new address[](1);
        assets[0] = address(_aToken);
        // amount = MAX_UINT to claim all
        rewardsController.claimRewards(assets, type(uint256).max, address(this), address(_WETH));
        receivedWAVAX = _WETH.balanceOf(address(this)) - WAVAXBefore;
    }

    function _reinvest(IATokenV3 _aToken, IWNative _WETH, uint256 _workerFee, uint256 _amount) internal {
        //gas saving
        uint256 protocolReserves = reserves[address(_aToken)];
        
        _WETH.withdraw(_workerFee);
        (bool _success, ) = payable(worker).call{value: _workerFee}("");
        require(_success, "Failed to send Ethers to worker");
        // re-supply into pool
        uint256 aTokenBefore = _aToken.scaledBalanceOf(address(this));
        lendingPool.supply(address(baseToken), _amount, address(this), 0);
        uint256 receivedAToken = _aToken.scaledBalanceOf(address(this)) - aTokenBefore;
        // calculate protocol reward
        uint256 protocolReward = protocolReserves.mulDiv(receivedAToken, (_aToken.scaledBalanceOf(address(this)) + protocolReserves));
        reserves[address(_aToken)] += protocolReward;
        emit Reinvest(address(lendingPool), _amount);
    }
}
