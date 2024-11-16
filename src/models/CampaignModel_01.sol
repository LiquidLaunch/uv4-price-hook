// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

contract CampaignModel_01 {

	enum PoolState {NORMAL, CAMPAIGN}

    struct Round {
        uint256 until;
        uint256 tokenPrice;
    }
    
    struct Campaign {
        PoolState poolState;
        address projectFund;
        //uint256 vipPrice;
        //address[] vipWL;
        Round[] rounds;
    }

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------
    mapping(PoolId => Campaign campaign) public campaigns;

    function getCampaignForPool(
        PoolId  _polId
    ) view external returns(Campaign memory camp){
       camp = campaigns[_polId];
    }
    //////////////////////////////////  Campain Hook Logic Functions ///////////////

    function _setCampaignForPool(PoolId  _poolId, Campaign memory _camp) internal {
        campaigns[_poolId] = _camp;

    }

    function _checkPoolState(PoolId  _poolId) internal returns(PoolState state, uint256 roundPrice) {
        Campaign memory _camp = campaigns[_poolId];
        state = _camp.poolState;
        if (state != PoolState.NORMAL) {
            roundPrice = _getRoundPrice(_camp);
            if (roundPrice == 0) {
                // SET state to NORMAL because of zero price(= campaign finished)
                campaigns[_poolId].poolState = PoolState.NORMAL;
                state = PoolState.NORMAL;
            } 
        }        
    }

    function _getRoundPrice(Campaign memory _camp) internal view returns(uint256 rp) {
        if (_camp.rounds.length != 0 ) {
            for (uint256 i = 0; i < _camp.rounds.length; ++ i) {
                // If not last array record
                // TODO optimize
                if (i != _camp.rounds.length - 1) {
                    if(
                        _camp.rounds[i].until >= block.timestamp 
                        && _camp.rounds[i + 1].until < block.timestamp 
                      ) { 
                           rp = _camp.rounds[i].tokenPrice;
                        }
                } else {
                    // if lsat record then need check only it
                    if (_camp.rounds[i].until >= block.timestamp) {
                        rp = _camp.rounds[i].tokenPrice;
                    }
                }
            }
        }
    }

    function _getPoolState(PoolId  _polId) view internal returns(PoolState) {
        return campaigns[_polId].poolState;
    }

	
}