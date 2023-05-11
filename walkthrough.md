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

1. unlock torch
2. use torch()'s _burndrip call to reach into other storage slots? (provide encodedDripId that overwrites another value, eg lastdripid and admin)

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