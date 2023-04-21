-include .env

.PHONY: test build

build			:; forge build && brownie compile
test			:; forge test -vvv
clean			:; forge clean
