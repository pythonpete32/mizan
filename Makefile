# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

all : clean remove install update build 


# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules

# Install the Modules
install :; 
	forge install foundry-rs/forge-std --no-commit
	forge install OpenZeppelin/openzeppelin-contracts --no-commit
	forge install transmissions11/solmate --no-commit

# Update Dependencies
update :; forge update

# Builds
build  :; forge clean && forge build --optimize --optimizer-runs 1000000
