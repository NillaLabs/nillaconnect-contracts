import eth_utils
import json

from brownie import network, Contract
from brownie import ProxyAdminImpl, AaveV2NillaLendingPool, TransparentUpgradeableProxyImpl

network.priority_fee("2 gwei")
f_chain = open('./scripts/utils/chainId.json',)
f_address = open('./scripts/utils/address.json',)
data_chain_id = json.load(f_chain)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def set_network(network):
    return data_chain_id[network.upper()] 

def set_vault(chain_id, token):
    return data_address[chain_id]['AAVEV2_ATOKEN'][token.upper()]

def encode_function_data(initializer=None, *args):
    if len(args) == 0 or not initializer:
        return eth_utils.to_bytes(hexstr="0x")
    return initializer.encode_input(*args)

def print_info():
    print('-----------------------------------')
    print(f"Network: '{network.show_active()}'")
    print(f"Using account: [{deployer}]")
    print('-----------------------------------')

def main():
    print_info()

    chain_id = set_network('avalanche')
    a_token = set_vault(chain_id, 'aave')

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
