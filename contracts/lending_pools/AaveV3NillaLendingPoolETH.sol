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

contract AaveV3NillaLendingPoolETH is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IWNative public WETH;

    // NOTE: add later for swapping WAVAX
    // ITraderJoeXYZ swapper;

    IATokenV3 public aToken;
    IERC20 public baseToken;
    uint8 private _decimals;
    address public pool;
    IWrappedTokenGatewayV3 public gateway;

    uint16 public harvestFeeBPS;
    uint256 private constant RAY = 1e27;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);
    event Reinvest(address indexed lendingPool, uint256 amount);

    function initialize(
        address _wrappedTokenGateway,
        address _lendingPool,
        address _aToken,
        address _weth,
        // address swapper,  NOTE: add later for swapping WAVAX
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        uint16 _harvestFeeBPS,
        address _executor,
        address _bridge
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _executor, _bridge);
        gateway = IWrappedTokenGatewayV3(_wrappedTokenGateway);
        aToken = IATokenV3(_aToken);
        WETH = IWNative(_weth);
        pool = _lendingPool;
        IERC20 _baseToken = IERC20(IATokenV3(_aToken).UNDERLYING_ASSET_ADDRESS());
        baseToken = _baseToken;
        _baseToken.safeApprove(IAaveV3LendingPool(_lendingPool), type(uint256).max);
        _decimals = IATokenV3(_aToken).decimals();
        // NOTE: add later for swapping WAVAX
        // swapper = ITraderJoeXYZ(router);
        harvestFeeBPS = _harvestFeeBPS;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function deposit(address _receiver) external payable nonReentrant {
        // gas saving
        IWNative _WETH = WETH;
        IATokenV3 _aToken = aToken;
        // supply to Aave V3, using share instead.
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        gateway.depositETH{value: msg.value}(pool, address(this), 0);
        uint256 receivedAToken = _aToken.scaledBalanceOf(address(this)) - aTokenShareBefore;
        // collect protocol's fee.
        uint256 depositFee = receivedAToken.mulDiv(depositFeeBPS, BPS);
        reserves[address(_aToken)] += depositFee;
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
        gateway.withdrawETH(pool, amount, onBehalfOf);
        uint256 burnedATokenShare = aTokenShareBefore - _aToken.scaledBalanceOf(address(this));

        uint256 receivedNativeToken = address(this).balance - nativeTokenBefore;

        // dust after burn rounding.
        uint256 dust = shareAfterFee - burnedATokenShare;
        reserves[address(aToken)] += (withdrawFee + dust);
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
    function reinvest(uint256 _slippage, bytes memory _path) external {
        require(msg.sender == worker, "only worker is allowed");
        // gas saving:-

        // 1. withdraw rewards from pool
        uint256 WAVAXBefore = IERC20(WAVAX).balanceOf(address(this));
        // NOTE: TO DO- Perform withdraw WAVAX rewards
        uint256 receivedWAVAX = IERC20(WAVAX).balanceOf(address(this)) - WAVAXBefore;

        // 1.5 Calculate worker's fee before swapping
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

    receive() external payable {
        require(msg.sender == address(WETH), 'Receive not allowed');
    }

    fallback() external payable {
        revert('Fallback not allowed');
    }
}
