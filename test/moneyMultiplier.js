const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AaveMoneyMultiplier", function () {
  it("Should return the new greeting once it's changed", async function () {
    const addressProvider = "0x3ac4e9aa29940770aeC38fe853a4bbabb2dA9C19";
    const daiAddress = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";

    const MM = await ethers.getContractFactory("AaveMoneyMultiplier");
    const mm = await Greeter.deploy(addressProvider, daiAddress);
    await mm.deployed();

    let amount = 100000;
    let flashLoanAmount = 200000;

    let dai = await ethers.getContractAt("IERC20", daiAddress);

    mm.deposit(amount, flashLoanAmount);
  });
});
