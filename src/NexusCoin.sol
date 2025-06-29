// SPDX-License-Identifier: MIT
// Layout of the contract
//version
pragma solidity ^0.8.20;

//imports
import { ERC20, ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

// errors
// interfaces,libraries,contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view&& pure

/*
@title NexusCoin
@author @0xKaizendev
@dev Collateral : Exogenous (wETH, wBTC)
@dev Stability Mechanism : Algorithmic (Decentralized)
@dev Relative Stability : Pegged to the US Dollar
@notice this contract is meant to be governed by NexusEngine. The contract is just the ERC20 implementation of our
stablecoin.*/
contract NexusCoin is ERC20Burnable, Ownable {
    error NexusCoin__BurnAmountExceedsBalance();
    error NexusCoin__BurnAmountMustBeGreaterThanZero();
    error NexusCoin__MintToZeroAddress();
    error NexusCoin__MintAmountMustBeGreaterThanZero();

    constructor() ERC20("NexusCoin", "NEX") Ownable(msg.sender) { }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount == 0) {
            revert NexusCoin__BurnAmountMustBeGreaterThanZero();
        }

        if (_amount > balance) {
            revert NexusCoin__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) public onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert NexusCoin__MintToZeroAddress();
        }
        if (_amount <= 0) {
            revert NexusCoin__MintAmountMustBeGreaterThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
