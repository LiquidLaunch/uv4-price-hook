// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PriceHook} from "../src/PriceHook.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract PriceHookTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    PriceHook hook;
    PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    struct DebugB {
            uint256 bf0;
            uint256 after0;
            uint256 bf1;
            uint256 after1;
        }

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        deployAndApprovePosm(manager);

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                    | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        deployCodeTo("PriceHook.sol:PriceHook", constructorArgs, flags);
        hook = PriceHook(flags);

        // Create the pool
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1);

        // Provide full-range liquidity to the pool
        tickLower = TickMath.minUsableTick(key.tickSpacing);
        tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        uint128 liquidityAmount = 100e18;

        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        (tokenId,) = posm.mint(
            key,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
    }

    function testPriceBeforeSwapHook() public {
        

        DebugB memory bal;
        bal.bf0 = currency0.balanceOf(address(this));
        bal.bf1 = currency1.balanceOf(address(this));
        // positions were created in setup()
        //assertEq(hook.beforeAddLiquidityCount(poolId), 1);
        //assertEq(hook.beforeRemoveLiquidityCount(poolId), 0);

        //assertEq(hook.beforeSwapCount(poolId), 0);
        //assertEq(hook.afterSwapCount(poolId), 0);

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1e18; // negative number indicates exact input swap!
        //BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, abi.encode(address(this)));
        // ------------------- //

        assertEq(int256(swapDelta.amount0()), amountSpecified);
        bal.after0 = currency0.balanceOf(address(this));
        bal.after1 = currency1.balanceOf(address(this));

        assertEq(bal.bf0 - bal.after0, 1e18);
        //assertEq(bal.after1 - bal.bf1, 1e18 * 4);



        //assertEq(hook.beforeSwapCount(poolId), 0);
        //assertEq(hook.afterSwapCount(poolId), 1);
    }

    // function testLiquidityHooks() public {
    //     // positions were created in setup()
    //     assertEq(hook.beforeAddLiquidityCount(poolId), 1);
    //     assertEq(hook.beforeRemoveLiquidityCount(poolId), 0);

    //     // remove liquidity
    //     uint256 liquidityToRemove = 1e18;
    //     posm.decreaseLiquidity(
    //         tokenId,
    //         liquidityToRemove,
    //         MAX_SLIPPAGE_REMOVE_LIQUIDITY,
    //         MAX_SLIPPAGE_REMOVE_LIQUIDITY,
    //         address(this),
    //         block.timestamp,
    //         ZERO_BYTES
    //     );

    //     assertEq(hook.beforeAddLiquidityCount(poolId), 1);
    //     assertEq(hook.beforeRemoveLiquidityCount(poolId), 1);
    // }
}
