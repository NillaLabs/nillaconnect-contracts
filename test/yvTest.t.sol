pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";

contract YVTest is Test {
    ProxyAdminImpl internal proxyAdmin;
    TransparentUpgradeableProxyImpl internal transparentUpgradeableProxyImpl;

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161");
        vm.selectFork(mainnetFork);
        
    }

    function testDeposit() public {
        // ynv = new YearnNillaVault(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9, "USDC Vault", "USDC", 1, 1, address(0));
        uint256 amount = 1_000_000;
    }
}