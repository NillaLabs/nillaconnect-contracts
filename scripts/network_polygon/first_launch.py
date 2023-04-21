import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import ProxyAdminImpl, AaveV3NillaLendingPoolNoRewards, TransparentUpgradeableProxyImplNative, NativeGateway
from scripts.utils.utils import *

network.max_fee("150 gwei")
network.priority_fee("1 gwei")

load_dotenv()

CHAIN_ID = set_network('polygon')

f_address = open('./scripts/constants/address.json', )
data_address = json.load(f_address)

aave_v3_address = data_address[CHAIN_ID]['AAVEV3_ATOKEN']

WETH = data_address[CHAIN_ID]['WETH']
AAVE_V3_POOL = data_address[CHAIN_ID]['AAVEV3_POOL']

DEPOSIT_FEE_BPS = 3
WITHDRAW_FEE_BPS = 3

# NOTE: Uncomment this when deploying on main.
# deployer = Account.from_mnemonic(
#     os.getenv("MNEMONIC"))  # NOTE: Change address later
# accounts.add(deployer.privateKey)
deployer = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
HARVEST_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later
WORKER_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later


def main():
    # Can globally deploy once for each network!
    admin = ProxyAdminImpl.deploy({'from': deployer})
    gateway = NativeGateway.deploy(WETH, {'from': deployer})

    # ---------- Deploy AAVE V3's ----------
    impl_aave_v3_no_rewards = AaveV3NillaLendingPoolNoRewards.deploy(
        WETH, AAVE_V3_POOL, {'from': deployer})
    for token in aave_v3_address:
        aave_v3_initilize_encoded = encode_function_data(
            impl_aave_v3_no_rewards.initialize,
            aave_v3_address[token],
            f"{token} AAVE V3-Nilla LP",
            "na" + str(token),
            DEPOSIT_FEE_BPS,
            WITHDRAW_FEE_BPS,
        )
        proxy_impl_aave_v3_no_rewards = TransparentUpgradeableProxyImplNative.deploy(
            impl_aave_v3_no_rewards, admin, aave_v3_initilize_encoded, WETH,
            {'from': deployer})
        aave_v3_lp = Contract.from_abi("AaveV3NillaLendingPoolNoRewards",
                                       proxy_impl_aave_v3_no_rewards.address,
                                       impl_aave_v3_no_rewards.abi)
        print(f'AAVE V3:- Proxy LP {token}', aave_v3_lp,
              '\n -----------------------------------------------------')
