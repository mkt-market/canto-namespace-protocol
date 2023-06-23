// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../src/Namespace.sol";
import "../src/Tray.sol";

contract SetPrice is Script {
    address constant NAMESPACE = address(0x65cA83eCb77b418c2c5B7fc7712e1aDC0655961B);

    function setUp() public {}

    function run() public {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast(privateKey);
        Namespace namespace = Namespace(NAMESPACE);
        namespace.changeFusingCost(1, type(uint256).max);
        namespace.changeFusingCost(2, type(uint256).max);
        namespace.changeFusingCost(3, type(uint256).max);
        namespace.changeFusingCost(4, type(uint256).max);
        namespace.changeFusingCost(5, type(uint256).max);
        namespace.changeFusingCost(6, type(uint256).max);
        namespace.changeFusingCost(7, type(uint256).max);
        namespace.changeFusingCost(8, 64 * 1e18);
        namespace.changeFusingCost(9, 32 * 1e18);
        namespace.changeFusingCost(10, 16 * 1e18);
        namespace.changeFusingCost(11, 8 * 1e18);
        namespace.changeFusingCost(12, 1e18);
        namespace.changeFusingCost(13, 1e18);
        namespace.changeFusingCost(14, 1e18);
        vm.stopBroadcast();
    }
}
