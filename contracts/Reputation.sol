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

    address[] internal authorityNodes;

    // check if node with address _address is authorityNode and return index
    function isAuthorityNode(
        address _address
    ) public view returns (bool, uint256) {
        for (uint256 s = 0; s < authorityNodes.length; s += 1) {
            if (_address == authorityNodes[s]) return (true, s);
        }
        return (false, 0);
    }

    //add authorityNode if doesnt exist
    function addAuthorityNode(address _authorityNode) public {
        (bool _isAuthorityNode, ) = isAuthorityNode(_authorityNode);
        if (!_isAuthorityNode) authorityNodes.push(_authorityNode);
    }

    //remove authorityNode if exists
    function removeAuthorityNode(address _authorityNode) public {
        (bool _isAuthorityNode, uint256 s) = isAuthorityNode(_authorityNode);
        if (_isAuthorityNode) {
            authorityNodes[s] = authorityNodes[authorityNodes.length - 1];
            authorityNodes.pop();
        }
    }

    mapping(address => uint256) internal reputationPoints;

    function ReputationPointsOf(
        address _authorityNode
    ) public view returns (uint256) {
        return reputationPoints[_authorityNode];
    }

    //all reputationPoints sum
    function totalReputationPoints() public view returns (uint256) {
        uint256 _totalReputationPoints = 0;
        for (uint256 s = 0; s < authorityNodes.length; s += 1) {
            _totalReputationPoints = _totalReputationPoints.add(
                reputationPoints[authorityNodes[s]]
            );
        }
        return _totalReputationPoints;
    }

    //delete is reputationPoints exists and create new
    function createReputationPoints(uint256 _reputationPoints) public {
        _mint(msg.sender, _reputationPoints);
        if (reputationPoints[msg.sender] == 0) addAuthorityNode(msg.sender);
        reputationPoints[msg.sender] = reputationPoints[msg.sender].add(
            _reputationPoints
        );
    }

    function removeReputationPoints(uint256 _reputationPoints) public {
        reputationPoints[msg.sender] = reputationPoints[msg.sender].sub(
            _reputationPoints
        );
        if (reputationPoints[msg.sender] == 0) removeAuthorityNode(msg.sender);
        _burn(msg.sender, _reputationPoints);
    }

    mapping(address => uint256) internal rewards;

    function rewardOf(address _authorityNode) public view returns (uint256) {
        return rewards[_authorityNode];
    }

    function totalRewards() public view returns (uint256) {
        uint256 _totalRewards = 0;
        for (uint256 s = 0; s < authorityNodes.length; s += 1) {
            _totalRewards = _totalRewards.add(rewards[authorityNodes[s]]);
        }
        return _totalRewards;
    }

    function calculateReward(
        address _authorityNode
    ) public view returns (uint256) {
        return reputationPoints[_authorityNode] / 100;
    }

    function distributeRewards() public onlyOwner {
        for (uint256 s = 0; s < authorityNodes.length; s += 1) {
            address authorityNode = authorityNodes[s];
            uint256 reward = calculateReward(authorityNode);
            rewards[authorityNode] = rewards[authorityNode].add(reward);
        }
    }

    function withdrawReward() public {
        uint256 reward = rewards[msg.sender];
        rewards[msg.sender] = 0;
        _mint(msg.sender, reward);
    }
}
