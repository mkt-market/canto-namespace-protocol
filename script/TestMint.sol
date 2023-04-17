// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../src/Namespace.sol";
import "../src/Tray.sol";

contract TestMint is Script {
    address constant TRAY = address(0x300434a6615A209FeDe174073FCE263D322D0E50);

    function setUp() public {}

    function run() public {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast(privateKey);
        Tray tray = Tray(TRAY);
        tray.buy(1);
        vm.stopBroadcast();
    }
}
