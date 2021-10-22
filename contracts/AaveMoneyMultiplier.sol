// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "../interfaces/IAaveLendingPool.sol";

contract AaveMoneyMultiplier {

    address _tokenAddress;
    address _aTokenAddress;
    address _aaveLendingPoolAddress;
    IAaveLendingPool _aaveLendingPool;
    uint256 interestRateMode = 2;

    constructor(address tokenAddress) {
        _tokenAddress = tokenAddress;
        _aTokenAddress = _aaveLendingPool.getReserveData(tokenAddress).aTokenAddress;
        _aaveLendingPool = ILendingPool(_aaveLendingPoolAddress);
        _aaveLendingPool.setUserUseReserveAsCollateral(_aaveLendingPoolAddress, true);
    }

    function deposit(uint256 amount) public view returns () {
        // Transfer Asset into contract
        IERC20(inputs.tokens[i]).safeTransferFrom(msg.sender, address(this), amount);

        // Lend Asset
        _aaveLendingPool.deposit(_tokenAddress,
                                 IERC20(_tokenAddress).balanceOf(address(this)),
                                 address(this),
                                 0);

        // Borrow Asset
        _aaveLendingPool.borrow(_tokenAddress, amount, interestRateMode, 0, address(this));
        (,,uint256 availableBorrowsETH,,,uint256 healthFactor) = _aaveLendingPool.getUserAccountData();
    }

    function withdraw(uint256 amount) public {
        _aaveLendingPool.withdraw(_tokenAddress, amount, address(this));
        _aaveLendingPool.repay(_tokenAddress, amount, interestRateMode, address(this));
        (,,uint256 availableBorrowsETH,,,uint256 healthFactor) = _aaveLendingPool.getUserAccountData();
    }
}
