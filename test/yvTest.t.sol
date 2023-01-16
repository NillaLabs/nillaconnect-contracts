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
    address internal executor = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    // receiver for test
    address internal receiver = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    // zero-address
    address internal ZERO_ADDRESS = address(0);

    uint256 mainnetFork;

    IYVToken internal yvToken = IYVToken(0x5f18C75AbDAe578b483E5F43f12a39cF75b973a9);

    function setUp() public {
        mainnetFork = vm.createFork("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161");
        vm.selectFork(mainnetFork);
        
        admin = address(new ProxyAdminImpl());
        impl  = address(new YearnNillaVault());

        // Contract VaultNilla
        proxy = new TransparentUpgradeableProxyImpl(
            impl,
            admin,
            abi.encodeWithSelector(YearnNillaVault.initialize.selector, yvToken, "USDC Vault", "USDC", 1, 1, executor, address(0))
        );
    }

    function testDepositNormal() public {
        uint256 amount = 10_000;
        YearnNillaVault(proxy).deposit(amount, receiver);
    }

    function testDepositZeroAmount() public {
        uint256 amount = 0;
        // deposit(amount, receiver)
        // expect revert?
    }

    function testDepositZeroAddress() public {
        uint256 amount = 10_000;
        // deposit(amount, ZERO_ADDRESS)
        // expect revert?
    }

    function redeemNormal() public {
        uint256 shares = 100; //how to check share owned?
        uint256 maxLoss = 1;
        // redeem(shares, receiver, maxLoss)
    }

    function redeemExceedingShares() public {
        uint256 shares = 1_000_000;
        uint256 maxLoss = 1;
        // redeem(shares, receiver, maxLoss)
        // revert
    }

    function redeemZeroShare() public {
        uint256 shares = 0;
        uint256 maxLoss = 1;
        // redeem(shares, receiver, maxLoss)
        // revert
    }

    function redeemZeroAddress() public {
        uint256 shares = 100;
        uint256 maxLoss = 1;
        // redeem(shares, ZERO_ADDRESS, maxLoss)
        // revert
    }

    function redeemExceedingMaxLoss() public {
        uint256 shares = 100;
        uint256 maxLoss = 10_100;
        // redeem(shares, receiver, maxLoss)
        // revert
    }

    function redeemZeroMaxLoss() public {
        uint256 shares = 100;
        uint256 maxLoss = 0;
        // redeem(shares, receiver, maxLoss)
        // revert
    }
}