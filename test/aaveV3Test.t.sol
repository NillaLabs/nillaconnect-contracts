pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImplNative.sol";
import "../contracts/lending_pools/AaveV3NillaLendingPool.sol";

import "../interfaces/IAToken.sol";
import "../interfaces/IRewardsController.sol";
import "../interfaces/IUniswapRouterV2.sol";
import "../interfaces/IWNative.sol";

contract AaveV3Test is Test {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    TransparentUpgradeableProxyImplNative public proxy;
    address public impl;
    address public admin;
    address public rewarder = 0xA68eEB34418871d844a1301F97353cB20343B65d; // someone who has rewards on AAVE.
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bot = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    address public WETH = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;

    // zero-address
    address public ZERO_ADDRESS = address(0);

    uint256 public avalancheFork;

    IERC20 public baseToken;
    IAToken public aToken = IAToken(0x6ab707Aca953eDAeFBc4fD23bA73294241490620);
    IRewardsController rewardsController = IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);
    IUniswapRouterV2 swapRouter = IUniswapRouterV2(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);

    AaveV3NillaLendingPool public aaveV3Pool;

    function setUp() public {
        avalancheFork = vm.createFork("https://avalanche-mainnet.infura.io/v3/e6282a54498e433a87766276d1d4b67b"); // Avalanche
        vm.selectFork(avalancheFork);
        startHoax(user);

        vm.label(user, "#### User ####");
        vm.label(address(aToken), "#### AToken ####");
        vm.label(WETH, "#### WETH ####");
        vm.label(address(rewardsController), "#### Reward Controller ####");
        vm.label(address(swapRouter), "#### Swap Router ####");

        admin = address(new ProxyAdminImpl());
        impl  = address(new AaveV3NillaLendingPool(
                            address(rewardsController),
                            address(WETH),
                            address(aToken)
                        ));

        proxy = new TransparentUpgradeableProxyImplNative(
            impl,
            admin,
            abi.encodeWithSelector(
                AaveV3NillaLendingPool.initialize.selector,
                address(aToken),
                address(swapRouter),
                bot,
                "Nilla-AaveV3 USDT LP",
                "nUSDT",
                1,
                1,
                1
            ),
            WETH
        );
        aaveV3Pool = AaveV3NillaLendingPool(payable(address(proxy)));
        aaveV3Pool.setWorker(user);
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
        
        vm.warp(block.timestamp + 1_000_000);
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
    }

    function testFuzzyRedeem(uint256 amount) public {
        console.log("---------- TEST FUZZY REDEEM ----------");
        amount = bound(amount, 10, 1e13);
        deal(address(baseToken), user, amount);
        aaveV3Pool.deposit(amount, user);

        uint256 shares = aaveV3Pool.balanceOf(user);  // Redeem total shares
        uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 withdrawFee = shares.mulDiv(1, 10_000);
        uint256 reserveBefore = aaveV3Pool.reserves(address(aToken));
        
        vm.warp(block.timestamp + 1_000_000);
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

        vm.expectRevert(bytes("ERC20: burn from the zero address"));
        aaveV3Pool.redeem(10_000, address(0));
    }

    function testReinvest() public {
        console.log("---------- TEST NORMAL REDEEM ----------");
        uint256 amount = 1e9;
        deal(address(baseToken), user, amount);

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        aaveV3Pool.deposit(amount, user);
        uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV3Pool));

        vm.stopPrank();
        vm.startPrank(address(aToken));
        rewardsController.handleAction(address(aaveV3Pool), aToken.totalSupply(), aToken.scaledBalanceOf(address(aaveV3Pool)));

        vm.warp(block.timestamp + 1_000_000);

        rewardsController.handleAction(address(aaveV3Pool), aToken.totalSupply(), aToken.scaledBalanceOf(address(aaveV3Pool)));
        vm.stopPrank();
        startHoax(bot);

        address[] memory _path = new address[](2);
        _path[0] = WETH;
        _path[1] = address(baseToken);
        uint256 _deadline = block.timestamp + 1000;

        aaveV3Pool.reinvest(100, _path, _deadline);
        uint256 aTokenAfterReinvest = aToken.scaledBalanceOf(address(aaveV3Pool));

        console.log("LP balance in aave before deposit:", aTokenBefore);
        console.log("LP balance in aave after deposit:", aTokenAfterDeposit);
        console.log("LP balance in aave after reinvest:", aTokenAfterReinvest);
    }

    function testWithdrawReserve() public {
        uint256 amount = 1e9;
        deal(address(baseToken), user, amount);

        aaveV3Pool.deposit(amount, user);
        uint256 reserveB = aaveV3Pool.reserves(address(aToken));
        uint256 amountToWithdraw = reserveB * 9 / 10;
        uint256 aTokenShareBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        aaveV3Pool.withdrawReserve(address(aToken), amountToWithdraw); // withdraw 90%
        uint256 aTokenShareAfter = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 transferedATokenShare = aTokenShareBefore - aTokenShareAfter;
        uint256 reserveA = aaveV3Pool.reserves(address(aToken));
        // User(Worker) has 0 at first
        assertEq(aToken.balanceOf(user), amountToWithdraw);
        assertEq(reserveA, reserveB - transferedATokenShare);
    }
}