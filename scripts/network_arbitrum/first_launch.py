import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import (
    ProxyAdminImpl,
    AaveV3NillaLendingPoolNoRewards,
    TransparentUpgradeableProxyImplNative,
    NativeGateway,
)
from scripts.utils.utils import *

network.gas_price("0.1 gwei")

load_dotenv()

CHAIN_ID = set_network("arbitrum")

f_address = open(
    "./scripts/constants/address.json",
)
data_address = json.load(f_address)

aave_v3_address = data_address[CHAIN_ID]["AAVEV3_ATOKEN"]

WETH = data_address[CHAIN_ID]["WETH"]
AAVE_V3_POOL = data_address[CHAIN_ID]["AAVEV3_POOL"]

DEPOSIT_FEE_BPS = 0
WITHDRAW_FEE_BPS = 0
PERFORMANCE_FEE_BPS = 500

# NOTE: Uncomment this when deploying on main.
deployer = Account.from_mnemonic(os.getenv("MNEMONIC"))  # NOTE: Change address later
accounts.add(deployer.privateKey)
deployer = accounts[0]


def main():
    # Can globally deploy once for each network!
    admin = ProxyAdminImpl.deploy({"from": deployer}, publish_source=True)
    gateway = NativeGateway.deploy(WETH, {"from": deployer}, publish_source=True)

    # ---------- Deploy AAVE V3's ----------
    impl_aave_v3_no_rewards = AaveV3NillaLendingPoolNoRewards.deploy(
        WETH, AAVE_V3_POOL, {"from": deployer}, publish_source=True
    )
    for token in aave_v3_address:
        aave_v3_initilize_encoded = encode_function_data(
            impl_aave_v3_no_rewards.initialize,
            aave_v3_address[token],
            f"{token} AAVE V3-Nilla LP",
            "na" + str(token),
            DEPOSIT_FEE_BPS,
            WITHDRAW_FEE_BPS,
            PERFORMANCE_FEE_BPS,
        )
        proxy_impl_aave_v3_no_rewards = TransparentUpgradeableProxyImplNative.deploy(
            impl_aave_v3_no_rewards,
            admin,
            aave_v3_initilize_encoded,
            WETH,
            {"from": deployer},
            publish_source=True,
        )
