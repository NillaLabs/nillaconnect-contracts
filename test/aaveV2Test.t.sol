// pragma solidity ^0.8.17;

// import "forge-std/Test.sol";
// import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
// import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

// import "../contracts/ProxyAdminImpl.sol";
// import "../contracts/TransparentUpgradeableProxyImpl.sol";
// import "../contracts/lending_pools/AaveV2NillaLendingPool.sol";

// import "../interfaces/IAToken.sol";
// import "../interfaces/IWNative.sol";

// contract AaveV2Test is Test {
//     using SafeERC20 for IERC20;
//     using Math for uint256;

//     TransparentUpgradeableProxyImpl public proxy;
//     address public impl;
//     address public admin;
//     address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
//     address public WETH = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
//     uint256 public mainnetFork;

//     IERC20 public baseToken;
//     IAToken public aToken = IAToken(0x028171bCA77440897B824Ca71D1c56caC55b68A3);

//     AaveV2NillaLendingPool public aaveV2Pool;

//     function setUp() public {
//         mainnetFork = vm.createFork(
//             "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
//         );
//         vm.selectFork(mainnetFork);
//         startHoax(user);

//         vm.label(user, "#### User ####");
//         vm.label(address(aToken), "#### AToken ####");
//         vm.label(WETH, "#### WETH ####");

//         admin = address(new ProxyAdminImpl());
//         impl = address(new AaveV2NillaLendingPool());

//         proxy = new TransparentUpgradeableProxyImpl(
//             impl,
//             admin,
//             abi.encodeWithSelector(
//                 AaveV2NillaLendingPool.initialize.selector,
//                 address(aToken),
//                 "AAVE V2 - DAI",
//                 "naDAI",
//                 1,
//                 1,
//                 500
//             )
//         );

//         aaveV2Pool = AaveV2NillaLendingPool(payable(address(proxy)));
//         aaveV2Pool.setWorker(user);
//         baseToken = IERC20(aaveV2Pool.baseToken());

//         baseToken.safeApprove(address(aaveV2Pool), type(uint256).max);

//         vm.label(address(aaveV2Pool), "#### Nilla ####");
//         vm.label(address(baseToken), "#### BaseToken ####");
//     }

//     function testDepositNormal() public {
//         console.log("---------- TEST NORMAL DEPOSIT ----------");
//         uint256 amount = 1e20;
//         deal(address(baseToken), user, amount);

//         uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 reserveBefore = aaveV2Pool.reserves(address(aToken));

//         aaveV2Pool.deposit(amount, user);

//         uint256 aTokenAfter = aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 reserveAfter = aaveV2Pool.reserves(address(aToken));
//         uint256 depositFee = ((aTokenAfter - aTokenBefore) * 1) / 10_000;

//         assertEq(reserveAfter - reserveBefore, depositFee);
//         assertEq(aaveV2Pool.balanceOf(user), aTokenAfter - depositFee);
//         assertEq(
//             aaveV2Pool.reserves(address(aToken)) + aaveV2Pool.totalSupply(),
//             aToken.scaledBalanceOf(address(aaveV2Pool))
//         );
//         assertEq(
//             aaveV2Pool.principals(user),
//             aaveV2Pool.balanceOf(user).mulDiv(
//                 IAaveLendingPoolV2(aToken.POOL()).getReserveNormalizedIncome(address(baseToken)),
//                 1e27,
//                 Math.Rounding.Up
//             )
//         );

//         console.log("LP balance in aave before:", aTokenBefore);
//         console.log("LP balance in aave after:", aTokenAfter);
//         console.log("Reserves before:", reserveBefore);
//         console.log("Reserves after:", reserveAfter);
//     }

//     function testFuzzyDeposit(uint256 amount) public {
//         console.log("---------- TEST FUZZY DEPOSIT ----------");
//         amount = bound(amount, 1e16, 1e25);
//         deal(address(baseToken), user, amount);

//         uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 reserveBefore = aaveV2Pool.reserves(address(aToken));

//         aaveV2Pool.deposit(amount, user);

//         uint256 aTokenAfter = aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 reserveAfter = aaveV2Pool.reserves(address(aToken));
//         uint256 depositFee = ((aTokenAfter - aTokenBefore) * 1) / 10_000;

//         assertEq(reserveAfter - reserveBefore, depositFee);
//         assertEq(aaveV2Pool.balanceOf(user), aTokenAfter - depositFee);
//         assertEq(
//             aaveV2Pool.reserves(address(aToken)) + aaveV2Pool.totalSupply(),
//             aToken.scaledBalanceOf(address(aaveV2Pool))
//         );
//         assertEq(
//             aaveV2Pool.principals(user),
//             aaveV2Pool.balanceOf(user).mulDiv(
//                 IAaveLendingPoolV2(aToken.POOL()).getReserveNormalizedIncome(address(baseToken)),
//                 1e27,
//                 Math.Rounding.Up
//             )
//         );
//     }

//     function testDepositTooLarge() public {
//         uint256 amount = 1e70;
//         deal(address(baseToken), user, amount);
//         vm.expectRevert();
//         aaveV2Pool.deposit(amount, user);
//     }

//     function testDepositInvalidAmount() public {
//         uint256 amount = 0;
//         deal(address(baseToken), user, amount);
//         vm.expectRevert();
//         aaveV2Pool.deposit(amount, user);
//     }

//     function testDepositInvalidAddress() public {
//         uint256 amount = 1_000;
//         deal(address(baseToken), user, amount);
//         vm.expectRevert(bytes("ERC20: mint to the zero address"));
//         aaveV2Pool.deposit(amount, address(0));
//     }

//     function testRedeemNormal() public {
//         console.log("---------- TEST NORMAL REDEEM ----------");
//         uint256 amount = 1e20;
//         deal(address(baseToken), user, amount);
//         uint256 baseTokenBefore = baseToken.balanceOf(user);

//         aaveV2Pool.deposit(amount, user);
//         uint256 principal = aaveV2Pool.principals(user);
//         uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 shares = aaveV2Pool.balanceOf(user); // Redeem total shares
//         uint256 withdrawFee = shares.mulDiv(1, 10_000);
//         uint256 reserveBefore = aaveV2Pool.reserves(address(aToken));

//         assertEq(
//             aaveV2Pool.reserves(address(aToken)) + aaveV2Pool.totalSupply(),
//             aToken.scaledBalanceOf(address(aaveV2Pool))
//         );

//         vm.warp(block.timestamp + 10_000_000);

//         uint256 currentBal = shares.mulDiv(
//             IAaveLendingPoolV2(aToken.POOL()).getReserveNormalizedIncome(address(baseToken)),
//             1e27,
//             Math.Rounding.Down
//         );
//         uint256 profit = currentBal > principal ? (currentBal - principal) : 0;
//         uint256 performanceFee = (profit * 500) / 10_000;
//         withdrawFee += performanceFee.mulDiv(
//             1e27,
//             IAaveLendingPoolV2(aToken.POOL()).getReserveNormalizedIncome(address(baseToken)),
//             Math.Rounding.Down
//         );

//         aaveV2Pool.redeem(shares, user);

//         uint256 addedReserve = aaveV2Pool.reserves(address(aToken)) - reserveBefore;
//         uint256 burnedATokenShare = aTokenAfterDeposit -
//             aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 dust = (shares - withdrawFee) - burnedATokenShare;

//         assertEq(addedReserve, withdrawFee + dust);
//         assertEq(aaveV2Pool.balanceOf(user), 0);
//         assertEq(
//             aaveV2Pool.reserves(address(aToken)) + aaveV2Pool.totalSupply(),
//             aToken.scaledBalanceOf(address(aaveV2Pool))
//         );

//         uint256 baseTokenAfter = baseToken.balanceOf(user);
//         uint256 aTokenAfterRedeem = aToken.scaledBalanceOf(address(aaveV2Pool));

//         console.log("LP balance in aave after deposit:", aTokenAfterDeposit);
//         console.log("LP balance in aave after redeem:", aTokenAfterRedeem);
//         console.log("Base Token Before deposit:", baseTokenBefore);
//         console.log("Base Token After withdraw:", baseTokenAfter);
//     }

//     function testFuzzyRedeem(uint256 amount) public {
//         console.log("---------- TEST FUZZY REDEEM ----------");
//         amount = bound(amount, 1e16, 1e25);
//         deal(address(baseToken), user, amount);
//         aaveV2Pool.deposit(amount, user);
//         uint256 principal = aaveV2Pool.principals(user);
//         uint256 shares = aaveV2Pool.balanceOf(user); // Redeem total shares
//         uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 withdrawFee = shares.mulDiv(1, 10_000);
//         uint256 reserveBefore = aaveV2Pool.reserves(address(aToken));

//         assertEq(
//             aaveV2Pool.reserves(address(aToken)) + aaveV2Pool.totalSupply(),
//             aToken.scaledBalanceOf(address(aaveV2Pool))
//         );

//         vm.warp(block.timestamp + 1_000_000);

//         uint256 currentBal = shares.mulDiv(
//             IAaveLendingPoolV2(aToken.POOL()).getReserveNormalizedIncome(address(baseToken)),
//             1e27,
//             Math.Rounding.Down
//         );
//         uint256 profit = currentBal > principal ? (currentBal - principal) : 0;
//         uint256 performanceFee = (profit * 500) / 10_000;
//         withdrawFee += performanceFee.mulDiv(
//             1e27,
//             IAaveLendingPoolV2(aToken.POOL()).getReserveNormalizedIncome(address(baseToken)),
//             Math.Rounding.Down
//         );

//         aaveV2Pool.redeem(shares, user);

//         uint256 addedReserve = aaveV2Pool.reserves(address(aToken)) - reserveBefore;
//         uint256 burnedATokenShare = aTokenAfterDeposit -
//             aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 dust = (shares - withdrawFee) - burnedATokenShare;

//         assertEq(
//             aaveV2Pool.reserves(address(aToken)) + aaveV2Pool.totalSupply(),
//             aToken.scaledBalanceOf(address(aaveV2Pool))
//         );
//         assertEq(addedReserve, withdrawFee + dust);
//         assertEq(aaveV2Pool.balanceOf(user), 0);
//     }

//     function testRedeemTooLarge() public {
//         uint256 amount = 1e18;
//         deal(address(baseToken), user, amount);
//         aaveV2Pool.deposit(amount, user);

//         uint256 shares = aaveV2Pool.balanceOf(user);
//         vm.expectRevert();
//         aaveV2Pool.redeem(shares * 10 ** 10, user);
//     }

//     function testRedeemInvalidAmount() public {
//         uint256 amount = 1e10;
//         deal(address(baseToken), user, amount);
//         aaveV2Pool.deposit(amount, user);

//         vm.expectRevert();
//         aaveV2Pool.redeem(0, user);
//     }

//     function testRedeemInvalidAddress() public {
//         uint256 amount = 1e10;
//         deal(address(baseToken), user, amount);
//         aaveV2Pool.deposit(amount, user);

//         vm.expectRevert(bytes("ERC20: burn from the zero address"));
//         aaveV2Pool.redeem(10_000, address(0));
//     }

//     function testWithdrawReserve() public {
//         uint256 amount = 1e20;
//         deal(address(baseToken), user, amount);

//         aaveV2Pool.deposit(amount, user);
//         uint256 reserveB = aaveV2Pool.reserves(address(aToken));
//         uint256 amountToWithdraw = (reserveB * 9) / 10;
//         uint256 aTokenShareBefore = aToken.scaledBalanceOf(address(aaveV2Pool));
//         aaveV2Pool.withdrawReserve(address(aToken), amountToWithdraw); // withdraw 90%
//         uint256 aTokenShareAfter = aToken.scaledBalanceOf(address(aaveV2Pool));
//         uint256 transferedATokenShare = aTokenShareBefore - aTokenShareAfter;
//         uint256 reserveA = aaveV2Pool.reserves(address(aToken));
//         // User(Worker) has 0 at first
//         assertEq(aToken.balanceOf(user), amountToWithdraw);
//         assertEq(reserveA, reserveB - transferedATokenShare);
//     }
// }
