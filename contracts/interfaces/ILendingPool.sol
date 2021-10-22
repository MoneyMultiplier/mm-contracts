// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;

import {DataTypes} from '../libraries/DataTypes.sol';

interface ILendingPool {
    function flashLoan(address _receiver, address _reserve, uint256 _amount, bytes memory _params) external;

    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

    function withdraw(address asset, uint256 amount, address to) external returns (uint256);

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode,
        uint16 referralCode,
        address onBehalfOf
    ) external;

    function repay(
        address asset,
        uint256 amount,
        uint256 rateMode,
        address onBehalfOf
    ) external returns (uint256);

    function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

    function getUserAccountData(address user)
    external
    view
    returns (
        uint256 totalCollateralETH,
        uint256 totalDebtETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );

    function setUserUseReserveAsCollateral(address _reserve, bool _useAsCollateral) external;
}