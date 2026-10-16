// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./interfaces/IResolvedPrice.sol";

interface IOSM {
    function read() external view returns (bytes32, bool);
}

contract RWJOAdapter {
    IOSM public immutable osm;
    IResolvedPrice public immutable disputeModule;

    constructor(address _osm, address _disputeModule) {
        osm = IOSM(_osm);
        disputeModule = IResolvedPrice(_disputeModule);
    }

    function read() external view returns (uint256 price, bool isValid) {
        (uint256 disputePrice, bool disputed) = disputeModule.read();

        if (disputed || disputePrice > 0) {
            return (disputePrice, !disputed);
        }

        (bytes32 osmVal, bool osmValid) = osm.read();
        return (uint256(osmVal), osmValid);
    }
}