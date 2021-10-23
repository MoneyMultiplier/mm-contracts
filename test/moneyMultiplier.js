const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AaveMoneyMultiplier", function () {
  it("Should return the new greeting once it's changed", async function () {
    const addressProvider = "0x3ac4e9aa29940770aeC38fe853a4bbabb2dA9C19";
    const uniswapRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";

    const daiAddress = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
    const wMaticAddress = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";

    const MM = await ethers.getContractFactory("AaveMoneyMultiplier");
    const mm = await MM.deploy(addressProvider, daiAddress);
    await mm.deployed();

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

    mm.deposit(amount, flashLoanAmount);
  });
});