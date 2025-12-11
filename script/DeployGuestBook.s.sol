// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {GuestBook} from "../src/GuestBook.sol";
import "forge-std/console.sol";

contract DeployGuestBook is Script {

    function run() external {
        uint256 deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));

        vm.startBroadcast(deployerPrivateKey);

        GuestBook guestBook = new GuestBook();

        console.log("Guestbook deployed to:", address(guestBook));

        vm.stopBroadcast();
    }
}
