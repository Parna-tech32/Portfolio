// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/mocks/MockERC20.sol";
import "../src/Layer3_RWJODispute.sol";

contract RWJOTest is Test {
    MockERC20 token;
    JurorRegistry registry;
    DisputeModule disputeModule;

    address juror1 = address(0x1);
    address juror2 = address(0x2);
    address juror3 = address(0x3);

    function setUp() public {
        // -------------------------------------------------
        // Deploy mock token
        // -------------------------------------------------
        token = new MockERC20();

        // -------------------------------------------------
        // Deploy JurorRegistry
        // -------------------------------------------------
        registry = new JurorRegistry(address(token));

        // -------------------------------------------------
        // Deploy DisputeModule
        // -------------------------------------------------
        disputeModule =
            new DisputeModule(address(registry));

        // -------------------------------------------------
        // Give test jurors bond tokens
        // -------------------------------------------------
        deal(
            address(token),
            juror1,
            100 ether
        );

        deal(
            address(token),
            juror2,
            200 ether
        );

        deal(
            address(token),
            juror3,
            300 ether
        );

        // -------------------------------------------------
        // Juror 1 registration
        // -------------------------------------------------
        vm.startPrank(juror1);

        token.approve(
            address(registry),
            100 ether
        );

        registry.register(100 ether);

        vm.stopPrank();

        // -------------------------------------------------
        // Juror 2 registration
        // -------------------------------------------------
        vm.startPrank(juror2);

        token.approve(
            address(registry),
            200 ether
        );

        registry.register(200 ether);

        vm.stopPrank();

        // -------------------------------------------------
        // Juror 3 registration
        // -------------------------------------------------
        vm.startPrank(juror3);

        token.approve(
            address(registry),
            300 ether
        );

        registry.register(300 ether);

        vm.stopPrank();
    }

    // =====================================================
    // BASIC DEPLOYMENT TESTS
    // =====================================================

    function testRegistryDeploys() public view {
        assertTrue(
            address(registry) != address(0)
        );
    }

    function testDisputeModuleDeploys() public view {
        assertTrue(
            address(disputeModule) != address(0)
        );
    }

    // =====================================================
    // JUROR REGISTRATION
    // =====================================================

    function testJurorsRegistered() public view {
        (
            uint256 bond1,
            uint256 reputation1,
            uint256 vested1,
            uint256 lastRound1,
            bool registered1
        ) = registry.jurors(juror1);

        assertEq(
            bond1,
            100 ether
        );

        assertEq(
            reputation1,
            10000
        );

        assertEq(
            vested1,
            10000
        );

        assertTrue(
            lastRound1 > 0
        );

        assertTrue(
            registered1
        );
    }

    function testEffectiveWeights() public view {
        uint256 weight1 =
            registry.getEffectiveWeight(juror1);

        uint256 weight2 =
            registry.getEffectiveWeight(juror2);

        uint256 weight3 =
            registry.getEffectiveWeight(juror3);

        // bond × reputation / 10000
        //
        // Juror 1:
        // 100 ETH × 10000 / 10000 = 100 ETH
        //
        // Juror 2:
        // 200 ETH × 10000 / 10000 = 200 ETH
        //
        // Juror 3:
        // 300 ETH × 10000 / 10000 = 300 ETH

        assertEq(
            weight1,
            100 ether
        );

        assertEq(
            weight2,
            200 ether
        );

        assertEq(
            weight3,
            300 ether
        );
    }

    // =====================================================
    // DISPUTE INITIATION
    // =====================================================

    function testInitiateDispute() public {
        uint256 roundId =
            disputeModule.initiateDispute(
                1500,
                1000,
                false,
                0
            );

        assertEq(
            roundId,
            1
        );

        assertTrue(
            disputeModule.isDisputed()
        );

        (
            uint256 candidatePrice,
            uint256 referenceBasePrice,
            ,
            ,
            bool isHoneypot,
            ,
            bool settled,
            uint256 resolvedPrice
        ) = disputeModule.disputes(roundId);

        assertEq(
            candidatePrice,
            1500
        );

        assertEq(
            referenceBasePrice,
            1000
        );

        assertFalse(
            isHoneypot
        );

        assertFalse(
            settled
        );

        assertEq(
            resolvedPrice,
            0
        );
    }

    // =====================================================
    // COMMIT / REVEAL
    // =====================================================

    function testCommitAndRevealVote() public {
        uint256 roundId =
            disputeModule.initiateDispute(
                1500,
                1000,
                false,
                0
            );

        uint256 price =
            1100;

        uint256 predictedMean =
            1050;

        bytes32 salt =
            keccak256(
                abi.encodePacked(
                    "juror1-secret"
                )
            );

        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    price,
                    predictedMean,
                    salt
                )
            );

        // -------------------------------------------------
        // Commit
        // -------------------------------------------------

        vm.prank(juror1);

        disputeModule.commitVote(
            roundId,
            commitment
        );

        (
            bytes32 storedCommitment,
            bool hasCommitted
        ) = disputeModule.commits(
            roundId,
            juror1
        );

        assertEq(
            storedCommitment,
            commitment
        );

        assertTrue(
            hasCommitted
        );

        // -------------------------------------------------
        // Move into reveal window
        // -------------------------------------------------

        vm.warp(
            block.timestamp + 31 minutes
        );

        // -------------------------------------------------
        // Reveal
        // -------------------------------------------------

        vm.prank(juror1);

        disputeModule.revealVote(
            roundId,
            price,
            predictedMean,
            salt
        );

        (
            uint256 revealedPrice,
            uint256 revealedPrediction,
            bool revealed
        ) = disputeModule.reveals(
            roundId,
            juror1
        );

        assertEq(
            revealedPrice,
            price
        );

        assertEq(
            revealedPrediction,
            predictedMean
        );

        assertTrue(
            revealed
        );
    }

    // =====================================================
    // FULL WEIGHTED RWJO FLOW
    // =====================================================

    function testWeightedDisputeResolution() public {
        // -------------------------------------------------
        // Base/reference price
        // -------------------------------------------------

        uint256 basePrice =
            1000;

        uint256 roundId =
            disputeModule.initiateDispute(
                1500,
                basePrice,
                false,
                0
            );

        // -------------------------------------------------
        // Juror 1:
        //
        // Weight = 100
        // Vote = 1000
        // -------------------------------------------------

        uint256 price1 =
            1000;

        uint256 predicted1 =
            1000;

        bytes32 salt1 =
            keccak256(
                abi.encodePacked(
                    "salt-1"
                )
            );

        bytes32 commitment1 =
            keccak256(
                abi.encodePacked(
                    price1,
                    predicted1,
                    salt1
                )
            );

        vm.prank(juror1);

        disputeModule.commitVote(
            roundId,
            commitment1
        );

        // -------------------------------------------------
        // Juror 2:
        //
        // Weight = 200
        // Vote = 2000
        // -------------------------------------------------

        uint256 price2 =
            2000;

        uint256 predicted2 =
            2000;

        bytes32 salt2 =
            keccak256(
                abi.encodePacked(
                    "salt-2"
                )
            );

        bytes32 commitment2 =
            keccak256(
                abi.encodePacked(
                    price2,
                    predicted2,
                    salt2
                )
            );

        vm.prank(juror2);

        disputeModule.commitVote(
            roundId,
            commitment2
        );

        // -------------------------------------------------
        // Move from commit → reveal
        // -------------------------------------------------

        vm.warp(
            block.timestamp + 31 minutes
        );

        // -------------------------------------------------
        // Juror 1 reveal
        // -------------------------------------------------

        vm.prank(juror1);

        disputeModule.revealVote(
            roundId,
            price1,
            predicted1,
            salt1
        );

        // -------------------------------------------------
        // Juror 2 reveal
        // -------------------------------------------------

        vm.prank(juror2);

        disputeModule.revealVote(
            roundId,
            price2,
            predicted2,
            salt2
        );

        // -------------------------------------------------
        // Move beyond reveal deadline
        // -------------------------------------------------

        vm.warp(
            block.timestamp + 31 minutes
        );

        // -------------------------------------------------
        // Settle
        // -------------------------------------------------

        disputeModule.settleDispute(
            roundId
        );

        // -------------------------------------------------
        // Weighted average:
        //
        // (1000 × 100 + 2000 × 200)
        // --------------------------
        //       100 + 200
        //
        // = 500000 / 300
        // = 1666
        //
        // BUT the contract has a 10% deviation cap.
        //
        // Base = 1000
        // Maximum allowed = 1100
        //
        // Therefore final price = 1100.
        // -------------------------------------------------

        (
            uint256 finalPrice,
            bool disputed
        ) = disputeModule.read();

        assertEq(
            finalPrice,
            1100
        );

        assertFalse(
            disputed
        );

        // -------------------------------------------------
        // Check stored dispute
        // -------------------------------------------------

        (
            ,
            ,
            ,
            ,
            ,
            ,
            bool settled,
            uint256 resolvedPrice
        ) = disputeModule.disputes(
            roundId
        );

        assertTrue(
            settled
        );

        assertEq(
            resolvedPrice,
            1100
        );
    }

    // =====================================================
    // TEST DEVIATION CAP
    // =====================================================

    function testDeviationCap() public {
        uint256 basePrice =
            1000;

        uint256 roundId =
            disputeModule.initiateDispute(
                5000,
                basePrice,
                false,
                0
            );

        // -------------------------------------------------
        // Juror 1 votes extremely high
        // -------------------------------------------------

        uint256 price =
            5000;

        uint256 predictedMean =
            5000;

        bytes32 salt =
            keccak256(
                abi.encodePacked(
                    "cap-test"
                )
            );

        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    price,
                    predictedMean,
                    salt
                )
            );

        vm.prank(juror1);

        disputeModule.commitVote(
            roundId,
            commitment
        );

        // -------------------------------------------------
        // Enter reveal phase
        // -------------------------------------------------

        vm.warp(
            block.timestamp + 31 minutes
        );

        vm.prank(juror1);

        disputeModule.revealVote(
            roundId,
            price,
            predictedMean,
            salt
        );

        // -------------------------------------------------
        // Enter settlement phase
        // -------------------------------------------------

        vm.warp(
            block.timestamp + 31 minutes
        );

        disputeModule.settleDispute(
            roundId
        );

        // -------------------------------------------------
        // Base = 1000
        // MAX_DEVIATION_CAP_BPS = 1000 = 10%
        //
        // Maximum = 1100
        //
        // Raw vote = 5000
        //
        // Therefore final = 1100
        // -------------------------------------------------

        (
            uint256 finalPrice,
            bool disputed
        ) = disputeModule.read();

        assertEq(
            finalPrice,
            1100
        );

        assertFalse(
            disputed
        );
    }

    // =====================================================
    // TEST BELOW-BASE CLAMP
    // =====================================================

    function testLowerDeviationCap() public {
        uint256 basePrice =
            1000;

        uint256 roundId =
            disputeModule.initiateDispute(
                100,
                basePrice,
                false,
                0
            );

        uint256 price =
            100;

        uint256 predictedMean =
            100;

        bytes32 salt =
            keccak256(
                abi.encodePacked(
                    "lower-cap"
                )
            );

        bytes32 commitment =
            keccak256(
                abi.encodePacked(
                    price,
                    predictedMean,
                    salt
                )
            );

        vm.prank(juror1);

        disputeModule.commitVote(
            roundId,
            commitment
        );

        vm.warp(
            block.timestamp + 31 minutes
        );

        vm.prank(juror1);

        disputeModule.revealVote(
            roundId,
            price,
            predictedMean,
            salt
        );

        vm.warp(
            block.timestamp + 31 minutes
        );

        disputeModule.settleDispute(
            roundId
        );

        (
            uint256 finalPrice,
            bool disputed
        ) = disputeModule.read();

        // 10% below 1000 = 900

        assertEq(
            finalPrice,
            900
        );

        assertFalse(
            disputed
        );
    }

    // =====================================================
    // TEST HONEYPOT REWARD / PENALTY
    // =====================================================

    function testHoneypotRewardAndPenalty() public {

        // -------------------------------------------------
        // IMPORTANT:
        //
        // JurorRegistry.rewardJuror() and
        // JurorRegistry.penalizeJuror() are onlyOwner.
        //
        // DisputeModule performs these calls during
        // honeypot settlement.
        //
        // Therefore DisputeModule must own the registry.
        // -------------------------------------------------

        registry.transferOwnership(
            address(disputeModule)
        );

        // -------------------------------------------------
        // Create honeypot dispute
        // -------------------------------------------------

        uint256 roundId =
            disputeModule.initiateDispute(
                1000,
                1000,
                true,
                1000
            );

        // -------------------------------------------------
        // Juror 1:
        // Correct honeypot prediction
        // -------------------------------------------------

        uint256 price1 =
            1000;

        uint256 predicted1 =
            1000;

        bytes32 salt1 =
            keccak256(
                abi.encodePacked(
                    "honeypot-1"
                )
            );

        bytes32 commitment1 =
            keccak256(
                abi.encodePacked(
                    price1,
                    predicted1,
                    salt1
                )
            );

        vm.prank(juror1);

        disputeModule.commitVote(
            roundId,
            commitment1
        );

        // -------------------------------------------------
        // Juror 2:
        // Incorrect prediction
        // -------------------------------------------------

        uint256 price2 =
            2000;

        uint256 predicted2 =
            2000;

        bytes32 salt2 =
            keccak256(
                abi.encodePacked(
                    "honeypot-2"
                )
            );

        bytes32 commitment2 =
            keccak256(
                abi.encodePacked(
                    price2,
                    predicted2,
                    salt2
                )
            );

        vm.prank(juror2);

        disputeModule.commitVote(
            roundId,
            commitment2
        );

        // -------------------------------------------------
        // Move into reveal phase
        // -------------------------------------------------

        vm.warp(
            block.timestamp + 31 minutes
        );

        // -------------------------------------------------
        // Juror 1 reveal
        // -------------------------------------------------

        vm.prank(juror1);

        disputeModule.revealVote(
            roundId,
            price1,
            predicted1,
            salt1
        );

        // -------------------------------------------------
        // Juror 2 reveal
        // -------------------------------------------------

        vm.prank(juror2);

        disputeModule.revealVote(
            roundId,
            price2,
            predicted2,
            salt2
        );

        // -------------------------------------------------
        // Move past reveal deadline
        // -------------------------------------------------

        vm.warp(
            block.timestamp + 31 minutes
        );

        // -------------------------------------------------
        // Settle
        // -------------------------------------------------

        disputeModule.settleDispute(
            roundId
        );

        // -------------------------------------------------
        // Check settlement
        // -------------------------------------------------

        (
            ,
            ,
            ,
            ,
            ,
            ,
            bool settled,
            uint256 resolvedPrice
        ) = disputeModule.disputes(
            roundId
        );

        assertTrue(
            settled
        );

        // -------------------------------------------------
        // Weighted average:
        //
        // Juror 1 weight = 100
        // Juror 2 weight = 200
        //
        // (1000*100 + 2000*200) / 300
        // = 1666
        //
        // Reference = 1000
        // Maximum deviation = 10%
        // Maximum = 1100
        //
        // Therefore final price = 1100
        // -------------------------------------------------

        assertEq(
            resolvedPrice,
            1100
        );
    }
}