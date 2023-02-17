pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";
import "../contracts/lending_pools/AaveV3NillaLendingPool.sol";

import "../interfaces/IATokenV3.sol";
import "../interfaces/IWrappedTokenGatewayV3.sol";

contract AaveV3Test is Test {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    TransparentUpgradeableProxyImpl public proxy;
    address public impl;
    address public admin;
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address public executor = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    address public WAVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    // zero-address
    address public ZERO_ADDRESS = address(0);

    uint256 public avalancheFork;

    IERC20 public baseToken;
    IATokenV3 public aToken = IATokenV3(0x625E7708f30cA75bfd92586e17077590C60eb4cD);
    IAaveV3LendingPool public pool = IAaveV3LendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IWrappedTokenGatewayV3 public gateway = IWrappedTokenGatewayV3(0x6F143FE2F7B02424ad3CaD1593D6f36c0Aab69d7);

    AaveV3NillaLendingPool public aaveV3Pool;

    function setUp() public {
        avalancheFork = vm.createFork("https://avalanche-mainnet.infura.io/v3/e6282a54498e433a87766276d1d4b67b"); // Avalanche
        vm.selectFork(avalancheFork);
        startHoax(user);

        vm.label(user, "#### User ####");
        vm.label(address(pool), "#### Aave Pool ####");
        vm.label(address(aToken), "#### AToken ####");
        vm.label(address(gateway), "#### Gateway ####");
        vm.label(WAVAX, "#### WAVAX ####");

        admin = address(new ProxyAdminImpl());
        impl  = address(new AaveV3NillaLendingPool());

        proxy = new TransparentUpgradeableProxyImpl(
            impl,
            admin,
            abi.encodeWithSelector(
                AaveV3NillaLendingPool.initialize.selector,
                address(pool),
                address(aToken),
                address(gateway),
                WAVAX,
                "USDC Vault",
                "USDC",
                1,    // Deposit Fee BPS
                1,    // Withdraw Fee BPS  
                1,    // Harvest Fee BPS
                executor,
                address(0))
        );

        aaveV3Pool = AaveV3NillaLendingPool(address(proxy));
        baseToken = IERC20(aaveV3Pool.baseToken());

        baseToken.safeApprove(address(aaveV3Pool), type(uint256).max);

        vm.label(address(aaveV3Pool), "#### Nilla ####");
        vm.label(address(baseToken), "#### BaseToken ####");
    }

    function testDepositNormal() public {
        console.log("---------- TEST NORMAL DEPOSIT ----------");
        uint256 amount = 1e15;
        deal(address(baseToken), user, amount);

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 reserveBefore = aaveV3Pool.reserves(address(aToken));

        aaveV3Pool.deposit(amount, user);

        uint256 aTokenAfter = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 reserveAfter = aaveV3Pool.reserves(address(aToken));
        uint256 depositFee = (aTokenAfter - aTokenBefore) * 1 / 10_000;

        assertEq(reserveAfter - reserveBefore, depositFee);
        assertEq(aaveV3Pool.balanceOf(user), aTokenAfter - depositFee); 

        console.log("LP balance in aave before:", aTokenBefore);
        console.log("LP balance in aave after:", aTokenAfter);
        console.log("Reserves before:", reserveBefore);
        console.log("Reserves after:", reserveAfter);
    }

    function testFuzzyDeposit(uint256 amount) public {
        console.log("---------- TEST FUZZY DEPOSIT ----------");
        amount = bound(amount, 10, 1e15);
        deal(address(baseToken), user, amount);

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 reserveBefore = aaveV3Pool.reserves(address(aToken));

        aaveV3Pool.deposit(amount, user);

        uint256 aTokenAfter = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 reserveAfter = aaveV3Pool.reserves(address(aToken));
        uint256 depositFee = (aTokenAfter - aTokenBefore) * 1 / 10_000;

        assertEq(reserveAfter - reserveBefore, depositFee);
        assertEq(aaveV3Pool.balanceOf(user), aTokenAfter - depositFee); 
    }

    function testDepositTooLarge() public {
        uint256 amount = 1e30;
        deal(address(baseToken), user, amount);
        vm.expectRevert(bytes("51"));
        aaveV3Pool.deposit(amount, user);
    }

    function testDepositInvalidAmount() public {
        uint256 amount = 0;
        deal(address(baseToken), user, amount);
        vm.expectRevert(bytes("26"));
        aaveV3Pool.deposit(amount, user);
    }

    function testDepositInvalidAddress() public {
        uint256 amount = 1_000;
        deal(address(baseToken), user, amount);
        vm.expectRevert(bytes("ERC20: mint to the zero address"));
        aaveV3Pool.deposit(amount, address(0));
    }

    function testRedeemNormal() public {
        console.log("---------- TEST NORMAL REDEEM ----------");
        uint256 amount = 1e15;
        deal(address(baseToken), user, amount);

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 baseTokenBefore = baseToken.balanceOf(user);

        aaveV3Pool.deposit(amount, user);

        uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 shares = aaveV3Pool.balanceOf(user);  // Redeem total shares
        uint256 withdrawFee = shares.mulDiv(1, 10_000);
        uint256 reserveBefore = aaveV3Pool.reserves(address(aToken));
        
        console.log("Block timestamp:", block.timestamp);
        vm.warp(block.timestamp + 1_000_000_000);
        console.log("Block timestamp 2:", block.timestamp);
        aaveV3Pool.redeem(shares, user);

        uint256 addedReserve = aaveV3Pool.reserves(address(aToken)) - reserveBefore;
        uint256 burnedATokenShare = aTokenAfterDeposit - aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 dust = (shares - withdrawFee) - burnedATokenShare;

        assertEq(addedReserve, withdrawFee + dust);
        assertEq(aaveV3Pool.balanceOf(user), 0);

        uint256 baseTokenAfter = baseToken.balanceOf(user);
        uint256 aTokenAfterRedeem = aToken.scaledBalanceOf(address(aaveV3Pool));

        console.log("LP balance in aave before deposit:", aTokenBefore);
        console.log("LP balance in aave after deposit:", aTokenAfterDeposit);
        console.log("LP balance in aave after redeem:", aTokenAfterRedeem);
        console.log("Base Token Before deposit:", baseTokenBefore);
        console.log("Base Token After withdraw:", baseTokenAfter);
        console.log("USER WAVAX:", IERC20(WAVAX).balanceOf(user));
        console.log("NILLA WAVAX:", IERC20(WAVAX).balanceOf(address(aaveV3Pool)));
    }

    function testFuzzyRedeem(uint256 amount) public {
        console.log("---------- TEST FUZZY REDEEM ----------");
        amount = bound(amount, 10, 1e15);
        deal(address(baseToken), user, amount);
        aaveV3Pool.deposit(amount, user);

        uint256 shares = aaveV3Pool.balanceOf(user);  // Redeem total shares
        uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 withdrawFee = shares.mulDiv(1, 10_000);
        uint256 reserveBefore = aaveV3Pool.reserves(address(aToken));
        
        vm.warp(block.timestamp + 1_000_000_000);
        aaveV3Pool.redeem(shares, user);

        uint256 addedReserve = aaveV3Pool.reserves(address(aToken)) - reserveBefore;
        uint256 burnedATokenShare = aTokenAfterDeposit - aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 dust = (shares - withdrawFee) - burnedATokenShare;

        assertEq(addedReserve, withdrawFee + dust);
        assertEq(aaveV3Pool.balanceOf(user), 0);
    }

    function testRedeemTooLarge() public {
        uint256 amount = 1e10;
        deal(address(baseToken), user, amount);
        aaveV3Pool.deposit(amount, user);

        uint256 shares = aaveV3Pool.balanceOf(user);
        vm.expectRevert(bytes("ERC20: burn amount exceeds balance"));
        aaveV3Pool.redeem(shares * 10**10, user);
    }

    function testRedeemInvalidAmount() public {
        uint256 amount = 1e10;
        deal(address(baseToken), user, amount);
        aaveV3Pool.deposit(amount, user);

        vm.expectRevert(bytes("26"));
        aaveV3Pool.redeem(0, user);
    }

    function testRedeemInvalidAddress() public {
        uint256 amount = 1e10;
        deal(address(baseToken), user, amount);
        aaveV3Pool.deposit(amount, user);

        vm.expectRevert(bytes("ERC20: transfer to the zero address"));
        aaveV3Pool.redeem(10_000, address(0));
    }
}