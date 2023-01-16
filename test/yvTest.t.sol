pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";
import "../contracts/vaults/YearnNillaVault.sol";
import "../interfaces/IYVToken.sol";

contract YVTest is Test {
    
    TransparentUpgradeableProxyImpl internal proxy;
    address internal impl;
    address internal admin;
    address internal executor = address(0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266);

    uint256 mainnetFork;

    IYVToken internal yvToken = IYVToken(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);

    function setUp() public {
        mainnetFork = vm.createFork("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161");
        vm.selectFork(mainnetFork);
        
        admin = address(new ProxyAdminImpl());
        impl  = address(new YearnNillaVault());

        proxy = new TransparentUpgradeableProxyImpl(
            impl,
            admin,
            abi.encodeWithSelector(YearnNillaVault.initialize.selector, yvToken, "USDC Vault", "USDC", 1, 1, executor)
        );
    }

    function testDeposit() public {
        // ynv = new YearnNillaVault(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9, "USDC Vault", "USDC", 1, 1, address(0));
        uint256 amount = 1_000_000;
        address receiver = address(0x70997970c51812dc3a010c7d01b50e0d17dc79c8);
    }
}