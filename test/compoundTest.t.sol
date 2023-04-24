pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImplNative.sol";
import "../contracts/lending_pools/CompoundNillaLendingPool.sol";

import "../interfaces/ICToken.sol";

contract CompoundTest is Test {
    using SafeERC20 for IERC20;

    TransparentUpgradeableProxyImplNative public proxy;
    address public impl;
    address public admin;
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public bot = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    uint256 public mainnetFork;

    address public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public swapRouter = 0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F; // Sushi SwapRouter --UniV2 forked.

    IERC20 public baseToken;
    ICToken public cToken = ICToken(0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643);
    address public comptroller = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;

    CompoundNillaLendingPool public nilla;

    function setUp() public {
        mainnetFork = vm.createFork(
            "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
        );
        vm.selectFork(mainnetFork);
        startHoax(user);

        admin = address(new ProxyAdminImpl());
        impl = address(new CompoundNillaLendingPool(comptroller, WETH));

        proxy = new TransparentUpgradeableProxyImplNative(
            impl,
            admin,
            abi.encodeWithSelector(
                CompoundNillaLendingPool.initialize.selector,
                address(cToken),
                swapRouter,
                bot,
                "Compound - DAI",
                "ncDAI",
                1,
                1,
                1,
                500
            ),
            WETH
        );

        nilla = CompoundNillaLendingPool(address(proxy));
        baseToken = nilla.baseToken();
        baseToken.safeApprove(address(nilla), type(uint256).max);

        vm.label(address(nilla), "#### Nilla ####");
        vm.label(address(baseToken), "#### Base Token ####");
        vm.label(address(cToken), "#### cToken ####");
    }

    function testDeposit() public {
        console.log("---------- TEST NORMAL DEPOSIT ----------");
        uint256 amount = 1e18;
        deal(address(baseToken), user, amount);

        uint256 balanceBefore = cToken.balanceOf(address(nilla));
        uint256 reservesBefore = nilla.reserves(address(cToken));

        nilla.deposit(amount, user);

        uint256 balanceAfter = cToken.balanceOf(address(nilla));
        uint256 reservesAfter = nilla.reserves(address(cToken));
        uint256 depositFee = ((balanceAfter - balanceBefore) * 1) / 10_000; //depositFeeBPS = 0.01%, BPS = 100%

        assertEq(reservesAfter - reservesBefore, depositFee);
        assertEq(nilla.balanceOf(user), balanceAfter - depositFee);
        assertEq(
            nilla.reserves(address(cToken)) + nilla.totalSupply(),
            cToken.balanceOf(address(nilla))
        );
        assertEq(
            nilla.principals(user),
            uint256(cToken.exchangeRateCurrent()) * nilla.balanceOf(user)
        );
    }

    function testFuzzyDeposit(uint256 amount) public {
        amount = bound(amount, 10_000, 1e50);
        deal(address(baseToken), user, amount);

        uint256 balanceBefore = cToken.balanceOf(address(nilla));
        uint256 reservesBefore = nilla.reserves(address(cToken));

        nilla.deposit(amount, user);

        uint256 balanceAfter = cToken.balanceOf(address(nilla));
        uint256 reservesAfter = nilla.reserves(address(cToken));
        uint256 depositFee = ((balanceAfter - balanceBefore) * 1) / 10_000; //depositFeeBPS = 0.01%, BPS = 100%

        assertEq(reservesAfter - reservesBefore, depositFee);
        assertEq(nilla.balanceOf(user), balanceAfter - depositFee);
        assertEq(reservesAfter - reservesBefore, depositFee);
        assertEq(
            nilla.reserves(address(cToken)) + nilla.totalSupply(),
            cToken.balanceOf(address(nilla))
        );
        assertEq(
            nilla.principals(user),
            uint256(cToken.exchangeRateCurrent()) * nilla.balanceOf(user)
        );
    }

    function testDepositToZeroAddress() public {
        uint256 amount = 1e5;
        deal(address(baseToken), user, amount);
        vm.expectRevert();
        nilla.deposit(amount, address(0));
    }

    function testRedeemNormal() public {
        uint256 amount = 1e18;
        deal(address(baseToken), user, amount);

        nilla.deposit(amount, user);

        uint256 principal = nilla.principals(user);
        uint256 reserveBefore = nilla.reserves(address(cToken));
        uint256 shares = nilla.balanceOf(user);
        uint256 withdrawFee = (shares * 1) / 10_000;

        vm.roll(block.number + 20);

        uint256 currentBal = nilla.balanceOf(user) * uint256(cToken.exchangeRateCurrent());
        uint256 profit = currentBal > principal ? (currentBal - principal) : 0;
        uint256 fee = (profit * 500) / 10_000;
        withdrawFee += fee / uint256(cToken.exchangeRateCurrent());

        nilla.redeem(shares, user);

        uint256 reserveAfter = nilla.reserves(address(cToken));

        assertEq(reserveAfter - reserveBefore, withdrawFee);
        assertEq(
            nilla.reserves(address(cToken)) + nilla.totalSupply(),
            cToken.balanceOf(address(nilla))
        );
        assertEq(
            nilla.principals(user),
            uint256(cToken.exchangeRateCurrent()) * nilla.balanceOf(user)
        );
    }

    function testFuzzyRedeem(uint256 amount) public {
        amount = bound(amount, 1e5, 1e30);
        deal(address(baseToken), user, amount);
        nilla.deposit(amount, user);

        uint256 reserveBefore = nilla.reserves(address(cToken));
        uint256 shares = nilla.balanceOf(user);
        uint256 withdrawFee = (shares * 1) / 10_000;

        vm.roll(block.number + 20);
        nilla.redeem(shares, user);
        uint256 reserveAfter = nilla.reserves(address(cToken));
        assertEq(reserveAfter - reserveBefore, withdrawFee);
    }

    function testReinvest() public {
        console.log("---------- TEST REINVEST ----------");
        uint256 amount = 1e20;
        deal(address(baseToken), user, amount);

        uint256 cTokenBefore = cToken.balanceOf(address(nilla));
        nilla.deposit(amount, user);
        uint256 cTokenAfterDeposit = cToken.balanceOf(address(nilla));

        vm.roll(block.number + 100);
        vm.stopPrank();
        startHoax(bot);

        address[] memory _path = new address[](2);
        _path[0] = address(nilla.COMP());
        //_path[1] = address(WETH);
        _path[1] = address(baseToken);
        uint256 _deadline = block.timestamp + 1000;

        uint256 compAmount = IERC20(nilla.COMP()).balanceOf(address(nilla));
        uint256 minCompAmount = (compAmount * 9) / 10;

        uint256 botBalanceB = bot.balance;
        nilla.reinvest(minCompAmount, (minCompAmount * 1) / 10_000, _path, _deadline);
        uint256 botBalanceA = bot.balance;
        uint256 cTokenAfterReinvest = cToken.balanceOf(address(nilla));

        console.log("LP balance in aave before deposit:", cTokenBefore);
        console.log("LP balance in aave after deposit:", cTokenAfterDeposit);
        console.log("LP balance in aave after reinvest:", cTokenAfterReinvest);
        console.log("Balance in Bot Before:", botBalanceB);
        console.log("Balance in Bot After:", botBalanceA);
        console.log("Bot received:", botBalanceA - botBalanceB);
    }
}
