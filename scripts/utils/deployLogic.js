import { ethers } from "hardhat";
import { readFileSync } from "fs";

type DeployLogicProps = {
    networkName: string,
    contractName: string,
    filePath: string,
    nonce: number
}

const deployLogic = async ({ networkName, contractName, filePath, nonce } : DeployLogicProps):Promise<boolean> => {
    console.log(`Deploying ${contractName}...`);
    let contractInterface = await ethers.getContractFactory(contractName);

    const deployedContract = await contractInterface.deploy({'nonce': nonce});

    await deployedContract.deployed();

    console.log(`${contractName} contract deployed on ${networkName} at: ${deployedContract.address}`);

    const contractFile = readFileSync(
        filePath,
        'utf8')
    const contract = JSON.parse(contractFile)

    console.log(`${contractName} on ${networkName} inserted into DB.`)

    return Promise.resolve(true);
}

export default deployLogic;
