// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../src/Namespace.sol";
import "../src/Tray.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract TestMintPrice is Script {
    address constant TRAY = address(0x300434a6615A209FeDe174073FCE263D322D0E50);
    ERC20 NOTE = ERC20(0x03F734Bd9847575fDbE9bEaDDf9C166F880B5E5f);

    function setUp() public {}

    function run() public {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast(privateKey);
        Tray tray = Tray(TRAY);
        NOTE.approve(address(tray), 1e18);
        tray.buy(1);
        vm.stopBroadcast();
    }
}
