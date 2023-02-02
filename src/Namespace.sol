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
        // TODO: Check for duplicate tiles in characterList
        // TODO: Verify not minted yet
        // TODO: Burn (unique) trays in the end
        // TODO: Mint Namespace NFT and add metadata
        for (uint256 i; i < _characterList.length; ++i) {
            uint256 trayId = _characterList[i].trayID;
            address trayOwner = tray.ownerOf(trayId);
            if (
                trayOwner != msg.sender &&
                tray.getApproved(trayId) != msg.sender &&
                !tray.isApprovedForAll(trayOwner, msg.sender)
            ) revert CallerNotAllowedToFuse();
            uint8 tileOffset = _characterList[i].tileOffset;
            Tray.TileData memory tileData = tray.getTile(trayId, tileOffset); // Will revert if tileOffset is too high
        }
    }
}
