import json

from brownie import network, Contract
from brownie import ProxyAdminImpl, CompoundNillaLendingPool, TransparentUpgradeableProxyImpl

from scripts.utils.utils import print_info, encode_function_data

network.priority_fee("2 gwei")
f_address = open('./scripts/constants/address.json',)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later
protocol_bot = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def set_c_token(token):
    c_token = data_address['1']['COMPOUND_CTOKEN'][token.upper()]
    comptroller = data_address['1']['COMPTROLLER']
    swap_router = data_address['1']['SUSHISWAP_ROUTER']
    weth = data_address['1']['WETH']
    return [c_token, comptroller, swap_router, weth]

def main():
    print_info()
    data = set_c_token('usdt')
    c_token = data[0]
    comptroller = data[1]
    swap_router = data[2]
    weth = data[3]
    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = CompoundNillaLendingPool.deploy(comptroller, weth, {'from': deployer})
    compound_initilize_encoded = encode_function_data(
        impl.initialize,
        c_token,
        swap_router,
        protocol_bot,
        "Compound LP - USDT",
        "ncUSDT",
        3,
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
