// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "./Tray.sol";

/// @notice Utiltities for the on-chain SVG generation of the text data
library StringImageUtils {
    bytes constant FONT_SQUIGGLE =
        hex"CEB1E182A6C688D483D2BDCF9DC9A0D48BCEB9CA9DC699CA85C9B1C9B3CF83CF81CF99C9BECA82C69ACF85CA8BC9AF78E183A7C8A5";

    /// @notice Convert a given font class, character index, and a seed (for font classes with randomness) to their Unicode representation as bytes
    /// @param _fontClass The class to convert
    /// @param _characterIndex Index within the class
    /// @param _seed Pseudorandom seed. Needs to be the same for every call for the given class / index combination to ensure consistency
    function characterToUnicodeBytes(
        uint8 _fontClass,
        uint16 _characterIndex,
        uint256 _seed
    ) public pure returns (bytes memory) {
        if (_fontClass == 0) {
            // TODO: Emoji
            return hex"F09F9881";
        } else if (_fontClass == 1) {
            // Basic, sans-serif text
            uint8 asciiStartingIndex = 48; // Starting index for numbers
            if (_characterIndex > 9) {
                asciiStartingIndex = 87; // Starting index for (lowercase) characters - 10
            }
            return abi.encodePacked(bytes1(asciiStartingIndex + uint8(_characterIndex)));
        } else if (_fontClass == 7) {
            // Zalgo
        } else {
            // TODO: Numbers that do not have a symbol
            uint24 unicodeStartingIndex;
            uint256 letterIndex = _characterIndex - 10;
            if (_fontClass == 2) {
                // Script
                unicodeStartingIndex = 119990; // 1D4B6
            } else if (_fontClass == 3) {
                // Script Bold
                unicodeStartingIndex = 120042; // 1D4EA
            } else if (_fontClass == 4) {
                // Olde
                unicodeStartingIndex = 120094; // 1D51E
            } else if (_fontClass == 5) {
                // Olde Bold
                unicodeStartingIndex = 120198; // 1D586
            } else if (_fontClass == 6) {
                // Squiggle
                // TODO: Optimize/Library
                // Font: αႦƈԃҽϝɠԋιʝƙʅɱɳσρϙɾʂƚυʋɯxყȥ
                // Hex encoding: CEB1 E182A6 C688 D483 D2BD CF9D C9A0 D48B CEB9 CA9D C699 CA85 C9B1 C9B3 CF83 CF81 CF99 C9BE CA82 C69A CF85 CA8B C9AF 78 E183A7 C8A5
                if (letterIndex == 0) {
                    return abi.encodePacked(FONT_SQUIGGLE[0], FONT_SQUIGGLE[1]);
                } else if (letterIndex == 1) {
                    return abi.encodePacked(FONT_SQUIGGLE[2], FONT_SQUIGGLE[3], FONT_SQUIGGLE[4]);
                } else if (letterIndex < 23 || letterIndex == 25) {
                    uint256 offset = (letterIndex - 2) * 2;
                    return abi.encodePacked(FONT_SQUIGGLE[5 + offset], FONT_SQUIGGLE[6 + offset]);
                } else if (letterIndex == 23) {
                    return abi.encodePacked(FONT_SQUIGGLE[47]);
                } else if (letterIndex == 24) {
                    return abi.encodePacked(FONT_SQUIGGLE[48], FONT_SQUIGGLE[49], FONT_SQUIGGLE[50]);
                }
            } else if (_fontClass == 8) {
                // Blocks
                unicodeStartingIndex = 127280; // 1F130
            } else if (_fontClass == 9) {
                // Blocks inverted
                unicodeStartingIndex = 127344; // 1F170
            }
            return bytes(abi.encodePacked(unicodeStartingIndex + letterIndex));
        }
    }

    /// @notice Generate the SVG for the given tiles
    /// @param _tiles Tiles to generate the SVG for
    /// @param _isTray If true, a border will be added around the tiles
    function generateSVG(Tray.TileData[] memory _tiles, bool _isTray) public pure returns (string memory) {
        string memory textData;
        string memory tspanAttributes = 'dx="1"';
        if (_isTray) {
            tspanAttributes = 'dx="1" style="outline: 1px solid black;"';
        }
        for (uint256 i; i < _tiles.length; ++i) {
            textData = string.concat(
                textData,
                "<tspan ",
                tspanAttributes,
                ">",
                string(characterToUnicodeBytes(_tiles[i].fontClass, _tiles[i].characterIndex, _tiles[i].seed)),
                "</tspan>"
            );
        }
        return
            string.concat(
                '<svg viewBox="0 0 200 30" xmlns="http://www.w3.org/2000/svg"><text font-family="sans-serif">',
                textData,
                "</text></svg>"
            );
    }
}
