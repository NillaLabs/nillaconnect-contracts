import eth_utils
import json

from brownie import network, interface, Contract
from brownie import ProxyAdminImpl, LidoNillaLiquidityStaking, TransparentUpgradeableProxyImplNative

network.priority_fee("2 gwei")
f_chain = open('./scripts/utils/chainId.json',)
f_address = open('./scripts/utils/address.json',)
data_chain_id = json.load(f_chain)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def encode_function_data(initializer=None, *args):
    if len(args) == 0 or not initializer:
        return eth_utils.to_bytes(hexstr="0x")
    return initializer.encode_input(*args)

def main():
    st_eth = data_address['1']['LIDO']['STETH']
    curve_pool = data_address['1']['LIDO']['CURVE_POOL']
    print(f"Network: '{network.show_active()}'")
    print(f"Using account: [{deployer}]")

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
        curve_pool
        {'from': deployer}
    )
    proxy_vault = Contract.from_abi("LidoNillaLiquidityStaking", proxy_impl.address, impl.abi)
    print(proxy_vault)
