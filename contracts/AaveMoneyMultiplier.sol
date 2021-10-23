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
    address _debtTokenAddress;
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

        _aTokenAddress = _aaveLendingPool.getReserveData(tokenAddress).aTokenAddress;
        _debtTokenAddress = _aaveLendingPool.getReserveData(tokenAddress).variableDebtTokenAddress;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        console.log('flashed');
        console.log('balance before', IERC20(_tokenAddress).balanceOf(address(this)));

        Operation operation = abi.decode(params, (Operation));

        if (operation == Operation.DEPOSIT) {
            uint256 amount = IERC20(_tokenAddress).balanceOf(address(this));

            IERC20(_tokenAddress).approve(address(_aaveLendingPool), amount);

            // Lend Asset
            _aaveLendingPool.deposit(
                _tokenAddress,
                amount,
                address(this),
                0
            );
            console.log('balance after deposit', IERC20(_tokenAddress).balanceOf(address(this)));

            uint256 amountOwing = amounts[0] + premiums[0];

            // Borrow Asset
            _aaveLendingPool.borrow(_tokenAddress, amountOwing, 2, 0, address(this));
            console.log('balance after borrow', IERC20(_tokenAddress).balanceOf(address(this)));

            // Approve the LendingPool contract allowance to *pull* the owed amount
            IERC20(_tokenAddress).approve(address(_aaveLendingPool), amountOwing);

            console.log('balance before return', IERC20(_tokenAddress).balanceOf(address(this)));

        } else if (operation == Operation.WITHDRAW) {
            console.log('withdraw');
            uint256 amount = amounts[0];

            console.log('amount withdraw', amount);

            IERC20(_tokenAddress).approve(address(_aaveLendingPool), amount);

            // TODO repay balance
            _aaveLendingPool.repay(_tokenAddress, amount, 2, address(this));
            console.log('balance after repay', IERC20(_tokenAddress).balanceOf(address(this)));

            uint256 amountOwing = amounts[0] + premiums[0];

            console.log('amount owing', amountOwing);
            _aaveLendingPool.withdraw(
                _tokenAddress,
                amountOwing - IERC20(_tokenAddress).balanceOf(address(this)),
                address(this)
            );
            console.log('balance after withdraw', IERC20(_tokenAddress).balanceOf(address(this)));

            // Approve the LendingPool contract allowance to *pull* the owed amount
            IERC20(_tokenAddress).approve(address(_aaveLendingPool), amountOwing);
        }
        return true;
    }

    function deposit(uint256 amount) public {
        // Transfer Asset into contract
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = address(_tokenAddress);

        uint256 liquidityIndex = _aaveLendingPool.getReserveData(_tokenAddress).liquidityIndex;
        sumAmount += (amount * 10 ** 27) / liquidityIndex;
        userAmount[msg.sender] += (amount * 10 ** 27) / liquidityIndex;

    uint256[] memory amounts = new uint256[](1);
        amounts[0] = ((multiplier - 1025) * amount) / 1000;
        console.log('flash loan amount', amounts[0]);

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
        // Transfer Asset into contract
        // IERC20(_tokenAddress).safeTransferFrom(
        //     msg.sender,
        //     address(this),
        //     amount
        // );

        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = address(_tokenAddress);

        uint256[] memory amounts = new uint256[](1);

        uint256 liquidityIndex = _aaveLendingPool.getReserveData(_tokenAddress).liquidityIndex;

        uint256 balance = IERC20(_debtTokenAddress).balanceOf(address(this)) * amount / (userAmount[msg.sender] * liquidityIndex / 10 ** 27);
        console.log('balance', balance);
        console.log('user', userAmount[msg.sender]);
        console.log('total', sumAmount);

        amounts[0] = userAmount[msg.sender] * balance / sumAmount;
        console.log('flash loan amount', amounts[0]);

        sumAmount -= (amount * 10 ** 27) / liquidityIndex;
        userAmount[msg.sender] -= (amount * 10 ** 27) / liquidityIndex;

        uint256[] memory modes = new uint256[](1);
        modes[0] = flashLoanMode;

        address onBehalfOf = address(this);
        Operation operation = Operation.WITHDRAW;
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


        // (
        //     ,
        //     ,
        //     uint256 availableBorrowsETH,
        //     ,
        //     ,
        //     uint256 healthFactor
        // ) = _aaveLendingPool.getUserAccountData(msg.sender);
    }

    function claim() public {
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

        uint256 amount = IERC20(_tokenAddress).balanceOf(address(this));

        // Approve 0 first as a few ERC20 tokens are requiring this pattern.
        IERC20(_tokenAddress).approve(routerAddress, 0);
        IERC20(_tokenAddress).approve(routerAddress, amount);

        // uint256[] memory amounts = router.swapExactTokensForTokens(
        //     amount,
        //     1,
        //     [claimedAsset, _tokenAddress],
        //     address(this),
        //     block.timestamp + 100000
        // );
    }
}
