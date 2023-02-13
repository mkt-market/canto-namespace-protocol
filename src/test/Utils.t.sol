// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {Utilities} from "./utils/Utilities.sol";
import "forge-std/Test.sol";
import "../Tray.sol";

contract UtilsTest is DSTest {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    Utilities internal utils;
    address payable[] internal users;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
    }

    function testSVGEmojis() public {
        Tray.TileData[] memory _tiles = new Tray.TileData[](7);
        uint256 numGenerated;
        for (uint256 i; i < 420; ++i) {
            uint256 numModifier;
            if (i == 15 || i == 16 || (i >= 383 - 47 && i < 383)) {
                numModifier = 5;
            }
            for (uint256 modifierIndex; modifierIndex <= numModifier; ++modifierIndex) {
                Tray.TileData memory tileData;
                tileData.fontClass = 0;
                tileData.characterIndex = uint16(i);
                tileData.characterModifier = uint8(modifierIndex);
                _tiles[numGenerated % 7] = tileData;
                if ((numGenerated > 0 && (numGenerated + 1) % 7 == 0) || i == 419) {
                    vm.writeFile(
                        string.concat("utils/data/emojis", vm.toString(numGenerated / 7), ".svg"),
                        Utils.generateSVG(_tiles, true)
                    );
                    _tiles = new Tray.TileData[](7);
                }
                numGenerated++;
            }
        }
    }

    function testFont1() public {
        Tray.TileData[] memory _tiles = new Tray.TileData[](7);
        for (uint256 i; i < 42; ++i) {
            Tray.TileData memory tileData;
            tileData.fontClass = 1;
            tileData.characterIndex = uint16(i % 36);
            _tiles[i % 7] = tileData;
            if ((i > 0 && (i + 1) % 7 == 0)) {
                vm.writeFile(
                    string.concat("utils/data/font1_", vm.toString(i / 7), ".svg"),
                    Utils.generateSVG(_tiles, true)
                );
                _tiles = new Tray.TileData[](7);
            }
        }
    }

    function testOtherFonts() public {
        Tray.TileData[] memory _tiles = new Tray.TileData[](7);
        uint256 startingFont;
        for (uint256 i; i < 8 * 26; ++i) {
            Tray.TileData memory tileData;
            uint256 fontNumber = 2 + i / 26;
            if (i % 7 == 0) startingFont = fontNumber;
            tileData.fontClass = uint8(fontNumber);
            tileData.characterIndex = uint16(i % 26);
            tileData.characterModifier = uint8(i);
            _tiles[i % 7] = tileData;
            if ((i > 0 && (i + 1) % 7 == 0) || i == 8 * 26 - 1) {
                vm.writeFile(
                    string.concat("utils/data/font", vm.toString(startingFont), "_", vm.toString(i / 7), ".svg"),
                    Utils.generateSVG(_tiles, true)
                );
                _tiles = new Tray.TileData[](7);
            }
        }
    }
}
