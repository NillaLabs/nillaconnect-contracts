pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface IYVToken is IERC20 {
    function pricePerShare() external view returns (uint256)

    function maxAvailableShares() external view returns (uint256);

    function deposit(uint256, address) external returns (uint256);

    function withdraw(uint256, address, uint256) external returns (uint256);
}