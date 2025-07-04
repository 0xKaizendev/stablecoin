// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { NexusCoin } from "../../src/NexusCoin.sol";
import { NexusEngine } from "../../src/NexusEngine.sol";

import { StdCheats } from "forge-std/StdCheats.sol";
import { DeployNEX } from "../../script/DeployNEX.s.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
import { MockMoreDebtNEX } from "../mocks/MockMoreDebtNEX.sol";
import { MockFailedMintNEX } from "../mocks/MockFailedMintNEX.sol";
import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";
import { MockFailedTransfer } from "../mocks/MockFailedTransfer.sol";
import { Test, console } from "forge-std/Test.sol";
import { StdCheats } from "forge-std/StdCheats.sol";

contract NexusEngineTest is Test {
    event CollateralRedeemed(address indexed redeemFrom, address indexed redeemTo, address token, uint256 amount);

    NexusEngine public nexe;
    NexusCoin public nex;
    HelperConfig public helperConfig;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;
    address public user = address(1);

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() external {
        DeployNEX deployer = new DeployNEX();
        (nex, nexe, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        if (block.chainid == 31_337) {
            vm.deal(user, STARTING_USER_BALANCE);
        }
        // Should we put our integration tests here?
        // else {
        //     user = vm.addr(deployerKey);
        //     ERC20Mock mockErc = new ERC20Mock("MOCK", "MOCK", user, 100e18);
        //     MockV3Aggregator aggregatorMock = new MockV3Aggregator(
        //         helperConfig.DECIMALS(),
        //         helperConfig.ETH_USD_PRICE()
        //     );
        //     vm.etch(weth, address(mockErc).code);
        //     vm.etch(wbtc, address(mockErc).code);
        //     vm.etch(ethUsdPriceFeed, address(aggregatorMock).code);
        //     vm.etch(btcUsdPriceFeed, address(aggregatorMock).code);
        // }
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    address[] public tokenAddresses;
    address[] public feedAddresses;

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        feedAddresses.push(ethUsdPriceFeed);
        feedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(NexusEngine.NexusEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new NexusEngine(tokenAddresses, feedAddresses, address(nex));
    }

    function testGetTokenAmountFromUsd() public view {
        // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
        uint256 expectedWeth = 0.05 ether;
        uint256 amountWeth = nexe.getTokenAmountFromUsd(weth, 100 ether);
        assertEq(amountWeth, expectedWeth);
    }

    function testUsdValue() public view {
        uint256 ethAmount = 15e18;
        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30_000e18;
        uint256 usdValue = nexe.getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    function testRevertsIfTransferFromFails() public {
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransferFrom mockCollateralToken = new MockFailedTransferFrom();
        tokenAddresses = [address(mockCollateralToken)];
        feedAddresses = [ethUsdPriceFeed];
        // DSCEngine receives the third parameter as dscAddress, not the tokenAddress used as collateral.
        vm.prank(owner);
        NexusEngine mockDsce = new NexusEngine(tokenAddresses, feedAddresses, address(nex));
        mockCollateralToken.mint(user, amountCollateral);
        vm.startPrank(user);
        ERC20Mock(address(mockCollateralToken)).approve(address(mockDsce), amountCollateral);
        // Act / Assert
        vm.expectRevert(NexusEngine.NexusEngine__TransferFailed.selector);
        mockDsce.depositCollateral(address(mockCollateralToken), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);

        vm.expectRevert(NexusEngine.NexusEngine__NeedsMoreThanZero.selector);
        nexe.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(NexusEngine.NexusEngine__TokenNotAllowed.selector, address(randToken)));
        nexe.depositCollateral(address(randToken), amountCollateral);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralWithoutMinting() public depositedCollateral {
        uint256 userBalance = nex.balanceOf(user);
        assertEq(userBalance, 0);
    }

    function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalNexMinted, uint256 collateralValueInUsd) = nexe.getAccountInformation(user);
        uint256 expectedDepositedAmount = nexe.getTokenAmountFromUsd(weth, collateralValueInUsd);
        assertEq(totalNexMinted, 0);
        assertEq(expectedDepositedAmount, amountCollateral);
    }

    ///////////////////////////////////////
    // depositCollateralAndMintDsc Tests //
    ///////////////////////////////////////

    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * nexe.getAdditionalFeedPrecision())) / nexe.getPrecision();
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);

        uint256 expectedHealthFactor =
            nexe.calculateHealthFactor(amountToMint, nexe.getUsdValue(weth, amountCollateral));
        vm.expectRevert(
            abi.encodeWithSelector(NexusEngine.NexusEngine__BreaksHealthFactor.selector, expectedHealthFactor)
        );
        nexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    modifier depositedCollateralAndMintedDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        _;
    }

    function testCanMintWithDepositedCollateral() public depositedCollateralAndMintedDsc {
        uint256 userBalance = nex.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }
    ///////////////////////////////////
    // mintDsc Tests //
    ///////////////////////////////////
    // This test needs it's own custom setup

    function testRevertsIfMintFails() public {
        // Arrange - Setup
        MockFailedMintNEX mockDsc = new MockFailedMintNEX();
        tokenAddresses = [weth];
        feedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        NexusEngine mockDsce = new NexusEngine(tokenAddresses, feedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockDsce), amountCollateral);

        vm.expectRevert(NexusEngine.NexusEngine__MintFailed.selector);
        mockDsce.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.expectRevert(NexusEngine.NexusEngine__NeedsMoreThanZero.selector);
        nexe.mintNex(0);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountBreaksHealthFactor() public depositedCollateral {
        // 0xe580cc6100000000000000000000000000000000000000000000000006f05b59d3b20000
        // 0xe580cc6100000000000000000000000000000000000000000000003635c9adc5dea00000
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint = (amountCollateral * (uint256(price) * nexe.getAdditionalFeedPrecision())) / nexe.getPrecision();

        vm.startPrank(user);
        uint256 expectedHealthFactor =
            nexe.calculateHealthFactor(amountToMint, nexe.getUsdValue(weth, amountCollateral));
        vm.expectRevert(
            abi.encodeWithSelector(NexusEngine.NexusEngine__BreaksHealthFactor.selector, expectedHealthFactor)
        );
        nexe.mintNex(amountToMint);
        vm.stopPrank();
    }

    function testCanMintDsc() public depositedCollateral {
        vm.prank(user);
        nexe.mintNex(amountToMint);

        uint256 userBalance = nex.balanceOf(user);
        assertEq(userBalance, amountToMint);
    }

    ///////////////////////////////////
    // burnDsc Tests //
    ///////////////////////////////////

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.expectRevert(NexusEngine.NexusEngine__NeedsMoreThanZero.selector);
        nexe.burnNex(0);
        vm.stopPrank();
    }

    function testCantBurnMoreThanUserHas() public {
        vm.prank(user);
        vm.expectRevert();
        nexe.burnNex(1);
    }

    function testCanBurnDsc() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        nex.approve(address(nexe), amountToMint);
        nexe.burnNex(amountToMint);
        vm.stopPrank();

        uint256 userBalance = nex.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ///////////////////////////////////
    // redeemCollateral Tests //
    //////////////////////////////////

    // this test needs it's own setup
    function testRevertsIfTransferFails() public {
        // Arrange - Setup
        address owner = msg.sender;
        vm.prank(owner);
        MockFailedTransfer mockNex = new MockFailedTransfer();
        tokenAddresses = [address(mockNex)];
        feedAddresses = [ethUsdPriceFeed];
        vm.prank(owner);
        NexusEngine mockNexe = new NexusEngine(tokenAddresses, feedAddresses, address(mockNex));
        mockNex.mint(user, amountCollateral);

        vm.prank(owner);
        mockNex.transferOwnership(address(mockNexe));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(address(mockNex)).approve(address(mockNexe), amountCollateral);
        // Act / Assert
        mockNexe.depositCollateral(address(mockNex), amountCollateral);
        vm.expectRevert(NexusEngine.NexusEngine__TransferFailed.selector);
        mockNexe.redeemCollateral(address(mockNex), amountCollateral);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.expectRevert(NexusEngine.NexusEngine__NeedsMoreThanZero.selector);
        nexe.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateral() public depositedCollateral {
        vm.startPrank(user);
        uint256 userBalanceBeforeRedeem = nexe.getCollateralBalanceOfUser(user, weth);
        assertEq(userBalanceBeforeRedeem, amountCollateral);
        nexe.redeemCollateral(weth, amountCollateral);
        uint256 userBalanceAfterRedeem = nexe.getCollateralBalanceOfUser(user, weth);
        assertEq(userBalanceAfterRedeem, 0);
        vm.stopPrank();
    }

    function testEmitCollateralRedeemedWithCorrectArgs() public depositedCollateral {
        vm.expectEmit(true, true, true, true, address(nexe));
        emit CollateralRedeemed(user, user, weth, amountCollateral);
        vm.startPrank(user);
        nexe.redeemCollateral(weth, amountCollateral);
        vm.stopPrank();
    }
    ///////////////////////////////////
    // redeemCollateralForDsc Tests //
    //////////////////////////////////

    function testMustRedeemMoreThanZero() public depositedCollateralAndMintedDsc {
        vm.startPrank(user);
        nex.approve(address(nexe), amountToMint);
        vm.expectRevert(NexusEngine.NexusEngine__NeedsMoreThanZero.selector);
        nexe.redeemCollateralForNex(weth, 0, amountToMint);
        vm.stopPrank();
    }

    function testCanRedeemDepositedCollateral() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        nex.approve(address(nexe), amountToMint);
        nexe.redeemCollateralForNex(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        uint256 userBalance = nex.balanceOf(user);
        assertEq(userBalance, 0);
    }

    ////////////////////////
    // healthFactor Tests //
    ////////////////////////

    function testProperlyReportsHealthFactor() public depositedCollateralAndMintedDsc {
        uint256 expectedHealthFactor = 100 ether;
        uint256 healthFactor = nexe.getHealthFactor(user);
        // $100 minted with $20,000 collateral at 50% liquidation threshold
        // means that we must have $200 collatareral at all times.
        // 20,000 * 0.5 = 10,000
        // 10,000 / 100 = 100 health factor
        assertEq(healthFactor, expectedHealthFactor);
    }

    function testHealthFactorCanGoBelowOne() public depositedCollateralAndMintedDsc {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        // Remember, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = nexe.getHealthFactor(user);
        // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
        // 0.9
        assert(userHealthFactor == 0.9 ether);
    }

    ///////////////////////
    // Liquidation Tests //
    ///////////////////////

    // This test needs it's own setup
    function testMustImproveHealthFactorOnLiquidation() public {
        // Arrange - Setup
        MockMoreDebtNEX mockNex = new MockMoreDebtNEX(ethUsdPriceFeed);
        tokenAddresses = [weth];
        feedAddresses = [ethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        NexusEngine mockNexe = new NexusEngine(tokenAddresses, feedAddresses, address(mockNex));
        mockNex.transferOwnership(address(mockNexe));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockNexe), amountCollateral);
        mockNexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.stopPrank();

        // Arrange - Liquidator
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockNexe), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockNexe.depositCollateralAndMintNex(weth, collateralToCover, amountToMint);
        mockNex.approve(address(mockNexe), debtToCover);
        // Act
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        vm.expectRevert(NexusEngine.NexusEngine__HealthFactorNotImproved.selector);
        mockNexe.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public depositedCollateralAndMintedDsc {
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(nexe), collateralToCover);
        nexe.depositCollateralAndMintNex(weth, collateralToCover, amountToMint);
        nex.approve(address(nexe), amountToMint);

        vm.expectRevert(NexusEngine.NexusEngine__HealthFactorOk.selector);
        nexe.liquidate(weth, user, amountToMint);
        vm.stopPrank();
    }

    modifier liquidated() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateralAndMintNex(weth, amountCollateral, amountToMint);
        vm.stopPrank();
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18

        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactor = nexe.getHealthFactor(user);

        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(nexe), collateralToCover);
        nexe.depositCollateralAndMintNex(weth, collateralToCover, amountToMint);
        nex.approve(address(nexe), amountToMint);
        nexe.liquidate(weth, user, amountToMint); // We are covering their whole debt
        vm.stopPrank();
        _;
    }

    function testLiquidationPayoutIsCorrect() public liquidated {
        uint256 liquidatorWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedWeth = nexe.getTokenAmountFromUsd(weth, amountToMint)
            + (nexe.getTokenAmountFromUsd(weth, amountToMint) * nexe.getLiquidationBonus() / nexe.getLiquidationPrecision());
        uint256 hardCodedExpected = 6_111_111_111_111_111_110;
        assertEq(liquidatorWethBalance, hardCodedExpected);
        assertEq(liquidatorWethBalance, expectedWeth);
    }

    function testUserStillHasSomeEthAfterLiquidation() public liquidated {
        // Get how much WETH the user lost
        uint256 amountLiquidated = nexe.getTokenAmountFromUsd(weth, amountToMint)
            + (nexe.getTokenAmountFromUsd(weth, amountToMint) * nexe.getLiquidationBonus() / nexe.getLiquidationPrecision());

        uint256 usdAmountLiquidated = nexe.getUsdValue(weth, amountLiquidated);
        uint256 expectedUserCollateralValueInUsd = nexe.getUsdValue(weth, amountCollateral) - (usdAmountLiquidated);

        (, uint256 userCollateralValueInUsd) = nexe.getAccountInformation(user);
        uint256 hardCodedExpectedValue = 70_000_000_000_000_000_020;
        assertEq(userCollateralValueInUsd, expectedUserCollateralValueInUsd);
        assertEq(userCollateralValueInUsd, hardCodedExpectedValue);
    }

    function testLiquidatorTakesOnUsersDebt() public liquidated {
        (uint256 liquidatorDscMinted,) = nexe.getAccountInformation(liquidator);
        assertEq(liquidatorDscMinted, amountToMint);
    }

    function testUserHasNoMoreDebt() public liquidated {
        (uint256 userDscMinted,) = nexe.getAccountInformation(user);
        assertEq(userDscMinted, 0);
    }

    ///////////////////////////////////
    // View & Pure Function Tests //
    //////////////////////////////////
    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = nexe.getCollateralTokenPriceFeed(weth);
        assertEq(priceFeed, ethUsdPriceFeed);
    }

    function testGetCollateralTokens() public {
        address[] memory collateralTokens = nexe.getCollateralTokens();
        assertEq(collateralTokens[0], weth);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = nexe.getMinHealthFactor();
        assertEq(minHealthFactor, MIN_HEALTH_FACTOR);
    }

    function testGetLiquidationThreshold() public {
        uint256 liquidationThreshold = nexe.getLiquidationThreshold();
        assertEq(liquidationThreshold, LIQUIDATION_THRESHOLD);
    }

    function testGetAccountCollateralValueFromInformation() public depositedCollateral {
        (, uint256 collateralValue) = nexe.getAccountInformation(user);
        uint256 expectedCollateralValue = nexe.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetCollateralBalanceOfUser() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralBalance = nexe.getCollateralBalanceOfUser(user, weth);
        assertEq(collateralBalance, amountCollateral);
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(nexe), amountCollateral);
        nexe.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        uint256 collateralValue = nexe.getAccountCollateralValue(user);
        uint256 expectedCollateralValue = nexe.getUsdValue(weth, amountCollateral);
        assertEq(collateralValue, expectedCollateralValue);
    }

    function testGetDsc() public {
        address nexAddress = nexe.getNexus();
        assertEq(nexAddress, address(nex));
    }

    function testLiquidationPrecision() public {
        uint256 expectedLiquidationPrecision = 100;
        uint256 actualLiquidationPrecision = nexe.getLiquidationPrecision();
        assertEq(actualLiquidationPrecision, expectedLiquidationPrecision);
    }
}
