// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/FlashLoanReceiverBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/IAaveIncentivesController.sol";

contract AaveMoneyMultiplier is FlashLoanReceiverBase {
    using SafeERC20 for IERC20;

    address _tokenAddress;
    address _aTokenAddress;
    ILendingPoolAddressesProvider _addressesProvider;
    address _aaveLendingPoolAddress;
    ILendingPool _aaveLendingPool;
    uint256 interestRateMode = 2;
    uint256 flashLoanMode = 0;
    uint256 multiplier;

    uint256 constant LTV_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000;
    uint256 sumAmount;
    mapping(address => uint256) userAmount;

    enum Operation {
        DEPOSIT,
        WITHDRAW
    }

    constructor(address _addressProvider, address tokenAddress)
        public
        FlashLoanReceiverBase(_addressProvider)
    {
        _tokenAddress = tokenAddress;
        _addressesProvider = ILendingPoolAddressesProvider(_addressProvider);

        _aaveLendingPoolAddress = _addressesProvider.getLendingPool();
        _aaveLendingPool = ILendingPool(_aaveLendingPoolAddress);

        //        _aaveLendingPool.setUserUseReserveAsCollateral(tokenAddress, true);
        //        console.log('c2.2');

        multiplier = 10000000 / (10000 - (_aaveLendingPool.getConfiguration(tokenAddress).data & ~LTV_MASK));

        _aTokenAddress = _aaveLendingPool
            .getReserveData(tokenAddress)
            .aTokenAddress;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        console.log('flashed');
        console.log('balance before', IERC20(assets[0]).balanceOf(address(this)));

        Operation operation = abi.decode(params, (Operation));

        if (operation == Operation.DEPOSIT) {
            console.log('tokenAddress', _tokenAddress);
            console.log('assets0', assets[0]);
            // require(
            //     _amount <= getBalanceInternal(address(this), _reserve),
            //     "Invalid balance, was the flashLoan successful?"
            // );

            uint256 amount = IERC20(assets[0]).balanceOf(address(this));

            IERC20(assets[0]).approve(address(_aaveLendingPool), amount);

            // Lend Asset
            _aaveLendingPool.deposit(
                _tokenAddress,
                amount,
                address(this),
                0
            );
            console.log('balance after deposit', IERC20(assets[0]).balanceOf(address(this)));

            uint256 amountOwing = amounts[0] + premiums[0];

            // Borrow Asset
            _aaveLendingPool.borrow(assets[0], amountOwing, 2, 0, address(this));
            console.log('balance after borrow', IERC20(assets[0]).balanceOf(address(this)));

            // Approve the LendingPool contract allowance to *pull* the owed amount
            IERC20(assets[0]).approve(address(_aaveLendingPool), amountOwing);

            console.log('balance before return', IERC20(assets[0]).balanceOf(address(this)));
            return true;
            // transferFundsBackToPoolInternal(_reserve, totalDebt);
        }
    }

    function deposit(uint256 amount) public {
        // Transfer Asset into contract
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        uint256 liquidityIndex = _aaveLendingPool
            .getReserveData(_tokenAddress)
            .liquidityIndex;
        sumAmount += amount / liquidityIndex; //TODO deal with floating numbers
        userAmount[msg.sender] += amount / liquidityIndex; //TODO deal with floating numbers

        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = address(_tokenAddress);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = ((multiplier - 1025) * amount) / 1000;
        console.log('flash loan amount', amounts[0]);

        // 0 = no debt, 1 = stable, 2 = variable
        uint256[] memory modes = new uint256[](1);
        modes[0] = flashLoanMode;

        address onBehalfOf = address(this);
        Operation operation = Operation.DEPOSIT;
        bytes memory params = abi.encode(operation);
        uint16 referralCode = 0;

        console.log('gonna flash');
        // Flash Loan
        _aaveLendingPool.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function withdraw(uint256 amount) public {
        uint256 liquidityIndex = _aaveLendingPool
            .getReserveData(_tokenAddress)
            .liquidityIndex;

        sumAmount -= amount / liquidityIndex; //TODO deal with floating numbers
        userAmount[msg.sender] -= amount / liquidityIndex; //TODO deal with floating numbers

        _aaveLendingPool.withdraw(_tokenAddress, amount, address(this));
        _aaveLendingPool.repay(
            _tokenAddress,
            amount,
            interestRateMode,
            address(this)
        );
        (
            ,
            ,
            uint256 availableBorrowsETH,
            ,
            ,
            uint256 healthFactor
        ) = _aaveLendingPool.getUserAccountData(msg.sender);
    }

    function claim(
        uint256 amountInPercentage,
        uint256 amountOutMin,
        address[] calldata path
    ) public {
        address incentivesControllerAddress = 0x357D51124f59836DeD84c8a1730D72B749d8BC23;
        IAaveIncentivesController distributor = IAaveIncentivesController(
            incentivesControllerAddress
        );

        address[] memory assets = new address[](1);
        assets[0] = _aTokenAddress;

        uint256 amountToClaim = distributor.getRewardsBalance(
            assets,
            address(this)
        );
        uint256 claimedReward = distributor.claimRewards(
            assets,
            amountToClaim,
            address(this)
        );
        address claimedAsset = distributor.REWARD_TOKEN();

        address routerAddress = 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff;
        IUniswapV2Router02 router = IUniswapV2Router02(routerAddress);

        uint256 amountIn = (IERC20(path[0]).balanceOf(address(this)) *
            amountInPercentage) / 100000;

        // Approve 0 first as a few ERC20 tokens are requiring this pattern.
        IERC20(path[0]).approve(routerAddress, 0);
        IERC20(path[0]).approve(routerAddress, amountIn);

        uint256[] memory amounts = router.swapExactTokensForTokens(
            amountIn,
            amountOutMin,
            path,
            address(this),
            block.timestamp + 100000
        );
    }
}
