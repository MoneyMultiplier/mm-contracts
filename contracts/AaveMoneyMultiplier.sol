// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ILendingPoolAddressesProvider.sol";
import "./interfaces/FlashLoanReceiverBase.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./interfaces/IAaveIncentivesController.sol";

contract AaveMoneyMultiplier is FlashLoanReceiverBase, ERC20 {
    using SafeERC20 for IERC20;

    // Token Addresses
    address _tokenAddress;
    address _aTokenAddress;
    address _debtTokenAddress;

    // Aave
    address immutable _aaveLendingPoolAddress;
    ILendingPoolAddressesProvider _addressesProvider;
    ILendingPool _aaveLendingPool;
    address immutable _incentivesControllerAddress;

    // Config
    uint256 constant interestRateMode = 2;
    uint256 constant flashLoanMode = 0;
    uint256 immutable multiplier;
    address immutable _routerAddress;

    // Helpers
    uint256 constant LTV_MASK = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000;
    enum Operation {
        DEPOSIT,
        WITHDRAW
    }

    constructor(address tokenAddress,
                address _addressProvider,
                address incentivesControllerAddress,
                address routerAddress,
                string memory name,
                string memory symbol)
    public
        FlashLoanReceiverBase(_addressProvider)
        ERC20(name, symbol)
    {
        _tokenAddress = tokenAddress;
        _addressesProvider = ILendingPoolAddressesProvider(_addressProvider);

        _aaveLendingPoolAddress = _addressesProvider.getLendingPool();
        _aaveLendingPool = ILendingPool(_aaveLendingPoolAddress);

        // This is the maximum leverage we can achieve * 1000 (4x leverage = 4000)
        multiplier = 10000000 / (10000 - (_aaveLendingPool.getConfiguration(tokenAddress).data & ~LTV_MASK));

        _aTokenAddress = _aaveLendingPool.getReserveData(tokenAddress).aTokenAddress;
        _debtTokenAddress = _aaveLendingPool.getReserveData(tokenAddress).variableDebtTokenAddress;

        _incentivesControllerAddress = incentivesControllerAddress;
        _routerAddress = routerAddress;
    }

    function deposit(uint256 amount) public {
        console.log('deposit');
        // Transfer Asset into contract
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        // Track balance in contract
        uint256 liquidityIndex = _aaveLendingPool.getReserveData(_tokenAddress).liquidityIndex;
        _mint(msg.sender, (amount * 10 ** 27) / liquidityIndex);

        // FlashLoan params
        address receiverAddress = address(this);
        address[] memory assets = new address[](1);
        assets[0] = address(_tokenAddress);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = (multiplier * 995 * amount) / 1000;

        uint256[] memory modes = new uint256[](1);
        modes[0] = flashLoanMode;

        address onBehalfOf = address(this);
        Operation operation = Operation.DEPOSIT;
        bytes memory params = abi.encode(operation, 0);
        uint16 referralCode = 0;

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
        console.log('withdraw');

        // Track balance in contract
        uint256 liquidityIndex = _aaveLendingPool.getReserveData(_tokenAddress).liquidityIndex;
        _burn(msg.sender, (amount * 10 ** 27) / liquidityIndex);

        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = address(_tokenAddress);

        uint256[] memory amounts = new uint256[](1);
        uint256 debtBalance = IERC20(_debtTokenAddress).balanceOf(address(this)) * amount / (balanceOf(msg.sender) * liquidityIndex / 10 ** 27);
        amounts[0] = balanceOf(msg.sender) * debtBalance / totalSupply();

        uint256 assetBalance = IERC20(_aTokenAddress).balanceOf(address(this)) * amount / (balanceOf(msg.sender) * liquidityIndex / 10 ** 27);
        uint256 aTokenAmount = balanceOf(msg.sender) * assetBalance / totalSupply();

        uint256[] memory modes = new uint256[](1);
        modes[0] = flashLoanMode;

        address onBehalfOf = address(this);
        Operation operation = Operation.WITHDRAW;
        bytes memory params = abi.encode(operation, aTokenAmount);
        uint16 referralCode = 0;

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

        // Transfer tokens back to owner
        IERC20(_tokenAddress).safeTransfer(msg.sender, aTokenAmount);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        (Operation operation, uint256 aTokenAmount) = abi.decode(params, (Operation, uint256));

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

            uint256 amountOwing = amounts[0] + premiums[0];

            // Borrow Asset
            _aaveLendingPool.borrow(_tokenAddress, amountOwing, 2, 0, address(this));

            // Approve the LendingPool contract allowance to *pull* the owed amount
            IERC20(_tokenAddress).approve(address(_aaveLendingPool), amountOwing);

        } else if (operation == Operation.WITHDRAW) {
            uint256 amount = amounts[0];

            IERC20(_tokenAddress).approve(address(_aaveLendingPool), amount);
            _aaveLendingPool.repay(_tokenAddress, amount, 2, address(this));

            uint256 amountOwing = amounts[0] + premiums[0];

            _aaveLendingPool.withdraw(
                _tokenAddress,
                aTokenAmount - IERC20(_tokenAddress).balanceOf(address(this)),
                address(this)
            );

            // Approve the LendingPool contract allowance to *pull* the owed amount
            IERC20(_tokenAddress).approve(address(_aaveLendingPool), amountOwing);
        }
        return true;
    }

    function claim() public {
        IAaveIncentivesController distributor = IAaveIncentivesController(
            _incentivesControllerAddress
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

        IUniswapV2Router02 router = IUniswapV2Router02(_routerAddress);

        uint256 amount = IERC20(_tokenAddress).balanceOf(address(this));

        // Approve 0 first as a few ERC20 tokens are requiring this pattern.
        IERC20(_tokenAddress).approve(_routerAddress, 0);
        IERC20(_tokenAddress).approve(_routerAddress, amount);

        address[] memory path = new address[](2);
        path[0] = claimedAsset;
        path[1] = _tokenAddress;

        router.swapExactTokensForTokens(
             amount,
             1,
             path,
             address(this),
             block.timestamp + 100000
         );

        _aaveLendingPool.deposit(
            _tokenAddress,
            IERC20(_tokenAddress).balanceOf(address(this)),
            address(this),
            0
        );
    }

    function scaledBalanceOf(address user) external view returns (uint256) {
        // TODO
        return 0;
    }
}
