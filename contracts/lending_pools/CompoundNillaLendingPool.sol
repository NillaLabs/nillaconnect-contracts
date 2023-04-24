// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IWNative.sol";
import "../../interfaces/ICToken.sol";
import "../../interfaces/IComptroller.sol";
import "../../interfaces/IUniswapRouterV2.sol";

contract CompoundNillaLendingPool is BaseNillaEarn {
    using SafeERC20 for IERC20;

    IUniswapRouterV2 public swapRouter;

    IWNative public immutable WNATIVE;
    IComptroller public immutable COMPTROLLER;

    ICToken public cToken;
    IERC20 public baseToken;
    uint8 private _decimals;

    uint16 public harvestFeeBPS;
    address public HARVEST_BOT;

    IERC20 public constant COMP = IERC20(0xc00e94Cb662C3520282E6f5717214004A7f26888);

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);
    event Reinvest(uint256 amount);
    event SetHarvestBot(address indexed newBot);

    function initialize(
        address _cToken,
        address _swapRouter,
        address _harvestBot,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        uint16 _harvestFeeBPS,
        uint16 _performanceFeeBPS
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _performanceFeeBPS);
        cToken = ICToken(_cToken);
        swapRouter = IUniswapRouterV2(_swapRouter);
        harvestFeeBPS = _harvestFeeBPS;
        HARVEST_BOT = _harvestBot;
        IERC20 _baseToken = IERC20(ICToken(_cToken).underlying());
        baseToken = _baseToken;
        _baseToken.safeApprove(_cToken, type(uint256).max);
        COMP.safeApprove(_swapRouter, type(uint256).max);
        _decimals = ICToken(_cToken).decimals();
    }

    constructor(address _comptroller, address _wNative) {
        COMPTROLLER = IComptroller(_comptroller);
        WNATIVE = IWNative(_wNative);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function setHarvestBot(address newBot) external onlyOwner {
        HARVEST_BOT = newBot;
        emit SetHarvestBot(newBot);
    }

    function deposit(uint256 _amount, address _receiver) external nonReentrant returns (uint256) {
        // gas saving
        IERC20 _baseToken = baseToken;
        ICToken _cToken = cToken;
        uint256 principal = principals[_receiver];
        uint256 exchangeRate = uint256(_cToken.exchangeRateCurrent()) / 1e18;
        // calculate performance fee
        uint256 depositFee;
        if (principal != 0) {
            // get current balance from share
            uint256 currentBal = exchangeRate * balanceOf(_receiver);
            // calculate profit from current balance compared to latest known principal
            uint256 profit = currentBal > principal ? (currentBal - principal) : 0;
            // calculate performance fee
            uint256 fee = (profit * performanceFeeBPS) / BPS;
            // sum fee into the depositFee, convert to share
            depositFee = fee / exchangeRate;
        }
        // transfer fund.
        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        _baseToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
        // deposit to Compound.
        uint256 cTokenBefore = _cToken.balanceOf(address(this));
        require(_cToken.mint(receivedBaseToken) == 0, "!mint");
        uint256 receivedCToken = _cToken.balanceOf(address(this)) - cTokenBefore;
        // collect protocol's fee.
        depositFee += (receivedCToken * depositFeeBPS) / BPS;
        reserves[address(_cToken)] += depositFee;
        _mint(_receiver, receivedCToken - depositFee);
        // calculate new receiver's principal
        principals[_receiver] =
            (uint256(_cToken.exchangeRateCurrent()) * balanceOf(_receiver)) /
            1e18;
        emit Deposit(msg.sender, _receiver, _amount);
        return (receivedCToken - depositFee);
    }

    function redeem(uint256 _shares, address _receiver) external nonReentrant returns (uint256) {
        // gas saving
        IERC20 _baseToken = baseToken;
        ICToken _cToken = cToken;
        uint256 principal = principals[_receiver];
        uint256 exchangeRate = uint256(_cToken.exchangeRateCurrent()) / 1e18;
        // calculate performance fee
        uint256 withdrawFee;
        if (principal != 0) {
            // get current balance from share
            uint256 currentBal = exchangeRate * balanceOf(_receiver);
            // calculate profit from current balance compared to latest known principal
            uint256 profit = currentBal > principal ? (currentBal - principal) : 0;
            // calculate performance fee
            uint256 fee = (profit * performanceFeeBPS) / BPS;
            // sum fee into the withdrawFee, convert to share
            withdrawFee = fee / exchangeRate;
        }
        // burn user's shares
        _burn(_receiver, _shares);
        // collect protocol's fee.
        withdrawFee += (_shares * withdrawFeeBPS) / BPS;
        reserves[address(_cToken)] += withdrawFee;
        // withdraw user's fund.
        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        require(_cToken.redeem(_shares - withdrawFee) == 0, "!redeem");
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
        _baseToken.safeTransfer(_receiver, receivedBaseToken);
        // calculate new receiver's principal
        principals[_receiver] =
            (uint256(_cToken.exchangeRateCurrent()) * balanceOf(_receiver)) /
            1e18;
        emit Withdraw(msg.sender, _receiver, receivedBaseToken);
        return receivedBaseToken;
    }

    function reinvest(
        uint256 _amountOutMin,
        uint256 _amountOutMinForBot,
        address[] calldata _path,
        uint256 _deadline
    ) external {
        require(msg.sender == HARVEST_BOT, "only harvest bot is allowed");
        require(_path[0] != address(cToken), "Asset to swap should not be cToken");
        // gas saving
        ICToken _cToken = cToken;
        IERC20 compound = IERC20(COMP);
        IERC20 _baseToken = baseToken;
        IWNative _WNATIVE = WNATIVE;
        // claime rewards from controller
        uint256 compBefore = compound.balanceOf(address(this));
        COMPTROLLER.claimComp(address(this));
        uint256 receivedComp = compound.balanceOf(address(this)) - compBefore;
        // calculate worker's fee before swapping
        uint256 botFee = (receivedComp * harvestFeeBPS) / BPS;
        {
            // send botFee to bot, swap COMP to WETH
            uint256 wethBefore = IERC20(_WNATIVE).balanceOf(address(this));
            // amountOutMin for bot is 90% of fee.
            address[] memory pathToNative = new address[](2);
            pathToNative[0] = address(compound);
            pathToNative[1] = address(_WNATIVE);
            swapRouter.swapExactTokensForTokens(
                botFee,
                _amountOutMinForBot,
                pathToNative,
                address(this),
                _deadline
            );
            uint256 receivedWeth = IERC20(_WNATIVE).balanceOf(address(this)) - wethBefore;
            // unwrap WETH to native
            _WNATIVE.withdraw(receivedWeth);
            (bool _success, ) = payable(HARVEST_BOT).call{ value: receivedWeth }("");
            require(_success, "Failed to send Ethers to bot");
        }
        {
            uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
            swapRouter.swapExactTokensForTokens(
                receivedComp - botFee,
                _amountOutMin,
                _path,
                address(this),
                _deadline
            );
            uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
            // re-supply into pool
            require(_cToken.mint(receivedBaseToken) == 0, "!mint");
            emit Reinvest(receivedBaseToken);
        }
    }
}
