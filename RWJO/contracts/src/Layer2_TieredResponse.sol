// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TierClassifier is Ownable {
    enum Tier { Tier0_Normal, Tier1_SoftCap, Tier2_DisputeHalt }

    uint256 public theta1 = 300; // 3.00%
    uint256 public theta2 = 800; // 8.00%

    constructor() Ownable(msg.sender) {}

    function setThresholds(uint256 _t1, uint256 _t2) external onlyOwner {
        require(_t1 < _t2, "Invalid ordering");
        theta1 = _t1;
        theta2 = _t2;
    }

    function classify(
        uint256 candidatePrice,
        uint256 lastAcceptedPrice
    ) external view returns (Tier) {
        if (lastAcceptedPrice == 0) {
            return Tier.Tier0_Normal;
        }

        uint256 diff = candidatePrice > lastAcceptedPrice
            ? candidatePrice - lastAcceptedPrice
            : lastAcceptedPrice - candidatePrice;

        uint256 bps = (diff * 10000) / lastAcceptedPrice;

        if (bps >= theta2) {
            return Tier.Tier2_DisputeHalt;
        }

        if (bps >= theta1) {
            return Tier.Tier1_SoftCap;
        }

        return Tier.Tier0_Normal;
    }
}

contract SoftCapController {
    uint256 public maxRateOfChangeBps = 250; // 2.5% max adjustment

    function clampPrice(
        uint256 candidatePrice,
        uint256 lastPrice
    ) external view returns (uint256) {
        uint256 deltaMax = (lastPrice * maxRateOfChangeBps) / 10000;

        if (candidatePrice > lastPrice + deltaMax) {
            return lastPrice + deltaMax;
        } else if (candidatePrice < lastPrice - deltaMax) {
            return lastPrice - deltaMax;
        }

        return candidatePrice;
    }
}