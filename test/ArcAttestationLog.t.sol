// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ArcAttestationLog} from "../src/ArcAttestation/ArcAttestationLog.sol";

contract ArcAttestationLogTest is Test {

    ArcAttestationLog public attestationLog;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    bytes32 internal constant TOPIC_INVOICE_ACCEPTED = keccak256("invoice:accepted");
    bytes32 internal constant TOPIC_AUDIT_PASSED = keccak256("audit:passed");

    function setUp() public {
        attestationLog = new ArcAttestationLog();
    }

    //helper
    function _hashString(string memory s) internal pure returns (bytes32) {
        return keccak256(bytes(s));
    }

    //post attestation 
    function testPostAttestation() public {
        bytes32 h = _hashString("Hello arc attestation");

        vm.prank(alice);
        uint256 id = attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, h);

        assertEq(id, 0);
        assertEq(attestationLog.getAttestationCount(), 1);
        assertTrue(attestationLog.hasAttested(alice));

        (address author, bytes32 topic, bytes32 contentHash, uint256 ts, uint256 approvals) = attestationLog.getAttestation(0);

        assertEq(author, alice);
        assertEq(topic, TOPIC_INVOICE_ACCEPTED);
        assertEq(contentHash, h);
        assertGt(ts, 0);
        assertEq(approvals, 0);
    }

    function testPostAttestationEmitsEvent() public {

        bytes32 h = _hashString("Building on arc!");

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);

        emit ArcAttestationLog.AttestationPosted(0, alice, TOPIC_AUDIT_PASSED, h, block.timestamp);

        attestationLog.postAttestation(TOPIC_AUDIT_PASSED, h);
    }

    function testCannotPostWithEmptyTopic() public {
        bytes32 h = _hashString("payload");

        vm.prank(alice);
        vm.expectRevert(bytes("Topic cannot be empty"));
        attestationLog.postAttestation(bytes32(0), h);
    }

    function testCannotPostWithEmptyContentHash() public {
        vm.prank(alice);
        vm.expectRevert(bytes("Content hash cannot be empty"));
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, bytes32(0));

    }

    function testMultipleAttestations() public {
        vm.prank(alice);
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("A1"));

        vm.prank(bob);
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("B1"));

        vm.prank(charlie);
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("C1"));

        assertEq(attestationLog.getAttestationCount(), 3);

        (address a0,,,,) = attestationLog.getAttestation(0);
        (address a1,,,,) = attestationLog.getAttestation(1);
        (address a2,,,,) = attestationLog.getAttestation(2);       

        assertEq(a0, alice);
        assertEq(a1, bob);
        assertEq(a2, charlie);

    }

    function testApprove() public {
        vm.prank(alice);
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("approve me"));

        vm.prank(bob);
        attestationLog.approve(0);

        (,,,, uint256 approvals) = attestationLog.getAttestation(0);
        assertEq(approvals, 1);
        assertTrue(attestationLog.hasApproved(0, bob));
    }

    function testApproveEmitsEvent() public {
        vm.prank(alice);
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("emit approve"));

        vm.prank(bob);
        attestationLog.approve(0);

        vm.prank(bob);
        vm.expectRevert(bytes("Already approved"));
        attestationLog.approve(0);
    }

    function testCannotApproveNonexistentAttestation() public {
        vm.prank(bob);
        vm.expectRevert(bytes("Attestation does not exist"));
        attestationLog.approve(0);
    }

    function testMultipleApprovals() public {
        vm.prank(alice);
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("popular"));

        vm.prank(bob);
        attestationLog.approve(0);

        vm.prank(charlie);
        attestationLog.approve(0);

        (,,,, uint256 approvals) = attestationLog.getAttestation(0);
        assertEq(approvals, 2);
    }

    function testGetAllAttestations() public {
        vm.prank(alice);
        attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("A"));

        vm.prank(bob);
        attestationLog.postAttestation(TOPIC_AUDIT_PASSED, _hashString("B"));

        ArcAttestationLog.Attestation[] memory all = attestationLog.getAllAttestations();
        assertEq(all.length, 2);

        assertEq(all[0].author, alice);
        assertEq(all[0].topic, TOPIC_INVOICE_ACCEPTED);

        assertEq(all[1].author, bob);
        assertEq(all[1].topic, TOPIC_AUDIT_PASSED);
    }

    function testGetAttestationsPaginated() public {
        for (uint256 i = 1; i <=5; i++) {
            vm.prank(alice);
            attestationLog.postAttestation(
                TOPIC_INVOICE_ACCEPTED,
                _hashString(string(abi.encodePacked("payload ", vm.toString(i) )))
            );
        }

            ArcAttestationLog.Attestation[] memory page = attestationLog.getAttestationsPaginated(1, 3);
            assertEq(page.length, 3);

            assertEq(page[0].contentHash, _hashString("payload 2"));
            assertEq(page[1].contentHash, _hashString("payload 3"));
            assertEq(page[2].contentHash, _hashString("payload 4"));
        }

        function testGetAttestationsPaginatedHandlesEndOfArray() public {
            vm.prank(alice);
            attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("p1"));

            vm.prank(bob);
            attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("p2"));

            ArcAttestationLog.Attestation[] memory page = attestationLog.getAttestationsPaginated(0, 10);
            assertEq(page.length, 2);
        }

        function testGetAttestationsPaginatedOffSetEqualsLengthReturnsEmpty() public {
            vm.prank(alice);
            attestationLog.postAttestation(TOPIC_INVOICE_ACCEPTED, _hashString("p1"));

            ArcAttestationLog.Attestation[] memory page = attestationLog.getAttestationsPaginated(1, 10);
            assertEq(page.length, 0);            
        }

        function testGetNonexistentAttestationReverts() public {
            vm.expectRevert(bytes("Attestation does not exist"));
            attestationLog.getAttestation(0);
        }
    
}
