// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721AQueryable, ERC721A, IERC721A} from "erc721a/extensions/ERC721AQueryable.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {LibString} from "solmate/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import "./Utils.sol";
import "../interface/Turnstile.sol";

contract Tray is ERC721AQueryable, Owned {
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
    uint256 private constant NUM_CHARS_LETTERS = 26;

    /// @notice Number of characters for letters and numbers
    uint256 private constant NUM_CHARS_LETTERS_NUMBERS = 36;

    /// @notice Maximum number of trays that can be minted pre-launch (by the owner)
    uint256 private constant PRE_LAUNCH_MINT_CAP = 1_000;

    /// @notice Price of one tray in $NOTE. Changeable by the owner
    uint256 public trayPrice;

    /*//////////////////////////////////////////////////////////////
                                 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Wallet that receives the revenue
    address private revenueAddress;

    /// @notice Reference to the $NOTE TOKEN
    ERC20 public note;

    /// @notice Reference to the Namespace NFT contract
    address public namespaceNFT;

    /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Font and character index of a tile
    struct TileData {
        /// @notice Allowed values between 0 (emoji) and 9 (font5 rare)
        uint8 fontClass;
        /// @notice For Emojis (font class 0) between 0..NUM_CHARS_EMOJIS - 1, otherwise between 0..NUM_CHARS_LETTERS - 1
        uint16 characterIndex;
        /// @notice For generative fonts with randomness (Zalgo), we generate and fix this on minting. For some emojis, it can be set by the user to influence the skin color
        uint8 characterModifier;
    }

    /// @notice Stores the content of a tray, i.e. all tiles
    mapping(uint256 => TileData[TILES_PER_TRAY]) private tiles;

    /// @notice Last hash that was used to generate a tray
    bytes32 public lastHash;

    /// @notice Address that can change the prices. Can be revoked such that no more changes are possible
    address public priceAdmin;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event RevenueAddressUpdated(address indexed oldRevenueAddress, address indexed newRevenueAddress);
    event NoteAddressUpdate(address indexed oldNoteAddress, address indexed newNoteAddress);
    event TrayPriceUpdated(uint256 oldTrayPrice, uint256 newTrayPrice);
    event PriceAdminUpdated(address indexed oldPriceAdmin, address indexed newPriceAdmin);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CallerNotAllowedToBurn();
    error CallerNotAllowedToBuy();
    error TrayNotMinted(uint256 tokenID);
    error NamespaceNftAlreadySet();
    error CallerNotAllowedToChangeTrayPrice();
    error PriceAdminRevoked();

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
    ) ERC721A("Namespace Tray", "NSTRAY") Owned(msg.sender) {
        lastHash = _initHash;
        trayPrice = _trayPrice;
        revenueAddress = _revenueAddress;
        note = ERC20(_note);
        priceAdmin = msg.sender;
        if (block.chainid == 7700 || block.chainid == 7701) {
            // Register CSR on Canto main- and testnet
            Turnstile turnstile = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44);
            turnstile.register(tx.origin);
        }
    }

    /// @notice Get the token URI for the specified _id
    /// @param _id ID to query for
    function tokenURI(uint256 _id) public view override(ERC721A, IERC721A) returns (string memory) {
        if (!_exists(_id)) revert TrayNotMinted(_id);
        // Need to do an explicit copy here, implicit one not supported
        TileData[TILES_PER_TRAY] storage storedNftTiles = tiles[_id];
        TileData[] memory nftTiles = new TileData[](TILES_PER_TRAY);
        for (uint256 i; i < TILES_PER_TRAY; ++i) {
            nftTiles[i] = storedNftTiles[i];
        }
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Tray #',
                        LibString.toString(_id),
                        '", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(Utils.generateSVG(nftTiles, true))),
                        '"}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// @notice Buy a specifiable amount of trays
    /// @param _amount Amount of trays to buy
    function buy(uint256 _amount) external {
        uint256 startingTrayId = _nextTokenId();
        if (trayPrice == 0) {
            // Only allow minting by owner if price is 0
            if (msg.sender != owner) revert CallerNotAllowedToBuy();
        } else {
            SafeTransferLib.safeTransferFrom(note, msg.sender, revenueAddress, _amount * trayPrice);
        }
        for (uint256 i; i < _amount; ++i) {
            TileData[TILES_PER_TRAY] memory trayTiledata;
            for (uint256 j; j < TILES_PER_TRAY; ++j) {
                lastHash = keccak256(abi.encode(lastHash));
                trayTiledata[j] = _drawing(uint256(lastHash));
            }
            tiles[startingTrayId + i] = trayTiledata;
        }
        _mint(msg.sender, _amount); // We do not use _safeMint on purpose here to disallow callbacks and save gas
    }

    /// @notice Burn a specified tray
    /// @dev Callable by the owner, an authorized address, or the Namespace NFT (when fusing)
    /// @param _id Tray ID
    function burn(uint256 _id) external {
        address trayOwner = ownerOf(_id);
        if (
            namespaceNFT != msg.sender &&
            trayOwner != msg.sender &&
            getApproved(_id) != msg.sender &&
            !isApprovedForAll(trayOwner, msg.sender)
        ) revert CallerNotAllowedToBurn();
        delete tiles[_id];
        _burn(_id);
    }

    /// @notice Get the information about one tile
    /// @dev Reverts for non-existing tray ID
    /// @param _trayId Tray to query
    /// @param _tileOffset Offset of the tile within the query, needs to be between 0 .. TILES_PER_TRAY - 1
    function getTile(uint256 _trayId, uint8 _tileOffset) external view returns (TileData memory tileData) {
        if (!_exists(_trayId)) revert TrayNotMinted(_trayId);
        tileData = tiles[_trayId][_tileOffset];
    }

    /// @notice Query all tiles of a tray
    /// @dev Reverts for non-existing tray ID
    /// @param _trayId Tray to query
    function getTiles(uint256 _trayId) external view returns (TileData[TILES_PER_TRAY] memory tileData) {
        if (!_exists(_trayId)) revert TrayNotMinted(_trayId);
        tileData = tiles[_trayId];
    }

    /// @notice Change the address of the $NOTE token
    /// @param _newNoteAddress New address to use
    function changeNoteAddress(address _newNoteAddress) external onlyOwner {
        address currentNoteAddress = address(note);
        note = ERC20(_newNoteAddress);
        emit NoteAddressUpdate(currentNoteAddress, _newNoteAddress);
    }

    /// @notice Change the revenue address
    /// @param _newRevenueAddress New address to use
    function changeRevenueAddress(address _newRevenueAddress) external onlyOwner {
        address currentRevenueAddress = revenueAddress;
        revenueAddress = _newRevenueAddress;
        emit RevenueAddressUpdated(currentRevenueAddress, _newRevenueAddress);
    }

    /// @notice Change the tray price. Only callable by the price admin
    /// @param _newTrayPrice New tray price to use
    function changeTrayPrice(uint256 _newTrayPrice) external {
        if (msg.sender != priceAdmin) revert CallerNotAllowedToChangeTrayPrice();
        uint256 currentTrayPrice = trayPrice;
        trayPrice = _newTrayPrice;
        emit TrayPriceUpdated(currentTrayPrice, _newTrayPrice);
    }

    /// @notice Change the price admin
    /// @param _newPriceAdmin New price admin to use. If set to address(0), the price admin is revoked forever
    function changePriceAdmin(address _newPriceAdmin) external onlyOwner {
        address currentPriceAdmin = priceAdmin;
        if (currentPriceAdmin == address(0)) revert PriceAdminRevoked();
        priceAdmin = _newPriceAdmin;
        emit PriceAdminUpdated(currentPriceAdmin, _newPriceAdmin);
    }

    /// @notice Set the namespace address after deployment (because of cyclic dependencies)
    /// @param _namespaceNft Address of the namespace NFT
    function setNamespaceNft(address _namespaceNft) external onlyOwner {
        if (namespaceNFT != address(0)) revert NamespaceNftAlreadySet();
        namespaceNFT = _namespaceNft;
    }

    function _drawing(uint256 _seed) private pure returns (TileData memory tileData) {
        uint256 res = _seed % SUM_ODDS;
        uint256 charRandValue = Utils.iteratePRNG(_seed); // Iterate PRNG to not have any biasedness / correlation between random numbers
        if (res < 32) {
            // Class is 0 in that case
            tileData.characterIndex = uint16(charRandValue % NUM_CHARS_EMOJIS);
        } else {
            tileData.characterIndex = uint16(charRandValue % NUM_CHARS_LETTERS);
            if (res < 64) {
                tileData.fontClass = 1;
                tileData.characterIndex = uint16(charRandValue % NUM_CHARS_LETTERS_NUMBERS);
            } else if (res < 80) {
                tileData.fontClass = 2;
            } else if (res < 96) {
                tileData.fontClass = 3 + uint8((res - 80) / 8);
            } else if (res < 104) {
                tileData.fontClass = 5 + uint8((res - 96) / 4);
            } else if (res < 108) {
                tileData.fontClass = 7 + uint8((res - 104) / 2);
                if (tileData.fontClass == 7) {
                    // Set seed for Zalgo to ensure same characters will be always generated for this tile
                    uint256 zalgoSeed = Utils.iteratePRNG(_seed);
                    tileData.characterModifier = uint8(zalgoSeed % 256);
                }
            } else {
                tileData.fontClass = 9;
            }
        }
    }

    /// @dev Overridden function of ERC721A to start minting at 1
    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
