// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../src/Namespace.sol";
import "../src/Tray.sol";

contract SetPrice is Script {
    address constant TRAY = address(0xA8ac87126F8599D53cDcbfe2C08FAFeb88e637F3);

    function setUp() public {}

    function run() public {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast(privateKey);
        Tray tray = Tray(TRAY);
        tray.changeTrayPrice(1e18);
        vm.stopBroadcast();
    }
}
