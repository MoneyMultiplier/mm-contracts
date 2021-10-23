// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./FlashLoanReceiverBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract AaveMoneyMultiplier is FlashLoanReceiverBase {
    using SafeERC20 for IERC20;

    address _tokenAddress;
    address _aTokenAddress;
    ILendingPoolAddressesProvider _addressesProvider;
    address _aaveLendingPoolAddress;
    ILendingPool _aaveLendingPool;
    uint256 interestRateMode = 2;

    uint256 sumAmount;
    mapping(address => uint256) userAmount;

    constructor(address _addressProvider, address tokenAddress) FlashLoanReceiverBase(_addressProvider) public {
        _tokenAddress = tokenAddress;
        _addressesProvider = ILendingPoolAddressesProvider(_addressProvider);

        _aaveLendingPoolAddress = _addressesProvider.getLendingPool();
        _aaveLendingPool = ILendingPool(_aaveLendingPoolAddress);
        console.log('c2');

//        _aaveLendingPool.setUserUseReserveAsCollateral(tokenAddress, true);
//        console.log('c2.2');

        _aTokenAddress = _aaveLendingPool.getReserveData(tokenAddress).aTokenAddress;
        console.log('c3');
    }

    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    ) external override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");

        // Lend Asset
        _aaveLendingPool.deposit(_tokenAddress,
            IERC20(_tokenAddress).balanceOf(address(this)),
            address(this),
            0);

        // Borrow Asset
        _aaveLendingPool.borrow(_tokenAddress, _amount, interestRateMode, 0, address(this));

        uint totalDebt = _amount + _fee;
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    function deposit(uint256 amount, uint256 flashLoanAmount) public {
        // Transfer Asset into contract
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        // Flash Loan
        _aaveLendingPool.flashLoan(address(this), _tokenAddress, flashLoanAmount, "");
    }

    function withdraw(uint256 amount) public {
        _aaveLendingPool.withdraw(_tokenAddress, amount, address(this));
        _aaveLendingPool.repay(_tokenAddress, amount, interestRateMode, address(this));
        (,,uint256 availableBorrowsETH,,,uint256 healthFactor) = _aaveLendingPool.getUserAccountData(msg.sender);
    }

    function claim( uint256 amountInPercentage,
        uint256 amountOutMin,
        address[] calldata path) public {
        address routerAddress = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;

        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        uint256 amountIn = IERC20(path[0]).balanceOf(address(this)) * amountInPercentage / 100000;

        // Approve 0 first as a few ERC20 tokens are requiring this pattern.
        IERC20(path[0]).approve(routerAddress, 0);
        IERC20(path[0]).approve(routerAddress, amountIn);

        uint[] memory amounts = router.swapExactTokensForTokens(
        amountIn,
        amountOutMin,
        path,
        address(this),
        block.timestamp + 100000
        );
    }
}
