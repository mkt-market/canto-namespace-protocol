// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";

contract Namespace is ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Tray NFT
    ERC721 public immutable tray;

    /// @notice Sets the reference to the tray
    /// @param _tray Address of the tray contract
    constructor(address _tray) ERC721("Namespaces", "NS") {
        tray = ERC721(_tray);
    }

    /// TODO
    function tokenURI(uint256 id) public view override returns (string memory) {}
}
