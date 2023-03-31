import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import network, Contract, accounts
from brownie import ProxyAdminImpl, YearnNillaVault, TransparentUpgradeableProxyImpl, NativeGatewayVault
from scripts.utils.utils import *

load_dotenv()

f_address = open('./scripts/constants/address.json', )
data_address = json.load(f_address)

deployer = Account.from_mnemonic(
    os.getenv("MNEMONIC"))  # NOTE: Change address later
accounts.add(deployer.privateKey)

WETH = '0x4200000000000000000000000000000000000006'


def set_vault(chain_id, token):
    yv_token = data_address[chain_id]['YEARN_VAULT'][token.upper()]
    partner_tracker = data_address[chain_id]['YEARN_PARTNER_TRACKER']
    return yv_token, partner_tracker


def main():
    # print_info()

    # chain_id = set_network('optimism')
    # yv_token, partner_tracker = set_vault(chain_id, 'weth')

    # Note: Deployed on OP mainnet. No need for more unless it's another chain.
    # admin = ProxyAdminImpl.deploy({'from': accounts[0]})  Get from deployed one
    # impl = YearnNillaVault.deploy({'from': accounts[0]})  Get from deployed one
    # yearn_initilize_encoded = encode_function_data(YearnNillaVault.initialize,
    #                                                yv_token, partner_tracker,
    #                                                "WETH Yearn Vault",
    #                                                "NYVWETH", 3, 3)
    # proxy_impl = TransparentUpgradeableProxyImpl.deploy(
    #     impl, admin, yearn_initilize_encoded, {'from': accounts[0]})
    # proxy_vault = Contract.from_abi("YearnNillaVault", proxy_impl.address,
    #                                 impl.abi)
    gateway = NativeGatewayVault.deploy(WETH, {'from': accounts[0]})

    # print('Proxy Vault:', proxy_vault)
    print('Gateway:', gateway)
