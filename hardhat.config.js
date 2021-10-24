require("@nomiclabs/hardhat-waffle");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const gwei = 1000000000;

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.9"
      },    
    ]
  },
  defaultNetwork: "hardhat",
  mocha: { timeout: '1800000'},
  networks: {
    hardhat: {
      forking: {
        url: `https://polygon-mainnet.infura.io/v3/213b88e46783471ba5496473a7a3c42d`,
      }
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/213b88e46783471ba5496473a7a3c42d`,
      accounts: {
        mnemonic: process.env.POLYGON_TEST_MNEMONIC
      },
      gasPrice: 5*gwei
    }
  },
};
