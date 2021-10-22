// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "../interfaces/IAaveLendingPool.sol";

contract AaveMoneyMultiplier {

    address _tokenAddress;
    address aaveLendingPoolAddress =;
    IAaveLendingPool _aaveLendingPool = ILendingPool(aaveLendingPoolAddress);


    constructor(address tokenAddress) {
        _tokenAddress = tokenAddress;
    setUserUseReserveAsCollateral; // TODO
    }

    function deposit(uint256 amount) public view returns () {
        _aaveLendingPool.deposit(_tokenAddress, amount, address(this), 0);

        return greeting;
    }

    function withdraw(uint256 amount) public {
        console.log("Withdraw");
    }
}
