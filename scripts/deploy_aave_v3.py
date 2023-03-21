import json

from brownie import network, Contract
from brownie import ProxyAdminImpl, AaveV3NillaLendingPool, TransparentUpgradeableProxyImplNative

from scripts.utils.utils import *

network.priority_fee("2 gwei")
f_address = open('./scripts/constants/address.json',)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later
protocol_bot = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def set_lending_pool(chain_id, token):
    a_token = data_address[chain_id]['AAVEV3_ATOKEN'][token.upper()]
    weth = data_address[chain_id]['WETH']
    # Only available on Avalanche chain
    swap_router = data_address["43114"]['TRADERJOE_ROUTER']
    rewards_controller = data_address["43114"]['AAVEV3_REWARDS_CONTROLLER']
    return [rewards_controller, weth, a_token, swap_router]

def main():
    print_info()
    
    chain_id = set_network('mainnet')
    data = set_lending_pool(chain_id, 'WETH')

    rewardsController = data[0]
    weth = data[1]
    aToken = data[2]
    swap_router = data[3]
    
    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = AaveV3NillaLendingPool.deploy(
        rewardsController,
        weth,
        aToken,
        {'from': deployer}
    )
    aav_v3_initilize_encoded = encode_function_data(
        impl.initialize,
        aToken,
        swap_router,
        protocol_bot,
        "WETH AAVE V3 LP",
        "naWETH",
        3,
        3,
        3
    )
    proxy_impl = TransparentUpgradeableProxyImplNative.deploy(
        impl,
        admin,
        aav_v3_initilize_encoded,
        weth,
        {'from': deployer}
    )
    proxy_lending = Contract.from_abi("AaveV3NillaLendingPool", proxy_impl.address, impl.abi)
    print(proxy_lending)
