const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AaveMoneyMultiplier", function () {
                                                                                                                                                                  let addressProvider;
  let uniswapRouter;

  let daiAddress;
  let wMaticAddress;

  let AaveMoneyMultiplier;
  let aaveMoneyMultiplier;

  let uniswapV2Router02;
  beforeEach(async function () {
    addressProvider = "0xd05e3E715d945B59290df0ae8eF85c1BdB684744";
    uniswapRouter = "0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff";
  
    daiAddress = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
    wMaticAddress = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";  

    AaveMoneyMultiplier = await ethers.getContractFactory("AaveMoneyMultiplier");
    aaveMoneyMultiplier = await AaveMoneyMultiplier.deploy(addressProvider, daiAddress);
    await aaveMoneyMultiplier.deployed();

    uniswapV2Router02 = await ethers.getContractAt("IUniswapV2Router02", uniswapRouter);

  });

  it("Testing a deposit then a withdraw", async function () {
    let [owner] = await ethers.getSigners();

    let amount = 100000;

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
      { value: ethers.utils.parseEther("1") },
    )

    dai = await ethers.getContractAt("IERC20", daiAddress);
    await dai.approve(aaveMoneyMultiplier.address, amount);


    console.log('dai', dai)
    console.log('amount', amount)
    let tx = await aaveMoneyMultiplier.deposit(amount);
    console.log('tx', tx)

    tx.wait();

  });

});
