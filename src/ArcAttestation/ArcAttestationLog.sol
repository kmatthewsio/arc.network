// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
  
contract ArcAttestationLog {

     struct Attestation {
        address author;
        bytes32 topic;        // namespace/category, e.g. keccak256("invoice:accepted")
        bytes32 contentHash;  // keccak256(payload)
        uint64  timestamp;    // block timestamp (fits for a long time)
        uint32  approvals;    // optional lightweight signal (not sybil-resistant)
    }

    Attestation[] public attestations;

    mapping(address => bool) public hasAttested;
    mapping(uint256 => mapping(address => bool)) public approvedBy; // attestationId => user => approved?
 
    event AttestationPosted(
        uint256 indexed attestationId,
        address indexed author,
        bytes32 indexed topic,
        bytes32 contentHash,
        uint256 timestamp
    );

    event AttestationApproved(
        uint256 indexed attestationId,
        address indexed approver,
        uint256 totalApprovals
    );

    /// @notice Post an attestation (topic + contentHash)
    function postAttestation(bytes32 topic, bytes32 contentHash) external returns (uint256 attestationId) {
        require(topic != bytes32(0), "Topic cannot be empty");
        require(contentHash != bytes32(0), "Content hash cannot be empty");

        Attestation memory a = Attestation({
            author: msg.sender,
            topic: topic,
            contentHash: contentHash,
            timestamp: uint64(block.timestamp),
            approvals: 0
        });

        attestations.push(a);
        hasAttested[msg.sender] = true;

        attestationId = attestations.length - 1;

        emit AttestationPosted(
            attestationId,
            msg.sender,
            topic,
            contentHash,
            block.timestamp
        );
    }
    
}