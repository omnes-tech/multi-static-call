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

import {MultiStaticcall} from "../src/MultiStaticcall.sol";

/// -----------------------------------------------------------------------
/// Script
/// -----------------------------------------------------------------------

/**
 * @title Deployment script.
 * @author Omnes Tech (Eduardo W. da Cunha - @EWCunha && Gustavo W. Deps - @G-Deps && Afonso Dalvi - @Afonsodalvi).
 */
contract Deploy is Script {
    bytes32 public salt = bytes32("salt");
    uint256 public key = vm.envUint("PRIVATE_KEY");

    MultiStaticcall public multiStaticCall;

    function run() public {
        vm.startBroadcast(key);

        multiStaticCall = new MultiStaticcall{salt: salt}();

        vm.stopBroadcast();

        console.log("deployed address:", address(multiStaticCall));
    }
}
