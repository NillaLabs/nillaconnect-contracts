// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IstETH.sol";
import "../../interfaces/ICurvePool.sol";

contract LidoNillaLiquidityStaking is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    IstETH public immutable stETH;
    ICurvePool public swapRouter;

    uint8 private _decimals;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);

    function initialize(
        address _swapRouter,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        uint16 _performanceFeeBPS
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _performanceFeeBPS);
        swapRouter = ICurvePool(_swapRouter);
        IERC20(stETH).safeApprove(_swapRouter, type(uint256).max);
    }

    constructor(address _stETH) {
        stETH = IstETH(_stETH);
        _decimals = IstETH(_stETH).decimals();
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function deposit(address _receiver) external payable nonReentrant returns (uint256) {
        // gas saving
        IstETH _stETH = stETH;
        uint256 principal = principals[_receiver];
        // calculate performance fee
        uint256 depositFee = _calculatePerformanceFee(_receiver, principal, _stETH);
        // submit to stETH Finance.
        uint256 sharesBefore = _stETH.sharesOf(address(this));
        _stETH.submit{ value: msg.value }(address(this));
        uint256 receivedShares = _stETH.sharesOf(address(this)) - sharesBefore;
        // collect protocol's fee.
        depositFee += (receivedShares * depositFeeBPS) / BPS;
        reserves[address(_stETH)] += depositFee;
        _mint(_receiver, receivedShares - depositFee);
        // calculate new receiver's principal
        _updateNewPrincipals(_receiver, _stETH);
        emit Deposit(msg.sender, _receiver, msg.value);
        return (receivedShares - depositFee);
    }

    function redeem(
        uint256 _shares,
        address _receiver,
        uint256 _minAmount
    ) external nonReentrant returns (uint256) {
        // gas saving
        IstETH _stETH = stETH;
        uint256 principal = principals[_receiver];
        // calculate performance fee
        uint256 withdrawFee = _calculatePerformanceFee(_receiver, principal, _stETH);
        // burn user's shares
        _burn(_receiver, _shares);
        // collect protocol's fee
        withdrawFee += (_shares * withdrawFeeBPS) / BPS;
        reserves[address(stETH)] += withdrawFee;
        // convert nilla's shares to stETH amount
        uint256 amount = _stETH.getPooledEthByShares(_shares - withdrawFee);
        // swap user's fund via Curve; stETH --> ETH
        uint256 ETHBefore = address(this).balance;
        swapRouter.exchange{ value: 0 }(
            1, // index of stETH in Curve Pool
            0, // index of ETH in Curve Pool
            amount,
            _minAmount
        );
        uint256 receivedETH = address(this).balance - ETHBefore;
        (bool success, ) = payable(_receiver).call{ value: receivedETH }("");
        require(success, "!withdraw");
        // calculate new receiver's principal
        // NOTE: Rate that we calculate fee is different from user's rate when withdrawing.
        _updateNewPrincipals(_receiver, _stETH);
        emit Withdraw(msg.sender, _receiver, receivedETH);
        return receivedETH;
    }

    // internal function to calculate performance fee
    function _calculatePerformanceFee(
        address _receiver,
        uint256 _principal,
        IstETH _stETH
    ) internal view returns (uint256 performanceFee) {
        // Note: we used rate 1 stETH : 1 ETH for calculate performanceFee
        // get current balance from current shares
        if (_principal != 0) {
            // get current balance from share
            uint256 currentBal = _stETH.getPooledEthByShares(balanceOf(_receiver));
            // calculate profit from current balance compared to latest known principal
            uint256 profit = currentBal > _principal ? (currentBal - _principal) : 0;
            // calculate performance fee
            uint256 fee = profit.mulDiv(performanceFeeBPS, BPS);
            // sum fee into the withdrawFee, convert to share
            performanceFee = _stETH.getSharesByPooledEth(fee);
        } else {
            performanceFee = 0;
        }
    }

    // internal function to update receiver's latest principal
    function _updateNewPrincipals(address _receiver, IstETH _stETH) internal {
        principals[_receiver] = _stETH.getPooledEthByShares(balanceOf(_receiver));
    }
}
