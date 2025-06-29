// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {NexusCoin} from "../../src/NexusCoin.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {DeployNEX} from "../../script/DeployNEX.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {MockMoreDebtNEX} from "../mocks/MockMoreDebtNEX.sol";
import {MockFailedMintNEX} from "../mocks/MockFailedMintNEX.sol";
import {MockFailedTransferFrom} from "../mocks/MockFailedTransferFrom.sol";
import {MockFailedTransfer} from "../mocks/MockFailedTransfer.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

contract NexusEngineTest is Test {}
