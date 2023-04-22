// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IAToken.sol";
import "../../interfaces/IAaveLendingPoolV2.sol";

contract AaveV2NillaLendingPool is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IAToken public aToken;
    IERC20 public baseToken;
    uint8 private _decimals;
    IAaveLendingPoolV2 public lendingPool;

    uint256 private constant RAY = 1e27;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);

    function initialize(
        address _aToken,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        uint16 _performanceFeeBPS
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _performanceFeeBPS);
        lendingPool = IAaveLendingPoolV2(IAToken(_aToken).POOL());
        aToken = IAToken(_aToken);
        IERC20 _baseToken = IERC20(IAToken(_aToken).UNDERLYING_ASSET_ADDRESS());
        baseToken = _baseToken;
        _baseToken.safeApprove(IAToken(_aToken).POOL(), type(uint256).max);
        _decimals = IAToken(_aToken).decimals();
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function deposit(uint256 _amount, address _receiver) external nonReentrant returns (uint256) {
        // gas saving
        IERC20 _baseToken = baseToken;
        IAToken _aToken = aToken;
        IAaveLendingPoolV2 _lendingPool = lendingPool;
        uint256 principal = principals[_receiver];
        uint256 reserveNormalizedIncome = _lendingPool.getReserveNormalizedIncome(
            address(_baseToken)
        );
        // calculate performance fee, avoiding stack-too-deep
        uint256 depositFee = _calculatePerformanceFee(
            _receiver,
            principal,
            reserveNormalizedIncome
        );
        // transfer fund.
        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        _baseToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
        // deposit to Aave v2.
        // using share not rebase amount.
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        _lendingPool.deposit(address(_baseToken), receivedBaseToken, address(this), 0);
        uint256 received = _aToken.scaledBalanceOf(address(this)) - aTokenShareBefore;
        // collect protocol's fee.
        depositFee += (received * depositFeeBPS) / BPS;
        reserves[address(_aToken)] += depositFee;
        _mint(_receiver, received - depositFee);
        // calculate new receiver's principal, avoiding stack-too-deep
        _calculateNewPrincipals(_receiver, reserveNormalizedIncome);
        emit Deposit(msg.sender, _receiver, _amount);
        return (received - depositFee);
    }

    function redeem(uint256 _shares, address _receiver) external nonReentrant returns (uint256) {
        // gas saving
        IAaveLendingPoolV2 _lendingPool = lendingPool;
        address _baseToken = address(baseToken);
        IAToken _aToken = aToken;
        uint256 principal = principals[_receiver];
        uint256 reserveNormalizedIncome = _lendingPool.getReserveNormalizedIncome(
            address(_baseToken)
        );
        // calculate performance fee, avoiding stack-too-deep
        uint256 withdrawFee = _calculatePerformanceFee(
            _receiver,
            principal,
            reserveNormalizedIncome
        );
        // burn user's shares
        _burn(_receiver, _shares);
        // calculate new receiver's principal, avoiding stack-too-deep
        _calculateNewPrincipals(_receiver, reserveNormalizedIncome);
        // collect protocol's fee.
        withdrawFee += (_shares * withdrawFeeBPS) / BPS;
        uint256 shareAfterFee = _shares - withdrawFee;
        // withdraw user's fund.
        uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
        uint256 receivedBaseToken = _lendingPool.withdraw(
            _baseToken,
            shareAfterFee.mulDiv(reserveNormalizedIncome, RAY, Math.Rounding.Down), // aToken amount rounding down
            _receiver
        );
        uint256 burnedATokenShare = aTokenShareBefore - _aToken.scaledBalanceOf(address(this));
        // dust after burn rounding.
        uint256 dust = shareAfterFee - burnedATokenShare;
        reserves[address(aToken)] += (withdrawFee + dust);
        emit Withdraw(msg.sender, _receiver, receivedBaseToken);
        return receivedBaseToken;
    }

    function withdrawReserve(address _token, uint256 _amount) external override {
        require(msg.sender == worker, "only worker");
        IAToken _aToken = aToken; // gas saving
        if (_token != address(aToken)) {
            reserves[_token] -= _amount;
            IERC20(_token).safeTransfer(msg.sender, _amount);
            emit WithdrawReserve(msg.sender, _token, _amount);
        } else {
            // using shares for aToken
            uint256 aTokenShareBefore = _aToken.scaledBalanceOf(address(this));
            IERC20(_token).safeTransfer(msg.sender, _amount);
            uint256 transferedATokenShare = aTokenShareBefore -
                _aToken.scaledBalanceOf(address(this));
            reserves[_token] -= transferedATokenShare;
            emit WithdrawReserve(msg.sender, _token, transferedATokenShare);
        }
    }

    // internal function to calculate performance fee, avoiding stack-too-deep
    function _calculatePerformanceFee(
        address _receiver,
        uint256 _principal,
        uint256 _reserveNormalizedIncome
    ) internal view returns (uint256 performanceFee) {
        // get current balance from current shares
        if (_principal != 0) {
            uint256 currentBal = balanceOf(_receiver).mulDiv(
                _reserveNormalizedIncome,
                RAY,
                Math.Rounding.Down
            );
            // calculate profit from current balance compared to latest known principal
            uint256 profit = currentBal > _principal ? (currentBal - _principal) : 0;
            // calculate performance fee
            uint256 fee = profit.mulDiv(performanceFeeBPS, BPS);
            // sum fee into the fee
            performanceFee = fee.mulDiv(RAY, _reserveNormalizedIncome, Math.Rounding.Down);
        }
    }

    function _calculateNewPrincipals(address _receiver, uint256 _reserveNormalizedIncome) internal {
        // calculate new receiver's principal
        principals[_receiver] = balanceOf(_receiver).mulDiv(
            _reserveNormalizedIncome,
            RAY,
            Math.Rounding.Up
        );
    }
}
