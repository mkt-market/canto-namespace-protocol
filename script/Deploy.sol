// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "forge-std/Script.sol";
import "../src/Namespace.sol";
import "../src/Tray.sol";

contract DeploymentScript is Script {
    // https://docs.canto.io/evm-development/contract-addresses
    address constant NOTE = address(0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503);
    address FEE_WALLET = address(0x26Be9f7b0b3c3E241e8E19C1332d95127b515541);
    uint256 constant TRAY_PRICE = 0 * 1e18;
    uint256 constant INIT_HASH = 42;
    string subprotocolName = "namespace";
    address cidNFT = address(0);

    function setUp() public {}

    function run() public {
        string memory seedPhrase = vm.readFile(".secret");
        uint256 privateKey = vm.deriveKey(seedPhrase, 0);
        vm.startBroadcast(privateKey);
        Tray tray = _deployTray();
        address namespace = _deployNamespace(address(tray));
        tray.setNamespaceNft(namespace);
        vm.stopBroadcast();
    }

    function _deployTray() private returns (Tray) {
        Tray tray = new Tray(bytes32(INIT_HASH),
            TRAY_PRICE,
            FEE_WALLET,
            NOTE);
        return tray;
    }

    function _deployNamespace(address _tray) private returns (address) {
        Namespace ns = new Namespace(_tray,
            NOTE,
            FEE_WALLET,
            subprotocolName,
            cidNFT);
        return address(ns);
    }
}
