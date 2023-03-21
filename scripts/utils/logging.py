from brownie import network

deployer = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

def print_info():
    print('-----------------------------------')
    print(f"Network: '{network.show_active()}'")
    print(f"Using account: [{deployer}]")
    print('-----------------------------------')