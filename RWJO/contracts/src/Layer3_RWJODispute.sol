// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IResolvedPrice.sol";

contract JurorRegistry is Ownable {
    struct Juror {
        uint256 bond;
        uint256 reputation;
        uint256 vestedReputation;
        uint256 lastRoundActive;
        bool isRegistered;
    }

    IERC20 public immutable bondToken;

    uint256 public constant MIN_BOND = 100 ether;
    uint256 public constant MAX_REPUTATION = 30000;
    uint256 public constant MIN_REPUTATION = 1000;

    mapping(address => Juror) public jurors;
    address[] public jurorList;

    constructor(address _token) Ownable(msg.sender) {
        bondToken = IERC20(_token);
    }

    function register(uint256 amount) external {
        require(amount >= MIN_BOND, "Bond below minimum");

        bondToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );

        if (!jurors[msg.sender].isRegistered) {
            jurors[msg.sender] = Juror({
                bond: amount,
                reputation: 10000,
                vestedReputation: 10000,
                lastRoundActive: block.number,
                isRegistered: true
            });

            jurorList.push(msg.sender);
        } else {
            jurors[msg.sender].bond += amount;
        }
    }

    function penalizeJuror(
        address juror,
        uint256 slashAmount,
        uint256 repDrop
    ) external onlyOwner {
        Juror storage j = jurors[juror];

        if (slashAmount > j.bond) {
            slashAmount = j.bond;
        }

        j.bond -= slashAmount;

        if (j.reputation > repDrop + MIN_REPUTATION) {
            j.reputation -= repDrop;
        } else {
            j.reputation = MIN_REPUTATION;
        }

        j.vestedReputation = j.reputation;
    }

    function rewardJuror(
        address juror,
        uint256 repGain
    ) external onlyOwner {
        Juror storage j = jurors[juror];

        j.reputation =
            (j.reputation + repGain > MAX_REPUTATION)
                ? MAX_REPUTATION
                : j.reputation + repGain;

        j.vestedReputation =
            (j.vestedReputation * 80 + j.reputation * 20) / 100;
    }

    function getEffectiveWeight(
        address juror
    ) external view returns (uint256) {
        Juror memory j = jurors[juror];

        if (
            !j.isRegistered ||
            j.bond < MIN_BOND
        ) {
            return 0;
        }

        return
            (j.bond * j.vestedReputation) /
            10000;
    }
}

contract DisputeModule is IResolvedPrice, Ownable {
    JurorRegistry public immutable jurorRegistry;

    struct DisputeRound {
        uint256 candidatePrice;
        uint256 referenceBasePrice;
        uint256 commitDeadline;
        uint256 revealDeadline;
        bool isHoneypot;
        uint256 honeypotTarget;
        bool settled;
        uint256 resolvedPrice;
    }

    struct VoteCommit {
        bytes32 commitment;
        bool hasCommitted;
    }

    struct VoteReveal {
        uint256 price;
        uint256 predictedMean;
        bool revealed;
    }

    uint256 public constant MAX_DEVIATION_CAP_BPS = 1000;

    uint256 public disputeCounter;

    mapping(uint256 => DisputeRound) public disputes;

    mapping(
        uint256 => mapping(address => VoteCommit)
    ) public commits;

    mapping(
        uint256 => mapping(address => VoteReveal)
    ) public reveals;

    mapping(
        uint256 => address[]
    ) public roundJurors;

    uint256 public latestResolvedPrice;
    bool public isDisputed;

    event DisputeInitiated(
        uint256 indexed roundId,
        uint256 candidatePrice,
        bool isHoneypot
    );

    event VoteCommitted(
        uint256 indexed roundId,
        address indexed juror
    );

    event VoteRevealed(
        uint256 indexed roundId,
        address indexed juror,
        uint256 price,
        uint256 predicted
    );

    event DisputeResolved(
        uint256 indexed roundId,
        uint256 finalPrice,
        bool clamped
    );

    constructor(
        address _jurorRegistry
    ) Ownable(msg.sender) {
        jurorRegistry =
            JurorRegistry(_jurorRegistry);
    }

    function initiateDispute(
        uint256 candidatePrice,
        uint256 basePrice,
        bool honeypot,
        uint256 honeypotTarget
    )
        external
        onlyOwner
        returns (uint256 roundId)
    {
        roundId = ++disputeCounter;

        disputes[roundId] = DisputeRound({
            candidatePrice: candidatePrice,
            referenceBasePrice: basePrice,
            commitDeadline: block.timestamp + 30 minutes,
            revealDeadline: block.timestamp + 60 minutes,
            isHoneypot: honeypot,
            honeypotTarget: honeypotTarget,
            settled: false,
            resolvedPrice: 0
        });

        isDisputed = true;

        emit DisputeInitiated(
            roundId,
            candidatePrice,
            honeypot
        );
    }

    function commitVote(
        uint256 roundId,
        bytes32 hashCommit
    ) external {
        DisputeRound storage round =
            disputes[roundId];

        require(
            block.timestamp <= round.commitDeadline,
            "Commit window closed"
        );

        require(
            !commits[roundId][msg.sender].hasCommitted,
            "Already committed"
        );

        commits[roundId][msg.sender] =
            VoteCommit({
                commitment: hashCommit,
                hasCommitted: true
            });

        roundJurors[roundId].push(msg.sender);

        emit VoteCommitted(
            roundId,
            msg.sender
        );
    }

    function revealVote(
        uint256 roundId,
        uint256 price,
        uint256 predictedMean,
        bytes32 salt
    ) external {
        DisputeRound storage round =
            disputes[roundId];

        require(
            block.timestamp > round.commitDeadline,
            "Commit window open"
        );

        require(
            block.timestamp <= round.revealDeadline,
            "Reveal window closed"
        );

        require(
            commits[roundId][msg.sender].hasCommitted,
            "No commit found"
        );

        require(
            !reveals[roundId][msg.sender].revealed,
            "Already revealed"
        );

        bytes32 verify =
            keccak256(
                abi.encodePacked(
                    price,
                    predictedMean,
                    salt
                )
            );

        require(
            verify ==
                commits[roundId][msg.sender].commitment,
            "Hash mismatch"
        );

        reveals[roundId][msg.sender] =
            VoteReveal({
                price: price,
                predictedMean: predictedMean,
                revealed: true
            });

        emit VoteRevealed(
            roundId,
            msg.sender,
            price,
            predictedMean
        );
    }

    function settleDispute(
        uint256 roundId
    ) external {
        DisputeRound storage round =
            disputes[roundId];

        require(
            !round.settled,
            "Already settled"
        );

        address[] memory jurors =
            roundJurors[roundId];

        uint256 totalWeight = 0;
        uint256 weightedSum = 0;

        for (
            uint256 i = 0;
            i < jurors.length;
            i++
        ) {
            address jAddr = jurors[i];

            VoteReveal memory v =
                reveals[roundId][jAddr];

            if (!v.revealed) {
                continue;
            }

            uint256 w =
                jurorRegistry
                    .getEffectiveWeight(jAddr);

            weightedSum +=
                v.price * w;

            totalWeight += w;
        }

        require(
            totalWeight > 0,
            "Quorum zero"
        );

        uint256 rawResolved =
            weightedSum / totalWeight;

        if (round.isHoneypot) {
            for (
                uint256 i = 0;
                i < jurors.length;
                i++
            ) {
                address jAddr =
                    jurors[i];

                VoteReveal memory v =
                    reveals[roundId][jAddr];

                if (!v.revealed) {
                    continue;
                }

                uint256 diff =
                    v.price >
                    round.honeypotTarget
                        ? v.price -
                            round.honeypotTarget
                        : round.honeypotTarget -
                            v.price;

                if (
                    (diff * 100) /
                        round.honeypotTarget >
                    3
                ) {
                    jurorRegistry.penalizeJuror(
                        jAddr,
                        20 ether,
                        4000
                    );
                } else {
                    jurorRegistry.rewardJuror(
                        jAddr,
                        500
                    );
                }
            }
        }

        uint256 maxDelta =
            (
                round.referenceBasePrice *
                MAX_DEVIATION_CAP_BPS
            ) / 10000;

        uint256 clampedPrice =
            rawResolved;

        bool wasClamped = false;

        if (
            rawResolved >
            round.referenceBasePrice +
                maxDelta
        ) {
            clampedPrice =
                round.referenceBasePrice +
                maxDelta;

            wasClamped = true;

        } else if (
            rawResolved <
            round.referenceBasePrice -
                maxDelta
        ) {
            clampedPrice =
                round.referenceBasePrice -
                maxDelta;

            wasClamped = true;
        }

        round.resolvedPrice =
            clampedPrice;

        round.settled = true;

        latestResolvedPrice =
            clampedPrice;

        isDisputed = false;

        emit DisputeResolved(
            roundId,
            clampedPrice,
            wasClamped
        );
    }

    function read()
        external
        view
        override
        returns (
            uint256 price,
            bool disputed
        )
    {
        return (
            latestResolvedPrice,
            isDisputed
        );
    }
}