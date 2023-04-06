// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Reputation is ERC20, Ownable {
    using SafeMath for uint256;


    struct Block {
        uint256 index;
        bytes32 data;
        bytes32 previousHash;
        bytes32 hash;
    }

    Block private genesisBlock;

    mapping(bytes32 => bool) private blockExists;
    mapping(uint256 => bytes32) private blockHashes;
    mapping(bytes32 => bytes32) private blockParents;
    mapping(bytes32 => uint256) private blockLengths;
    Block private lastBlock;

    event BlockAdded(address authorityNode, uint256 blockNumber, bytes32 blockHash, bytes32 message);


    constructor(
        address _owner,
        uint256 _supply
    ) ERC20("Reputation", "REP") {
        _mint(_owner, _supply);

        genesisBlock = Block({
            index: 0,
            data: "",
            previousHash: bytes32(0),
            hash: keccak256(abi.encodePacked(uint(0), "", bytes32(0)))
        });
        blockExists[genesisBlock.hash] = true;
        blockHashes[0] = genesisBlock.hash;
        lastBlock = genesisBlock;
    }
    struct Node
    {
        bool isAuthority;
        bool isFullNode;
        uint256 reputation;
        uint256 authorityIndex;
        bytes certificate;
    }

    mapping(address => Node) public nodes;
    address[] public authorityNodes;
    uint256 public authorityCount;
    uint256 public candidateCount;
    address public currentPrimary;
    uint256 public authorityThreshold = 1000;
    uint256 public primaryIndex = 0;
    uint256 public blockReward = 100;

    event NodeAdded(address nodeAddress, bool isAuthority, bool isFullNode);
    event NodeRemoved(address nodeAddress);
    event NodePromoted(address nodeAddress);
    event NodeDemoted(address nodeAddress);
    event ReputationAdded(address authorityNode, address nodeAddress, uint256 points);
    event ReputationRemoved(address authorityNode, address nodeAddress, uint256 points);

    modifier onlyAuthorityNode() {
        require(nodes[msg.sender].isAuthority, "Only an authority node can call this function");
        _;
    }

    function addNode(bool _isAuthority, bool _isFullNode) public {
        Node storage node = nodes[msg.sender];
        require(node.reputation == 0, "Node already added");
        
        node.isAuthority = _isAuthority;
        node.isFullNode = _isFullNode;
        node.reputation = 0;
        if (_isAuthority) {
            authorityNodes.push(msg.sender);
            node.authorityIndex = authorityNodes.length - 1;
            node.reputation = authorityThreshold;
            authorityCount++;
        } else {
            candidateCount++;
        }
        
        emit NodeAdded(msg.sender, _isAuthority, _isFullNode);
    }

    function removeNode(address nodeAddress) public
    {
        Node storage node = nodes[nodeAddress];
        require(node.reputation == 0, "Node must have 0 reputation to be removed");
        if (node.isAuthority)
        {
            require(authorityCount > 1, "Cannot remove last authority node");
            uint256 index = node.authorityIndex;
            authorityNodes[index] = authorityNodes[authorityNodes.length - 1];
            nodes[authorityNodes[index]].authorityIndex = index;
            authorityNodes.pop();
            authorityCount--;
        }
        else
        {
            candidateCount--;
        }
        delete nodes[msg.sender];
        emit NodeRemoved(msg.sender);
    }

    function promoteNode(address nodeAddress) public onlyAuthorityNode
    {
        Node storage node = nodes[nodeAddress];
        require(!node.isAuthority, "Node is already an authority");
        require(candidateCount > 0, "No candidates to promote");
        node.isAuthority = true;
        node.authorityIndex = authorityNodes.length;
        authorityNodes.push(nodeAddress);
        candidateCount--;
        authorityCount++;
        emit NodePromoted(nodeAddress);
    }

    function demoteNode(address nodeAddress) public onlyAuthorityNode
    {
        Node storage node = nodes[nodeAddress];
        require(node.isAuthority, "Node is not an authority");
        require(authorityCount > 1, "Cannot demote last authority node");
        uint256 index = node.authorityIndex;
        authorityNodes[index] = authorityNodes[authorityNodes.length - 1];
        nodes[authorityNodes[index]].authorityIndex = index;
        authorityNodes.pop();
        node.isAuthority = false;
        candidateCount++;
        authorityCount--;
        emit NodeDemoted(nodeAddress);
    }


    function addReputation(address nodeAddress, uint256 points) public onlyAuthorityNode
    {
        require(points > 0, "Reputation points must be greater than 0");
        Node storage node = nodes[nodeAddress];
        node.reputation += points;
        emit ReputationAdded(msg.sender, nodeAddress, points);
        if(node.reputation > authorityThreshold)
        {
            promoteNode(nodeAddress);
        }
    }

    function removeReputation(address nodeAddress, uint256 points) public onlyAuthorityNode
    {
        Node storage node = nodes[nodeAddress];
        require(node.reputation >= points, "Node does not have enough reputation");
        if(node.reputation <= points)
        {
            node.reputation = 0;
        }
        else
        {
            node.reputation -= points;
        }
        if (node.isAuthority && node.reputation < authorityThreshold)
        {
            demoteNode(nodeAddress);
        }
            emit ReputationRemoved(msg.sender, nodeAddress, points);
    }

    function rewardPrimary() public onlyAuthorityNode
    {
        Node storage node = nodes[currentPrimary];
        require(node.isAuthority, "Primary node must be an authority");
        node.reputation += blockReward;
    }

    function getNextPrimary() public
    {
        primaryIndex = (primaryIndex + 1) % authorityNodes.length;
        currentPrimary = authorityNodes[primaryIndex];
        rewardPrimary();
    }
    

    function getLatestBlock() public view returns (Block memory)
    {
        return getBlockByIndex(getChainLength() - 1);
    }

    function getBlockByIndex(uint256 index) public view returns (Block memory)
    {
        require(index >= 0 && index < getChainLength(), "Block does not exist");

        return getBlockByHash(blockHashes[index]);
    }

    function getBlockByHash(bytes32 hash) public view returns (Block memory)
    {
        require(blockExists[hash], "Block does not exist");

        Block storage blockRef;
        assembly {
            blockRef.slot := add(hash, 1)
        }

        return blockRef;
    }

    function getChainLength() public view returns (uint256)
    {
        return lastBlock.index+1;
    }

    //authority nodes call VerifyBlock() in Javascript. Wait ten seconds? and call getNumVotes() to see if the block was verified.
    function appendBlock(bytes32 data) public onlyAuthorityNode
    {
        //require(!blockExists[keccak256(abi.encodePacked(getChainLength(), data, getLatestBlock().hash))], "Block already exists");
        require(msg.sender == currentPrimary, "Only primary node can add a block");

        Block memory previousBlock = getLatestBlock();

        Block memory newBlock = Block({
            index: previousBlock.index + 1,
            data: data,
            previousHash: previousBlock.hash,
            hash: keccak256(abi.encodePacked(previousBlock.index + 1, data, previousBlock.hash))
        });

        blockExists[newBlock.hash] = true;
        blockHashes[newBlock.index] = newBlock.hash;
        emit BlockAdded(msg.sender, newBlock.index, newBlock.hash, newBlock.data);
    }

    //implement Javascript logic to listen for a block being added and verify it
    function verifyBlock(bytes32 data, bytes32 hash) public returns (bool exists)
    {
        if(blockExists[keccak256(abi.encodePacked(getChainLength(), data, hash))])
        {
            lastBlock = getBlockByHash(hash);
            return true;
        }
    }

    function recoverSigner(bytes32 messageHash, uint8 v, bytes32 r, bytes32 s) public pure returns (address)
    {
        bytes32 prefixedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        return ecrecover(prefixedHash, v, r, s);
    }

    
    function getNumAdminVotes(bytes32 _transactionHash) public view returns (uint256) {
        uint256 numVotes = 0;
        for (uint256 i = 0; i < authorityCount ; i++) {
            address authAddress = authorityNodes[i];
            Node memory verifier = nodes[authAddress];
            if (verifier.isAuthority) {
                bytes32 message = keccak256(abi.encodePacked(_transactionHash, authAddress));
                bytes32 prefixedMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
                address recoveredAddress = ecrecover(prefixedMessage, 27, bytes32(0), bytes32(0));
                if (recoveredAddress == authAddress) {
                    numVotes++;
                }
            }
        }
        return numVotes;
    }

    function getMajorityVote(uint256 _numVotes) public view returns (bool) {
        return (_numVotes * 2 > authorityCount);
    }
        

}