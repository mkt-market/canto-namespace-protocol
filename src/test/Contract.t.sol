// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import "forge-std/Test.sol";
import {Utils} from "../Utils.sol";
import "../Tray.sol";

contract UtilsTest is DSTest {
    // Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
    }

    function testSVGEmojis() public {
        Tray.TileData[] memory _tiles = new Tray.TileData[](7);
        for (uint i; i < 420; ++i) {
            Tray.TileData memory tileData = _tiles[i % 7];
            tileData.fontClass = 0;
            tileData.characterIndex = uint16(i);
            if (i % 7 == 0) {
                vm.writeLine("emoji.svg", Utils.generateSVG(_tiles, true));
                _tiles = new Tray.TileData[](7);
            }
        }
    }
}
