import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import ProxyAdminImpl, AaveV2NillaLendingPool, AaveV3NillaLendingPool, CompoundNillaLendingPool, LidoNillaLiquidityStaking, YearnNillaVault, TransparentUpgradeableProxyImpl, TransparentUpgradeableProxyImplNative, NativeGateway, NativeGatewayVault
from scripts.utils.utils import *

network.gas_price("0.001 gwei")

load_dotenv()

CHAIN_ID = set_network('optimism')

f_address = open('./scripts/constants/address.json', )
data_address = json.load(f_address)

aave_v3_address = data_address[CHAIN_ID]['AAVEV3_ATOKEN']
yearn_address = data_address[CHAIN_ID]['YEARN_VAULT']

WETH = data_address[CHAIN_ID]['WETH']
AAVE_V3_POOL = data_address[CHAIN_ID]['AAVEV3_POOL']
AAVE_V3_REWARDS_CONTROLLER = data_address[CHAIN_ID]['AAVEV3_REWARDS_CONTROLLER']
YEARN_PARTNER_TRACKER = data_address[CHAIN_ID]['YEARN_PARTNER_TRACKER']

DEPOSIT_FEE_BPS = 3
WITHDRAW_FEE_BPS = 3
HARVEST_FEE_BPS = 3

# NOTE: Uncomment this when deploying on main.
# deployer = Account.from_mnemonic(
#     os.getenv("MNEMONIC"))  # NOTE: Change address later
# accounts.add(deployer.privateKey)
deployer = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
HARVEST_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f' # NOTE Change later
WORKER_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later
MULTISIG_WALLET = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'


def main():
    # Can globally deploy once for each network!
    admin = ProxyAdminImpl.deploy({'from': deployer})
    gateway = NativeGateway.deploy(WETH, {'from': deployer})
    gateway_vault = NativeGatewayVault.deploy(WETH, {'from': deployer})

    # ---------- Deploy Yearn's ----------
    impl_yearn = YearnNillaVault.deploy({'from': deployer})
    for token in yearn_address:
        yearn_initilize_encoded = encode_function_data(
            impl_yearn.initialize,
            yearn_address[token],
            YEARN_PARTNER_TRACKER,
            MULTISIG_WALLET,
            f"{token} Yearn-Nilla Vault",
            "nyv" + str(token),
            DEPOSIT_FEE_BPS,
            WITHDRAW_FEE_BPS
        )
        proxy_impl_yearn = TransparentUpgradeableProxyImpl.deploy(
            impl_yearn, admin, yearn_initilize_encoded, {'from': deployer})
        yearn_vault = Contract.from_abi("YearnNillaVault", proxy_impl_yearn.address,
                                        impl_yearn.abi)
        print(f'Yearn:- Proxy Vault {token}:', yearn_vault,
              '\n -----------------------------------------------------')
    
    # ---------- Deploy AAVE V3's ----------
    impl_aave_v3 = AaveV3NillaLendingPool.deploy(
        AAVE_V3_REWARDS_CONTROLLER,
        WETH,
        AAVE_V3_POOL,
        {'from': deployer})
    for token in aave_v3_address:
        aave_v3_initilize_encoded = encode_function_data(
            impl_aave_v3.initialize,
            aave_v3_address[token],
            '0x0',
            HARVEST_BOT,
            f"{token} AAVE V3-Nilla LP",
            "na" + str(token),
            DEPOSIT_FEE_BPS,
            WITHDRAW_FEE_BPS,
            HARVEST_FEE_BPS
        )
        proxy_impl_aave_v3 = TransparentUpgradeableProxyImplNative.deploy(
            impl_aave_v3,
            admin,
            aave_v3_initilize_encoded,
            WETH,
            {'from': deployer}
        )
        aave_v3_lp = Contract.from_abi("AaveV3NillaLendingPool", proxy_impl_aave_v3.address, impl_aave_v3.abi)
        print(f'AAVE V3:- Proxy LP {token}', aave_v3_lp, '\n -----------------------------------------------------')
