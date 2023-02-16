// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";
import "../BaseNillaEarn.sol";

import "../../interfaces/IYVToken.sol";
import "../../interfaces/IYearnPartnerTracker.sol";

contract YearnNillaVault is BaseNillaEarn {
    using SafeERC20 for IERC20;

    address public PARTNER_ADDRESS = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // MOCK-UP

    IYVToken public yvToken;
    IYearnPartnerTracker public yearnPartnerTracker;

    IERC20 public baseToken;
    uint8 private _decimals;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount, uint256 maxLoss);
    event SetNewPartnerAddress(address newAddress);

    function initialize(
        address _yvToken,
        address _yearnPartnerTracker,
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        address _executor,
        address _bridge
    ) external {
        __initialize__(_name, _symbol, _depositFeeBPS, _withdrawFeeBPS, _executor, _bridge);
        yvToken = IYVToken(_yvToken);
        yearnPartnerTracker = IYearnPartnerTracker(_yearnPartnerTracker);

        IERC20 _baseToken = IERC20(address(IYVToken(_yvToken).token()));
        baseToken = _baseToken;
        _baseToken.safeApprove(_yvToken, type(uint256).max);
        _baseToken.safeApprove(_yearnPartnerTracker, type(uint256).max);

        _decimals = IYVToken(_yvToken).decimals();
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function SetPartnerAddress(address _newAddress) external onlyOwner {
        require(_newAddress != address(0), "Set to empty address");
        PARTNER_ADDRESS = _newAddress;
        emit SetNewPartnerAddress(_newAddress);
    }

    function deposit(uint256 _amount, address _receiver) external nonReentrant {
        //gas saving
        IERC20 _baseToken = baseToken;
        IYVToken _yvToken = yvToken;

        // transfer fund.
        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        _baseToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;

        // // deposit to yearn.
        uint256 receivedYVToken = yearnPartnerTracker.deposit(address(_yvToken), PARTNER_ADDRESS, receivedBaseToken);

        // collect protocol's fee.
        uint256 depositFee = (receivedYVToken * depositFeeBPS) / BPS;
        reserves[address(_yvToken)] += depositFee;
        _mint(_receiver, receivedYVToken - depositFee);
        emit Deposit(msg.sender, _receiver, _amount);
    }

    function redeem(uint256 _shares, address _receiver, uint256 _maxLoss) external nonReentrant {
        // gas saving
        IERC20 _baseToken = baseToken;
        IYVToken _yvToken = yvToken;
        // set msgSender for cross chain tx.
        address msgSender = _msgSender(_receiver);
        // burn user's shares
        _burn(msgSender, _shares);

        uint256 withdrawFee = (_shares * withdrawFeeBPS) / BPS;
        reserves[address(_yvToken)] += withdrawFee;

        uint256 baseTokenBefore = _baseToken.balanceOf(address(this));
        // withdraw user's fund.
        _yvToken.withdraw(_shares - withdrawFee,  msg.sender == executor ? address(this) : _receiver, _maxLoss);
        uint256 receivedBaseToken = _baseToken.balanceOf(address(this)) - baseTokenBefore;
        
        // bridge token back if cross chain tx.
        // NOTE: need to fix bridge token condition.
        if (msg.sender == executor) {
            _bridgeTokenBack(_receiver, receivedBaseToken);
            emit Withdraw(msg.sender, bridge, receivedBaseToken, _maxLoss);
        }
        else { 
            // NOTE: if not need, del _maxLoss later
            emit Withdraw(msg.sender, _receiver, receivedBaseToken, _maxLoss);
        }
    }
}
