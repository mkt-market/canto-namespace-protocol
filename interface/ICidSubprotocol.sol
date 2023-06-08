// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import "./IERC721.sol";

interface ICidSubprotocol /*is IERC721*/ {

    /// @notice Get the subprotocol metadata that is associated with a subprotocol NFT
    /// @dev NFTs assigned to the zero address are considered invalid, and this
    ///  function throws for queries about the zero address.
    /// @param _tokenID The NFT to query
    /// @return Subprotocol metadata as JSON
    function metadata(uint256 _tokenID) external view returns (string memory);

    /// @notice Return the URL of the subprotocol documentation
    /// @return Location of the subprotocol documentation
    function docs() external view returns (string memory);

    /// @notice Return the libraries / SDKs of the subprotocol (if any)
    /// @return Location of the subprotocol library
    function lib() external view returns (string[] memory);
}
