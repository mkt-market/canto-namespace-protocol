// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import "./Tray.sol";

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

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CallerNotAllowedToFuse();
    error TooManyCharactersProvided(uint256 numCharacters);
    error FusingDuplicateCharactersNotAllowed();

    /// @notice Sets the reference to the tray
    /// @param _tray Address of the tray contract
    constructor(address _tray) ERC721("Namespaces", "NS") {
        tray = Tray(_tray);
    }

    /// TODO
    function tokenURI(uint256 id) public view override returns (string memory) {}

    /// @notice Fuse a new Namespace NFT with the referenced tiles
    /// @param _characterList The tiles to use for the fusing
    function fuse(CharacterData[] calldata _characterList) external {
        uint256 numCharacters = _characterList.length;
        if (numCharacters > 13) revert TooManyCharactersProvided(numCharacters);
        // Extract unique trays for burning them later on
        uint256 numUniqueTrays;
        uint256[] memory uniqueTrays = new uint256[](_characterList.length);
        // Check for duplicate characters in the provided list. 1/2 * n^2 loop iterations, but n is bounded to 13 and we do not perform any storage operations
        for (uint256 i; i < numCharacters; ++i) {
            bool isLastTileEntry = true;
            uint256 trayID = _characterList[i].trayID;
            uint8 tileOffset = _characterList[i].tileOffset;
            for (uint256 j = i + 1; j < numCharacters; ++j) {
                if (_characterList[j].trayID == trayID) {
                    isLastTileEntry = false;
                    if (_characterList[j].tileOffset == tileOffset) revert FusingDuplicateCharactersNotAllowed();
                }
            }
            if (isLastTileEntry) {
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
        // TODO: Verify not minted yet
        // TODO: Burn (unique) trays in the end
        // TODO: Mint Namespace NFT and add metadata
        for (uint256 i; i < numCharacters; ++i) {
            uint256 trayId = _characterList[i].trayID;
            uint8 tileOffset = _characterList[i].tileOffset;
            Tray.TileData memory tileData = tray.getTile(trayId, tileOffset); // Will revert if tileOffset is too high
        }
        for (uint256 i; i < numUniqueTrays; ++i) {
            tray.burn(uniqueTrays[i]);
        }
    }
}
