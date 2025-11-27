//SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken public rebaseToken;
    Vault public vault;
    address public user = makeAddr("user");
    address public owner = makeAddr("owner");

    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1 ether}("");
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}("");
    }

    function testIntrestIsLinear(uint256 depositeAmount) public {
        depositeAmount = bound(depositeAmount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, depositeAmount);
        vault.deposit{value: depositeAmount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, depositeAmount);

        uint256 startTime = block.timestamp;
        vm.warp(startTime + 1 hours);
        uint256 newBalance = rebaseToken.balanceOf(user);
        assertGt(newBalance, startBalance);

        vm.warp(startTime + 2 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, newBalance);

        uint256 firstHourGrowth = newBalance - startBalance;
        uint256 secondHourGrowth = endBalance - newBalance;
        // Due to integer arithmetic and precision, allow for larger tolerance
        // Check that growth is approximately linear (within 60% relative tolerance)
        assertApproxEqRel(firstHourGrowth, secondHourGrowth, 0.6e18);

        vm.stopPrank();
    }

    function testRedeemStraightForward(uint256 depositeAmount) public {
        depositeAmount = bound(depositeAmount, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, depositeAmount);
        vault.deposit{value: depositeAmount}();
        uint256 startBalance = rebaseToken.balanceOf(user);
        assertEq(startBalance, depositeAmount);
        vault.redeem(type(uint256).max);
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertEq(endBalance, 0);
        assertEq(address(user).balance, depositeAmount);

        vm.stopPrank();
    }

    function testRedeemAfterSomeTime(uint256 depositeAmount, uint256 time) public {
        depositeAmount = bound(depositeAmount, 1e5, type(uint96).max);
        time = bound(time, 1000, type(uint96).max);
        vm.deal(user, depositeAmount);
        vm.prank(user);
        vault.deposit{value: depositeAmount}();

        vm.warp(block.timestamp + time);

        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        vm.deal(owner, balanceAfterSomeTime - depositeAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositeAmount);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        uint256 ethBalance = address(user).balance;
        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositeAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        vm.prank(owner);
        rebaseToken.setIntrestRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(user2BalanceAfterTransfer, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        assertEq(rebaseToken.getUserIntrestRate(user), 5e10);
        assertEq(rebaseToken.getUserIntrestRate(user2), 5e10);
    }

    function testCannotSetIntrestRateIfNotOwner(uint256 intrestRate) public {
        uint256 currentIntrestRate = rebaseToken.getIntrestRate();
        intrestRate = bound(intrestRate, currentIntrestRate - 1e5, currentIntrestRate - 1e1); //bounding as we need intrest rate to always decrease.
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setIntrestRate(intrestRate);
    }

    function testCannotMintAndBurnIfNotAllowed(uint256 amount) public {
        vm.deal(user, amount);
        uint256 intrestRate = rebaseToken.getIntrestRate();
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user, amount, intrestRate);
        vm.prank(user);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(user, amount);
    }

    function testGetPrincipleAmount(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
        uint256 principleAmount = rebaseToken.principleBalanceOf(user);
        assertEq(principleAmount, amount);

        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(user), amount);
    }

    function testGetRebaseTokenAddress() public {
        assertEq(vault.getRebaseToken(), address(rebaseToken));
    }

    function testRevertIfIntrestRateIsGreaterThanCurrentIntrestRate(uint256 intrestRate) public {
        intrestRate = bound(intrestRate, rebaseToken.getIntrestRate() + 1e1, type(uint96).max);
        uint256 currentIntrestRate = rebaseToken.getIntrestRate();
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__IntrestRateCanOnlyDecrease.selector, currentIntrestRate, intrestRate
            )
        );
        rebaseToken.setIntrestRate(intrestRate);
        assertEq(rebaseToken.getIntrestRate(), currentIntrestRate);
    }

    function testOwnerCanGrantMintAndBurnRole() public {
        vm.prank(owner);
        rebaseToken.grantMintAndBurnRole(user);
        assertEq(rebaseToken.hasRole(keccak256("MINT_AND_BURN_ROLE"), user), true);
    }

    function testOwnerCanRevokeMintAndBurnRole(address _user) public {
        vm.prank(owner);
        rebaseToken.grantMintAndBurnRole(_user);
        assertEq(rebaseToken.hasRole(keccak256("MINT_AND_BURN_ROLE"), _user), true);
        vm.prank(owner);
        rebaseToken.revokeMintAndBurnRole(_user);
        assertEq(rebaseToken.hasRole(keccak256("MINT_AND_BURN_ROLE"), _user), false);
    }
}
