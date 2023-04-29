/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      forking: {
        url: 'https://ethereum.publicnode.com',
      },
      chainId: 1
    }
  },
};
