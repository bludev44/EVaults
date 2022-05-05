// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IStrategy.sol";
import {SafeTransferLib} from "./lib/SafeTransferLib.sol";

import "./lib/ERC4626.sol";

contract EVault is ERC4626{
    using SafeTransferLib for ERC20;

    struct StrategyProposal{
        address implementation;
        uint proposedTime;
    }

    StrategyProposal public proposedStartegy;

    IStrategy public strategy;

    uint256 public immutable approvalDelay;

    event NewStrategy(address implementation);
    event StrategyUpgraded(address implementation);


    constructor(IStrategy _strategy,uint256 _apporovalDelay,string memory _vaultName,string memory _vaultSymbol,address _wantToken) ERC4626(ERC20(_wantToken),_vaultName,_vaultSymbol){
        strategy = _strategy;
        approvalDelay = _apporovalDelay;
    }

    function available() public view returns(uint256){
        return asset.balanceOf(address(this));
    }

    function getPricePerFullShare() public view returns(uint256){
        return totalSupply == 0 ? 1e18 : totalAssets()* 1e18 /totalSupply;
    }

    function totalAssets() public override view returns(uint256){
        return asset.balanceOf(address(this)) + strategy.balanceOf();
    }

    function beforeDeposit() internal override{
        strategy.beforeDeposit();
    }

    function afterDeposit(uint256 assets)internal override{
        earn(assets);
    }

    //function to send funds to strategy and put them to work
    function earn(uint256 assets) public{
        asset.safeTransferFrom(address(this), address(strategy), assets);
        strategy.deposit();
    }

    function beforeWithdraw(uint256 assets)internal override returns(uint256){
        uint256 _init = asset.balanceOf(address(this));
        

        if(asset.balanceOf(address(this)) < assets) {
            uint256 _withdraw = assets - _init;
            strategy.withdraw(_withdraw);
            uint256 _after = asset.balanceOf(address(this));
            uint256 _diff = _after - _init;
            if(_diff < _withdraw){
                assets += _diff;
            }
            return uint256(assets);
        }

        return uint256(assets);
    }

    function proposeStrategy(address _implementation)public onlyOwner{
        require(address(this) == strategy.vault(),"Proposal not valid for this Vault");

        proposedStrategy = StrategyProposal({
            implementation : _implementation,
            proposedTime: block.timestamp
        });

        emit NewStrategy(_implementation);
    }

    function upgradeStrategy()public onlyOwner{
        require(proposedStrategy.implementation != address(0),"No proposed strategy");
        require(proposedStrategy.proposedTime + approvalDelay < block.timestamp,"Waiting time is'nt finished for the proposal");
        
        strategy.retireStrat();
        strategy = IStrategy(proposedStrategy.implementation);
        emit StrategyUpgraded(proposedStrategy.implementation);
        proposedStrategy.implementation = address(0);
        proposedStrategy.proposedTime = 5000000000;

        earn();
    }

    function inCaseTokensGetStuck(address _token)external override{
        ERC20(_token).safeTransfer(msg.sender,ERC20(_token).balanceOf(address(this)));
    }
    
}