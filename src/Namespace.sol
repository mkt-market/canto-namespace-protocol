// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import "./Tray.sol";
import "./StringImageUtils.sol";

contract Namespace is ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Tray NFT
    Tray public immutable tray;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice References the tile for fusing by specifying the tray ID and the index within the tray
    struct CharacterData {
        /// @notice ID of the Tray NFT
        uint256 trayID;
        /// @notice Offset of the tile within the tray. Valid values 0..TILES_PER_TRAY - 1
        uint8 tileOffset;
    }

    /// @notice Next Namespace ID to mint. We start with minting at ID 1
    uint256 public nextNamespaceIDToMint;

    /// @notice Maps names to NFT IDs
    mapping(string => uint256) public nameToToken;

    /// @notice Maps NFT IDs to (ASCII) names
    mapping(uint256 => string) public tokenToName;

    /// @notice Stores the character data of an NFT
    mapping(uint256 => Tray.TileData[]) private nftCharacters;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CallerNotAllowedToFuse();
    error CallerNotAllowedToBurn();
    error InvalidNumberOfCharacters(uint256 numCharacters);
    error FusingDuplicateCharactersNotAllowed();
    error NameAlreadyRegistered(uint256 nftID);

    /// @notice Sets the reference to the tray
    /// @param _tray Address of the tray contract
    constructor(address _tray) ERC721("Namespaces", "NS") {
        tray = Tray(_tray);
    }

    /// TODO
    function tokenURI(uint256 _id) public view override returns (string memory) {}

    /// @notice Fuse a new Namespace NFT with the referenced tiles
    /// @param _characterList The tiles to use for the fusing
    function fuse(CharacterData[] calldata _characterList) external {
        uint256 numCharacters = _characterList.length;
        if (numCharacters > 13 || numCharacters == 0) revert InvalidNumberOfCharacters(numCharacters);
        uint256 namespaceIDToMint = ++nextNamespaceIDToMint;
        Tray.TileData[] storage nftToMintCharacters = nftCharacters[namespaceIDToMint];
        bytes memory bName = new bytes(numCharacters * 4); // Used to convert into a string. Can be four times longer than the string at most (only 4-bytes emojis)
        uint256 numBytes;
        // Extract unique trays for burning them later on
        uint256 numUniqueTrays;
        uint256[] memory uniqueTrays = new uint256[](_characterList.length);
        for (uint256 i; i < numCharacters; ++i) {
            bool isLastTrayEntry = true;
            uint256 trayID = _characterList[i].trayID;
            uint8 tileOffset = _characterList[i].tileOffset;
            // Check for duplicate characters in the provided list. 1/2 * n^2 loop iterations, but n is bounded to 13 and we do not perform any storage operations
            for (uint256 j = i + 1; j < numCharacters; ++j) {
                if (_characterList[j].trayID == trayID) {
                    isLastTrayEntry = false;
                    if (_characterList[j].tileOffset == tileOffset) revert FusingDuplicateCharactersNotAllowed();
                }
            }
            Tray.TileData memory tileData = tray.getTile(trayID, tileOffset); // Will revert if tileOffset is too high
            nftToMintCharacters.push(tileData);
            if (tileData.fontClass == 0) {
                // Emoji
                bytes memory emojiAsBytes = StringImageUtils.characterToUnicodeBytes(0, tileData.characterIndex, 0);
                uint256 numBytesEmoji = emojiAsBytes.length;
                for (uint256 j; j < numBytesEmoji; ++j) {
                    bName[numBytes + j] = emojiAsBytes[j];
                }
                numBytes += numBytesEmoji;
            } else {
                // Normal text, convert characterIndex to ASCII index
                uint16 characterIndex = tileData.characterIndex;
                uint8 asciiStartingIndex = 48; // Starting index for numbers
                if (characterIndex > 9) {
                    asciiStartingIndex = 87; // Starting index for (lowercase) characters - 10
                }
                bName[numBytes++] = bytes1(asciiStartingIndex + uint8(characterIndex)); // TODO: Check in Tray that no higher vals possible / this is validated
            }
            // We keep track of the unique trays NFTs (for burning them) and only check the owner once for the last occurence of the tray
            if (isLastTrayEntry) {
                uniqueTrays[numUniqueTrays++] = trayID;
                // Verify address is allowed to fuse
                address trayOwner = tray.ownerOf(trayID);
                if (
                    trayOwner != msg.sender &&
                    tray.getApproved(trayID) != msg.sender &&
                    !tray.isApprovedForAll(trayOwner, msg.sender)
                ) revert CallerNotAllowedToFuse();
            }
        }
        // Set array to the real length (in bytes) to avoid zero bytes in the end when doing the string conversion
        assembly {
            mstore(bName, numBytes)
        }
        string memory nameToRegister = string(bName);
        uint256 currentRegisteredID = nameToToken[nameToRegister];
        if (currentRegisteredID != 0) revert NameAlreadyRegistered(currentRegisteredID);
        nameToToken[nameToRegister] = namespaceIDToMint;
        tokenToName[namespaceIDToMint] = nameToRegister;

        for (uint256 i; i < numUniqueTrays; ++i) {
            tray.burn(uniqueTrays[i]);
        }
        _mint(msg.sender, namespaceIDToMint);
    }

    /// @notice Burn a specified Namespace NFT
    /// @param _id Namespace NFT ID
    function burn(uint256 _id) external {
        address owner = ownerOf[_id];
        if (owner != msg.sender && getApproved[_id] != msg.sender && !isApprovedForAll[owner][msg.sender])
            revert CallerNotAllowedToBurn();
        string memory associatedName = tokenToName[_id];
        delete tokenToName[_id];
        delete nameToToken[associatedName];
        _burn(_id);
    }
}
