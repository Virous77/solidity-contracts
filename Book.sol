// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Book {
    uint256 public tax;
    address immutable taxAccount;
    uint256 totalSupply;
    BookStruct[] books;
    mapping(address => BookStruct[]) public bookOf;
    mapping(uint256 => address) public sellerOf;
    mapping(uint256 => bool) public bookExist;

    struct BookStruct {
        uint256 id;
        address seller;
        string name;
        string description;
        string author;
        uint256 amount;
        uint256 timestamp;
    }

    event Sale(
        uint256 id,
        address indexed buyer,
        address indexed seller,
        uint256 amount,
        uint256 timestamp
    );

    event Created(uint256 id, address indexed seller, uint256 timestamp);

    constructor(uint256 _tax) {
        tax = _tax;
        taxAccount = msg.sender;
    }

    function createBook(
        string memory _name,
        string memory _description,
        uint256 _amount,
        string memory _author
    ) public returns (bool) {
        require(bytes(_name).length > 0, "Name is empty");
        require(bytes(_description).length > 0, "Description is empty");
        require(bytes(_author).length > 0, "Author name is empty");
        require(_amount > 0, "Amount should be greator than 0");

        sellerOf[totalSupply] = msg.sender;
        bookExist[totalSupply] = true;

        books.push(
            BookStruct(
                totalSupply,
                msg.sender,
                _name,
                _description,
                _author,
                _amount,
                block.timestamp
            )
        );

        emit Created(totalSupply++, msg.sender, block.timestamp);
        return true;
    }

    function payOfBook(uint256 id) public payable returns (bool) {
        require(bookExist[id], "Book does not exist");
        require(msg.value >= books[id].amount, "insufficient amount");

        address seller = sellerOf[id];
        uint256 fee = (msg.value / 100) * tax;
        uint256 payment = msg.value - fee;

        payTo(seller, payment);
        payTo(taxAccount, fee);
        bookOf[msg.sender].push(books[id]);

        emit Sale(id, msg.sender, seller, books[id].amount, block.timestamp);

        return true;
    }

    function payTo(address to, uint256 amount) internal returns (bool) {
        (bool success, ) = payable(to).call{value: amount}("");
        require(success, "Payment failed");
        return true;
    }

    function myBooks(address buyer) public view returns (BookStruct[] memory) {
        return bookOf[buyer];
    }

    function getBooks() public view returns (BookStruct[] memory) {
        return books;
    }

    function getBook(uint256 id) public view returns (BookStruct memory) {
        return books[id];
    }
}
