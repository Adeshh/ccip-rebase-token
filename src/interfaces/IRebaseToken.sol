// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRebaseToken {
    function mint(address _to, uint256 _amount, uint256 _intrestRate) external;
    function burn(address _from, uint256 _amount) external;
    function balanceOf(address _user) external view returns (uint256);
    function transfer(address _recipient, uint256 _amount) external returns (bool);
    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool);
    function getUserIntrestRate(address _user) external view returns (uint256);
    function getIntrestRate() external view returns (uint256);
    function grantMintAndBurnRole(address _account) external;
}