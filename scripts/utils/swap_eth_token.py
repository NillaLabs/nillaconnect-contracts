import click
from brownie import interface, chain, network, web3, Wei
from eth_utils import is_checksum_address

UNISWAP_ADDRESS = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"

network.priority_fee("2 gwei")

def get_address(msg: str, default: str = None) -> str:
    val = click.prompt(msg, default=default)

    # Keep asking user for click.prompt until it passes
    while True:

        if is_checksum_address(val):
            return val
        elif addr := web3.ens.address(val):
            click.secho(f"Found ENS '{val}' [{addr}]", fg='green')
            return addr

        click.secho(
            f"I'm sorry, but '{val}' is not a checksummed address or valid ENS record",
            fg='red'
        )
        # NOTE: Only display default once
        val = click.prompt(msg)

def main():
    uniswap = interface.IUniswapRouterV2(UNISWAP_ADDRESS)
    weth_address = uniswap.WETH()
    weth = interface.IWNative(weth_address) 

    sender = get_address("Sender", default="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266")
    receiver = get_address("Receiver", default=sender)
    token_out = get_address("Token Address (default=WETH)", default=f"{weth_address}")
    amount_in = click.prompt("Amount(ethers)", default='1')
    amount_in_wei = Wei(f'{amount_in} ethers')
    click.secho(f"Sender: {sender}", fg='green')
    click.secho(f"Receiver: {receiver}", fg='green')
    click.secho(f"Amount: {amount_in} ethers\n", fg='green')

    if(token_out == weth):
        deposit = weth.deposit({'from': sender, 'value': amount_in_wei})
        click.secho("Done Deposit!", fg='green')
        click.secho(deposit)
    else:        
        path = [weth, token_out]
        amounts  = uniswap.getAmountsOut(amount_in_wei, path)
        click.secho(f"swapExactETHForTokens...", fg='yellow')
        swap_amounts = uniswap.swapExactETHForTokens(amounts[1],
                                                     path,
                                                     receiver,
                                                     chain.time() + 1000000000000,
                                                     {'from': sender, 'value': amounts[0]})
        click.secho("Done Swap!", fg='green')
        click.secho(swap_amounts)
