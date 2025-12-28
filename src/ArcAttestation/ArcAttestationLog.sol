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

    //@notice approve an attestation(social signal; not sybil-resistant)
    function approve(uint256 attestationId) external {

        require(attestationId < attestations.length, "Attestation does not exist");
        require(!approvedBy[attestationId][msg.sender], "Already approved");

        approvedBy[attestationId][msg.sender] = true;

        attestations[attestationId].approvals += 1;

        emit AttestationApproved(attestationId, msg.sender, attestations[attestationId].approvals);

    }

    function getAttestation(uint256 attestationId) external view returns (
        address author,
        bytes32 topic,
        bytes32 contentHash,
        uint256 timestamp,
        uint256 approvals
    ) {

        require(attestationId < attestations.length, "Attestation does not exist");

        Attestation storage a = attestations[attestationId];
        return (a.author, a.topic, a.contentHash, a.timestamp, a.approvals);

    }

    function getAttestationCount() external view returns (uint256) {
        return attestations.length;

    }

    function getAllAttestations() external view returns (Attestation[] memory) {
        return attestations;
    }

    /// @notice pagination that never panics; offset=length returns empty
    function getAttestationsPaginated(uint256 offset, uint256 limit)
    external
    view
    returns (Attestation[] memory)
{
    require(offset <= attestations.length, "Offset out of bounds");

    // Return empty array if asking for 0 items or exactly at the end
    if (limit == 0 || offset == attestations.length) {
        return new Attestation[](0);
    }

    uint256 end = offset + limit;
    if (end > attestations.length) end = attestations.length;

    uint256 resultLength = end - offset;
    Attestation[] memory result = new Attestation[](resultLength);

    for (uint256 i = 0; i < resultLength; i++) {
        result[i] = attestations[offset + i];
    }

    return result;
}


    function hasApproved(uint256 attestationId, address user) external view returns (bool) {

        require(attestationId < attestations.length, "Attestation does not exist");
        return approvedBy[attestationId][user];
    }

    function hasContent(bytes calldata payload) external pure returns (bytes32) {
        return keccak256(payload);
    }

}