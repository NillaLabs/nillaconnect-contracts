pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/IERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@4.7.3/contracts/token/ERC20/utils/SafeERC20.sol";

import "../contracts/ProxyAdminImpl.sol";
import "../contracts/TransparentUpgradeableProxyImpl.sol";
import "../contracts/lending_pools/CompoundNillaLendingPool.sol";

import "../interfaces/ICToken.sol";

contract CompoundTest is Test {
    using SafeERC20 for IERC20;

    TransparentUpgradeableProxyImpl public proxy;
    address public impl;
    address public admin;
    address public user = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    uint256 public mainnetFork;

    IERC20 public baseToken;
    ICToken public cToken = ICToken(0xC11b1268C1A384e55C48c2391d8d480264A3A7F4);

    CompoundNillaLendingPool public nilla;

    function setUp() public {
        mainnetFork = vm.createFork(
            "https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161"
        );
        vm.selectFork(mainnetFork);
        startHoax(user);

        admin = address(new ProxyAdminImpl());
        impl = address(new CompoundNillaLendingPool());

        proxy = new TransparentUpgradeableProxyImpl(
            impl,
            admin,
            abi.encodeWithSelector(
                CompoundNillaLendingPool.initialize.selector,
                address(cToken),
                "Compound - XXX",
                "XXX",
                1,
                1
            )
        );

        nilla = CompoundNillaLendingPool(address(proxy));
        baseToken = nilla.baseToken();

        vm.label(address(nilla), "#### Nilla ####");
        vm.label(address(baseToken), "#### Base Token ####");
        vm.label(address(cToken), "#### cToken ####");
    }

    function testDeposit() public {
        console.log('DONE');
    }
}