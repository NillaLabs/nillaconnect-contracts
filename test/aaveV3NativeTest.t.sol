pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImplAave.sol";
import "../contracts/lending_pools/AaveV3NillaLendingPoolETH.sol";

import "../interfaces/IATokenV3.sol";
import "../interfaces/IRewardsController.sol";
import "../../interfaces/IWrappedTokenGatewayV3.sol";
import "../interfaces/IJoeRouter.sol";
import "../interfaces/IWNative.sol";

contract AaveV3NativeTest is Test {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    TransparentUpgradeableProxyImplAave public proxy;
    address public impl;
    address public admin;
    // address public rewarder = 0xA68eEB34418871d844a1301F97353cB20343B65d; // someone who has rewards on AAVE.
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public executor = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address public WETH = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    uint256 public avalancheFork;
    IERC20 public baseToken;
    IATokenV3 public aToken = IATokenV3(0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97); // WAVAX
    IAaveV3LendingPool public pool = IAaveV3LendingPool(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    IRewardsController rewardsController = IRewardsController(0x929EC64c34a17401F460460D4B9390518E5B473e);
    IWrappedTokenGatewayV3 gateway = IWrappedTokenGatewayV3(0x6F143FE2F7B02424ad3CaD1593D6f36c0Aab69d7);
    IJoeRouter swapRouter = IJoeRouter(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);

    AaveV3NillaLendingPoolETH public aaveV3Pool;

    struct AaveObj {
        address aToken;
        address lendingPool;
        address gateway;
        address rewardsController;
    }

    function setUp() public {
        avalancheFork = vm.createFork("https://avalanche-mainnet.infura.io/v3/e6282a54498e433a87766276d1d4b67b"); // Avalanche
        vm.selectFork(avalancheFork);
        startHoax(user);

        vm.label(user, "#### User ####");
        vm.label(address(pool), "#### Aave Pool ####");
        vm.label(address(aToken), "#### AToken ####");
        vm.label(WETH, "#### WETH ####");
        vm.label(address(rewardsController), "#### Reward Controller ####");
        vm.label(address(swapRouter), "#### Swap Router ####");
        vm.label(address(gateway), "#### Gateway ####");

        admin = address(new ProxyAdminImpl());
        impl  = address(new AaveV3NillaLendingPoolETH());

        AaveObj memory _aaveObj;
        _aaveObj.aToken = address(aToken);
        _aaveObj.lendingPool = address(pool);
        _aaveObj.gateway = address(gateway);
        _aaveObj.rewardsController = address(rewardsController);

        proxy = new TransparentUpgradeableProxyImplAave(
            impl,
            admin,
            abi.encodeWithSelector(
                AaveV3NillaLendingPoolETH.initialize.selector,
                _aaveObj,
                address(swapRouter),
                "USDC Vault",
                "USDC",
                1,    // Deposit Fee BPS
                1,    // Withdraw Fee BPS  
                1,    // Harvest Fee BPS
                executor,
                address(0)),
            address(gateway)
        );
        aaveV3Pool = AaveV3NillaLendingPoolETH(payable(address(proxy)));
        aaveV3Pool.setWorker(user);
        baseToken = IERC20(aaveV3Pool.baseToken());

        baseToken.safeApprove(address(aaveV3Pool), type(uint256).max);

        vm.label(address(aaveV3Pool), "#### Nilla ####");
        vm.label(address(baseToken), "#### BaseToken ####");
    }

    function testDepositNormal() public {
        console.log("---------- TEST NORMAL DEPOSIT ----------");
        uint256 amount = 1e19;

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 reserveBefore = aaveV3Pool.reserves(address(aToken));

        aaveV3Pool.deposit{value: amount}(user);

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
        amount = bound(amount, 1e15, 1e24);

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 reserveBefore = aaveV3Pool.reserves(address(aToken));

        aaveV3Pool.deposit{value: amount}(user);

        uint256 aTokenAfter = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 reserveAfter = aaveV3Pool.reserves(address(aToken));
        uint256 depositFee = (aTokenAfter - aTokenBefore) * 1 / 10_000;

        assertEq(reserveAfter - reserveBefore, depositFee);
        assertEq(aaveV3Pool.balanceOf(user), aTokenAfter - depositFee); 
    }

    function testDepositTooLarge() public {
        uint256 amount = 1e50;
        vm.expectRevert();
        aaveV3Pool.deposit{value: amount}(user);
    }

    function testDepositInvalidAmount() public {
        uint256 amount = 0;
        vm.expectRevert();
        aaveV3Pool.deposit{value: amount}(user);
    }

    function testDepositInvalidAddress() public {
        uint256 amount = 1_000;
        deal(address(baseToken), user, amount);
        vm.expectRevert();
        aaveV3Pool.deposit{value: amount}(address(0));
    }

    function testRedeemNormal() public {
        console.log("---------- TEST NORMAL REDEEM ----------");
        uint256 amount = 999999999000000000505787;
        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 balanceBefore = user.balance;

        aaveV3Pool.deposit{value: amount}(user);
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
    
        uint256 aTokenAfterRedeem = aToken.scaledBalanceOf(address(aaveV3Pool));

        console.log("LP balance in aave before deposit:", aTokenBefore);
        console.log("LP balance in aave after deposit:", aTokenAfterDeposit);
        console.log("LP balance in aave after redeem:", aTokenAfterRedeem);
        console.log("User Balance Before D:", balanceBefore);
        console.log("User Balance After  W:", user.balance);
    }

    function testFuzzyRedeem(uint256 amount) public {
        console.log("---------- TEST FUZZY REDEEM ----------");
        amount = bound(amount, 1e15, 1e24);
        aaveV3Pool.deposit{value: amount}(user);

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
        aaveV3Pool.deposit{value: amount}(user);

        uint256 shares = aaveV3Pool.balanceOf(user);
        vm.expectRevert();
        aaveV3Pool.redeem(shares * 10**10, user);
    }

    function testRedeemInvalidAmount() public {
        uint256 amount = 1e10;
        aaveV3Pool.deposit{value: amount}(user);

        vm.expectRevert();
        aaveV3Pool.redeem(0, user);
    }

    function testRedeemInvalidAddress() public {
        uint256 amount = 1e10;
        aaveV3Pool.deposit{value: amount}(user);

        vm.expectRevert();
        aaveV3Pool.redeem(10_000, address(0));
    }

    function testReinvest() public {
        console.log("---------- TEST NORMAL REDEEM ----------");
        uint256 amount = 1e19;

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        aaveV3Pool.deposit{value: amount}(user);
        uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV3Pool));

        vm.stopPrank();
        vm.startPrank(address(aToken));
        rewardsController.handleAction(address(aaveV3Pool), aToken.totalSupply(), aToken.scaledBalanceOf(address(aaveV3Pool)));

        vm.warp(block.timestamp + 1_000_000);

        rewardsController.handleAction(address(aaveV3Pool), aToken.totalSupply(), aToken.scaledBalanceOf(address(aaveV3Pool)));
        vm.stopPrank();
        startHoax(user);

        aaveV3Pool.reinvest();
        uint256 aTokenAfterReinvest = aToken.scaledBalanceOf(address(aaveV3Pool));

        console.log("LP balance in aave before deposit:", aTokenBefore);
        console.log("LP balance in aave after deposit:", aTokenAfterDeposit);
        console.log("LP balance in aave after redeem:", aTokenAfterReinvest);
    }
}