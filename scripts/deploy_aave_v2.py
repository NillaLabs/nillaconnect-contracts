import json

from brownie import network, Contract
from brownie import ProxyAdminImpl, AaveV2NillaLendingPool, TransparentUpgradeableProxyImpl

from scripts.utils.utils import *

network.priority_fee("2 gwei")
f_address = open('./scripts/constants/address.json',)

data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def set_vault(chain_id, token):
    return data_address[chain_id]['AAVEV2_ATOKEN'][token.upper()]

def main():
    print_info()

    chain_id = set_network('mainnet')
    a_token = set_vault(chain_id, 'usdc')

    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = AaveV2NillaLendingPool.deploy({'from': deployer})
    aave_v2_initilize_encoded = encode_function_data(
        impl.initialize,
        a_token,
        "WETH AAVE V2 LP",
        "naWETH",
        3,
        3
    )
    proxy_impl = TransparentUpgradeableProxyImpl.deploy(
        impl,
        admin,
        aave_v2_initilize_encoded,
        {'from': deployer}
    )
    proxy_vault = Contract.from_abi("AaveV2NillaLendingPool", proxy_impl.address, impl.abi)
    print(proxy_vault)
