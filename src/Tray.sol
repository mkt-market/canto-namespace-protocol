// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

contract Tray is ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Price of one tray in $NOTE
    uint256 immutable trayPrice;

    /*//////////////////////////////////////////////////////////////
                                 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Wallet that receives the revenue
    address private immutable revenueAddress;

    /// @notice Reference to the $NOTE TOKEN
    ERC20 public immutable note;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Last hash that was used to generate a tray
    bytes32 public lastHash;

    /// @notice Sets the initial hash, tray price, and the revenue address
    /// @param _initHash Hash to initialize the system with. Will determine the generation sequence of the trays
    /// @param _trayPrice Price of one tray in $NOTE
    /// @param _revenueAddress Adress to send the revenue to
    /// @param _note Address of the $NOTE token
    constructor(
        bytes32 _initHash,
        uint256 _trayPrice,
        address _revenueAddress,
        address _note
    ) ERC721("Namespaces Tray", "NSTRAY") {
        lastHash = _initHash;
        trayPrice = _trayPrice;
        _revenueAddress = revenueAddress;
        note = ERC20(_note);
    }
}
