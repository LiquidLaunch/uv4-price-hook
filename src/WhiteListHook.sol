// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {toBeforeSwapDelta, BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {CurrencySettler} from "./utils/CurrencySettler.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";

contract WhiteListHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using SafeCast for uint256;

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
    mapping(address => bool) public whiteList;

    mapping(PoolId => Campaign campaign) public campaigns;

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;



    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true, //  for custom  price curve enable
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata hookParams)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address sender = abi.decode(hookParams, (address));

        require (whiteList[sender], 'WhiteListed Users Only');
        //beforeSwapCount[key.toId()]++;
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        afterSwapCount[key.toId()]++;
        //poolManager.settle();
        return (BaseHook.afterSwap.selector, 0);
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        beforeAddLiquidityCount[key.toId()]++;
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        beforeRemoveLiquidityCount[key.toId()]++;
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    // For Rresearc ONLY!   For  production please use owner pattern
    function addWLAddress(address _whiteListed, bool status) external {
        require (_whiteListed != address(0));
        whiteList[_whiteListed] = status;
    } 


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
