import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import ProxyAdminImpl, AaveV2NillaLendingPool, AaveV3NillaLendingPoolNoRewards, CompoundNillaLendingPool, LidoNillaLiquidityStaking, YearnNillaVault, TransparentUpgradeableProxyImpl, TransparentUpgradeableProxyImplNative, NativeGateway, NativeGatewayVault
from scripts.utils.utils import *

network.max_fee("20 gwei")
network.priority_fee("1 gwei")

load_dotenv()

CHAIN_ID = set_network('mainnet')

f_address = open('./scripts/constants/address.json', )
data_address = json.load(f_address)

# aave_v2_address = data_address[CHAIN_ID]['AAVEV2_ATOKEN']
# aave_v3_address = data_address[CHAIN_ID]['AAVEV3_ATOKEN']
# compound_address = data_address[CHAIN_ID]['COMPOUND_CTOKEN']
lido_address = data_address[CHAIN_ID]['LIDO']
yearn_address = data_address[CHAIN_ID]['YEARN_VAULT']

WETH = data_address[CHAIN_ID]['WETH']
# AAVE_V3_POOL = data_address[CHAIN_ID]['AAVEV3_POOL']
YEARN_PARTNER_TRACKER = data_address[CHAIN_ID]['YEARN_PARTNER_TRACKER']

# NOTE: Leave COMPOUND out of scope for Beta.
# COMPTROLLER = data_address[CHAIN_ID]['COMPTROLLER']
# SUSHISWAP_ROUTER = data_address[CHAIN_ID]['SUSHISWAP_ROUTER']

DEPOSIT_FEE_BPS = 3
WITHDRAW_FEE_BPS = 3
HARVEST_FEE_BPS = 3

# NOTE: Uncomment this when deploying on main.
# deployer = Account.from_mnemonic(
#     os.getenv("MNEMONIC"))  # NOTE: Change address later
# accounts.add(deployer.privateKey)
deployer = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
HARVEST_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later
WORKER_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later
MULTISIG_WALLET = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later


def main():
    # Can globally deploy once for each network!
    admin = ProxyAdminImpl.deploy({'from': deployer})
    gateway = NativeGateway.deploy(WETH, {'from': deployer})
    gateway_vault = NativeGatewayVault.deploy(WETH, {'from': deployer})

    # ---------- Deploy Yearn's ----------
    impl_yearn = YearnNillaVault.deploy({'from': deployer})
    for token in yearn_address:
        yearn_initilize_encoded = encode_function_data(
            impl_yearn.initialize, yearn_address[token], YEARN_PARTNER_TRACKER,
            MULTISIG_WALLET, f"{token} Yearn-Nilla Vault", "nyv" + str(token),
            DEPOSIT_FEE_BPS, WITHDRAW_FEE_BPS)
        proxy_impl_yearn = TransparentUpgradeableProxyImpl.deploy(
            impl_yearn, admin, yearn_initilize_encoded, {'from': deployer})
        yearn_vault = Contract.from_abi("YearnNillaVault",
                                        proxy_impl_yearn.address,
                                        impl_yearn.abi)
        print(f'Yearn:- Proxy Vault {token}:', yearn_vault,
              '\n -----------------------------------------------------')

    # ---------- Deploy Lido's ----------
    impl_lido = LidoNillaLiquidityStaking.deploy(lido_address['STETH'],
                                                 {'from': deployer})
    lido_initilize_encoded = encode_function_data(impl_lido.initialize,
                                                  lido_address['CURVE_POOL'],
                                                  "Lido-Nilla ETH Staking",
                                                  "nstETH", DEPOSIT_FEE_BPS,
                                                  WITHDRAW_FEE_BPS)
    proxy_impl_lido = TransparentUpgradeableProxyImplNative.deploy(
        impl_lido,
        admin,
        lido_initilize_encoded,
        lido_address['CURVE_POOL'],  # accept WETH from pool
        {'from': deployer})
    lido_liquidstaking = Contract.from_abi("LidoNillaLiquidityStaking",
                                           proxy_impl_lido.address,
                                           impl_lido.abi)
    print('Lido:-', lido_liquidstaking,
          '\n -----------------------------------------------------')

    # NOTE: Leave COMPOUND out of scope for Beta.
    # ---------- Deploy Compound's ----------
    # impl_compound = CompoundNillaLendingPool.deploy(COMPTROLLER, WETH, {'from': deployer})
    # for token in compound_address:
    #     compound_initilize_encoded = encode_function_data(
    #         impl_compound.initialize,
    #         compound_address[token],
    #         SUSHISWAP_ROUTER,
    #         HARVEST_BOT,
    #         f"{token} Compound-Nilla LP",
    #         "nc" + str(token),
    #         DEPOSIT_FEE_BPS,
    #         WITHDRAW_FEE_BPS,
    #         HARVEST_FEE_BPS
    #     )
    #     proxy_impl_compound = TransparentUpgradeableProxyImpl.deploy(
    #         impl_compound,
    #         admin,
    #         compound_initilize_encoded,
    #         {'from': deployer}
    #     )
    #     compound_lp = Contract.from_abi("CompoundNillaLendingPool", proxy_impl_compound.address, impl_compound.abi)
    #     print(f'Compound:- Proxy LP {token}', compound_lp, '\n -----------------------------------------------------')

    # ---------- Deploy AAVE V2's ----------
    # impl_aave_v2 = AaveV2NillaLendingPool.deploy({'from': deployer})
    # for token in aave_v2_address:
    #     aave_v2_initilize_encoded = encode_function_data(
    #         impl_aave_v2.initialize,
    #         aave_v2_address[token],
    #         f"{token} AAVE V2-Nilla LP",
    #         "na" + str(token),
    #         DEPOSIT_FEE_BPS,
    #         WITHDRAW_FEE_BPS
    #     )
    #     proxy_impl_aave_v2 = TransparentUpgradeableProxyImpl.deploy(
    #         impl_aave_v2,
    #         admin,
    #         aave_v2_initilize_encoded,
    #         {'from': deployer}
    #     )
    #     aave_v2_lp = Contract.from_abi("AaveV2NillaLendingPool", proxy_impl_aave_v2.address, impl_aave_v2.abi)
    #     print(f'AAVE V2:- Proxy LP {token}', aave_v2_lp, '\n -----------------------------------------------------')

    # ---------- Deploy AAVE V3's ----------
    # impl_aave_v3_no_rewards = AaveV3NillaLendingPoolNoRewards.deploy(
    #     WETH,
    #     AAVE_V3_POOL,
    #     {'from': deployer})
    # for token in aave_v3_address:
    #     aave_v3_initilize_encoded = encode_function_data(
    #         impl_aave_v3_no_rewards.initialize,
    #         aave_v3_address[token],
    #         f"{token} AAVE V3-Nilla LP",
    #         "na" + str(token),
    #         DEPOSIT_FEE_BPS,
    #         WITHDRAW_FEE_BPS
    #     )
    #     proxy_impl_aave_v3_no_rewards = TransparentUpgradeableProxyImplNative.deploy(
    #         impl_aave_v3_no_rewards,
    #         admin,
    #         aave_v3_initilize_encoded,
    #         WETH,
    #         {'from': deployer}
    #     )
    #     aave_v3_lp = Contract.from_abi("AaveV3NillaLendingPoolNoRewards", proxy_impl_aave_v3_no_rewards.address, impl_aave_v3_no_rewards.abi)
    #     print(f'AAVE V3:- Proxy LP {token}', aave_v3_lp, '\n -----------------------------------------------------')
