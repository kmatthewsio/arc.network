// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract GuestBook {

    //struct to hold message data
    struct Message {
        address author;
        string content;
        uint256 timestamp;
        uint256 likes;
    }

    //array to store all messages
    Message[] public messages;

    //mapping to track if an address has signed the guestbook
    mapping(address => bool) public hasSigned;

    //mapping to track which address liked which messages
    mapping(uint256 => mapping(address => bool)) public messageLikes;

    event MessagePosted(address indexed author, string content, uint256 timestamp, uint256 messageId);
    event MessageLiked(uint256 indexed messageId, address indexed liker, uint256 totalLikes);

    //prevent spam
    uint256 public constant MAX_MESSAGE_LENGTH = 280;

    function postMessage(string memory _content) public 
    {
        require(bytes(_content).length > 0, "Message cannot be empty");
        require(bytes(_content).length <= MAX_MESSAGE_LENGTH, "Message too long");

        Message memory newMessage = Message( {
            author: msg.sender,
            content: _content,
            timestamp: block.timestamp,
            likes: 0
        });

        messages.push(newMessage);
        hasSigned[msg.sender] = true;

        emit MessagePosted(msg.sender, _content, block.timestamp, messages.length -1);

    }

    function likeMessage(uint256 _messageId) public {
        require(_messageId < messages.length, "Message does not exist");
        require(!messageLikes[_messageId][msg.sender], "Already liked this message");

        messages[_messageId].likes++;
        messageLikes[_messageId][msg.sender] = true;

        emit MessageLiked(_messageId, msg.sender, messages[_messageId].likes);

    }

    function getMessage(uint256 _messageId) public view returns (
        address author,
        string memory content,
        uint256 timestamp,
        uint256 likes
    ) {
        require(_messageId < messages.length, "Message does not exist");

        Message memory message = messages[_messageId];

        return(message.author, message.content, message.timestamp, message.likes);

    }

    function getMessageCount() public view returns(uint256) {
        return messages.length;
    }

    function getAllMessages() public view returns (Message[] memory) {
        return messages;
    }

    function getMessagesPaginated(uint256 _offset, uint256 _limit) public view returns (Message[] memory) {
        require(_offset < messages.length, "Offset out of bounds");

        uint256 end = _offset + _limit;
        
        if(end > messages.length) {
            end = messages.length;
        }

        uint256 resultLength = end - _offset;
        Message[] memory result = new Message[](resultLength);

        for(uint256 i = 0; i < resultLength; i++) {
            result[i] = messages[_offset + i];
        }

        return result;
    }

    function hasLikedMessage(uint256 _messageId, address _user) public view returns (bool) {
        require(_messageId < messages.length, "Message does not exist");
        return messageLikes[_messageId][_user];

    }

}
