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

contract AaveV3NillaBase is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IWNative public WETH;

    // NOTE: add later for swapping WAVAX
    // ITraderJoeXYZ swapper;

    IATokenV3 public aToken;
    IERC20 public baseToken;
    uint8 internal _decimals;
    IAaveV3LendingPool public lendingPool;
    IWrappedTokenGatewayV3 public gateway;

    uint16 public harvestFeeBPS;
    uint256 internal constant RAY = 1e27;
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);
    event Reinvest(address indexed lendingPool, uint256 amount);

    function _initialize(
        address _lendingPool,
        address _aToken,
        address _gateway,
        address _weth,
        // address swapper,  NOTE: add later for swapping WAVAX
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
        WETH = IWNative(_weth);
        IERC20 _baseToken = IERC20(IATokenV3(_aToken).UNDERLYING_ASSET_ADDRESS());
        baseToken = _baseToken;
        _baseToken.safeApprove(_lendingPool, type(uint256).max);
        _decimals = IATokenV3(_aToken).decimals();
        // NOTE: add later for swapping WAVAX
        // swapper = ITraderJoeXYZ(router);
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

    // Only available in Avalanche chain.
    function reinvest(uint256 _slippage, address[] memory _path) external {
        require(msg.sender == worker, "only worker is allowed");
        // gas saving:-

        // 1. withdraw rewards from pool
        uint256 WAVAXBefore = IERC20(WAVAX).balanceOf(address(this));
        // NOTE: TO DO- Perform withdraw WAVAX rewards
        uint256 receivedWAVAX = IERC20(WAVAX).balanceOf(address(this)) - WAVAXBefore;

        // 1.2 Calculate worker's fee before swapping
        {
            uint256 workerFee = receivedWAVAX * harvestFeeBPS / BPS;
            WETH.withdraw(workerFee);
            (bool _success, ) = payable(worker).call{value: workerFee}("");
            require(_success, "Failed to send Ethers to worker");
        }

        // 2. swap WAVAX -> baseToken
        // uint256 receivedBase = swapper.swapExactTokensForTokens(receivedWAVAX, amountOutWithSlippage, pairBinSteps, path, receiverAddress, block.timestamp);

        // 3. re-supply into LP.
        uint256 aTokenBefore = aToken.scaledBalanceOf(address(this));
        // lendingPool.supply(address(baseToken), receivedBase, address(this), 0);
        uint256 receivedAToken = aToken.scaledBalanceOf(address(this)) - aTokenBefore;

        // 4. calculate protocol reward.
        // reserves[address(_pool)] += protocolReward;
         
        // emit Reinvest(address(lendingPool), receivedBase);
    }
}
