// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PaymentSplitter/PaymentSplitter.sol";

contract PaymentSplitterTest is Test {
    PaymentSplitter public splitter;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public david = address(0x4);

    address[] public payees;
    uint256[] public sharesArray;

    function setUp() public {
        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
        vm.deal(david, 100 ether);

        // Set up payees and shares
        payees.push(alice);
        payees.push(bob);
        payees.push(charlie);

        sharesArray.push(50);  // Alice: 50%
        sharesArray.push(30);  // Bob: 30%
        sharesArray.push(20);  // Charlie: 20%

        splitter = new PaymentSplitter(payees, sharesArray);
    }

    function testConstructor() public view {
        assertEq(splitter.totalShares(), 100);
        assertEq(splitter.payeeCount(), 3);
        assertEq(splitter.shares(alice), 50);
        assertEq(splitter.shares(bob), 30);
        assertEq(splitter.shares(charlie), 20);
    }

    function testCannotCreateWithMismatchedArrays() public {
        address[] memory badPayees = new address[](2);
        uint256[] memory badShares = new uint256[](3);
        
        vm.expectRevert("Payees and shares length mismatch");
        new PaymentSplitter(badPayees, badShares);
    }

    function testCannotCreateWithNoPayees() public {
        address[] memory emptyPayees = new address[](0);
        uint256[] memory emptyShares = new uint256[](0);
        
        vm.expectRevert("No payees provided");
        new PaymentSplitter(emptyPayees, emptyShares);
    }

    function testReceivePayment() public {
        uint256 payment = 10 ether;
        
        vm.expectEmit(true, true, true, true);
        emit PaymentSplitter.PaymentReceived(david, payment);
        
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: payment}("");
        assertTrue(success);
        
        assertEq(address(splitter).balance, payment);
    }

    function testRelease() public {
        // Send 10 USDC (ether) to splitter
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        uint256 aliceBalanceBefore = alice.balance;
        
        // Release to Alice (50% of 10 = 5)
        splitter.release(payable(alice));
        
        assertEq(alice.balance, aliceBalanceBefore + 5 ether);
        assertEq(splitter.released(alice), 5 ether);
        assertEq(splitter.totalReleased(), 5 ether);
    }

    function testReleaseEmitsEvent() public {
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        vm.expectEmit(true, true, true, true);
        emit PaymentSplitter.PaymentReleased(alice, 5 ether);
        
        splitter.release(payable(alice));
    }

    function testReleasable() public {
        // Send 10 ether to splitter
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        assertEq(splitter.releasable(alice), 5 ether);   // 50%
        assertEq(splitter.releasable(bob), 3 ether);      // 30%
        assertEq(splitter.releasable(charlie), 2 ether);  // 20%
    }

    function testReleaseAll() public {
        // Send 10 ether to splitter
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        uint256 aliceBalanceBefore = alice.balance;
        uint256 bobBalanceBefore = bob.balance;
        uint256 charlieBalanceBefore = charlie.balance;

        splitter.releaseAll();

        assertEq(alice.balance, aliceBalanceBefore + 5 ether);
        assertEq(bob.balance, bobBalanceBefore + 3 ether);
        assertEq(charlie.balance, charlieBalanceBefore + 2 ether);
    }

    function testCannotReleaseWithNoShares() public {
        vm.expectRevert("Account has no shares");
        splitter.release(payable(david));
    }

    function testCannotReleaseWhenNothingDue() public {
        // Don't send any payment to splitter
        vm.expectRevert("Account is not due payment");
        splitter.release(payable(alice));
    }

    function testMultiplePaymentsAndReleases() public {
        // First payment: 10 ether
        vm.prank(david);
        (bool success1, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success1);

        // Release to Alice
        splitter.release(payable(alice));
        assertEq(splitter.released(alice), 5 ether);

        // Second payment: 5 ether
        vm.prank(david);
        (bool success2, ) = address(splitter).call{value: 5 ether}("");
        assertTrue(success2);

        // Alice should be able to release 2.5 more ether (50% of 5)
        uint256 aliceBalanceBefore = alice.balance;
        splitter.release(payable(alice));
        assertEq(alice.balance, aliceBalanceBefore + 2.5 ether);
        assertEq(splitter.released(alice), 7.5 ether);
    }

    function testAddPayee() public {
        vm.expectEmit(true, true, true, true);
        emit PaymentSplitter.PayeeAdded(david, 10);
        
        splitter.addPayee(david, 10);

        assertEq(splitter.shares(david), 10);
        assertEq(splitter.totalShares(), 110);
        assertEq(splitter.payeeCount(), 4);
    }

    function testCannotAddPayeeWithZeroAddress() public {
        vm.expectRevert("PaymentSplitter: account is the zero address");
        splitter.addPayee(address(0), 10);
    }

    function testCannotAddPayeeWithZeroShares() public {
        vm.expectRevert("PaymentSplitter: shares are 0");
        splitter.addPayee(david, 0);
    }

    function testCannotAddPayeeTwice() public {
        vm.expectRevert("PaymentSplitter: account already has shares");
        splitter.addPayee(alice, 10);
    }

    function testRemovePayee() public {
        // Send some payment first
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        uint256 aliceBalanceBefore = alice.balance;
        
        vm.expectEmit(true, true, true, true);
        emit PaymentSplitter.PayeeRemoved(alice);
        
        // Remove Alice (should auto-release her pending payment)
        splitter.removePayee(payable(alice));

        // Alice should have received her share (5 ether)
        assertEq(alice.balance, aliceBalanceBefore + 5 ether);
        
        // Alice should no longer have shares
        assertEq(splitter.shares(alice), 0);
        assertEq(splitter.totalShares(), 50); // 30 + 20 (Bob + Charlie)
        assertEq(splitter.payeeCount(), 2);
    }

    function testCannotRemovePayeeWithNoShares() public {
        vm.expectRevert("Account has no shares");
        splitter.removePayee(payable(david));
    }

    function testGetPayees() public view {
        address[] memory currentPayees = splitter.getPayees();
        assertEq(currentPayees.length, 3);
        assertEq(currentPayees[0], alice);
        assertEq(currentPayees[1], bob);
        assertEq(currentPayees[2], charlie);
    }

    function testGetBalance() public {
        assertEq(splitter.getBalance(), 0);

        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        assertEq(splitter.getBalance(), 10 ether);
    }

    function testGetPayeeInfo() public {
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 10 ether}("");
        assertTrue(success);

        (uint256 payeeShares, uint256 payeeReleased, uint256 payeeReleasable) = splitter.getPayeeInfo(alice);
        
        assertEq(payeeShares, 50);
        assertEq(payeeReleased, 0);
        assertEq(payeeReleasable, 5 ether);
    }

    function testProportionalDistribution() public {
        // Send 100 ether for easy math
        vm.prank(david);
        (bool success, ) = address(splitter).call{value: 100 ether}("");
        assertTrue(success);

        assertEq(splitter.releasable(alice), 50 ether);   // 50%
        assertEq(splitter.releasable(bob), 30 ether);      // 30%
        assertEq(splitter.releasable(charlie), 20 ether);  // 20%

        // Total should equal the payment
        assertEq(
            splitter.releasable(alice) + splitter.releasable(bob) + splitter.releasable(charlie),
            100 ether
        );
    }
}
