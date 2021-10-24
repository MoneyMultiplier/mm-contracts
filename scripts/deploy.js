// import {BigNumber} from "ethers";
// import { readFileSync } from "fs";

const hre = require("hardhat");
const { BigNumber } = hre.ethers;
// const { ethers } = require("ethers");

const deployLogic = async ({ networkName, contractName, assetName, assetSymbol, nonce, addresses }) => {
  console.log(`Deploying ${contractName} for ${assetName}...`);
  let contractInterface = await hre.ethers.getContractFactory(contractName);

  const deployedContract = await contractInterface.deploy(
    addresses['daiAddress'],
    addresses['addressProvider'],
    addresses['aaveControllerAddress'],
    addresses['uniswapRouterAddress'],
    assetName,
    assetSymbol,
    {'nonce': nonce}
  );
  // .deploy({'nonce': nonce});

  await deployedContract.deployed();

  console.log(`Deployed at: ${deployedContract.address}`);

  // const contractFile = readFileSync(
  //     filePath,
  //     'utf8')
  // const contract = JSON.parse(contractFile)

  // console.log(`${contractName} on ${networkName} inserted into DB.`)

  return Promise.resolve(true);
}

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
        assetSymbol: 'DAI',
        contractName: "AaveMoneyMultiplier",
      },
    ],
    addresses: {
      lendingPoolAddressesProvider: '0xd05e3E715d945B59290df0ae8eF85c1BdB684744',
      uniswapRouterAddress: "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff",
      aaveControllerAddress: "0x357D51124f59836DeD84c8a1730D72B749d8BC23",
      addressProvider: "0xd05e3E715d945B59290df0ae8eF85c1BdB684744",
      daiAddress: "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063",  
    }
  },
  avalanche: {

  }
}

async function main() {
  const networkName = hre.hardhatArguments.network;

  if (networkName === undefined) {
      console.log('Please set a network before deploying');
      return;
  }

  // console.log(hre);
  // console.log(hre);
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const balanceBegin = await deployer.getBalance();
  console.log("Account balance:", weiToString(balanceBegin));

  let startingNonce = await deployer.getTransactionCount();
  console.log('Starting nonce:', startingNonce);

  var allOk = true;

  for (var i = 0; i < deployData[networkName]['contracts'].length; i++) {
      let nonce = await deployer.getTransactionCount();
      const isOk = await deployLogic({
          networkName: networkName,
          contractName: deployData[networkName]['contracts'][i].contractName,
          assetName: deployData[networkName]['contracts'][i].assetName,
          assetSymbol: deployData[networkName]['contracts'][i].assetSymbol,
          addresses: deployData[networkName]['addresses'],
          nonce: nonce
      })
      if (!isOk) {
          allOk = false;
      }
  }
  const balanceEnd = await deployer.getBalance();
  console.log("Account balance:", weiToString(balanceEnd));
  console.log("Cost to deploy:", weiToString(balanceBegin.sub(balanceEnd)));

  if (!allOk) {
      console.log('There was a problem during deployment.')
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
