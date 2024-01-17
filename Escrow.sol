// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    address public escAcc;
    uint256 public escAvailBal;
    uint256 public escFee;
    uint256 public escBal;
    uint256 public totalItems;
    uint256 public totalConfirmed;
    uint256 public totalDisputed;

    mapping(uint256 => itemsStruct) items;
    mapping(address => itemsStruct[]) itemsOf;
    mapping(address => mapping(uint256 => bool)) public requested;
    mapping(uint256 => address) public ownerOf;
    mapping(uint256 => Available) public isAvailable;

    struct itemsStruct {
        uint256 itemId;
        string purpose;
        uint256 amount;
        address owner;
        address buyer;
        Status status;
        bool provided;
        bool confirmed;
        uint256 timestamp;
    }

    enum Available {
        NO,
        YES
    }
    enum Status {
        OPEN,
        PENDING,
        DELIVERY,
        CONFIRMED,
        DISPUTED,
        REFUNDED,
        WITHDRAW
    }

    event Action(
        uint256 itemId,
        string actionType,
        Status status,
        address indexed executor
    );

    constructor(uint256 _escFee) {
        escFee = _escFee;
        escAcc = msg.sender;
    }

    function createItem(string memory _purpose) public payable returns (bool) {
        require(bytes(_purpose).length > 0, "Purpose cannot be empty");
        require(msg.value > 0, "Ammount cannot be zero");

        uint256 itemId = totalItems++;

        itemsStruct storage item = items[itemId];
        item.itemId = itemId;
        item.purpose = _purpose;
        item.amount = msg.value;
        item.owner = msg.sender;
        item.timestamp = block.timestamp;

        itemsOf[msg.sender].push(item);
        ownerOf[itemId] = msg.sender;
        isAvailable[itemId] = Available.YES;
        escBal += msg.value;

        emit Action(itemId, "ITEM CREATED", Status.OPEN, msg.sender);

        return true;
    }

    function getItems() public view returns (itemsStruct[] memory props) {
        props = new itemsStruct[](totalItems);

        for (uint256 i = 0; i < totalItems; i++) {
            props[i] = items[i];
        }
    }

    function getItem(uint256 _itemId) public view returns (itemsStruct memory) {
        return items[_itemId];
    }

    function myItems() public view returns (itemsStruct[] memory) {
        return itemsOf[msg.sender];
    }

    function requestItem(uint256 _itemId) public returns (bool) {
        require(msg.sender != ownerOf[_itemId], "Owner is not required");
        require(isAvailable[_itemId] == Available.YES, "Item is not available");
        requested[msg.sender][_itemId] = true;

        emit Action(_itemId, "REQUESTED", Status.OPEN, msg.sender);

        return true;
    }

    function approveItemRequest(
        uint256 _itemId,
        address _buyer
    ) public returns (bool) {
        require(msg.sender == ownerOf[_itemId], "Only Owner allowed");
        require(isAvailable[_itemId] == Available.YES, "Item not available");
        require(requested[_buyer][_itemId], "Buyer is not in the list");

        items[_itemId].buyer = _buyer;
        items[_itemId].status = Status.PENDING;
        isAvailable[_itemId] = Available.NO;

        emit Action(_itemId, "ITEM APPROVED", Status.PENDING, msg.sender);

        return true;
    }

    function performDelivery(uint256 _itemId) public returns (bool) {
        require(
            msg.sender == items[_itemId].buyer,
            "You are not approved buyer"
        );
        require(
            !items[_itemId].provided,
            "You have already delivered this item"
        );

        items[_itemId].status = Status.DELIVERY;
        items[_itemId].provided = true;

        emit Action(
            _itemId,
            "ITEM DEVLIVERY INITIATED",
            Status.DELIVERY,
            msg.sender
        );

        return true;
    }

    function confirmDelivery(
        uint256 _itemId,
        bool _provided
    ) public returns (bool) {
        require(msg.sender == ownerOf[_itemId], "Only Owner allowed");
        require(items[_itemId].provided, "You have not delivered this item");
        require(items[_itemId].status != Status.REFUNDED, "Already refunded");

        if (_provided) {
            uint256 fee = (items[_itemId].amount * escFee) / 100;
            uint256 amount = items[_itemId].amount - fee;
            payTo(items[_itemId].buyer, amount);
            escBal -= amount;
            escAvailBal += fee;

            items[_itemId].status = Status.CONFIRMED;
            items[_itemId].confirmed = true;

            totalConfirmed++;

            emit Action(
                _itemId,
                "ITEMS CONFIRMED",
                Status.CONFIRMED,
                msg.sender
            );
        } else {
            items[_itemId].status = Status.DISPUTED;
            emit Action(_itemId, "ITEMS disputed", Status.DISPUTED, msg.sender);
        }

        return true;
    }

    function refundItem(uint256 _itemId) public returns (bool) {
        require(msg.sender == escAcc, "Only Escrow admin is allowed");
        require(items[_itemId].provided, "You have not delivered this item");

        payTo(items[_itemId].owner, items[_itemId].amount);
        escBal -= items[_itemId].amount;
        items[_itemId].status = Status.REFUNDED;
        totalDisputed++;

        emit Action(_itemId, "ITEM REFUNDED", Status.REFUNDED, msg.sender);
        return true;
    }

    function withdrawFund(address _to, uint256 _amount) public returns (bool) {
        require(msg.sender == escAcc, "Only Escrow admin is allowed");
        require(_amount <= escAvailBal, "Insufficient fund");

        payTo(_to, _amount);
        escAvailBal -= _amount;

        return true;
    }

    function payTo(address to, uint256 amount) internal returns (bool) {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Payment failed");
        return true;
    }
}
