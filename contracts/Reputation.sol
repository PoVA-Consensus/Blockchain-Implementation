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
    uint256 public AUTHORITY_THRESHOLD = 1000;
    uint256 public primaryIndex = 0;
    uint256 public BLOCK_REWARD = 100;
    uint256 public PENALTY = 25;
    uint256 public MIN_TRANSACTION_RATIO = 2;

    event NodeAdded(address nodeAddress, bool isAuthority, bool isFullNode);
    event NodeRemoved(address nodeAddress);
    event NodePromoted(address nodeAddress);
    event NodeDemoted(address nodeAddress);
    event ReputationAdded(address authorityNode, address nodeAddress, uint256 points);
    event ReputationRemoved(address authorityNode, address nodeAddress, uint256 points);
    event PrimaryChanged(address primaryNode);

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
            node.reputation = AUTHORITY_THRESHOLD;
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
        if(node.reputation > AUTHORITY_THRESHOLD)
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
        if (node.isAuthority && node.reputation < AUTHORITY_THRESHOLD)
        {
                consensusState=IN_CONSENSUS;
            demoteNode(nodeAddress);
        }
            emit ReputationRemoved(msg.sender, nodeAddress, points);
    }

    function rewardPrimary() public onlyAuthorityNode
    {
        Node storage node = nodes[currentPrimary];
        require(node.isAuthority, "Primary node must be an authority");
        node.reputation += BLOCK_REWARD;
    }
    function penalisePrimary() public onlyAuthorityNode
    {
        Node storage node = nodes[currentPrimary];
        require(node.isAuthority, "Primary node must be an authority");
        node.reputation -= PENALTY;
    }

    function getNextPrimary() public
    {
        primaryIndex = (primaryIndex + 1) % authorityNodes.length;
        currentPrimary = authorityNodes[primaryIndex];
        emit PrimaryChanged(currentPrimary);
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

    //authority nodes call VerifyBlock() in Javascript.
    //Wait ten seconds? and call getNumVotes() to see if the block was verified.
    
    uint32 private consensusState=SLEEP;
    uint32 IN_CONSENSUS=0;
    uint32 SLEEP=1;
    Block selectedBlock;

    function appendBlock(bytes32 data) public onlyAuthorityNode
    {
        require(msg.sender == currentPrimary, "Only primary node can add a block");
        require(consensusState == SLEEP,
        "Another consensus is underway. Try again later"); //implement a queue?

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

        selectedBlock=newBlock;
        consensusState=IN_CONSENSUS;
    }

    //implement Javascript logic to listen for a block being added and verify it
    function verifyBlock(bytes32 data, bytes32 hash) public view returns (bool exists)
    {
        if(blockExists[keccak256(abi.encodePacked(getChainLength(), data, hash))])
        {
            return true;
        }
    }

    mapping (address => bool) public hasVoted;
    uint public yesVotes;
    uint public noVotes;
    mapping (address => bool) public hasVotedYes;

    uint32 CONSENSUS_NOT_REACHED=0;
    uint32 MAJORITY_YES=1;
    uint32 MAJORITY_NO=2;

    function vote(bool voteYes) public onlyAuthorityNode {
        require(hasVoted[msg.sender] == false, "Already voted.");
        hasVoted[msg.sender] = true;

        if (voteYes) {
            yesVotes += 1;
            hasVotedYes[msg.sender] = true;
        } else {
            noVotes += 1;
        }
        uint32 consenus = peekVotes();
        if(consenus==CONSENSUS_NOT_REACHED){
            return;
        }
        else{
            if(consenus==MAJORITY_YES){
                lastBlock = selectedBlock;
                rewardPrimary();
                getNextPrimary();
                //new transaction
                consensusState=SLEEP;
            }
            else if(consenus==MAJORITY_NO){
                penalisePrimary();
                getNextPrimary();
                //same transaction
            }
            else{
                revert("Invalid Consensus conclusion");
            }
            resetVotes();
        }
    }
    
    function peekVotes() public view returns (uint32){
        if(yesVotes + noVotes < MIN_TRANSACTION_RATIO/authorityCount){
            return CONSENSUS_NOT_REACHED;
        }
        else{
            if (hasMajority()) {
                return MAJORITY_YES;
            }
            else{
                return MAJORITY_NO;
            }
        }
    }
    function hasMajority() public view returns (bool) {
        return ((yesVotes + noVotes) < MIN_TRANSACTION_RATIO/authorityCount) && (yesVotes >= noVotes);
    }

    function resetVotes() public onlyAuthorityNode {
        require(yesVotes + noVotes > MIN_TRANSACTION_RATIO/authorityCount,
        "The minimum required number of authority nodes has not voted yet.");
        for (uint i = 0; i < authorityNodes.length; i++) {
            hasVoted[authorityNodes[i]] = false;
            hasVotedYes[authorityNodes[i]] = false;
        }
        yesVotes = 0;
        noVotes = 0;
    }
        
}