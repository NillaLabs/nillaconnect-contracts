import eth_utils
import json

from brownie import network

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

f_chain = open('./scripts/constants/chainId.json',)
data_chain_id = json.load(f_chain)

def print_info():
    print('-----------------------------------')
    print(f"Network: '{network.show_active()}'")
    print(f"Using account: [{deployer}]")
    print('-----------------------------------')

def encode_function_data(initializer=None, *args):
    if len(args) == 0 or not initializer:   return eth_utils.to_bytes(hexstr="0x")
    return initializer.encode_input(*args)

def set_network(network):
    return data_chain_id[network.upper()] 