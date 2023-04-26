import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import (
    ProxyAdminImpl,
    AaveV2NillaLendingPool,
    AaveV3NillaLendingPool,
    TransparentUpgradeableProxyImpl,
    TransparentUpgradeableProxyImplNative,
    NativeGateway,
)
from scripts.utils.utils import *

network.gas_price("26 gwei")

load_dotenv()

CHAIN_ID = set_network("avalanche")

f_address = open(
    "./scripts/constants/address.json",
)
data_address = json.load(f_address)

aave_v3_address = data_address[CHAIN_ID]["AAVEV3_ATOKEN"]

WETH = data_address[CHAIN_ID]["WETH"]
AAVE_V3_POOL = data_address[CHAIN_ID]["AAVEV3_POOL"]
AAVE_V3_REWARDS_CONTROLLER = data_address[CHAIN_ID]["AAVEV3_REWARDS_CONTROLLER"]
TRADERJOE_ROUTER = data_address[CHAIN_ID]["TRADERJOE_ROUTER"]

DEPOSIT_FEE_BPS = 0
WITHDRAW_FEE_BPS = 0
HARVEST_FEE_BPS = 100
PERFORMANCE_FEE_BPS = 500

# NOTE: Uncomment this when deploying on main.
# deployer = Account.from_mnemonic(
#     os.getenv("MNEMONIC"))  # NOTE: Change address later
# accounts.add(deployer.privateKey)
deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
HARVEST_BOT = "0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f"  # NOTE Change later
WORKER_BOT = "0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f"  # NOTE Change later


def main():
    # Can globally deploy once for each network!
    admin = ProxyAdminImpl.deploy({"from": deployer}, publish_source=True)
    gateway = NativeGateway.deploy(WETH, {"from": deployer}, publish_source=True)

    # ---------- Deploy AAVE V3's ----------
    impl_aave_v3 = AaveV3NillaLendingPool.deploy(
        AAVE_V3_REWARDS_CONTROLLER,
        WETH,
        AAVE_V3_POOL,
        {"from": deployer},
        publish_source=True,
    )
    for token in aave_v3_address:
        aave_v3_initilize_encoded = encode_function_data(
            impl_aave_v3.initialize,
            aave_v3_address[token],
            TRADERJOE_ROUTER,
            HARVEST_BOT,
            f"{token} AAVE V3-Nilla LP",
            "na" + str(token),
            DEPOSIT_FEE_BPS,
            WITHDRAW_FEE_BPS,
            HARVEST_FEE_BPS,
            PERFORMANCE_FEE_BPS,
        )
        proxy_impl_aave_v3 = TransparentUpgradeableProxyImplNative.deploy(
            impl_aave_v3,
            admin,
            aave_v3_initilize_encoded,
            WETH,
            {"from": deployer},
            publish_source=True,
        )
        aave_v3_lp = Contract.from_abi(
            "AaveV3NillaLendingPool", proxy_impl_aave_v3.address, impl_aave_v3.abi
        )
        print(
            f"AAVE V3:- Proxy LP {token}",
            aave_v3_lp,
            "\n -----------------------------------------------------",
        )
