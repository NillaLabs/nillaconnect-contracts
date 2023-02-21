// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IWNative.sol";
import "../../interfaces/IATokenV3.sol";
import "../../interfaces/IAaveV3LendingPool.sol";
import "../../interfaces/IWrappedTokenGatewayV3.sol";
import "../../interfaces/IRewardsController.sol";
import "../../interfaces/IJoeRouter.sol";

contract AaveV3NillaBase is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IWNative public WETH;

    // NOTE: add later for swapping WAVAX
    IJoeRouter swapRouter;

    IATokenV3 public aToken;
    IERC20 public baseToken;
    uint8 internal _decimals;
    IAaveV3LendingPool public lendingPool;
    IWrappedTokenGatewayV3 public gateway;
    IRewardsController public rewardsController;

    uint16 public harvestFeeBPS;
    uint256 internal constant RAY = 1e27;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);
    event Reinvest(address indexed lendingPool, uint256 amount);

    uint256 public totalAssets;

    function _initialize(
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
    ) internal {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _executor, _bridge);
        lendingPool = IAaveV3LendingPool(_lendingPool);
        aToken = IATokenV3(_aToken);
        gateway = IWrappedTokenGatewayV3(_gateway);
        rewardsController = IRewardsController(_rewardsController);
        swapRouter = IJoeRouter(_swapRouter);
        WETH = IWNative(_weth);
        IERC20(_weth).safeApprove(_swapRouter, type(uint256).max);
        IERC20 _baseToken = IERC20(IATokenV3(_aToken).UNDERLYING_ASSET_ADDRESS());
        baseToken = _baseToken;
        _baseToken.safeApprove(_lendingPool, type(uint256).max);
        _decimals = IATokenV3(_aToken).decimals();
        harvestFeeBPS = _harvestFeeBPS;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
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

    function _reinvest(IATokenV3 _aToken, IWNative _WETH, uint256 _workerFee, uint256 _amount) internal {
        //gas saving
        uint256 protocolReserves = reserves[address(_aToken)];
        
        _WETH.withdraw(_workerFee);
        (bool _success, ) = payable(worker).call{value: _workerFee}("");
        require(_success, "Failed to send Ethers to worker");
        // re-supply into pool.
        {
            uint256 aTokenBefore = _aToken.scaledBalanceOf(address(this));
            lendingPool.supply(address(baseToken), _amount, address(this), 0);
            uint256 receivedAToken = _aToken.scaledBalanceOf(address(this)) - aTokenBefore;
            // calculate protocol reward.
            uint256 protocolReward = protocolReserves.mulDiv(receivedAToken, (totalAssets + protocolReserves));
            reserves[address(_aToken)] += protocolReward;
        }
        emit Reinvest(address(lendingPool), _amount);
    }
}
