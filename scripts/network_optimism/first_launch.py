import json
import os
from dotenv import load_dotenv
from eth_account import Account
from brownie import Contract, accounts
from brownie import ProxyAdminImpl, AaveV3NillaLendingPoolNoRewards, YearnNillaVault, TransparentUpgradeableProxyImpl, TransparentUpgradeableProxyImplNative, NativeGateway, NativeGatewayVault
from scripts.utils.utils import *

network.gas_price("0.001 gwei")

load_dotenv()

CHAIN_ID = set_network('optimism')

f_address = open('./scripts/constants/address.json', )
admin_abi = json.load(open('./build/contracts/ProxyadminImpl.json', ))
aave_v3_no_rewards_abi = json.load(
    open('./build/contracts/AaveV3NillaLendingPoolNoRewards.json', ))
yearn_abi = json.load(open('./build/contracts/YearnNillaVault.json', ))

data_address = json.load(f_address)

aave_v3_address = data_address[CHAIN_ID]['AAVEV3_ATOKEN']
yearn_address = data_address[CHAIN_ID]['YEARN_VAULT']

WETH = data_address[CHAIN_ID]['WETH']
AAVE_V3_POOL = data_address[CHAIN_ID]['AAVEV3_POOL']
YEARN_PARTNER_TRACKER = data_address[CHAIN_ID]['YEARN_PARTNER_TRACKER']

DEPOSIT_FEE_BPS = 3
WITHDRAW_FEE_BPS = 3

#  NOTE: Uncomment this when deploying on main.
deployer = Account.from_mnemonic(
    os.getenv("MNEMONIC"))  # NOTE: Change address later
accounts.add(deployer.privateKey)

# deployer = '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266'
HARVEST_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later
WORKER_BOT = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # NOTE Change later
MULTISIG_WALLET = '0x6f650AE486eFc27BeEFb8Dc84000F63acA99735f'  # OP's


def main():
    # Can globally deploy once for each network!
    admin = Contract.from_abi("ProxyAdminImpl",
                              "0x85774d5Fc82EDC9633624c009F0edfAD2DDebA1C",
                              admin_abi['abi'])
    # gateway = NativeGateway.deploy(WETH, {'from': accounts[0]})
    # gateway_vault = NativeGatewayVault.deploy(WETH, {'from': accounts[0]})

    # ---------- Deploy Yearn's ----------
    # impl_yearn = Contract.from_abi(
    #     "YearnNillaVault", "0xA7397Afe71FDa96B2656Cf9FAFf72955952DeD32",
    #     yearn_abi['abi'])
    # for token in yearn_address:
    #     yearn_initilize_encoded = encode_function_data(
    #         impl_yearn.initialize, yearn_address[token], YEARN_PARTNER_TRACKER,
    #         MULTISIG_WALLET, f"{token} Yearn-Nilla Vault", "nyv" + str(token),
    #         DEPOSIT_FEE_BPS, WITHDRAW_FEE_BPS)
    #     proxy_impl_yearn = TransparentUpgradeableProxyImpl.deploy(
    #         impl_yearn, admin, yearn_initilize_encoded, {'from': accounts[0]})
    #     yearn_vault = Contract.from_abi("YearnNillaVault",
    #                                     proxy_impl_yearn.address,
    #                                     impl_yearn.abi)
    #     print(f'Yearn:- Proxy Vault {token}:', yearn_vault,
    #           '\n -----------------------------------------------------')

    # ---------- Deploy AAVE V3's ----------
    impl_aave_v3_no_rewards = Contract.from_abi(
        "AaveV3NillaLendingPoolNoRewards",
        "0xF4B45771953eed73ce3c99c51C8f263cC0917264",
        aave_v3_no_rewards_abi['abi'])

    for token in aave_v3_address:
        aave_v3_initilize_encoded = encode_function_data(
            impl_aave_v3_no_rewards.initialize, aave_v3_address[token],
            f"{token} AAVE V3-Nilla LP", "na" + str(token), DEPOSIT_FEE_BPS,
            WITHDRAW_FEE_BPS)
        proxy_impl_aave_v3_no_rewards = TransparentUpgradeableProxyImplNative.deploy(
            impl_aave_v3_no_rewards, admin, aave_v3_initilize_encoded, WETH,
            {'from': accounts[0]})
        aave_v3_lp = Contract.from_abi("AaveV3NillaLendingPool",
                                       proxy_impl_aave_v3_no_rewards.address,
                                       impl_aave_v3_no_rewards.abi)
        print(f'AAVE V3:- Proxy LP {token}', aave_v3_lp,
              '\n -----------------------------------------------------')
