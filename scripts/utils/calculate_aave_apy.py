import json

from brownie import network, interface

from scripts.utils.utils import encode_function_data

def main():
    network.priority_fee("2 gwei")
    asset = '0xdAC17F958D2ee523a2206206994597C13D831ec7' # USDT in V3
    pool = interface.IAaveLendingPool('0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2')

    print(pool.getReserveData(asset))
