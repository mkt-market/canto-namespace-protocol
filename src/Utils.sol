// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "./Tray.sol";

/// @notice Utiltities for the on-chain SVG generation of the text data and pseudo randomness
library Utils {
    bytes private constant FONT_SQUIGGLE =
        hex"CEB1E182A6C688D483D2BDCF9DC9A0D48BCEB9CA9DC699CA85C9B1C9B3CF83CF81CF99C9BECA82C69ACF85CA8BC9AF78E183A7C8A5";

    bytes private constant ZALGO_ABOVE_LETTER =
        hex"CC80CC81CC82CC83CC84CC85CC86CC87CC88CC89CC8ACC8BCC8CCC8DCC8ECC8FCC90CC91CC92CC93CC94CC95CC9ACC9BCCBDCCBECCBFCD80CD81CD82CD83CD84CD86CD8ACD8BCD8CCD90CD91CD92CD97CD98CD9BCD9DCD9ECDA0CDA1";

    uint256 private constant ZALGO_NUM_ABOVE = 46;

    bytes private constant ZALGO_BELOW_LETTER =
        hex"CC96CC97CC98CC99CC9CCC9DCC9ECC9FCCA0CCA1CCA2CCA3CCA4CCA5CCA6CCA7CCA8CCA9CCAACCABCCACCCADCCAECCAFCCB0CCB1CCB2CCB3CCB9CCBACCBBCCBCCD85CD87CD88CD89CD8DCD8ECD93CD94CD95CD96CD99CD9ACD9CCD9FCDA2";

    uint256 private constant ZALGO_NUM_BELOW = 47;

    bytes private constant ZALGO_OVER_LETTER = hex"CCB4CCB5CCB6CCB7CCB8";

    uint256 private constant ZALGO_NUM_OVER = 5;

    bytes private constant EMOJIS =
        hex"E29CA8E29C85E29D97E29AA1E29895E2AD90E29D8CE29ABDE29D93E28FB0E2AD95E29AABE29ABEE29894E29AAAE29C8BE29C8AF09F9882F09FA4A3F09F98ADF09F9898F09FA5B0F09F988DF09F988AF09F8E89F09F9881F09F9295F09FA5BAF09F9885F09F94A5F09F9984F09F9886F09FA497F09F9889F09F8E82F09FA494F09F9982F09F98B3F09FA5B3F09F988EF09F929CF09F9894F09F9296F09F9180F09F988BF09F988FF09F98A2F09F9297F09F98A9F09F92AFF09F8CB9F09F929EF09F8E88F09F9299F09F9883F09F98A1F09F9290F09F989CF09F9988F09F9884F09FA4A4F09FA4AAF09F9880F09F928BF09F9280F09F9294F09F988CF09F9293F09FA4A9F09F9983F09F98ACF09F98B1F09F98B4F09FA4ADF09F9890F09F8C9EF09F9892F09F9887F09F8CB8F09F9888F09F8EB6F09F8E8AF09FA5B5F09F989EF09F929AF09F96A4F09F92B0F09F989AF09F9191F09F8E81F09F92A5F09F9891F09FA5B4F09F92A9F09FA4AEF09F98A4F09FA4A2F09F8C9FF09F98A5F09F8C88F09F929BF09F989DF09F98ABF09F98B2F09F94B4F09F8CBBF09FA4AFF09FA4ACF09F9895F09F8D80F09F92A6F09FA68BF09FA4A8F09F8CBAF09F98B9F09F8CB7F09F929DF09F92A4F09F90B0F09F9893F09F9298F09F8DBBF09F989FF09F98A3F09FA790F09F98A0F09FA4A0F09F98BBF09F8C99F09F989BF09F998AF09FA7A1F09FA4A1F09FA4ABF09F8CBCF09FA582F09F98B7F09FA493F09FA5B6F09F98B6F09F9896F09F8EB5F09F9899F09F8D86F09FA491F09F9897F09F90B6F09F8D93F09F9185F09F9184F09F8CBFF09F9AA8F09F93A3F09F8D91F09F8D83F09F98AEF09F928EF09F93A2F09F8CB1F09F9981F09F8DB7F09F98AAF09F8C9AF09F8F86F09F8D92F09F9289F09F92A2F09F9B92F09F98B8F09F90BEF09F9A80F09F8EAFF09F8DBAF09F938CF09F93B7F09F92A8F09F8D95F09F8FA0F09F93B8F09F9087F09F9AA9F09F98B0F09F8C8AF09F9095F09F92ABF09F98B5F09F8EA4F09F8FA1F09FA580F09FA4A7F09F8DBEF09F8DB0F09F8D81F09F98AFF09F928CF09F92B8F09FA781F09F98BAF09F92A7F09F92A3F09FA490F09F8D8EF09F90B7F09F90A5F09F938DF09F8E80F09FA587F09F8C9DF09F94ABF09F90B1F09F90A3F09F8EA7F09F929FF09F91B9F09F928DF09F8DBCF09F92A1F09F98BDF09F8D8AF09F98A8F09F8DABF09FA7A2F09FA495F09F9AABF09F8EBCF09F90BBF09F93B2F09F91BBF09F91BFF09F8CAEF09F8DADF09F909FF09F90B8F09F909DF09F9088F09F94B5F09F94AAF09F98A7F09F8C84F09F98BEF09F93B1F09F8D87F09F8CB4F09F90A2F09F8C83F09F91BDF09F8D8CF09F93BAF09F9494F09F8C85F09FA684F09F8EA5F09F8D8BF09FA59AF09F92B2F09F939AF09F9094F09F8EB8F09FA583F09F98BFF09F9A97F09F8C8EF09F948AF09FA685F09F9ABFF09FA686F09F8D89F09F8DACF09FA7B8F09F8DA8F09F939DF09F93A9F09F92B5F09F92ADF09F8C8DF09F8DBFF09FA7BFF09F8F80F09F8D8FF09F8CB3F09F9989F09F98A6F09F8DB9F09F8DA6F09F9B91F09F8D94F09F8D82F09F9092F09F8DAAF09F9980F09F8D97F09F8CA0F09F8EACF09F8CB5F09F8D84F09F9090F09F8DA9F09FA681F09F939EF09F8D85F09F908DF09F92ACF09FA5A4F09F98BCF09F8CBEF09FA780F09F8EAEF09FA7A0F09F8C8FF09F949DF09F8C89F09FA492F09F9197F09F8CB2F09F8D9CF09F90A6F09F8DAFF09F8F85F09F90BCF09F9284F09F91BAF09F949EF09F8E86F09F8EA8F09F8D9EF09F8E87F09FA69CF09F9091F09F9099F09FA68DF09F9497F09F9396F09F94B9F09FA593F09FA592F09F8DB8F09F918DF09F998FF09FA4A6F09FA4B7F09F918FF09F918CF09F92AAF09F9189F09FA49EF09F998CF09F9187F09F998BF09F9188F09F918BF09F9695F09F9283F09F918AF09F8F83F09FA498F09FA49DF09FA499F09F9AB6F09F9285F09FA49FF09F918EF09F9987F09F91B6F09FA4B2F09F9186F09F95BAF09F9281F09F9985F09FA79AF09FA4B8F09F9190F09FA49AF09F91BCF09F91A7F09FA49CF09FA4B0F09FA798F09F9986F09F91B8F09F91A6F09F9B8CF09FA49BF09F91AEE29DA4EFB88FE298BAEFB88FE299A5EFB88FE29DA3EFB88FE29C8CEFB88FE29880EFB88FE298B9EFB88FE280BCEFB88FE298A0EFB88FE29EA1EFB88FE29AA0EFB88FE29C94EFB88FE2989DEFB88FE2AC87EFB88FE29D84EFB88FE28189EFB88FE2988EEFB88FE29C9DEFB88FE29898EFB88FE29C88EFB88FE296B6EFB88FE29C8DEFB88FE2AC85EFB88FE29881EFB88FE29891EFB88FE299BBEFB88FF09F9181EFB88FF09F9690EFB88FF09F97A3EFB88FF09F8CA7EFB88FF09F958AEFB88FF09F8FB5EFB88FF09F8F96EFB88FF09F87BAF09F87B8F09F87A7F09F87B7F09F87BAF09F87B2F09F8FB3EFB88FE2808DF09F8C88";

    uint256 private constant EMOJIS_LE_THREE_BYTES = 17;
    uint256 private constant EMOJIS_LE_FOUR_BYTES = 383;
    uint256 private constant EMOJIS_LE_SIX_BYTES = 409;
    uint256 private constant EMOJIS_LE_SEVEN_BYTES = 416;
    uint256 private constant EMOJIS_LE_EIGHT_BYTES = 419;
    // uint256 constant EMOJIS_LE_FOURTEEN_BYTES = 420;
    uint256 private constant EMOJIS_MOD_SKIN_TONE_THREE_BYTES = 2;
    uint256 private constant EMOJIS_MOD_SKIN_TONE_FOUR_BYTES = 47;
    // 0 for 7, 8, 14 bytes
    uint256 private constant EMOJIS_BYTE_OFFSET_FOUR_BYTES = 51; // 17 * 3
    uint256 private constant EMOJIS_BYTE_OFFSET_SIX_BYTES = 1327; // 17 * 3 + 319 * 4
    uint256 private constant EMOJIS_BYTE_OFFSET_SEVEN_BYTES = 1483; // 17 * 3 + 319 * 4 + 26 * 6
    uint256 private constant EMOJIS_BYTE_OFFSET_EIGHT_BYTES = 1532; // 17 * 3 + 319 * 4 + 26 * 6 + 7 * 7
    uint256 private constant EMOJIS_BYTE_OFFSET_FOURTEEN_BYTES = 1556; // 17 * 3 + 319 * 4 + 26 * 6 + 7 * 7 + 3 * 8

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
            // TODO: Skin Tone modifier
            uint256 byteOffset;
            uint256 numBytes;
            if (_characterIndex < EMOJIS_LE_THREE_BYTES) {
                numBytes = 3;
                byteOffset = _characterIndex * 3;
            } else if (_characterIndex < EMOJIS_LE_FOUR_BYTES) {
                numBytes = 4;
                byteOffset = EMOJIS_BYTE_OFFSET_FOUR_BYTES + (_characterIndex - EMOJIS_LE_THREE_BYTES) * 4;
            } else if (_characterIndex < EMOJIS_LE_SIX_BYTES) {
                numBytes = 6;
                byteOffset = EMOJIS_BYTE_OFFSET_SIX_BYTES + (_characterIndex - EMOJIS_LE_FOUR_BYTES) * 6;
            } else if (_characterIndex < EMOJIS_LE_SEVEN_BYTES) {
                numBytes = 7;
                byteOffset = EMOJIS_BYTE_OFFSET_SEVEN_BYTES + (_characterIndex - EMOJIS_LE_SIX_BYTES) * 7;
            } else if (_characterIndex < EMOJIS_LE_EIGHT_BYTES) {
                numBytes = 8;
                byteOffset = EMOJIS_BYTE_OFFSET_EIGHT_BYTES + (_characterIndex - EMOJIS_LE_SEVEN_BYTES) * 8;
            } else {
                numBytes = 14;
                byteOffset = EMOJIS_BYTE_OFFSET_FOURTEEN_BYTES + (_characterIndex - EMOJIS_LE_EIGHT_BYTES) * 14;
            }
            bytes memory character = abi.encodePacked(
                EMOJIS[byteOffset],
                EMOJIS[byteOffset + 1],
                EMOJIS[byteOffset + 2]
            );
            for (uint256 i = 3; i < numBytes; ++i) {
                character = abi.encodePacked(character, EMOJIS[byteOffset + i]);
            }
            return character;
        } else if (_fontClass == 1) {
            // Basic, sans-serif text
            uint8 asciiStartingIndex = 48; // Starting index for numbers
            if (_characterIndex > 9) {
                asciiStartingIndex = 87; // Starting index for (lowercase) characters - 10
            }
            return abi.encodePacked(bytes1(asciiStartingIndex + uint8(_characterIndex)));
        } else if (_fontClass == 7) {
            // Zalgo
            uint8 asciiStartingIndex = 48;
            if (_characterIndex > 9) {
                asciiStartingIndex = 87;
            }
            uint256 numAbove = (_seed % 7) + 1;
            // We do not reuse the same seed for the following generations to avoid any symmetries, e.g. that 2 chars above would also always result in 2 chars below
            _seed = iteratePRNG(_seed);
            uint256 numMiddle = _seed % 2;
            _seed = iteratePRNG(_seed);
            uint256 numBelow = (_seed % 7) + 1;
            bytes memory character = abi.encodePacked(bytes1(asciiStartingIndex + uint8(_characterIndex)));
            for (uint256 i; i < numAbove; ++i) {
                _seed = iteratePRNG(_seed);
                uint256 characterIndex = (_seed % ZALGO_NUM_ABOVE) * 2;
                character = abi.encodePacked(
                    character,
                    ZALGO_ABOVE_LETTER[characterIndex],
                    ZALGO_ABOVE_LETTER[characterIndex + 1]
                );
            }
            for (uint256 i; i < numMiddle; ++i) {
                _seed = iteratePRNG(_seed);
                uint256 characterIndex = (_seed % ZALGO_NUM_OVER) * 2;
                character = abi.encodePacked(
                    character,
                    ZALGO_OVER_LETTER[characterIndex],
                    ZALGO_OVER_LETTER[characterIndex + 1]
                );
            }
            for (uint256 i; i < numBelow; ++i) {
                _seed = iteratePRNG(_seed);
                uint256 characterIndex = (_seed % ZALGO_NUM_BELOW) * 2;
                character = abi.encodePacked(
                    character,
                    ZALGO_BELOW_LETTER[characterIndex],
                    ZALGO_BELOW_LETTER[characterIndex + 1]
                );
            }
            return character;
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

    /// @notice Simple PRNG to generate new numbers based on the current state
    /// @param _currState Current state of the PRNG (initially the seed)
    /// @return iteratedState New number
    function iteratePRNG(uint256 _currState) public pure returns (uint256 iteratedState) {
        unchecked {
            iteratedState = _currState * 15485863;
            iteratedState = (iteratedState * iteratedState * iteratedState) % 2038074743;
        }
    }
}
