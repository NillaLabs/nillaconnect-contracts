pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";
import "../contracts/vaults/YearnNillaVault.sol";
import "../interfaces/IYVToken.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

contract YVTest is Test {
    using SafeERC20 for IERC20;
    
    TransparentUpgradeableProxyImpl internal proxy;
    address internal impl;
    address internal admin;
    address internal executor = address(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    // receiver for test
    address internal receiver = address(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);

    // zero-address
    address internal ZERO_ADDRESS = address(0);
    
    // vault
    YearnNillaVault internal vault;

    uint256 mainnetFork;

    IERC20 baseToken; 
    IYVToken internal yvToken = IYVToken(address(0xa354F35829Ae975e850e23e9615b11Da1B3dC4DE)); //WETH

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount);
    event Withdraw(address indexed withdrawer, address indexed receiver, uint256 amount, uint256 maxLoss);

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

        startHoax(address(executor));

        vault = YearnNillaVault(address(proxy));
        baseToken = IERC20(address(vault.baseToken()));
        deal(address(baseToken), address(executor), 10_000_000);
        deal(address(baseToken), address(vault), 10_000_000);
        baseToken.safeApprove(address(vault), type(uint256).max);
        _checkInfo();
    }

    function _checkInfo() internal view {
        console.log("Vault address:", address(vault));
        console.log("Vault balance:", baseToken.balanceOf(address(vault)));
        console.log("Yearn deposit limit:", yvToken.depositLimit());
        console.log("Yearn vault name:", yvToken.name());
    }
    
    // function testDepositNormal() public {
    //     uint256 amount = 1_000;

    //     vm.expectEmit(true, false, true, true);
    //     emit Deposit(address(executor), address(receiver), amount);

    //     vault.deposit(amount, receiver);
    // }

    // function testDepositZeroAmount() public {
    //     uint256 amount = 0;

    //     vm.expectRevert();
    //     vault.deposit(amount, receiver);
    // }

    function testDepisitWithFuzzer(uint256 amount) public {
        // deposit with any amount that more 0 and not exceed (depositLimit - totalSupply), also not exceed the balance of spender.
        uint256 totalAssets = yvToken.totalDebt() + yvToken.totalIdle();
        uint256 maxLimit = yvToken.depositLimit() - totalAssets;
        vm.assume(amount < maxLimit && amount > 0 && amount < baseToken.balanceOf(address(executor)));
        vault.deposit(amount, receiver);
    }

    // function redeemNormal() public {
    //     uint256 shares = 100; //how to check share owned?
    //     uint256 maxLoss = 1;
    //     YearnNillaVault(address(proxy)).redeem(shares, receiver, maxLoss);
    // }

    // function redeemExceedingShares() public {
    //     uint256 shares = 1_000_000;
    //     uint256 maxLoss = 1;
    //     YearnNillaVault(address(proxy)).redeem(shares, receiver, maxLoss);
    //     // revert
    // }

    // function redeemZeroShare() public {
    //     uint256 shares = 0;
    //     uint256 maxLoss = 1;
    //     YearnNillaVault(address(proxy)).redeem(shares, receiver, maxLoss);
    //     // revert
    // }

    // function redeemExceedingMaxLoss() public {
    //     uint256 shares = 100;
    //     uint256 maxLoss = 10_100;
    //     YearnNillaVault(address(proxy)).redeem(shares, receiver, maxLoss);
    //     // revert
    // }

    // function redeemZeroMaxLoss() public {
    //     uint256 shares = 100;
    //     uint256 maxLoss = 0;
    //     YearnNillaVault(address(proxy)).redeem(shares, receiver, maxLoss);
    //     // revert
    // }
}