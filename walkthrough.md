# Dragonfly CTF Walkthrough: Puzzlebox.sol

Hello anon, welcome to KweenBirb's walkthrough of Dragonfly's recent CTF, held May 6-8 2023, featuring hackable quirks of Solidity and the EVM at large.

This walkthrough details the process of deciphering and auditing Puzzlebox.sol, a Solidity puzzlebox containing metaversal secrets so powerful they can be leveraged to save the internet from exploitation by bad actors.

#### Spoiler alert: I didn't win any of the prizes offered by Dragonfly to those who completed the CTF quickly and efficiently. The lucky few who did, were awarded Milady Maker NFTs which are currently selling for a floor of 3.8 ETH or just over $7000! Pretty damn awesome prizes, if you ask me. Next time I'll allot more time to the CTF rather than let that pesky 'personal life' stuff get in the way :P

## Getting the lay of the land

First things first! I started with reading the documentation to get an understanding of the smart contract architecture and operation of the Puzzlebox file on a high level.

Dragonfly provides a convenient [Foundry git repo](https://github.com/dragonfly-xyz/puzzlebox-ctf) with a nifty diagram of the contract structure including information about the way that the CTF is scored.

Some first impressions: the CTF is centered around a proxy scheme, something very familiar to smart contract security researchers like me and you, anon. There are 3 contracts of interest: PuzzleBox contract provides the logic implementation, the PuzzleBoxProxy contract serves as proxy that interfaces with PuzzleBox, and the PuzzleBoxFactory provides functions to deploy and initialize state in order to simulate constructor functions which cannot be used in proxy schemes.

The PuzzleBoxSolution contract provides an unimplemented function called ```solve()``` where our CTF solutions should be provided. This function gets called by a shell contract to complete the CTF's many challenges, record how many solutions we come up with, and issue us a score based on correct solutions and their level of gas efficiency.

## Priming the solve() call with important variables

Now that we understand the CTF uses a proxy pattern and that we must provide our solution to the CTF via PuzzleBoxSolution's ```solve()``` function, we can start priming a few important memory variables for use. For more familiar nomenclature, I renamed the PuzzleBox instance ```puzzle``` provided to ```solve()```:

```address proxy = address(puzzle);```

We'll also need to locate the PuzzleBoxFactory and use it to find the implementation address. The factory is created and stored in the PuzzleBox.t.sol test file which is the one used to set the onchain environment and then invoke our PuzzleBoxSolution's ```solve()``` function. To grab it, I just wrote some code to poke and prod around the test contract:

```address impl = address(_factory.logic());```

Now when we run ```forge test -vvvv``` we can see both the PuzzleBoxFactory address and the logic implementation in the stack traces. Returning to PuzzleBoxSolution, I hardcoded the factory address and used its public method to grab the impl.

```
address factory = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
address impl = PuzzleBoxFactory(factory).logic();
```

## First places to look in the codebase

Right off the bat, common proxy pattern vulnerabilities come to mind as a great place to start looking for ways to hack the Puzzlebox. These include privilege escalation via uninitialized logic implementation contract, the famed Exploding Kittens selfdestruct vulnerability, storage collisions between the logic and proxy contracts, and careless implementations of the delegatecall opcode.

##### To avoid adding unnecessary extra gas costs to our solve() function, I included all code for poking and prodding that doesn't actively contribute to hacking the CTF in the test_win() function within PuzzleBox.t.sol. This lets us keep an eye on important variables and answer our questions without detracting from our score!

Let's start by checking for initialization status on the proxy:

```
bool init = _puzzle.isInitialized();
```

OK, 0x01 is returned so nothing's out of place there. Let's check the impl contract:

First, ```$ cast sig 'isInitialized()'``` will give us the bytes4 function selector, 0x392e53cd, that we will need to provide in calldata.

```
(bool a, bytes memory b) = impl.call(hex'392e53cd');
```

0x00! That's some valuable information to keep in mind for later! Uninitialized logic implementations can be vulnerable to privilege escalation or Exploding Kittens, so that may be an avenue to explore.

## Continuing the common proxy vulnerabilities rabbithole

I then continued by observing the storage layout, as proxy contracts can easily give rise to storage collisions without careful attention. Since the impl contract is uninitialized, we should call initialize with the same parameters as the proxy contract so we can compare them as apples to apples:

```
    // initialize impl to then read impl's storage layout
    address payable[] memory friends = new address payable[](2);
    uint256[] memory friendsCutBps = new uint256[](friends.length);
    friends[0] = payable(0x416e59DaCfDb5D457304115bBFb9089531D873B7);
    friends[1] = payable(0xC817dD2a5daA8f790677e399170c92AabD044b57);
    friendsCutBps[0] = 0.015e4;
    friendsCutBps[1] = 0.0075e4;
    PuzzleBox(impl).initialize{value: 1337}(
        // initialDripFee
        100,
        friends,
        friendsCutBps,
        // adminSigNonce
        0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8,
        // adminSig
        (
            hex"c8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8"
            hex"625cb970c2768fefafc3512a3ad9764560b330dcafe02714654fe48dd069b6df"
            hex"1c"
        )
    );
```

In running the code above, two things stand out. 

First, the admin's signature and nonce are accepted without issue as we replay it to the impl contract. This implies that the domain separator used to generate the signature _does not contain the contract address_ as an entropy seed to guard against cross-contract signature replay. Another thing worth keeping in mind as we move forward!

Second, a discerning eye will notice that the nonce provided to the initialize function is identical to the ```bytes32 r``` value of ```adminSig``` Non-incrementing nonces aren't necessarily a vulnerability, but reusing the r value as a nonce could pose some problems in certain scenarios so we'll also keep tabs on that.

## The storage layouts 'diff' approach

Now that we've initialized the impl contract using the exact same calldata as the admin used to init the proxy contract, we can compare the two layouts like a 'diff' to identify any colliding slots and variables.

To do so, I just iterated over the first n slots of both contracts while calling Foundry's awesome vm.load() cheat code and observed the results in the resulting stack traces. I chose ```n == 10``` since the PuzzleBox contract has 10 declared storage items and the PuzzleBoxProxy contract has 2 declared storage items (the ```PuzzleBox private immutable _logic``` is not actually kept in storage since it is immutable). Since mapping indices are kept empty, ~10 iterations should be enough to get a good insight into the storage slot layout.

```
// proxy storage layout
for (uint i; i < 10; ++i) {
    bytes32 implStorageVal = vm.load(address(_puzzle), bytes32(i));
}

// impl storage layout
for (uint i; i < 10; ++i) {
    bytes32 implStorageVal = vm.load(impl, bytes32(i));
}
```

Here's the output:
![StorageLayout](public/StorageLayout.png)


locked functions:
0x925facb1 torch()

unlocked functions:
0x91169731 initialize()
0xb2e327e2 befriend()
0x7159a618 operate()
0x9f678cca drip()
0x2b071e47 spread()
0x00919055 zip()
0x8fd66f25 leak()
0x11551052 creep()
0x262ae75f creepForward()
0x58657dcf open()


admin signature & nonce can be reused to initialize logic impl:
0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8625cb970c2768fefafc3512a3ad9764560b330dcafe02714654fe48dd069b6df1c
nonce: 0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8

1. unlock torch by utilizing operator == owner storage collision in order to call ```lock(torch.selector, false)```
2. to satisfy torch's burnDripId(5) modifier, exploit reentrancy in drip to bypass fee exponentiation and raise lastDripId to 5
3. use torch()'s _burndrip call to reach into other storage slots? (provide encodedDripId that overwrites another value, eg lastdripid and admin)
    - must set isValidDripId[lastDripId] = true
    - use storage collision of friendshipHash <-> lastDripid to set it to true?


-proxy storage layout
slot 0 (packed): bool isInitialized & address admin ( == PuzzleBoxProxy._logic )
slot 1 operator ( == PuzzleBoxProxy.owner )
slot 2 friendshiphash
slot 3 lastdripid
slot 4 dripcount
slot 5 dripfee
slot 6 leakcount

-impl storage layout
same as proxy!? No safety offset implemented in storage layout, which means all of PuzzleBoxProxy contract's storage is vulnerable to collision!!