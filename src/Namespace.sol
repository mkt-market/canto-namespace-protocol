// SPDX-License-Identifier: GPL-3.0-only
pragma solidity >=0.8.0;

import {ERC721, ERC721Enumerable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {Base64} from "solady/utils/Base64.sol";
import "./Tray.sol";
import "./Utils.sol";
import "../interface/Turnstile.sol";
import {ICidNFT, IAddressRegistry} from "../interface/ICidNFT.sol";
import {ICidSubprotocol} from "../interface/ICidSubprotocol.sol";

contract Namespace is ERC721Enumerable, Owned {
    /*//////////////////////////////////////////////////////////////
                                 ADDRESSES
    //////////////////////////////////////////////////////////////*/

    /// @notice Reference to the Tray NFT
    Tray public immutable tray;

    /// @notice Reference to the $NOTE TOKEN
    ERC20 public note;

    /// @notice Wallet that receives the revenue
    address private revenueAddress;

    /// @notice Reference to the CID NFT
    ICidNFT private immutable cidNFT;

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
    uint256 public numTokensMinted;

    /// @notice Maps names to NFT IDs
    mapping(string => uint256) public nameToToken;

    /// @notice Maps NFT IDs to (ASCII) names
    mapping(uint256 => string) public tokenToName;

    /// @notice Stores the character data of an NFT
    mapping(uint256 => Tray.TileData[]) private nftCharacters;

    /// @notice Address that can change the prices. Can be revoked such that no more changes are possible
    address public priceAdmin;

    /// @notice Price for fusing a Namespace NFT with a given number of characters
    mapping(uint256 => uint256) public fusingCosts;

    /// @notice Name with which the subprotocol is registered
    string public subprotocolName;

    /// @notice Url of the docs
    string public docs;

    /// @notice Urls of the library
    string[] private libraries;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event NamespaceFused(address indexed fuser, uint256 indexed namespaceId, string indexed name);
    event RevenueAddressUpdated(address indexed oldRevenueAddress, address indexed newRevenueAddress);
    event NoteAddressUpdated(address indexed oldNoteAddress, address indexed newNoteAddress);
    event PriceAdminUpdated(address indexed oldPriceAdmin, address indexed newPriceAdmin);
    event FusingCostUpdated(uint256 indexed numCharacters, uint256 oldFusingCost, uint256 newFusingCost);
    event DocsChanged(string newDocs);
    event LibChanged(string[] newLibs);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error CallerNotAllowedToFuse();
    error CallerNotAllowedToBurn();
    error InvalidNumberOfCharacters(uint256 numCharacters);
    error FusingDuplicateCharactersNotAllowed();
    error NameAlreadyRegistered(uint256 nftID);
    error TokenNotMinted(uint256 tokenID);
    error CannotFuseCharacterWithSkinTone();
    error CallerNotAllowedToChangeFusingCost();
    error PriceAdminRevoked();
    error CannotFuseEmojisOnly();

    /// @notice Sets the reference to the tray
    /// @param _tray Address of the tray contract
    /// @param _note Address of the $NOTE token
    /// @param _revenueAddress Adress to send the revenue to
    /// @param _subprotocolName Name with which the subprotocol is registered
    /// @param _cidNFT Reference to the CID NFT
    constructor(
        address _tray,
        address _note,
        address _revenueAddress,
        string memory _subprotocolName,
        address _cidNFT
    ) ERC721("Namespace", "NS") Owned(msg.sender) {
        tray = Tray(_tray);
        note = ERC20(_note);
        revenueAddress = _revenueAddress;
        subprotocolName = _subprotocolName;
        cidNFT = ICidNFT(_cidNFT);
        priceAdmin = msg.sender;
        if (block.chainid == 7700 || block.chainid == 7701) {
            // Register CSR on Canto main- and testnet
            Turnstile turnstile = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44);
            turnstile.register(tx.origin);
        }
    }

    /// @notice Get the token URI for the specified _id
    /// @param _id ID to query for
    function tokenURI(uint256 _id) public view override returns (string memory) {
        if (_ownerOf(_id) == address(0)) revert TokenNotMinted(_id);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "',
                        tokenToName[_id],
                        '", "image": "data:image/svg+xml;base64,',
                        Base64.encode(bytes(Utils.generateSVG(nftCharacters[_id], false))),
                        '"}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /// @notice Fuse a new Namespace NFT with the referenced tiles
    /// @param _characterList The tiles to use for the fusing
    function fuse(CharacterData[] calldata _characterList) external {
        uint256 numCharacters = _characterList.length;
        if (numCharacters > 13 || numCharacters == 0) revert InvalidNumberOfCharacters(numCharacters);
        uint256 namespaceIDToMint = ++numTokensMinted;
        Tray.TileData[] storage nftToMintCharacters = nftCharacters[namespaceIDToMint];
        bytes memory bName = new bytes(numCharacters); // Used to convert into a string in base font without emojis. Could be shorter, but numCharacters at most
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
            uint8 characterModifier = tileData.characterModifier;

            if (tileData.fontClass != 0 && _characterList[i].skinToneModifier != 0) {
                revert CannotFuseCharacterWithSkinTone();
            }
            if (tileData.fontClass == 0) {
                // Emoji
                characterModifier = _characterList[i].skinToneModifier;
                bytes memory charAsBytes = Utils.characterToUnicodeBytes(
                    0, // We still do the conversion for emojis to validate skin tone modifiers
                    tileData.characterIndex,
                    characterModifier
                );
            } else {
                // We skip emojis and do not add them to the reserved name
                bytes memory charAsBytes = Utils.characterToUnicodeBytes(1, tileData.characterIndex, 0);
                bName[numBytes++] = charAsBytes[0];
            }
            tileData.characterModifier = characterModifier;
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
        if (numBytes == 0) revert CannotFuseEmojisOnly();
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
        uint256 costsToFuse = fusingCosts[numBytes]; // Costs are calculated based on the number of characters without emojis
        SafeTransferLib.safeTransferFrom(note, msg.sender, revenueAddress, costsToFuse);
        _mint(msg.sender, namespaceIDToMint);
        // Although _mint already emits an event, we additionally emit one because of the name
        emit NamespaceFused(msg.sender, namespaceIDToMint, nameToRegister);
    }

    /// @notice Burn a specified Namespace NFT
    /// @param _id Namespace NFT ID
    function burn(uint256 _id) external {
        address nftOwner = ownerOf(_id);
        if (nftOwner != msg.sender && getApproved(_id) != msg.sender && !isApprovedForAll(nftOwner, msg.sender))
            revert CallerNotAllowedToBurn();
        string memory associatedName = tokenToName[_id];
        delete tokenToName[_id];
        delete nameToToken[associatedName];
        _burn(_id);
    }

    /// @notice Get the characters of a Namespace NFT in the image font
    /// @param _id Namespace NFT ID
    /// @return characters Array containing the characters of the Namespace NFT
    function getNamespaceCharacters(uint256 _id) public view returns (string[] memory) {
        if (_ownerOf(_id) == address(0)) revert TokenNotMinted(_id);
        Tray.TileData[] memory namespaceTiles = nftCharacters[_id];
        string[] memory characters = new string[](namespaceTiles.length);
        for (uint256 i; i < namespaceTiles.length; ++i) {
            Tray.TileData memory tileData = namespaceTiles[i];
            characters[i] = string(
                Utils.characterToUnicodeBytes(tileData.fontClass, tileData.characterIndex, tileData.characterModifier)
            );
        }
        return characters;
    }

    /// @notice Get the subprotocol metadata that is associated with a subprotocol NFT
    /// @param _tokenID The NFT to query
    /// @return Subprotocol metadata as JSON
    function metadata(uint256 _tokenID) external view returns (string memory) {
        if (_ownerOf(_tokenID) == address(0)) revert TokenNotMinted(_tokenID);
        (uint256 cidNFTID, address cidNFTRegisteredAddress) = _getAssociatedCIDAndOwner(_tokenID);
        string memory subprotocolData = string.concat('"baseName": "', tokenToName[_tokenID], '"', ', "name": "');
        string[] memory fontCharacters = getNamespaceCharacters(_tokenID);
        for (uint256 i; i < fontCharacters.length; ++i) {
            subprotocolData = string.concat(subprotocolData, fontCharacters[i]);
        }
        subprotocolData = string.concat(subprotocolData, '"');
        string memory json = string.concat(
            "{",
            '"subprotocolName": "',
            subprotocolName,
            '",',
            '"associatedCidToken":',
            Strings.toString(cidNFTID),
            ",",
            '"associatedCidAddress": "',
            Strings.toHexString(uint160(cidNFTRegisteredAddress), 20),
            '",',
            '"subprotocolData": {',
            subprotocolData,
            "}",
            "}"
        );
        return json;
    }

    /// @notice Return the libraries / SDKs of the subprotocol (if any)
    /// @return Location of the subprotocol library
    function lib() external view returns (string[] memory) {
        return libraries;
    }

    /// @notice Change the docs url
    /// @param _newDocs New docs url
    function changeDocs(string memory _newDocs) external onlyOwner {
        docs = _newDocs;
        emit DocsChanged(_newDocs);
    }

    /// @notice Change the lib urls
    /// @param _newLibs New lib urls
    function changeLib(string[] memory _newLibs) external onlyOwner {
        libraries = _newLibs;
        emit LibChanged(_newLibs);
    }

    /// @notice Change the address of the $NOTE token
    /// @param _newNoteAddress New address to use
    function changeNoteAddress(address _newNoteAddress) external onlyOwner {
        address currentNoteAddress = address(note);
        note = ERC20(_newNoteAddress);
        emit NoteAddressUpdated(currentNoteAddress, _newNoteAddress);
    }

    /// @notice Change the revenue address
    /// @param _newRevenueAddress New address to use
    function changeRevenueAddress(address _newRevenueAddress) external onlyOwner {
        address currentRevenueAddress = revenueAddress;
        revenueAddress = _newRevenueAddress;
        emit RevenueAddressUpdated(currentRevenueAddress, _newRevenueAddress);
    }

    /// @notice Change the fusing cost for a given number of characters. Only callable by the price admin
    /// @param _numCharacters Number of characters to change the fusing cost for
    /// @param _newFusingCost New fusing cost to use
    function changeFusingCost(uint256 _numCharacters, uint256 _newFusingCost) external {
        if (msg.sender != priceAdmin) revert CallerNotAllowedToChangeFusingCost();
        uint256 currentFusingCost = fusingCosts[_numCharacters];
        fusingCosts[_numCharacters] = _newFusingCost;
        emit FusingCostUpdated(_numCharacters, currentFusingCost, _newFusingCost);
    }

    /// @notice Change the price admin
    /// @param _newPriceAdmin New price admin to use. If set to address(0), the price admin is revoked forever
    function changePriceAdmin(address _newPriceAdmin) external onlyOwner {
        address currentPriceAdmin = priceAdmin;
        if (currentPriceAdmin == address(0)) revert PriceAdminRevoked();
        priceAdmin = _newPriceAdmin;
        emit PriceAdminUpdated(currentPriceAdmin, _newPriceAdmin);
    }

    /// @notice Get the associated CID NFT ID and the address that has registered this CID (if any)
    /// @param _subprotocolNFTID ID of the subprotocol NFT to query
    /// @return cidNFTID The CID NFT ID, cidNFTRegisteredAddress The registered address
    function _getAssociatedCIDAndOwner(uint256 _subprotocolNFTID)
        internal
        view
        returns (uint256 cidNFTID, address cidNFTRegisteredAddress)
    {
        cidNFTID = cidNFT.getPrimaryCIDNFT(subprotocolName, _subprotocolNFTID);
        IAddressRegistry addressRegistry = cidNFT.addressRegistry();
        cidNFTRegisteredAddress = addressRegistry.getAddress(cidNFTID);
    }
}
