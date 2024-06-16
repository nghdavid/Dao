// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MyToken} from "../src/Token.sol";
import {MyGovernor} from "../src/Governor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";

contract DAOTest is Test {
    MyToken public token;
    MyGovernor public governor;
    TimeLock public timelock;
    Box public box;
    address[] public voters = new address[](5);
    function setUp() public {
        voters[0] = address(1);
        voters[1] = address(2);
        voters[2] = address(3);
        voters[3] = address(4);
        voters[4] = address(5);
        // Create token contract
        token = new MyToken(address(1));
        address[] memory proposers = new address[](1);
        proposers[0] = address(1);
        // Create timelock contract
        timelock = new TimeLock(1, proposers, new address[](0), address(this));
        // Create governor contract
        governor = new MyGovernor(token, timelock);
        // Create box contract
        box = new Box(address(timelock));

        // Mint and transfer tokens to voters
        vm.startPrank(address(1));
        token.mint(address(1), 1000e18);
        token.transfer(address(2), 200e18);
        token.transfer(address(3), 200e18);
        token.transfer(address(4), 200e18);
        token.transfer(address(5), 200e18);
        vm.stopPrank();

        // Delegate votes to voters
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            token.delegate(voters[i]);
        }

        // Grant roles to governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(governor));
    }

    function testVote() public {
        address[] memory targets = new address[](1); // Contract thats going to be called
        uint256[] memory values = new uint256[](1); // Ether to be sent
        bytes[] memory calldatas = new bytes[](1); // Function signature and parameters
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = abi.encodeWithSelector(box.store.selector, 10);

        string memory PROPOSAL_DESCRIPTION = "test";
        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            PROPOSAL_DESCRIPTION
        );
        // Before voting starts
        uint8 beforeState = uint8(governor.state(proposalId));
        console.log("before voting", beforeState);

        // Voting starts
        vm.roll(block.number + governor.votingDelay() + 1);
        uint8 afterState = uint8(governor.state(proposalId));
        console.log("Voting starts", afterState);

        // Voters vote
        for (uint256 i = 0; i < voters.length; i++) {
            vm.prank(voters[i]);
            governor.castVote(proposalId, 1);
        }

        // Voting ends
        vm.roll(block.number + governor.votingPeriod());
        uint8 afterVote = uint8(governor.state(proposalId));
        console.log("Voting ends", afterVote);

        // Queue execution into timelock contract
        governor.queue(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(PROPOSAL_DESCRIPTION))
        );
        uint8 inQueue = uint8(governor.state(proposalId));
        console.log("inQueue", inQueue);

        // After timelock delay, execute proposal
        vm.warp(block.timestamp + timelock.getMinDelay());
        governor.execute(
            targets,
            values,
            calldatas,
            keccak256(abi.encodePacked(PROPOSAL_DESCRIPTION))
        );
        uint8 afterExecution = uint8(governor.state(proposalId));
        console.log("afterExecution", afterExecution);

        // Check if box value is updated
        uint256 boxValue = box.retrieve();
        console.log("Box value is", boxValue);
    }
}
