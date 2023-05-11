// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PuzzleBox.sol";
import "../src/PuzzleBoxSolution.sol";

contract PuzzleBoxFixture is Test {
    event Lock(bytes4 selector, bool isLocked);
    event Operate(address operator);
    event Drip(uint256 dripId, uint256 fee);
    event Spread(uint256 amount, uint256 remaining);
    event Zip();
    event Creep();
    event Torch(uint256[] dripIds);
    event Burned(uint256 dripId);
    event Open(address winner);

    PuzzleBoxFactory _factory = new PuzzleBoxFactory();
    PuzzleBox _puzzle;
    PuzzleBoxSolution _solution;

    // Use a modifier instead of setUp() to keep it all in one tx.
    modifier initEnv() {
        _puzzle = _factory.createPuzzleBox{value: 1337}();
        _solution = PuzzleBoxSolution(address(new SolutionContainer(type(PuzzleBoxSolution).runtimeCode)));
        _;
    }

    function test_win() external initEnv {

        vm.deal(address(_solution), 12000);
        // // code to poke and prod around
        address proxy = address(_puzzle);
        address impl = address(_factory.logic());

        // bool init = _puzzle.isInitialized();
        // (bool a, bytes memory b) = impl.call(hex'392e53cd'); // 'isInitialized()' !!false!!
        
        // uint256 balance = proxy.balance;
        // assertTrue(balance > 0);

        // (bool c, bytes memory d) = proxy.call(hex'8da5cb5b'); //(hex'925facb1');
        
        // read proxy's storage layout
        // for (uint i; i < 20; ++i) {
        //     bytes32 proxyStorageVal = vm.load(proxy, bytes32(i));
        // }

        PuzzleBoxProxy(payable(proxy)).isFunctionLocked(hex'925facb1');
        bytes32 proxyMappingStorageVal = vm.load(proxy, keccak256(hex'925facb1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000')); //bytes.concat(abi.encode(hex'925facb1'), abi.encode(0x00'))));

        // // initialize impl to then read impl's storage layout
        // address payable[] memory friends = new address payable[](2);
        // uint256[] memory friendsCutBps = new uint256[](friends.length);
        // friends[0] = payable(0x416e59DaCfDb5D457304115bBFb9089531D873B7);
        // friends[1] = payable(0xC817dD2a5daA8f790677e399170c92AabD044b57);
        // friendsCutBps[0] = 0.015e4;
        // friendsCutBps[1] = 0.0075e4;
        // PuzzleBox(impl).initialize{value: 1337}(
        //     // initialDripFee
        //     100,
        //     friends,
        //     friendsCutBps,
        //     // adminSigNonce
        //     0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8,
        //     // adminSig
        //     (
        //         hex"c8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8"
        //         hex"625cb970c2768fefafc3512a3ad9764560b330dcafe02714654fe48dd069b6df"
        //         hex"1c"
        //     )
        // );
        
        // for (uint i; i < 20; ++i) {
        //     bytes32 implStorageVal = vm.load(impl, bytes32(i));
        // }

        // Uncomment to verify a complete solution.
        // vm.expectEmit(false, false, false, false, address(_puzzle));
        // emit Open(address(0));
        _solution.solve(_puzzle);

        // uint256 balanceAfter = proxy.balance;
        // assertEq(balanceAfter, 0);
    }

    // function test_stuff() external returns (bytes32) {
    //     bytes32 targetSlot = keccak256(hex'925facb1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000');
    //     // provide uint256 key that when concatenated with 0x07 and then is hashed equals targetSlot
    //     uint256 dripId = 42;
    //     // return keccak256(bytes.concat(hex'000000000000000000000000000000000000000000000000000000000000002a', hex'0000000000000000000000000000000000000000000000000000000000000007'));
    //     return targetSlot;
    // }
}

contract SolutionContainer {
    constructor(bytes memory solutionRuntime) {
        assembly {
            return(add(solutionRuntime, 0x20), mload(solutionRuntime))
        }
    }
}
