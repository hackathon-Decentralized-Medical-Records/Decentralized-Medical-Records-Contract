// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ModuleMain} from "./ModuleMain.sol";
import {LibTypeDef} from "../src/utils/LibTypeDef.sol";

// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

contract Role is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    /**
     * Error
     */
    error Role__improperRole(address user, uint8 roleType);
    error Role__mintNotApproved(address user);
    error Role__TransferFail();
    error Role__tokenNotApproved(address provider, uint256 tokenId);

    /**
     * Type declarations
     */

    /**
     * State Variables
     */
    LibTypeDef.RoleType private immutable i_roleType;
    address private s_systemAddress;
    uint256 private s_tokenCounter;
    bool private s_needFund;
    mapping(address => bool) private s_approvedMintState;
    mapping(uint256 tokenId => string) private s_tokenIdToMedicalInfo;
    mapping(uint256 tokenId => mapping(address provider => bool)) private s_tokenToProviderApprovalState;

    /**
     * Events
     */
    event Role__MaterialAddedAndCancelAddRight(address indexed sender, uint256 indexed tokenId);
    event Role__ApproveMintAddress(address indexed user);
    event Role__TokenAccessApproved(uint256 indexed tokenId, address indexed provider);
    event Role__FundRequested(string indexed statement, uint256 indexed amountInUsd);

    /**
     * Modifier
     */
    modifier mintApproved(address user) {
        if (s_approvedMintState[user] == false && msg.sender != owner()) {
            revert Role__mintNotApproved(user);
        }
        _;
    }

    modifier tokenApproved(address provider, uint256 tokenId) {
        if (s_tokenToProviderApprovalState[tokenId][provider] == false && s_needFund == false) {
            revert Role__tokenNotApproved(provider, tokenId);
        }
        _;
    }

    modifier onlyPatient() {
        if (i_roleType != LibTypeDef.RoleType.PATIENT) {
            revert Role__improperRole(msg.sender, uint8(i_roleType));
        }
        _;
    }

    modifier onlyDoctor() {
        if (i_roleType != LibTypeDef.RoleType.DOCTOR) {
            revert Role__improperRole(msg.sender, uint8(i_roleType));
        }
        _;
    }

    modifier onlyService() {
        if (i_roleType != LibTypeDef.RoleType.SERVICE) {
            revert Role__improperRole(msg.sender, uint8(i_roleType));
        }
        _;
    }

    modifier onlyData() {
        if (i_roleType != LibTypeDef.RoleType.DATA) {
            revert Role__improperRole(msg.sender, uint8(i_roleType));
        }
        _;
    }

    /**
     * Functions
     */
    constructor(address user, address systemAddress, LibTypeDef.RoleType roleType)
        payable
        ERC721("Medical Materials", "MM")
        Ownable(user)
    {
        require(
            type(LibTypeDef.RoleType).min <= roleType && roleType <= type(LibTypeDef.RoleType).max, "Invalid role type"
        );
        i_roleType = roleType;
        s_systemAddress = systemAddress;
    }

    fallback() external payable {}

    receive() external payable {}

    function setApprovalForAddingMaterial(address provider) public onlyOwner {
        s_approvedMintState[provider] = true;
        emit Role__ApproveMintAddress(provider);
    }

    function setApprovalForTokenId(uint256 tokenId, address provider) public onlyOwner {
        s_tokenToProviderApprovalState[tokenId][provider] = true;
        emit Role__TokenAccessApproved(tokenId, provider);
    }

    function addMaterial(string memory uri) public mintApproved(msg.sender) {
        uint256 tokenId = s_tokenCounter++;
        _safeMint(owner(), tokenId);
        _setTokenURI(tokenId, uri);
        s_approvedMintState[msg.sender] = false;
        emit Role__MaterialAddedAndCancelAddRight(msg.sender, tokenId);
    }

    function updateURI(uint256 tokenId, string memory uri) public mintApproved(msg.sender) {
        _setTokenURI(tokenId, uri);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        tokenApproved(msg.sender, tokenId)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function requestFund(string memory statement, uint256 amountUsd) public onlyOwner onlyPatient {
        s_needFund = true;
        ModuleMain(s_systemAddress).registerFundRequest(msg.sender, address(this), amountUsd);
        emit Role__FundRequested(statement, amountUsd);
    }
}
