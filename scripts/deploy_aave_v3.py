import eth_utils
import json

from brownie.convert import to_address
from brownie import network, interface, Contract
from brownie import ProxyAdminImpl, AaveV3NillaLendingPool, TransparentUpgradeableProxyImpl

network.priority_fee("2 gwei")
f_chain = open('./scripts/utils/chainId.json',)
f_address = open('./scripts/utils/address.json',)
data_chain_id = json.load(f_chain)
data_address = json.load(f_address)

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later
protocol_bot = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" # NOTE: Change address later

def set_network(network):
    return data_chain_id[network.upper()] 

def set_lending_pool(chain_id, token):
    a_token = data_address[chain_id]['AAVEV3_ATOKEN'][token.upper()]
    weth = data_address[chain_id]['WETH']
    # Only available on Avalanche chain
    swap_router = data_address["43114"]['TRADERJOE_ROUTER']
    rewards_controller = data_address["43114"]['AAVEV3_REWARDS_CONTROLLER']
    return [rewards_controller, weth, a_token, swap_router]

def encode_function_data(initializer=None, *args):
    if len(args) == 0 or not initializer:
        return eth_utils.to_bytes(hexstr="0x")
    return initializer.encode_input(*args)

def main():
    chain_id = set_network('mainnet')
    data = set_lending_pool(chain_id, 'WETH')

    print(f"Network: '{network.show_active()}'")
    print(f"Using account: [{deployer}]")

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
    proxy_impl = TransparentUpgradeableProxyImpl.deploy(
        impl,
        admin,
        aav_v3_initilize_encoded,
        weth,
        {'from': deployer}
    )
    proxy_lending = Contract.from_abi("AaveV3NillaLendingPool", proxy_impl.address, impl.abi)
    print(proxy_lending)
