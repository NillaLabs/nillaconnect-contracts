import os
from dotenv import load_dotenv
from brownie import (
    ProxyAdminImpl,
    YearnNillaVault,
    TransparentUpgradeableProxyImpl,
    AaveV3NillaLendingPoolNoRewards,
    TransparentUpgradeableProxyImplNative,
    NativeGateway,
    NativeGatewayVault,
)

aave_impl = "0xf216e98136d9d4F86bE951641be0fDB076B6be30"
proxy_aave = [
    "0x23fd7cC7799c2Ab48B670f712636cA97D0b47723",
    "0x0784314b540101d73Fc225ea11Fd60BeF16f1b62",
    "0x290a5544E5F14CB61A8402b0cd6132dc2a24b3fF",
    "0xd01f4083cb30a668B560Ed47228D59f90A768973",
    "0x703c3699d4aA76C46c837bC2947Ec09526120bef",
    "0xC13554800456442020991fF04A3b0d982f65cf6F",
    "0xeb4a0A69727a17F91854D21A10c524096C89556b",
]

yearn_impl = "0x615D26Fc22AA78c2bc6cE324eDBD325700197301"
proxy_yearn = [
    "0x676CF057e8e275df4FCFc5d72e6a334336C28069",
    "0x6d399C5BFd8a269a218CB3c4979D92dd9b801AC7",
    "0x64a487DA2eDB8cB63e9b0E032DB4184C76efeec5",
    "0xA7da71d3F65ecf86697b32dD8890d53EF49Be6F2",
    "0x6273359be3030E1b2E14E3937af1017D6974350c",
]

native_gateway = "0x9097412ebEEe8853E0Ea889F22591d5376738091"
native_gateway_vault = "0x10a278166dad38AE68Eea9270fEFC58eED103d09"
admin = "0x85774d5Fc82EDC9633624c009F0edfAD2DDebA1C"


def main():
    AaveV3NillaLendingPoolNoRewards.publish_source(
        AaveV3NillaLendingPoolNoRewards.at(aave_impl)
    )


def verify_aave():
    # AaveV3NillaLendingPoolNoRewards.publish_source(
    #     AaveV3NillaLendingPoolNoRewards.at(aave_impl)
    # )
    # print("DONE verifying AaveV3NoRewards's impl.")
    # print(":-")
    for na_token in proxy_aave:
        TransparentUpgradeableProxyImplNative.publish_source(
            TransparentUpgradeableProxyImplNative.at(na_token)
        )
        print(
            "DONE verifying naToken:",
            AaveV3NillaLendingPoolNoRewards.at(na_token).name(),
        )
        print("----")


def verify_yearn():
    YearnNillaVault.publish_source(YearnNillaVault.at(yearn_impl))
    print("DONE verifying Yearn' impl.")
    print(":-")
    for nyv_token in proxy_yearn:
        TransparentUpgradeableProxyImpl.publish_source(
            TransparentUpgradeableProxyImpl.at(nyv_token)
        )
        print(
            "DONE verifying nyvToken:",
            YearnNillaVault.at(nyv_token).name(),
        )
        print("----")


def verify_setup():
    NativeGateway.publish_source(NativeGateway.at(native_gateway))
    print("DONE verifying NativeGateway")
    NativeGatewayVault.publish_source(NativeGatewayVault.at(native_gateway_vault))
    print("DONE verifying NativeGatewayVault")
    ProxyAdminImpl.publish_source(ProxyAdminImpl.at(admin))
    print("DONE verifying ProxyAdmin.")
