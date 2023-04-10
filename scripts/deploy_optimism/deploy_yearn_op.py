import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import ProxyAdminImpl, YearnNillaVault, TransparentUpgradeableProxyImpl, NativeGatewayVault
from scripts.utils.utils import *

network.priority_fee("2 gwei")
load_dotenv()

f_address = open('./scripts/constants/address.json', )
data_address = json.load(f_address)

# deployer = Account.from_mnemonic(
#     os.getenv("MNEMONIC"))  # NOTE: Change address later
# accounts.add(deployer.privateKey)
deployer = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'

CHAIN_ID = '1'
WETH = '0x4200000000000000000000000000000000000006'
MULTISIGWALLET = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'
PARTNER_TRACKER = data_address[CHAIN_ID]['YEARN_PARTNER_TRACKER']
token_address = data_address[CHAIN_ID]['YEARN_VAULT']


def get_yv_token(token):
    yv_token = data_address[CHAIN_ID]['YEARN_VAULT'][token.upper()]
    return yv_token


def main():
    admin = ProxyAdminImpl.deploy({'from': deployer})
    impl = YearnNillaVault.deploy({'from': deployer})
    gateway = NativeGatewayVault.deploy(WETH, {'from': deployer})
    for token in token_address:
        yv_token = get_yv_token(token)
        yearn_initilize_encoded = encode_function_data(
            impl.initialize, yv_token, PARTNER_TRACKER, MULTISIGWALLET,
            f"{token} Yearn Vault", "NYV" + str(token), 3, 3)
        proxy_impl = TransparentUpgradeableProxyImpl.deploy(
            impl, admin, yearn_initilize_encoded, {'from': deployer})
        proxy_vault = Contract.from_abi("YearnNillaVault", proxy_impl.address,
                                        impl.abi)
        print(f'Proxy Vault {token}:', proxy_vault,
              '\n -----------------------------------------------------')
