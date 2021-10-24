import deployLogic from "./utils/deployLogic";
import {ethers} from "hardhat";
import {BigNumber} from "ethers";

const hre = require("hardhat");
const prompts = require("prompts");

const weiToString = (wei) => {
    return wei
        .div(
            BigNumber.from(10).pow(14)
        )
        .toNumber() / Math.pow(10, 4);
}

const deployData = {
  polygon: {
    contracts: [
      {
        assetName: 'DAI',
        contractName: "MoneyMultiplier",
        filePath: "./artifacts/contracts/AaveMoneyMultiplier.sol/AaveMoneyMultiplier.json",
      },
    ],
    lendingPoolAddressesProvider: '0xd05e3E715d945B59290df0ae8eF85c1BdB684744',
  },
  avalanche: {

  }
}

const contractsToDeploy = 

async function main() {
  const networkName = hre.hardhatArguments.network;

  if (networkName === undefined) {
      console.log('Please set a network before deploying :D');
      return;
  }

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const balanceBegin = await deployer.getBalance();
  console.log("Account balance:", weiToString(balanceBegin));

  let startingNonce = await deployer.getTransactionCount();
  console.log('Starting nonce:', startingNonce);

  const response = await prompts({
          type: 'confirm',
          name: 'confirm',
          message: `Are you sure you want to deploy to ${networkName}?`,
          initial: false
      }
  )

  if (!response.confirm) {
      console.log("Aborting");
      return;
  }

  var allOk = true;

  for (var i = 0; i < deployData[networkName][contracts].length; i++) {
    console.log('assetName',deployData[networkName][contracts].assetName);
      // let nonce = await deployer.getTransactionCount();
      // const isOk = await deployLogic({
      //     networkName: networkName,
      //     contractName: contractsToDeploy[i].contractName,
      //     filePath: contractsToDeploy[i].filePath,
      //     nonce: nonce
      // })
      // if (!isOk) {
      //     allOk = false;
      // }
  }
  const balanceEnd = await deployer.getBalance();
  console.log("Account balance:", weiToString(balanceEnd));
  console.log("Cost to deploy:", weiToString(balanceBegin.sub(balanceEnd)));

  if (!allOk) {
      console.log('There was a problem during deployment. Will not set network blockNumber.')
  } else {
      console.log('Deploy successful!')
  }
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
