import click
import eth_utils

from brownie import accounts, network
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

    proxy_admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = YearnNillaVault.deploy({'from': deployer})
    # print(impl.initialize)
    ayo = encode_function_data(impl.initialize)
    print(ayo)



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

