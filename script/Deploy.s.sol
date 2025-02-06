// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

//  ██████╗ ███╗   ███╗███╗   ██╗███████╗███████╗
// ██╔═══██╗████╗ ████║████╗  ██║██╔════╝██╔════╝
// ██║   ██║██╔████╔██║██╔██╗ ██║█████╗  ███████╗
// ██║   ██║██║╚██╔╝██║██║╚██╗██║██╔══╝  ╚════██║
// ╚██████╔╝██║ ╚═╝ ██║██║ ╚████║███████╗███████║
//  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝

/// -----------------------------------------------------------------------
/// Imports
/// -----------------------------------------------------------------------

//  ==========  External imports    ==========

import {Script, console} from "forge-std/Script.sol";

//  ==========  Internal imports    ==========

import {MultiCall} from "../src/MultiCall.sol";

/// -----------------------------------------------------------------------
/// Script
/// -----------------------------------------------------------------------

/**
 * @title Deployment script.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha && Gustavo W. Deps - @G-Deps && Afonso Dalvi - @Afonsodalvi).
 */
contract Deploy is Script {
    bytes32 public salt =
        bytes32(keccak256(abi.encodePacked(vm.envString("SALT"))));
    uint256 public key = vm.envUint("PRIVATE_KEY");

    MultiCall public multiCall;

    function run() public {
        vm.createSelectFork(vm.prompt("network"));

        vm.startBroadcast(key);

        multiCall = new MultiCall();

        vm.stopBroadcast();

        console.log("deployed address:", address(multiCall));
    }
}
