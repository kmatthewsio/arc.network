// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/**
 * @title PaymentSplitter
 * @dev Split incoming USDC payments among multiple payees based on predefined shares
 * Perfect for Arc's stablecoin-native features
 */
contract PaymentSplitter {
    // Total shares across all payees
    uint256 public totalShares;
    
    // Total USDC released to payees
    uint256 public totalReleased;

    // Shares for each payee
    mapping(address => uint256) public shares;
    
    // Amount already released to each payee
    mapping(address => uint256) public released;
    
    // Array of all payees
    address[] public payees;

    // Events
    event PaymentReceived(address indexed from, uint256 amount);
    event PaymentReleased(address indexed to, uint256 amount);
    event PayeeAdded(address indexed account, uint256 shares);
    event PayeeRemoved(address indexed account);

    /**
     * @dev Creates a payment splitter with initial payees and shares
     * @param _payees Array of payee addresses
     * @param _shares Array of shares for each payee
     */
    constructor(address[] memory _payees, uint256[] memory _shares) {
        require(_payees.length == _shares.length, "Payees and shares length mismatch");
        require(_payees.length > 0, "No payees provided");

        for (uint256 i = 0; i < _payees.length; i++) {
            _addPayee(_payees[i], _shares[i]);
        }
    }

    /**
     * @dev Fallback function to receive USDC (or any native token)
     * On Arc, this would be USDC
     */
    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    /**
     * @dev Release payment to a specific payee
     * @param account The address of the payee
     */
    function release(address payable account) public {
        require(shares[account] > 0, "Account has no shares");

        uint256 payment = releasable(account);
        require(payment > 0, "Account is not due payment");

        released[account] += payment;
        totalReleased += payment;

        (bool success, ) = account.call{value: payment}("");
        require(success, "Transfer failed");

        emit PaymentReleased(account, payment);
    }

    /**
     * @dev Release payments to all payees
     */
    function releaseAll() public {
        for (uint256 i = 0; i < payees.length; i++) {
            address payable payee = payable(payees[i]);
            if (releasable(payee) > 0) {
                release(payee);
            }
        }
    }

    /**
     * @dev Calculate the amount of payment that can be released to an account
     * @param account The address to check
     * @return The amount that can be released
     */
    function releasable(address account) public view returns (uint256) {
        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 payment = (totalReceived * shares[account]) / totalShares - released[account];
        return payment;
    }

    /**
     * @dev Add a new payee to the contract
     * @param account Address of the payee
     * @param shares_ Number of shares for the payee
     */
    function addPayee(address account, uint256 shares_) public {
        // In production, you'd want access control here (onlyOwner)
        _addPayee(account, shares_);
    }

    /**
     * @dev Internal function to add a payee
     */
    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(shares[account] == 0, "PaymentSplitter: account already has shares");

        payees.push(account);
        shares[account] = shares_;
        totalShares += shares_;

        emit PayeeAdded(account, shares_);
    }

    /**
     * @dev Remove a payee from the contract (releases pending payment first)
     * @param account Address of the payee to remove
     */
    function removePayee(address payable account) public {
        // In production, you'd want access control here (onlyOwner)
        require(shares[account] > 0, "Account has no shares");

        // Release any pending payment first
        if (releasable(account) > 0) {
            release(account);
        }

        // Update total shares
        totalShares -= shares[account];
        
        // Remove shares
        shares[account] = 0;

        // Remove from payees array
        for (uint256 i = 0; i < payees.length; i++) {
            if (payees[i] == account) {
                payees[i] = payees[payees.length - 1];
                payees.pop();
                break;
            }
        }

        emit PayeeRemoved(account);
    }

    /**
     * @dev Get the number of payees
     */
    function payeeCount() public view returns (uint256) {
        return payees.length;
    }

    /**
     * @dev Get all payees
     */
    function getPayees() public view returns (address[] memory) {
        return payees;
    }

    /**
     * @dev Get contract balance
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
     * @dev Get payee info
     * @param account Address of the payee
     */
    function getPayeeInfo(address account) public view returns (
        uint256 payeeShares,
        uint256 payeeReleased,
        uint256 payeeReleasable
    ) {
        return (
            shares[account],
            released[account],
            releasable(account)
        );
    }
}
