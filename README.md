# Uniswap V4  hook (price and whitelist)
Developed during ETHGlobal Bangkok Hackathon  
based on https://github.com/uniswapfoundation/v4-template  
Contract implement simple functionality for launch token campaign.  

### Custom Price Curve Research & Example
`CustomPriceHook` - contract with Custom Price Curve. Price Customization is possible through
`PRICE_MULTIPLYER`  constant change. Tested for simple case `PRICE_MULTIPLYER` = 1.  
More complex curves may cause pool imbalances. Will take longer to implement beyond the hackathon.

```shell
$ forge test --match-path ./test/custom-accounting/CustomPriceHook.t.sol -vvvv
```
### Custom White List Hook Example
`WhiteListHook` - contract with Custom WhiteList. Only approved addresses are enabled for swap.

`addWLAddress(address(this), true)`  method can be used for manage whitelist

```shell
$ forge test --match-path ./test/WLHook.t.sol -vvvv
```

---

### Check Forge Installation
*Ensure that you have correctly installed Foundry (Forge) and that it's up to date. You can update Foundry by running:*

```
foundryup
```

## Set up

*requires [foundry](https://book.getfoundry.sh)*

```
forge install
forge test
```

### Local Development (Anvil)

Other than writing unit tests (recommended!), you can only deploy & test hooks on [anvil](https://book.getfoundry.sh/anvil/)

```bash
# start anvil, a local EVM chain
anvil
PRICE_MULTIPLYER
# in a new terminal
forge script script/Anvil.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast
```

See [script/](script/) for hook deployment, pool creation, liquidity provision, and swapping.

---

<details>
<summary><h2>Troubleshooting</h2></summary>



### *Permission Denied*

When installing dependencies with `forge install`, Github may throw a `Permission Denied` error

Typically caused by missing Github SSH keys, and can be resolved by following the steps [here](https://docs.github.com/en/github/authenticating-to-github/connecting-to-github-with-ssh) 

Or [adding the keys to your ssh-agent](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent#adding-your-ssh-key-to-the-ssh-agent), if you have already uploaded SSH keys

### Hook deployment failures

Hook deployment failures are caused by incorrect flags or incorrect salt mining

1. Verify the flags are in agreement:
    * `getHookCalls()` returns the correct flags
    * `flags` provided to `HookMiner.find(...)`
2. Verify salt mining is correct:
    * In **forge test**: the *deployer* for: `new Hook{salt: salt}(...)` and `HookMiner.find(deployer, ...)` are the same. This will be `address(this)`. If using `vm.prank`, the deployer will be the pranking address
    * In **forge script**: the deployer must be the CREATE2 Proxy: `0x4e59b44847b379578588920cA78FbF26c0B4956C`
        * If anvil does not have the CREATE2 deployer, your foundry may be out of date. You can update it with `foundryup`

</details>

---

Additional resources:

[Uniswap v4 docs](https://docs.uniswap.org/contracts/v4/overview)

[v4-periphery](https://github.com/uniswap/v4-periphery) contains advanced hook implementations that serve as a great reference

[v4-core](https://github.com/uniswap/v4-core)

[v4-by-example](https://v4-by-example.org)

