pragma solidity 0.8.17;

import "../lib/forge-std/src/Test.sol";
import "../contracts/vaults/YearnNillaVault.sol";

contract YVTest is Test {
    YearnNillaVault internal ynv;

    function setUp() public {
        ynv = new YearnNillaVault(
            0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9, // USDC 
            "USDC Vault",
            "USDC",
            1,
            1,
            address(0)
        );
    }

    function testDeposit() public {
        uint256 amount = 1_000_000;
    }
}