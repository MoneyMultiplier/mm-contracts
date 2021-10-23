const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AaveMoneyMultiplier", function () {
  it("Testing a deposit", async function () {
    const addressProvider = "0xd05e3E715d945B59290df0ae8eF85c1BdB684744";
    const uniswapRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";

    const daiAddress = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
    const wMaticAddress = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

    const AaveMoneyMultiplier = await ethers.getContractFactory("AaveMoneyMultiplier");
    const aaveMoneyMultiplier = await AaveMoneyMultiplier.deploy(addressProvider, daiAddress);
    await aaveMoneyMultiplier.deployed();

    let [owner] = await ethers.getSigners();

    let uniswapV2Router02 = await ethers.getContractAt("IUniswapV2Router02", uniswapRouter);

    let amount = 100000;
    let flashLoanAmount = 200000;

    let dai = await ethers.getContractAt("IERC20", daiAddress);

    let provider = await ethers.getDefaultProvider();
    let blockNumber = await provider.getBlockNumber();
    let block = await provider.getBlock(blockNumber);

    await uniswapV2Router02.swapExactETHForTokens(
        1,
        [
          wMaticAddress,
          daiAddress
        ],
        owner.address,
        block.timestamp + 100000,
       {value: ethers.utils.parseEther("1")},
    )

    dai = await ethers.getContractAt("IERC20", daiAddress);
    amount = await dai.balanceOf(owner.address);

    aaveMoneyMultiplier.deposit(amount, flashLoanAmount);
  });
});
