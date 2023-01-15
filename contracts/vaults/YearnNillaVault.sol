// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IYVToken.sol";

// NOTE: not sure that yearn have lm process or not?
// if yes how to get it and implement auto-compound
contract IronBankNillaLendingPool is BaseNillaEarn {
    using SafeERC20 for IERC20;

    IYVToken public yvToken;
    IERC20 public baseToken;
    uint8 private _decimals;

    // TODO: add variables if needed

    function initialize(
        IYVToken _yvToken,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        address _executor
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _executor);
        // TODO: init variable
        yvToken = _yvToken;
        
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // NOTE: might add more param to match with yvToken's interface
    function deposit(uint256 _amount, address _receiver) external nonReentrant {
        // transfer fund.
        uint256 baseTokenBefore = baseToken.balanceOf(address(this));
        baseToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 receivedBaseToken = baseToken.balanceOf(address(this)) - baseTokenBefore;

        uint256 cTokenBefore = cToken.balanceOf(address(this));
        // TODO:
        // deposit to yearn.
        uint256 receivedCToken = cToken.balanceOf(address(this)) - cTokenBefore;
        // collect protocol's fee.
        uint256 depositFee = (receivedCToken * depositFeeBPS) / BPS;
        reserves[address(yvToken)] += depositFee;
        _mint(_receiver, receivedCToken - depositFee);
    }

    // NOTE: might add more param to match with yvToken's interface
    function redeem(uint256 _shares, address _receiver) external nonReentrant {
        // set msgSender for cross chain tx.
        address msgSender = _msgSender(_receiver);
        // burn user's shares
        _burn(msgSender, _shares);
        uint256 baseTokenBefore = baseToken.balanceOf(address(this));
        uint256 withdrawFee = (_shares * withdrawFeeBPS) / BPS;
        reserves[address(yvToken)] += withdrawFee;
        // TODO:
        // withdraw user's fund.
        uint256 receivedBaseToken = baseToken.balanceOf(address(this)) - baseTokenBefore;
        // bridge token back if cross chain tx.
        // NOTE: need to fix bridge token condition.
        if (msg.sender == executor) _bridgeTokenBack(_receiver, receivedBaseToken);
        else baseToken.safeTransfer(_receiver, receivedBaseToken);
    }
}
