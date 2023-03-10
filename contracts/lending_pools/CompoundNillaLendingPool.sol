// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/ICToken.sol";

contract CompoundNillaLendingPool is BaseNillaEarn {
    using SafeERC20 for IERC20;

    ICToken public cToken;
    IERC20 public baseToken;
    uint8 private _decimals;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount);

    function initialize(
        address _cToken,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS);
        cToken = ICToken(_cToken);
        IERC20 _baseToken = IERC20(ICToken(_cToken).underlying());
        baseToken = _baseToken;
        _baseToken.safeApprove(_cToken, type(uint256).max);
        _decimals = ICToken(_cToken).decimals();
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function deposit(uint256 _amount, address _receiver) external nonReentrant returns (uint256) {
        // gas saving
        IERC20 _baseToken = baseToken;
        ICToken _cToken = cToken;
        // transfer fund.
        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        _baseToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
        // deposit to Compound.
        uint256 cTokenBefore = _cToken.balanceOf(address(this));
        require(_cToken.mint(receivedBaseToken) == 0, "!mint");
        uint256 receivedCToken = _cToken.balanceOf(address(this)) - cTokenBefore;
        // collect protocol's fee.
        uint256 depositFee = (receivedCToken * depositFeeBPS) / BPS;
        reserves[address(_cToken)] += depositFee;
        _mint(_receiver, receivedCToken - depositFee);
        emit Deposit(msg.sender, _receiver, _amount);
        return (receivedCToken - depositFee);
    }

    function redeem(uint256 _shares, address _receiver) external nonReentrant returns (uint256) {
        // gas saving
        IERC20 _baseToken = baseToken;
        ICToken _cToken = cToken;
        // burn user's shares
        _burn(_receiver, _shares);
        // collect protocol's fee.
        uint256 withdrawFee = (_shares * withdrawFeeBPS) / BPS;
        reserves[address(_cToken)] += withdrawFee;
        // withdraw user's fund.
        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        require(_cToken.redeem(_shares - withdrawFee) == 0, "!redeem");
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
        _baseToken.safeTransfer(_receiver, receivedBaseToken);
        emit Withdraw(msg.sender, _receiver, receivedBaseToken);
        return receivedBaseToken;
    }

    /**
     * Reinvest() on Mainnet
     * rewards: compound token
     * Comptroller.sol --> claimeReward() // around this name
     * swap on either UniV2 or Sushi or UniV3 ; Check LQ.
     * Follow the same logic as others reinvest(). :D
     */
}
