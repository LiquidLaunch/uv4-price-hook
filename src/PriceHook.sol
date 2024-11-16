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

contract PriceHook is BaseHook {
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
        // Check Campaign state of exact pool
        BeforeSwapDelta returnDelta;
        (PoolState state, uint256 roundPrice) = _checkPoolState(key.toId());
        if (roundPrice != 0 && state == PoolState.CAMPAIGN) {
            // TODO add check that only exactInput this mode can serve
            // use this price for swap
            
            uint256 specifiedAmount = uint256(-params.amountSpecified);
            uint256 unspecifiedAmount = specifiedAmount * roundPrice;
            returnDelta = toBeforeSwapDelta(specifiedAmount.toInt128(), -unspecifiedAmount.toInt128());
            //return (BaseHook.beforeSwap.selector, returnDelta, 0);
        } else {
            // use normal UniSwap pool Loogic !!!!!!!!!! Uncoment after debug

            // returnDelta =  BeforeSwapDeltaLibrary.ZERO_DELTA;

            uint256 specifiedAmount = uint256(-params.amountSpecified);
            uint256 unspecifiedAmount = specifiedAmount * 4;

            Currency inputCur  = params.zeroForOne ? key.currency0 : key.currency1;
            Currency outputCur = params.zeroForOne ? key.currency1 : key.currency0;
            
            // This pice is from docd https://www.v4-by-example.org/hooks/custom-curve
            // with take transfer asset to hookConract from poolManager    -NOT   WORKS
            //inputCur.take(poolManager, address(this), specifiedAmount, true);
            //outputCur.settle(poolManager, address(this), unspecifiedAmount, true);

            // This pice is from CustomCurveHook  from corev4/test
            // this "custom curve" is a line, 1-1
            // take the full input amount, and give the full output amount
            //poolManager.take(inputCur, address(this), specifiedAmount);
            //outputCur.settle(poolManager, address(this), specifiedAmount, false);

            //inputCur.settle(poolManager, address(this), specifiedAmount, false);
            
            // this decrease errors count CurrencyNotSettled, but still 1
            poolManager.mint(address(this), inputCur.toId(), specifiedAmount);

            //inputCur.settle(poolManager, address(this), specifiedAmount, true);
            //poolManager.mint(sender, outputCur.toId(), unspecifiedAmount);
            //poolManager.mint(address(poolManager), outputCur.toId(), unspecifiedAmount);
            //poolManager.sync(inputCur);
            //poolManager.sync(outputCur);
            //poolManager.settle();
            //poolManager.burn(address(this), outputCur.toId(), unspecifiedAmount);
            
            //outputCur.settle(poolManager, address(poolManager), unspecifiedAmount, true);
            //poolManager.mint(address(this), inputCur.toId(), specifiedAmount);
            
            // This works good
            returnDelta = toBeforeSwapDelta(specifiedAmount.toInt128(), -unspecifiedAmount.toInt128());

            // This pice is from CustomCurveHook  from corev4/test - not  works
           //returnDelta = toBeforeSwapDelta(-specifiedAmount.toInt128(), specifiedAmount.toInt128());
        }
        //beforeSwapCount[key.toId()]++;
        return (BaseHook.beforeSwap.selector, returnDelta, 0);
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
