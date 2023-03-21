import json

from brownie import network, Contract
from brownie import ProxyAdminImpl, CompoundNillaLendingPool, TransparentUpgradeableProxyImpl

from scripts.utils.utils import print_info, encode_function_data

network.priority_fee("2 gwei")
f_address = open('./scripts/constants/address.json',)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def set_c_token(token):
    return data_address['1']['COMPOUND_CTOKEN'][token.upper()] 

def main():
    print_info()
    
    c_token = set_c_token('usdt')
    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = CompoundNillaLendingPool.deploy({'from': deployer})
    compound_initilize_encoded = encode_function_data(
        impl.initialize,
        c_token,
        "Compound LP - USDT",
        "ncUSDT",
        3,
        3
    )
    proxy_impl = TransparentUpgradeableProxyImpl.deploy(
        impl,
        admin,
        compound_initilize_encoded,
        {'from': deployer}
    )
    proxy_vault = Contract.from_abi("CompoundNillaLendingPool", proxy_impl.address, impl.abi)
    print(proxy_vault)
