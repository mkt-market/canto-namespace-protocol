// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Tray} from "../../Tray.sol";

contract MockTray is Tray {
    constructor(
        bytes32 _initHash,
        uint256 _trayPrice,
        address _revenueAddress,
        address _note
    ) Tray(_initHash, _trayPrice, _revenueAddress, _note) {}

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId();
    }
}
