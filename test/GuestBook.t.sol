// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import  {GuestBook} from "../src/GuestBook.sol";

contract GuestBookTest is Test {
    GuestBook public guestbook;
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        guestbook = new GuestBook();
    }

    function testPostMessage() public {
        string memory message = "Hello from arc";
        vm.prank(alice);
        guestbook.postMessage(message);

        assertEq(guestbook.getMessageCount(), 1);
        assertTrue(guestbook.hasSigned(alice));

        (address author, string memory content, uint256 timestamp, uint256 likes) = guestbook.getMessage(0);
        assertEq(author, alice);
        assertEq(content, message);
        assertGt(timestamp, 0);
        assertEq(likes, 0);

    }

    function testPostMessageEmitsEvent() public {
        string memory message = "Building on Arc OS!";
        vm.expectEmit(true, true, true, true);
        emit GuestBook.MessagePosted(alice, message, block.timestamp,0);
        vm.prank(alice);
        guestbook.postMessage(message);

    }

    function testCannotPostEmptyMessage() public {
        vm.prank(alice);
        vm.expectRevert("Message cannot be empty");
        guestbook.postMessage("");
    }

    function testCannotPostTooLongMessage() public  {
        string memory longMessage = "a";

        for (uint i = 0; i < 280; i++) {
            longMessage = string(abi.encodePacked(longMessage, "a"));
        }

        vm.prank(alice);
        vm.expectRevert("Message too long");
        guestbook.postMessage(longMessage);
    }

    function testMultipleMultipleMessages() public {
        vm.prank(alice);
        guestbook.postMessage("First message");
        
        vm.prank(bob);
        guestbook.postMessage("Second message");

        vm.prank(charlie);
          guestbook.postMessage("Second message");

          assertEq(guestbook.getMessageCount(), 3);

          (address author1,,, ) = guestbook.getMessage(0);
          (address author2,,, ) = guestbook.getMessage(1);
          (address author3,,, ) = guestbook.getMessage(2);

          assertEq(author1, alice);
          assertEq(author2, bob);
          assertEq(author3, charlie);
    }

    function testLikeMessage() public {
        vm.prank(alice);
        guestbook.postMessage("Like this message");

        vm.prank(bob);
        guestbook.likeMessage(0);

        (,,, uint256 likes) = guestbook.getMessage(0);
        assertEq(likes, 1);

        assertTrue(guestbook.hasLikedMessage(0, bob));
    }

    function testLikeMessageEmitsEvent() public {
        vm.prank(alice);
        guestbook.postMessage("Like me!");

        vm.expectEmit(true, true, true, true);
        emit GuestBook.MessageLiked(0, bob, 1);

        vm.prank(bob);
        guestbook.likeMessage(0);
    }

    function testCannotLikeMessageTwice() public {
        vm.prank(alice);
        guestbook.postMessage("Only liked once!");

        vm.prank(bob);
        guestbook.likeMessage(0);

        vm.prank(bob);
        vm.expectRevert("Already liked this message");
        guestbook.likeMessage(0);
    }

    function testCannotLikeNonexistentMessage() public {
        vm.prank(alice);
        vm.expectRevert("Message does not exist");
        guestbook.likeMessage(0);
    }

    function testMultipleLikes() public {
        vm.prank(alice);
        guestbook.postMessage("Popular message");

        vm.prank(bob);
        guestbook.likeMessage(0);

        vm.prank(charlie);
        guestbook.likeMessage(0);

        (,,, uint256 likes) = guestbook.getMessage(0);
        assertEq(likes, 2);
    }

    function testGetAllMessages() public {
        vm.prank(alice);
        guestbook.postMessage("Message 1");

        vm.prank(bob);
        guestbook.postMessage("Message 2");

        GuestBook.Message[] memory allMessages = guestbook.getAllMessages();
        assertEq(allMessages.length, 2);
        assertEq(allMessages[0].author, alice);
        assertEq(allMessages[1].author, bob);
    }

    function testGetMessagesPaginated() public {
        for (uint i = 1; i <= 5; i++) {
            vm.prank(alice);
            guestbook.postMessage(string(abi.encodePacked("Message ", vm.toString(i))));
        }

        GuestBook.Message[] memory paginatedMessages = guestbook.getMessagesPaginated(1, 3);

        assertEq(paginatedMessages.length, 3);
        assertEq(paginatedMessages[0].content, "Message 2");
        assertEq(paginatedMessages[1].content, "Message 3");
        assertEq(paginatedMessages[2].content, "Message 4");
    }

    function testGetMessagesPaginatedHandlesEndOfArray() public {
        vm.prank(alice);
        guestbook.postMessage("Message 1");

        vm.prank(bob);
        guestbook.postMessage("Message 2");

        GuestBook.Message[] memory messages = guestbook.getMessagesPaginated(0, 10);
        assertEq(messages.length, 2);
    }
    
    function testGetNonexistentMessage() public {
        vm.expectRevert("Message does not exist");
        guestbook.getMessage(0);
    }
}









