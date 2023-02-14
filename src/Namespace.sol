// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {Owned} from "solmate/auth/Owned.sol";
import "./Tray.sol";
import "./Utils.sol";

contract Namespace is ERC721, Owned {
    /*//////////////////////////////////////////////////////////////
                                 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Tray NFT
    Tray public immutable tray;

    /// @notice Reference to the $NOTE TOKEN
    ERC20 public note;

    /// @notice Wallet that receives the revenue
    address private revenueAddress;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice References the tile for fusing by specifying the tray ID and the index within the tray
    struct CharacterData {
        /// @notice ID of the Tray NFT
        uint256 trayID;
        /// @notice Offset of the tile within the tray. Valid values 0..TILES_PER_TRAY - 1
        uint8 tileOffset;
        /// @notice Emoji modifier for the skin tone. Can have values of 0 (yellow) and 1 - 5 (light to dark). Only supported by some emojis
        uint8 skinToneModifier;
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
    error TokenNotMinted(uint256 tokenID);

    /// @notice Sets the reference to the tray
    /// @param _tray Address of the tray contract
    /// @param _note Address of the $NOTE token
    /// @param _revenueAddress Adress to send the revenue to
    constructor(
        address _tray,
        address _note,
        address _revenueAddress
    ) ERC721("Namespaces", "NS") Owned(msg.sender) {
        tray = Tray(_tray);
        note = ERC20(_note);
        revenueAddress = _revenueAddress;
    }

    /// @notice Get the token URI for the specified _id
    /// @param _id ID to query for
    function tokenURI(uint256 _id) public view override returns (string memory) {
        if (_ownerOf[_id] == address(0)) revert TokenNotMinted(_id);
        return Utils.generateSVG(nftCharacters[_id], false); // TODO: JSON / Base64
    }

    /// @notice Fuse a new Namespace NFT with the referenced tiles
    /// @param _characterList The tiles to use for the fusing
    function fuse(CharacterData[] calldata _characterList) external {
        // TODO: Events
        uint256 numCharacters = _characterList.length;
        if (numCharacters > 13 || numCharacters == 0) revert InvalidNumberOfCharacters(numCharacters);
        uint256 fusingCosts = 2**(13 - numCharacters) * 1e18;
        SafeTransferLib.safeTransferFrom(note, msg.sender, revenueAddress, fusingCosts);
        uint256 namespaceIDToMint = ++nextNamespaceIDToMint;
        Tray.TileData[] storage nftToMintCharacters = nftCharacters[namespaceIDToMint];
        bytes memory bName = new bytes(numCharacters * 14); // Used to convert into a string. Can be fourteen times longer than the string at most (longest emoji)
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
            if (tileData.fontClass == 0) {
                // Emoji
                uint8 skinToneModifier = _characterList[i].skinToneModifier;
                bytes memory emojiAsBytes = Utils.characterToUnicodeBytes(0, tileData.characterIndex, skinToneModifier);
                tileData.characterModifier = skinToneModifier;
                uint256 numBytesEmoji = emojiAsBytes.length;
                for (uint256 j; j < numBytesEmoji; ++j) {
                    bName[numBytes + j] = emojiAsBytes[j];
                }
                numBytes += numBytesEmoji;
            } else {
                // Normal text, convert characterIndex to ASCII index
                uint16 characterIndex = tileData.characterIndex;
                uint8 asciiStartingIndex = 97; // Starting index for (lowercase) characters
                if (characterIndex > 25) {
                    asciiStartingIndex = 22; // Starting index for (lowercase) characters - 25
                }
                bName[numBytes++] = bytes1(asciiStartingIndex + uint8(characterIndex)); // Cannot overflow, characterIndex is always < 36 for these font classes because of the generation procedure
            }
            nftToMintCharacters.push(tileData);
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
        address owner = ownerOf(_id);
        if (owner != msg.sender && getApproved[_id] != msg.sender && !isApprovedForAll[owner][msg.sender])
            revert CallerNotAllowedToBurn();
        string memory associatedName = tokenToName[_id];
        delete tokenToName[_id];
        delete nameToToken[associatedName];
        _burn(_id);
    }

    /// @notice Change the address of the $NOTE token
    /// @param _newNoteAddress New address to use
    function changeNoteAddress(address _newNoteAddress) external onlyOwner {
        note = ERC20(_newNoteAddress);
    }

    /// @notice Change the revenue address
    /// @param _newRevenueAddress New address to use
    function changeRevenueAddress(address _newRevenueAddress) external onlyOwner {
        revenueAddress = _newRevenueAddress;
    }
}
