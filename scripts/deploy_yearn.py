import json

from brownie import network, Contract
from brownie import ProxyAdminImpl, YearnNillaVault, TransparentUpgradeableProxyImpl, NativeGatewayYearn

from scripts.utils.utils import *

network.priority_fee("2 gwei")
f_address = open('./scripts/constants/address.json',)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'

def set_vault(chain_id, token):
    yv_token = data_address[chain_id]['YEARN_VAULT'][token.upper()]
    partner_tracker = data_address[chain_id]['YEARN_PARTNER_TRACKER']
    return yv_token, partner_tracker

def main():
    print_info()
    
    chain_id = set_network('mainnet')
    yv_token, partner_tracker = set_vault(chain_id, 'eth')

    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = YearnNillaVault.deploy({'from': deployer})
    yearn_initilize_encoded = encode_function_data(
        impl.initialize,
        yv_token,
        partner_tracker,
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
    gateway = NativeGatewayYearn.deploy(WETH, {'from': deployer})

    print('Proxy Vault:', proxy_vault)
    print('Gateway:', gateway)
