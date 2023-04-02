// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Reputation is ERC20, Ownable {
    using SafeMath for uint256;

    constructor(
        address _owner,
        uint256 _supply
    ) ERC20("Reputation", "REP") {
        _mint(_owner, _supply);
    }
    struct Node
    {
        bool isAuthority;
        bool isFullNode;
        uint256 reputation;
        uint256 authorityIndex;
    }

    mapping(address => Node) public nodes;
    address[] public authorityNodes;
    uint256 public authorityCount;
    uint256 public candidateCount;
    uint256 public blockNumber = 0;
    address public currentPrimary;
    uint256 public penaltyThreshold = 50;
    uint256 public minAuthorityReputation = 1000;
    uint256 public primaryIndex = 0;
    uint256 public blockReward = 100;

    event NodeAdded(address nodeAddress, bool isAuthority, bool isFullNode);
    event NodeRemoved(address nodeAddress);
    event NodePromoted(address nodeAddress);
    event NodeDemoted(address nodeAddress);
    event NodePenalized(address nodeAddress, uint256 penalty);
    event BlockAdded(address authorityNode, uint256 blockNumber, bytes32 blockHash);
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
        if(node.reputation > minAuthorityReputation)
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
        if (node.isAuthority && node.reputation < minAuthorityReputation)
        {
            demoteNode(nodeAddress);
        }
            emit ReputationRemoved(msg.sender, nodeAddress, points);
    }

    function addBlock(bytes32 blockHash) public onlyAuthorityNode
    {
        require(msg.sender == currentPrimary, "Only primary node can add a block");
        blockNumber++;
        emit BlockAdded(msg.sender, blockNumber, blockHash);
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
}