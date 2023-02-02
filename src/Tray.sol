// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

contract Tray is ERC721 {
    /*//////////////////////////////////////////////////////////////
                                 CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Number of tiles that are in one tray
    uint256 private constant TILES_PER_TRAY = 7;

    /// @notice Sum of the odds for all fonts
    uint256 private constant SUM_ODDS = 109;

    /// @notice Number of characters for emojis
    uint256 private constant NUM_CHARS_EMOJIS = 420;

    /// @notice Number of characters for letters
    uint256 private constant NUM_CHARS_LETTERS = 36;

    /// @notice Price of one tray in $NOTE
    uint256 public immutable trayPrice;

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

    /// @notice Font and character index of a tile
    struct TileData {
        uint8 fontClass;
        /// @notice For Emojis between 0..NUM_CHARS_EMOJIS, otherwise between 0..NUM_CHARS_LETTERS
        uint16 characterIndex;
    }

    /// @notice Stores the content of a tray, i.e. all tiles
    mapping(uint256 => TileData[TILES_PER_TRAY]) private tiles;

    /// @notice Last hash that was used to generate a tray
    bytes32 public lastHash;

    /// @notice Next Tray ID to mint. We start with minting at ID 1
    uint256 public nextTrayIDToMint;

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
        revenueAddress = _revenueAddress;
        note = ERC20(_note);
    }

    /// TODO
    function tokenURI(uint256 id) public view override returns (string memory) {}

    /// @notice Buy a specifiable amount of trays
    /// @param _amount Amount of trays to buy
    function buy(uint256 _amount) external {
        SafeTransferLib.safeTransferFrom(note, msg.sender, revenueAddress, _amount * trayPrice);
        for (uint256 i; i < _amount; ++i) {
            uint256 trayId = ++nextTrayIDToMint;
            TileData[TILES_PER_TRAY] memory trayTiledata;
            for (uint256 j; j < TILES_PER_TRAY; ++j) {
                lastHash = keccak256(abi.encode(lastHash));
                trayTiledata[j] = _drawing(uint256(lastHash));
            }
            tiles[trayId] = trayTiledata;
            _mint(msg.sender, trayId); // We do not use _safeMint on purpose here to disallow callbacks and save gas
        }
    }

    /// @notice Get the information about one tile
    /// @param _trayId Tray to query
    /// @param _tileOffset Offset of the tile within the query, needs to be between 0 .. TILES_PER_TRAY - 1
    function getTile(uint256 _trayId, uint8 _tileOffset) external view returns (TileData memory tileData) {
        // TODO: Does this revert for non-existing tray ID?
        tileData = tiles[_trayId][_tileOffset];
    }

    /// @notice Query all tiles of a tray
    /// @param _trayId Tray to query
    function getTiles(uint256 _trayId) external view returns (TileData[TILES_PER_TRAY] memory tileData) {
        tileData = tiles[_trayId];
    }

    function _drawing(uint256 _seed) private pure returns (TileData memory tileData) {
        uint256 res = _seed % SUM_ODDS;
        if (res < 32) {
            // Class is 0 in that case
            tileData.characterIndex = uint16(_seed % NUM_CHARS_EMOJIS); // TODO: This might be biased
        } else {
            tileData.characterIndex = uint16(_seed % NUM_CHARS_LETTERS); // TODO: This might be biased
            if (res < 64) {
                tileData.fontClass = 1;
            } else if (res < 80) {
                tileData.fontClass = 2;
            } else if (res < 96) {
                tileData.fontClass = 3 + uint8((res - 80) / 8);
            } else if (res < 104) {
                tileData.fontClass = 5 + uint8((res - 96) / 4);
            } else if (res < 108) {
                tileData.fontClass = 7 + uint8((res - 104) / 2);
            } else {
                tileData.fontClass = 9;
            }
        }
    }
}
