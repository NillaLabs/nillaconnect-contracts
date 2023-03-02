pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImplNative.sol";
import "../contracts/liquidity_staking/LidoNillaLiquidityStaking.sol";

import "../interfaces/ILido.sol";

contract LidoTest is Test {
    using SafeERC20 for IERC20;
    using Math for uint256;
    
    TransparentUpgradeableProxyImplNative public proxy;
    address public impl;
    address public admin;
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    address public executor = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    uint256 public mainnetFork;

    IERC20 public baseToken;
    IWNative public WETH = IWNative(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ILido public lido = ILido(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IUniswapRouterV2 swapRouter = IUniswapRouterV2(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    LidoNillaLiquidityStaking public nilla;

    function setUp() public {
        mainnetFork = vm.createFork("https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"); // Avalanche
        vm.selectFork(mainnetFork);
        startHoax(user);

        admin = address(new ProxyAdminImpl());
        impl  = address(new LidoNillaLiquidityStaking());

        proxy = new TransparentUpgradeableProxyImplNative(
            impl,
            admin,
            abi.encodeWithSelector(
                LidoNillaLiquidityStaking.initialize.selector,
                address(lido),
                address(swapRouter),
                address(WETH),
                "ETH Staking",
                "ETH",
                1,
                1,
                executor,
                address(0)),
            address(WETH)
        );

        nilla = LidoNillaLiquidityStaking(payable(address(proxy)));
        baseToken = nilla.baseToken();

        vm.label(address(nilla), "#### Nilla ####");
        vm.label(address(baseToken), "#### Lido / stETH ####");
    }

    function testDeposit() public {
        uint256 amount = 1e19;
        
        uint256 baseBefore = lido.balanceOf(address(nilla));
        uint256 reserveBefore = nilla.reserves(address(lido));

        nilla.deposit{value: amount}(user);

        uint256 reserveAfter = nilla.reserves(address(lido));
        uint256 baseAfter = lido.balanceOf(address(nilla));
        uint256 depositFee = (baseAfter - baseBefore) * 1 / 10_000;

        console.log("Base B:", baseBefore);
        console.log("Base A:", baseAfter);
        console.log("Reserve B:", reserveBefore);
        console.log("Reserve A:", reserveAfter);
        console.log("Deposit Fee:", depositFee);

        assertEq(reserveAfter - reserveBefore, depositFee);
        assertEq(nilla.balanceOf(user), baseAfter - depositFee);
    }

}