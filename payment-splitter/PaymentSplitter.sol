// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Split {
    address[] private _payees;
    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    uint256 public totalShares;
    uint256 public totalReleased;

    event PaymentReceived(address indexed from, uint256 amount);
    event FundsReleased(address indexed to, uint256 amount);

    constructor(address[] memory payees, uint256[] memory shares_) {
        require(payees.length == shares_.length && payees.length > 0, "Invalid payees/shares");
        uint256 sum = 0;
        for (uint256 i = 0; i < payees.length; i++) {
            address payee = payees[i];
            uint256 share = shares_[i];
            require(payee != address(0), "Zero address payee");
            require(share > 0, "Share must be > 0");
            require(_shares[payee] == 0, "Duplicate payee");
            _payees.push(payee);
            _shares[payee] = share;
            sum += share;
        }
        require(sum == 100, "Shares must sum to 100");
        totalShares = sum;
    }

    receive() external payable {
        emit PaymentReceived(msg.sender, msg.value);
    }

    function getPayees() external view returns (address[] memory) {
        return _payees;
    }

    function getShares() external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_payees.length);
        for (uint256 i = 0; i < _payees.length; i++) {
            result[i] = _shares[_payees[i]];
        }
        return result;
    }

    function getReleasable(address account) public view returns (uint256) {
        if (_shares[account] == 0) return 0;
        uint256 totalReceived = address(this).balance + totalReleased;
        uint256 entitled = (totalReceived * _shares[account]) / totalShares;
        return entitled - _released[account];
    }

    function release(address payable account) external {
        require(_shares[account] > 0, "Account has no shares");
        uint256 payment = getReleasable(account);
        require(payment > 0, "Account is not due payment");

        _released[account] += payment;
        totalReleased += payment;

        (bool ok, ) = account.call{value: payment}("");
        require(ok, "ETH transfer failed");
        emit FundsReleased(account, payment);
    }
}

contract SplitFactory {
    address[] public allSplits;
    mapping(address => address[]) private _memberSplits;

    event SplitCreated(address indexed splitAddress, address indexed creator, address[] payees, uint256[] shares);

    function createSplit(address[] calldata payees, uint256[] calldata shares) external returns (address) {
        Split newSplit = new Split(payees, shares);
        address splitAddr = address(newSplit);
        allSplits.push(splitAddr);
        for (uint256 i = 0; i < payees.length; i++) {
            _memberSplits[payees[i]].push(splitAddr);
        }
        emit SplitCreated(splitAddr, msg.sender, payees, shares);
        return splitAddr;
    }

    function getMemberSplits(address member) external view returns (address[] memory) {
        return _memberSplits[member];
    }
}
