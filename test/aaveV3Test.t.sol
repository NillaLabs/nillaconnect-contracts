pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";
import "../contracts/lending_pools/AaveV3NillaLendingPool.sol";

import "../interfaces/IATokenV3.sol";

contract YVTest is Test {
    using SafeERC20 for IERC20;
    
    TransparentUpgradeableProxyImpl public proxy;
    address public impl;
    address public admin;
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address public executor = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    // zero-address
    address public ZERO_ADDRESS = address(0);

    uint256 public mainnetFork;

    IERC20 public baseToken;
    IATokenV3 public aToken = IATokenV3(0x7EfFD7b47Bfd17e52fB7559d3f924201b9DbfF3d);
    IAaveV3LendingPool public pool = IAaveV3LendingPool(0xfCc00A1e250644d89AF0df661bC6f04891E21585);

    AaveV3NillaLendingPool public aaveV3Pool;

    function setUp() public {
        mainnetFork = vm.createFork("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"); // ETH Mainnet
        vm.selectFork(mainnetFork);
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
    }

    function testDeposit() public {
        console.log("---------- TEST NORMAL DEPOSIT ----------");
        uint256 amount = 1e18;

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
}