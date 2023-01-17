// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.7.3/contracts/token/ERC20/ERC20Upgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.7.3/contracts/security/ReentrancyGuardUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts-upgradeable@4.7.3/contracts/access/OwnableUpgradeable.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

contract BaseNillaEarn is ERC20Upgradeable, ReentrancyGuardUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    uint16 internal constant BPS = 10000;

    mapping(address => uint256) reserves;
    uint16 public depositFeeBPS;
    uint16 public withdrawFeeBPS;
    address public worker; // wallet to withdraw fee
    address public executor; // executor contract for cross chain tx
    address public bridge; // bridge contract to bridge token cross chain

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[30] private __gap; //

    event SetWorker(address);
    event SetDepositFee(uint256);
    event SetWithdrawFee(uint256);
    event WithdrawReserve(address indexed token, address worker, uint256 amount);
    event SetExecutor(address);
    event SetBridge(address);

    function __initialize__(
        string memory _name,
        string memory _symbol,
        uint16 _depositFeeBPS,
        uint16 _withdrawFeeBPS,
        address _executor,
        address _bridge
    ) internal initializer {
        __ERC20_init(_name, _symbol);
        __ReentrancyGuard_init();
        __Ownable_init();
        depositFeeBPS = _depositFeeBPS;
        withdrawFeeBPS = _withdrawFeeBPS;
        executor = _executor;
        bridge = _bridge;
        emit SetDepositFee(_depositFeeBPS);
        emit SetWithdrawFee(_withdrawFeeBPS);
        emit SetExecutor(_executor);
        emit SetBridge(_bridge);
    }

    function setDepositFeeBPS(uint16 _depositFeeBPS) external onlyOwner {
        require(_depositFeeBPS <= 3, "fee too much"); // max fee = 0.03%
        depositFeeBPS = _depositFeeBPS;
        emit SetDepositFee(_depositFeeBPS);
    }

    function setWithdrawFeeBPS(uint16 _withdrawFeeBPS) external onlyOwner {
        require(_withdrawFeeBPS <= 3, "fee too much"); // max fee = 0.03%
        withdrawFeeBPS = _withdrawFeeBPS;
        emit SetWithdrawFee(_withdrawFeeBPS);
    }

    function setWorker(address _worker) external onlyOwner {
        worker = _worker;
        emit SetWorker(_worker);
    }

    function setExecutor(address _executor) external onlyOwner {
        executor = _executor;
        emit SetExecutor(_executor);
    }

    function setBridge(address _bridge) external onlyOwner {
        bridge = _bridge;
        emit SetBridge(_bridge);
    }

    function withdrawReserve(address _token, uint256 _amount) external virtual {
        require(msg.sender == worker, "only worker");
        reserves[_token] -= _amount;
        IERC20(_token).safeTransfer(msg.sender, _amount);
        emit WithdrawReserve(msg.sender, _token, _amount);
    }

    function _msgSender(address _user) internal view returns (address msgSender) { //NOTE: view is to be deleted, add to ignore the msg when testing
        if (msg.sender == executor) {
            // TODO: have to check a prove that cross chain tx is valid.
            // 1.validate
            // ***
            // CODE HERE
            // ***
            // 2.update msgSender to cross chain tx msg.sender
            // NOTE: (maybe get _user from prove).
            msgSender = _user;
        } else {
            msgSender = msg.sender;
        }
    }

    // NOTE: need to sync bridge token interfaces.
    function _bridgeTokenBack(address _receiver, uint256 _amount) internal {
        // TODO: bridge token logic (when withdraw)
        // ***
        // CODE HERE
        // ***
    }
}
