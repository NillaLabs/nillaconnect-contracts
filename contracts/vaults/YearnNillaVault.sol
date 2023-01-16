// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../BaseNillaEarn.sol";

import "../../interfaces/IYVToken.sol";

// NOTE: not sure that yearn have liquidy mining process or not?
// if yes how to get it and implement auto-compound

contract YearnNillaVault is BaseNillaEarn {
    using SafeERC20 for IERC20;

    IYVToken public yvToken;
    IERC20 public baseToken;
    uint8 private _decimals;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount, uint256 maxLoss);

    function initialize(
        IYVToken _yvToken,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        address _executor,
        address _bridge
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _executor, _bridge);
        yvToken = _yvToken;
        IERC20 _baseToken = IERC20(_yvToken.token());
        _baseToken.safeApprove(address(_yvToken), type(uint256).max);
        _decimals = _yvToken.decimals();
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

        uint256 yvTokenBefore = yvToken.balanceOf(address(this));
        yvToken.deposit(_amount, _receiver);
        // deposit to yearn.
        uint256 receivedYVToken = yvToken.balanceOf(address(this)) - yvTokenBefore;
        // collect protocol's fee.
        uint256 depositFee = (receivedYVToken * depositFeeBPS) / BPS;
        reserves[address(yvToken)] += depositFee;
        _mint(_receiver, receivedYVToken - depositFee);
        emit Deposit(msg.sender, _receiver, _amount);
    }

    // NOTE: might add more param to match with yvToken's interface
    function redeem(uint256 _shares, address _receiver, uint256 _maxLoss) external nonReentrant {
        // set msgSender for cross chain tx.
        address msgSender = _msgSender(_receiver);
        // burn user's shares
        _burn(msgSender, _shares);
        uint256 baseTokenBefore = baseToken.balanceOf(address(this));
        uint256 withdrawFee = (_shares * withdrawFeeBPS) / BPS;
        reserves[address(yvToken)] += withdrawFee;
        yvToken.withdraw(_shares - withdrawFee, _receiver, _maxLoss);
        // withdraw user's fund.
        uint256 receivedBaseToken = baseToken.balanceOf(address(this)) - baseTokenBefore;
        // bridge token back if cross chain tx.
        // NOTE: need to fix bridge token condition.
        if (msg.sender == executor) {
            _bridgeTokenBack(_receiver, receivedBaseToken);
            emit Withdraw(msg.sender, bridge, receivedBaseToken, _maxLoss);
        }
        else { 
            baseToken.safeTransfer(_receiver, receivedBaseToken);
            // NOTE: if not need, del _maxLoss later
            emit Withdraw(msg.sender, _receiver, receivedBaseToken, _maxLoss);
        }
    }
}
