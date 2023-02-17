// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IATokenV3.sol";
import "../../interfaces/IAaveV3LendingPool.sol";

contract AaveV3NillaLendingPool is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // NOTE: add later for swapping WAVAX
    // ITraderJoeXYZ swapper;

    IATokenV3 public aToken;
    IERC20 public baseToken;
    uint8 private _decimals;
    IAaveV3LendingPool public lendingPool;

    uint16 public harvestFeeBPS;
    uint256 private constant RAY = 1e27;
    address public constant WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);
    event Reinvest(address indexed lendingPool, uint256 amount);

    function initialize(
        address _lendingPool,
        address _aToken,
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
        lendingPool = IAaveV3LendingPool(_lendingPool);
        aToken = IATokenV3(_aToken);
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
        // bridge token back if cross chain tx.
        if (msg.sender == executor) {
            _bridgeTokenBack(_receiver, receivedBaseToken);
            emit Withdraw(msg.sender, bridge, receivedBaseToken);
        }
        // else transfer fund to user.
        else emit Withdraw(msg.sender, _receiver, receivedBaseToken);
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
    function reinvest(uint256 _slippage, bytes memory _path, uint256 _deadline) external {
        require(msg.sender == worker, "only worker is allowed");
        // gas saving:-

        // 1. withdraw rewards from pool
        uint256 WAVAXBefore = IERC20(WAVAX).balanceOf(address(this));
        // NOTE: TO DO- Perform withdraw WAVAX rewards
        uint256 receivedWAVAX = IERC20(WAVAX).balanceOf(address(this)) - WAVAXBefore;

        // 1.5 Calculate worker's fee before swapping
        {
            uint256 workerFee = receivedWAVAX * harvestFeeBPS / BPS;
            (bool _success, ) = payable(worker).call{value: workerFee}("");
            require(_success, "Failed to send Ethers to worker");
        }

        // 2. swap WAVAX -> baseToken
        IERC20[] memory path = new IERC20[](2);
        path[0] = IERC20(WAVAX);
        path[1] = baseToken;
        uint256[] memory pairBinSteps = new uint256[](1);
        pairBinSteps[0] = 1;    

        /**
        (uint256 amountOut, ) = router.getSwapOut(path, receivedWAVAX, true);
        uint256 amountOutWithSlippage = amountOut * _slippage / 100; // `_slippage`%
        uint256 receivedBase = swapper.swapExactTokensForTokens(receivedWAVAX, amountOutWithSlippage, pairBinSteps, path, receiverAddress, block.timestamp);
        */

        // 3. re-supply into LP.
        uint256 aTokenBefore = aToken.scaledBalanceOf(address(this));
        // lendingPool.supply(address(baseToken), receivedBase, address(this), 0);
        uint256 receivedAToken = aToken.scaledBalanceOf(address(this)) - aTokenBefore;

        // 4. calculate protocol reward.
        // reserves[address(_pool)] += protocolReward;
         
        // emit Reinvest(address(lendingPool), receivedBase);
    }
}
