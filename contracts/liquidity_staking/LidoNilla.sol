// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/utils/math/Math.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/ILido.sol";
import "../../interfaces/IWNative.sol";
import "../../interfaces/IUniswapRouterV2.sol";

contract IronBankNillaLendingPool is BaseNillaEarn {
    using SafeERC20 for IERC20;
    using Math for uint256;

    ILido public lido;
    IUniswapRouterV2 public swapRouter;
    IWNative public WETH;
    IERC20 public baseToken;
    uint8 private constant _decimals = 18; // stETH's decimals is 18

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);

    function initialize(
        address _lido,
        address _swapRouter,
        address _stETH,
        address _weth,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        address _executor,
        address _bridge
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _executor, _bridge);
        lido = ILido(_lido);
        swapRouter = IUniswapRouterV2(_swapRouter);
        WETH = IWNative(_weth);
        baseToken = IERC20(_stETH);
        IERC20(_weth).safeApprove(_swapRouter, type(uint256).max);
        IERC20(_stETH).safeApprove(_swapRouter, type(uint256).max);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function deposit(uint256 _amount, address _receiver) external payable nonReentrant returns (uint256) {
        // gas saving
        ILido _lido = lido;
        // submit to Lido Finance.
        uint256 receivedBase = _lido.submit{value: msg.value}(address(this));
        // collect protocol's fee.
        uint256 depositFee = (receivedBase * depositFeeBPS) / BPS;
        reserves[address(_lido)] += depositFee;
        _mint(_receiver, receivedBase - depositFee);
        emit Deposit(msg.sender, _receiver, _amount);
        return (receivedBase - depositFee);
    }

    function redeem(uint256 _shares, address _receiver, uint256 _amountOutMin, address[] calldata _path, uint256 _deadline) external nonReentrant returns (uint256) {
        // gas saving
        IWNative _WETH = WETH;
        ILido _lido = lido;
        // set msgSender for cross chain tx.
        address msgSender = _msgSender(_receiver);
        // burn user's shares
        _burn(msgSender, _shares);
        // collect protocol's fee.
        uint256 withdrawFee = (_shares * withdrawFeeBPS) / BPS;
        reserves[address(lido)] += withdrawFee;
        // convert shares to amount
        uint256 amount = _shares.mulDiv(_lido.totalSupply(), _lido.getTotalShares());
        // swap user's fund.
        uint256 WETHBefore = IERC20(_WETH).balanceOf(address(this));
        swapRouter.swapExactTokensForTokens(amount, _amountOutMin, _path, address(this), _deadline);
        uint256 receivedWETH = IERC20(_WETH).balanceOf(address(this)) - WETHBefore;
        // bridge token back if cross chain tx.
        if (msg.sender == executor) {
            _bridgeTokenBack(_receiver, receivedWETH);
            emit Withdraw(msg.sender, bridge, receivedWETH);
        }
        // else transfer fund to user.
        else {
            IERC20(_WETH).safeTransfer(_receiver, receivedWETH);
            emit Withdraw(msg.sender, _receiver, receivedWETH);
        }
        return receivedWETH;
    }
}
