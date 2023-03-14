import click
import eth_utils
import json

from brownie import accounts, network, interface, ZERO_ADDRESS, Contract
from brownie import ProxyAdminImpl, YearnNillaVault, TransparentUpgradeableProxyImpl

network.priority_fee("2 gwei")
data_chainId = json.load(open('./utils/chainId.json'))
data_address = json.load(open('./utils/address.json'))

chainId = "N/A"
yvToken = "N/A"
partner_tracker = "N/A"

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def set_network(network):
    chainId = data_chainId[network.upper()] 

def set_vault(token):
    yvToken = data_address[chainId]['YEARN_VAULT'][token.upper()]
    partner_tracker = data_address[chainId]['YEARN_PARTNER_TRACKER']

def encode_function_data(initializer=None, *args):
    if len(args) == 0 or not initializer:
        return eth_utils.to_bytes(hexstr="0x")
    return initializer.encode_input(*args)

def main():
    set_network('mainnet')
    set_vault('eth')
    print(f"Network: '{network.show_active()}'")
    print(f"Using account: [{deployer}]")

    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = YearnNillaVault.deploy({'from': deployer})
    yv_token = interface.IYVToken(yvToken)
    yearn_partner_tracker = interface.IYearnPartnerTracker(partner_tracker)
    yearn_initilize_encoded = encode_function_data(impl.initialize,
                                                   yv_token.address,
                                                   yearn_partner_tracker.address,
                                                   "WETH Yearn Vault",
                                                   "NYVWETH",
                                                   3,
                                                   3
                                                   )
    proxy_impl = TransparentUpgradeableProxyImpl.deploy(
            impl,
            admin,
            yearn_initilize_encoded,
            {'from': deployer}
            )
    proxy_vault = Contract.from_abi("YearnNillaVault", proxy_impl.address, impl.abi)
    print(proxy_vault)
