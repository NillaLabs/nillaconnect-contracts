import click
import eth_utils

from brownie import accounts, network, interface, ZERO_ADDRESS
from brownie import ProxyAdminImpl, YearnNillaVault, TransparentUpgradeableProxyImpl

network.priority_fee("2 gwei")

def encode_function_data(initializer=None, *args):
    if len(args) == 0 or not initializer:
        return eth_utils.to_bytes(hexstr="0x")
    return initializer.encode_input(*args)

def main():
    print(f"Network: '{network.show_active()}'")
    # deployer = accounts[1]
    # dev = accounts.load(click.prompt("Account", type=click.Choice(accounts.load())))
    deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    print(f"Using account: [{deployer}]")

    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = YearnNillaVault.deploy({'from': deployer})
    yv_token = interface.IYVToken("0xa258C4606Ca8206D8aA700cE2143D7db854D168c")
    yearn_partner_tracker = interface.IYearnPartnerTracker("0x8ee392a4787397126C163Cb9844d7c447da419D8")
    #     IYearnPartnerTracker yearnPartnerTracker = IYearnPartnerTracker(0x8ee392a4787397126C163Cb9844d7c447da419D8); // for mainnet
    executor = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

    # print(impl.initialize)
    yearn_initilize_encoded = encode_function_data(impl.initialize,
                                                   yv_token,
                                                   yearn_partner_tracker,
                                                   "USDC Vault",
                                                   "USDC",
                                                   3,
                                                   3,
                                                   executor,
                                                   ZERO_ADDRESS
                                                   )
    # print(yearn_initilize_encoded)
    proxy = TransparentUpgradeableProxyImpl.deploy(
            impl,
            admin,
            yearn_initilize_encoded,
            {'from': deployer}
            )

    # print(proxy)
    vault = YearnNillaVault(proxy)
    print(yv_token.dict())
    # # print(impl.initialize)
    # print(ayo)



    # proxy = TransparentUpgradeableProxyImpl.deploy(
    #         impl,
    #         proxy_admin,
    #         (YearnNillaVault.initialize.selector)
    #         )
        # proxy = new TransparentUpgradeableProxyImpl(
        #     impl,
        #     admin,
        #     abi.encodeWithSelector(
        #         YearnNillaVault.initialize.selector,
        #         yvToken,
        #         yearnPartnerTracker,
        #         "USDC Vault",
        #         "USDC",
        #         3,
        #         3,
        #         executor,
        #         address(0))
        # );

