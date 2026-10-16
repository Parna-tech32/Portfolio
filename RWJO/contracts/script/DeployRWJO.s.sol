// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/mocks/MockERC20.sol";
import "../src/mocks/MockOSM.sol";
import "../src/Layer1_SourceReliability.sol";
import "../src/Layer2_TieredResponse.sol";
import "../src/Layer3_RWJODispute.sol";
import "../src/RWJOAdapter.sol";

contract DeployRWJO is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envOr(
            "PRIVATE_KEY",
            uint256(
                0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
            )
        );

        vm.startBroadcast(deployerPrivateKey);

        MockERC20 token = new MockERC20();
        MockOSM osm = new MockOSM();

        SourceRegistry sRegistry =
            new SourceRegistry();

        SourceFilter sFilter =
            new SourceFilter(address(sRegistry));

        TierClassifier tClassifier =
            new TierClassifier();

        SoftCapController sCap =
            new SoftCapController();

        JurorRegistry jRegistry =
            new JurorRegistry(address(token));

        DisputeModule dispute =
            new DisputeModule(address(jRegistry));

        RWJOAdapter adapter =
            new RWJOAdapter(
                address(osm),
                address(dispute)
            );

        // Give DisputeModule permission to
        // reward and penalize jurors.
        jRegistry.transferOwnership(
            address(dispute)
        );

        vm.stopBroadcast();

        console.log(
            "MockERC20:",
            address(token)
        );

        console.log(
            "MockOSM:",
            address(osm)
        );

        console.log(
            "SourceRegistry:",
            address(sRegistry)
        );

        console.log(
            "SourceFilter:",
            address(sFilter)
        );

        console.log(
            "TierClassifier:",
            address(tClassifier)
        );

        console.log(
            "SoftCapController:",
            address(sCap)
        );

        console.log(
            "JurorRegistry:",
            address(jRegistry)
        );

        console.log(
            "DisputeModule:",
            address(dispute)
        );

        console.log(
            "RWJOAdapter:",
            address(adapter)
        );
    }
}