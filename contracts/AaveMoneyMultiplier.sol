// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "../interfaces/IAaveLendingPool.sol";

contract AaveMoneyMultiplier {

    address _tokenAddress;
    address _aaveLendingPoolAddress;
    IAaveLendingPool _aaveLendingPool;
    uint256 interestRateMode = 2;

    constructor(address tokenAddress) {
        _tokenAddress = tokenAddress;
        _aaveLendingPool = ILendingPool(_aaveLendingPoolAddress);
        _aaveLendingPool.setUserUseReserveAsCollateral(_aaveLendingPoolAddress, true);
    }

    function deposit(uint256 amount) public view returns () {
        _aaveLendingPool.deposit(_tokenAddress, amount, address(this), 0);
        _aaveLendingPool.borrow(_tokenAddress, amount, interestRateMode, 0, address(this));
        return greeting;
    }

    function withdraw(uint256 amount) public {
        _aaveLendingPool.withdraw(_tokenAddress, amount, address(this));
    }
}
