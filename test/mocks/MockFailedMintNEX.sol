// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20Burnable, ERC20 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockFailedMintNEX is ERC20Burnable, Ownable {
    error NexusCoin__AmountMustBeMoreThanZero();
    error NexusCoin__BurnAmountExceedsBalance();
    error NexusCoin__NotZeroAddress();

    /*
    In future versions of OpenZeppelin contracts package, Ownable must be declared with an address of the contract owner
    as a parameter.
    For example:
    constructor() ERC20("NexusCoin", "NEX") Ownable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266) {}
    Related code changes can be viewed in this commit:
    https://github.com/OpenZeppelin/openzeppelin-contracts/commit/13d5e0466a9855e9305119ed383e54fc913fdc60
    */
    constructor() ERC20("NexusCoin", "NEX") Ownable(msg.sender) { }

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert NexusCoin__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert NexusCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert NexusCoin__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert NexusCoin__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return false;
    }
}
