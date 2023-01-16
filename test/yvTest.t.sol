pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";
import "../contracts/vaults/YearnNillaVault.sol";

contract YVTest is Test {
    ProxyAdminImpl internal admin;
    TransparentUpgradeableProxyImpl internal proxy;
    address impl;

    uint256 mainnetFork;

    function setUp() public {
        mainnetFork = vm.createFork("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161");
        vm.selectFork(mainnetFork);
        
        admin = address(new ProxyAdminImpl());
        impl  = address(new YearnNillaVault());

        proxy = new TransparentUpgradeableProxyImpl(
            impl,
            admin,
            // NOTE: TO DO- abi.encodeWithSelector(Contract.initialize.selector, param1, param2, ...);
        );
    }

    function testDeposit() public {
        // ynv = new YearnNillaVault(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9, "USDC Vault", "USDC", 1, 1, address(0));
        uint256 amount = 1_000_000;
    }
}