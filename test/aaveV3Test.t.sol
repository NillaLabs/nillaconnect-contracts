pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";
import "../contracts/lending_pools/AaveV3NillaLendingPool.sol";

import "../interfaces/IATokenV3.sol";

contract AaveV3Test is Test {
    using SafeERC20 for IERC20;
    
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

    AaveV3NillaLendingPool public aaveV3Pool;

    function setUp() public {
        avalancheFork = vm.createFork("https://avalanche-mainnet.infura.io/v3/e6282a54498e433a87766276d1d4b67b"); // Avalanche
        vm.selectFork(avalancheFork);
        startHoax(user);

        admin = address(new ProxyAdminImpl());
        impl  = address(new AaveV3NillaLendingPool());

        proxy = new TransparentUpgradeableProxyImpl(
            impl,
            admin,
            abi.encodeWithSelector(
                AaveV3NillaLendingPool.initialize.selector,
                address(pool),
                address(aToken),
                "USDC Vault",
                "USDC",
                1,
                1,
                executor,
                address(0))
        );

        aaveV3Pool = AaveV3NillaLendingPool(address(proxy));
        baseToken = IERC20(aaveV3Pool.baseToken());

        baseToken.safeApprove(address(aaveV3Pool), type(uint256).max);

        vm.label(user, "#### User ####");
        vm.label(address(aaveV3Pool), "#### Nilla ####");
        vm.label(address(baseToken), "#### BaseToken ####");
        vm.label(address(pool), "#### Aave Pool ####");
        vm.label(address(aToken), "#### AToken ####");
        vm.label(WAVAX, "#### WAVAX ####");
    }

    function testDeposit() public {
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

    function testRedeem() public {
        console.log("---------- TEST NORMAL REDEEM ----------");
        uint256 amount = 1e15;
        deal(address(baseToken), user, amount);

        uint256 aTokenBefore = aToken.scaledBalanceOf(address(aaveV3Pool));
        uint256 baseTokenBefore = baseToken.balanceOf(user);

        aaveV3Pool.deposit(amount, user);

        uint256 receivedAToken = aToken.scaledBalanceOf(address(aaveV3Pool)) - aTokenBefore;
        uint256 depositFee = (receivedAToken - aTokenBefore) * 1 / 10_000;
        uint256 shares = receivedAToken - depositFee;
        uint256 aTokenAfterDeposit = aToken.scaledBalanceOf(address(aaveV3Pool));

        vm.warp(block.timestamp + 1_000_000_000);
        aaveV3Pool.redeem(shares, user);

        uint256 baseTokenAfter = baseToken.balanceOf(user);
        uint256 aTokenAfterRedeem = aToken.scaledBalanceOf(address(aaveV3Pool));

        console.log("LP balance in aave after deposit:", aTokenAfterDeposit);
        console.log("LP balance in aave after redeem:", aTokenAfterRedeem);
        console.log("Base Token Before deposit:", baseTokenBefore);
        console.log("Base Token After withdraw:", baseTokenAfter);
        console.log("WAVAX Balance:", IERC20(WAVAX).balanceOf(user));
        console.log("WAVAX Balance in Nilla:", IERC20(WAVAX).balanceOf(address(aaveV3Pool)));
    }
}