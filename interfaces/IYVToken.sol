pragma solidity 0.8.17;

import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";

interface IYVToken is IERC20 {
    function decimals() external view returns (uint8);

    function token() external view returns (address);

    function deposit(uint256, address) external returns (uint256);

    function withdraw(uint256, address, uint256) external returns (uint256);

    // FOR TESTING
    function depositLimit() external view returns (uint256);

    function name() external view returns (string memory);

    function totalDebt() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}