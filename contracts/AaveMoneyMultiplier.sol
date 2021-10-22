// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract AaveMoneyMultiplier {
    constructor(address token) {
        console.log("Deploying a Greeter with greeting:", _greeting);
        greeting = _greeting;
    }

    function deposit() public view returns (string memory) {
        return greeting;
    }

    function withdraw(string memory _greeting) public {
        console.log("Changing greeting from '%s' to '%s'", greeting, _greeting);
        greeting = _greeting;
    }
}
