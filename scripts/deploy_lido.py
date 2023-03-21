import json

from brownie import network, Contract
from brownie import ProxyAdminImpl, LidoNillaLiquidityStaking, TransparentUpgradeableProxyImplNative

from scripts.utils.utils import print_info, encode_function_data

network.priority_fee("2 gwei")
f_address = open('./scripts/constants/address.json',)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def main():
    print_info()
    st_eth = data_address['1']['LIDO']['STETH']
    curve_pool = data_address['1']['LIDO']['CURVE_POOL']

    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = LidoNillaLiquidityStaking.deploy(st_eth, {'from': deployer})
    aave_v2_initilize_encoded = encode_function_data(
        impl.initialize,
        curve_pool,
        "Lido ETH Staking",
        "nstETH",
        3,
        3
    )
    proxy_impl = TransparentUpgradeableProxyImplNative.deploy(
        impl,
        admin,
        aave_v2_initilize_encoded,
        curve_pool,
        {'from': deployer}
    )
    proxy_vault = Contract.from_abi("LidoNillaLiquidityStaking", proxy_impl.address, impl.abi)
    print(proxy_vault)
