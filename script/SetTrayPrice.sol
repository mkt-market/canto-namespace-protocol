// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../src/Namespace.sol";
import "../src/Tray.sol";

contract SetPrice is Script {
    address constant TRAY = address(0x364ACFceAf895aA369170f2b2237695e342E15AA);

    function setUp() public {}

    function run() public {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast(privateKey);
        Tray tray = Tray(TRAY);
        tray.changeTrayPrice(2 * 1e18);
        vm.stopBroadcast();
    }
}
