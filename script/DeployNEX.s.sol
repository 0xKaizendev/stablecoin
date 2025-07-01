// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { NexusEngine } from "../src/NexusEngine.sol";
import { NexusCoin } from "../src/NexusCoin.sol";

contract DeployNEX is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns (NexusCoin, NexusEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(deployerKey);

        NexusCoin nex = new NexusCoin();
        NexusEngine nexe = new NexusEngine(tokenAddresses, priceFeedAddresses, address(nex));
        nex.transferOwnership(address(nexe));

        vm.stopBroadcast();

        return (nex, nexe, helperConfig);
    }
}
