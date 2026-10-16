// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SourceRegistry is Ownable {
    struct Source {
        uint256 venueId;
        uint256 reputation;
        uint256 lastUpdated;
        bool isActive;
    }

    mapping(address => Source) public sources;

    uint256 public constant BASE_REPUTATION = 10000;
    uint256 public stalenessThreshold = 300 seconds;
    uint256 public minDistinctVenues = 2;

    event SourceRegistered(address indexed source, uint256 venueId);
    event SourceReputationUpdated(address indexed source, uint256 newRep);

    constructor() Ownable(msg.sender) {}

    function registerSource(address source, uint256 venueId) external onlyOwner {
        sources[source] = Source({
            venueId: venueId,
            reputation: BASE_REPUTATION,
            lastUpdated: block.timestamp,
            isActive: true
        });

        emit SourceRegistered(source, venueId);
    }

    function recordUpdate(address source) external {
        require(sources[source].isActive, "Inactive");
        sources[source].lastUpdated = block.timestamp;
    }

    function updateReputation(address source, bool accurate) external onlyOwner {
        Source storage s = sources[source];

        if (accurate) {
            if (s.reputation < 15000) {
                s.reputation += 200;
            }
        } else {
            if (s.reputation > 2000) {
                s.reputation -= 1000;
            }
        }

        emit SourceReputationUpdated(source, s.reputation);
    }
}

contract SourceFilter {
    SourceRegistry public immutable registry;

    struct FeedObservation {
        address source;
        uint256 price;
        uint256 timestamp;
    }

    constructor(address _registry) {
        registry = SourceRegistry(_registry);
    }

    function filterAndAggregate(
        FeedObservation[] calldata feeds
    ) external view returns (uint256 aggregate, uint256 validCount) {
        uint256 len = feeds.length;
        require(len > 0, "No feeds");

        uint256[] memory validPrices = new uint256[](len);
        uint256[] memory weights = new uint256[](len);
        uint256[] memory venueTracker = new uint256[](len);

        uint256 distinctVenues = 0;
        uint256 count = 0;

        for (uint256 i = 0; i < len; i++) {
            address src = feeds[i].source;

            (
                uint256 venueId,
                uint256 rep,
                uint256 lastUpdated,
                bool active
            ) = registry.sources(src);

            if (
                !active ||
                (block.timestamp - feeds[i].timestamp >
                    registry.stalenessThreshold())
            ) {
                continue;
            }

            bool venueSeen = false;

            for (uint256 v = 0; v < distinctVenues; v++) {
                if (venueTracker[v] == venueId) {
                    venueSeen = true;
                    break;
                }
            }

            if (!venueSeen) {
                venueTracker[distinctVenues++] = venueId;
            }

            validPrices[count] = feeds[i].price;
            weights[count] = rep;
            count++;
        }

        require(
            distinctVenues >= registry.minDistinctVenues(),
            "Insufficient diversity"
        );

        require(count > 0, "All feeds filtered");

        uint256 roughMedian = _quickSelect(
            validPrices,
            count / 2,
            count
        );

        uint256 totalWeight = 0;
        uint256 weightedSum = 0;

        for (uint256 i = 0; i < count; i++) {
            uint256 p = validPrices[i];

            uint256 diff = p > roughMedian
                ? p - roughMedian
                : roughMedian - p;

            if (diff * 100 / roughMedian <= 15) {
                weightedSum += p * weights[i];
                totalWeight += weights[i];
            }
        }

        require(totalWeight > 0, "No consensus");

        return (weightedSum / totalWeight, count);
    }

    function _quickSelect(
        uint256[] memory arr,
        uint256 k,
        uint256 n
    ) internal pure returns (uint256) {
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (arr[j] > arr[j + 1]) {
                    (arr[j], arr[j + 1]) =
                        (arr[j + 1], arr[j]);
                }
            }
        }

        return arr[k];
    }
}