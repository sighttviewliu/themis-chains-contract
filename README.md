# themis-chains-contract
Themis main contracts. Original contract is written in solidity under smartsolidity directory.
smartjava is java code compiled with web3j tools.

### Setup/Ganache-cli Test ###

themis-chains-contract integrates with [Truffle](https://github.com/trufflesuite/truffle), [Ganache-cli](https://github.com/trufflesuite/ganache-cli),

[zeppelin-solidity](https://github.com/OpenZeppelin/zeppelin-solidity),
an Ethereum development environment, Ethereum test tools and Ethereum smart contract library.
Please install Truffle, Ganache-cli and zeppelin-solidity before start
```bash
npm install -g truffle
npm install -g ganache-cli
```

```bash
cd  themis-chains-contract/smartsolidity

npm install  // install dependencies
npm install -E zeppelin-solidity
```

`Note that OpenZeppelin does not currently follow semantic versioning.`
 you can fix import problem by ```npm install``` or 
 [testing-in-es6](http://jamesknelson.com/testing-in-es6-with-mocha-and-babel-6/).  
 
start ganache-cli
```bash
ganache-cli
```   
on another terminal, start test. you can config truffle.js to test on private chains.
```bash
cd themis-chains-contract/smartsolidity

truffle test
```

test result:
```bash
  Contract: Trade test
    ✓ should right create order by owner (51ms)
    ✓ can not create two order with same orderID
    ✓ user id can not be zero when creating order
    ✓ only owner can create order
    ✓ seller/buyer can not be same when confirm an order
    ✓ user id can not be zero when confirm an order
    ✓ another user can confirm order, and should return actual trustees(even) (117ms)
    ✓ creator can upload encrypted shard (431ms)
    ✓ upload secret will be revert when secret's length is not same with trustee's length
    ✓ upload secret will be revert when userID is not buyer/seller
    ✓ trustee should send back the result of verification of shard (343ms)
    ✓ owner can request for arbitration for user (49ms)
    ✓ only judge can judge the order (115ms)
    ✓ trustee can withdraw fee (151ms)

  Contract: Trustee test
    Add/Update/Remove trustee
      ✓ should get nothing when there is no trustees
      ✓ owner should right add trustee (88ms)
      ✓ trustee should right increase deposit (60ms)
      ✓ should right remove trustee and get back deposit (415ms)
    Trustee list
      ✓ should get trustees sort by fame and deposit (515ms)
      ✓ should right update one's fame and his position in list will be changed (124ms)
      ✓ should right increase trustee' deposit and his position will be changed (99ms)
      ✓ should right decrease trustee's deposit and his position will be changed (429ms)


  22 passing (5s)
```


### Java Interface ###

Compiled java contract code is on generated by [web3j cmd tools](https://github.com/web3j/web3j/releases/tag/v3.4.0) and 
will used to communicate with ethereum nodes.

### Disclaim

The code is under rapid development and may change frequently.



