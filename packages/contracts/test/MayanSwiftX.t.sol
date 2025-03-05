// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "permit2/Permit2.sol";
import "permit2/interfaces/ISignatureTransfer.sol";
import "src/interfaces/IMayanSwift.sol";
import "src/interfaces/IMayanSwiftX.sol";
import "src/MayanSwiftX.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {Test, console} from "forge-std/Test.sol";

// A forked test that buys eth on arbitrum when eth is at a certain price 233x usdc 
// 

contract MayanSwiftXTest is Test {
    MayanSwiftX public mayanSwiftX;
    Permit2 public permit2;
    uint256 public baseFork;
    address public usdcAddress = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address public wethAddress = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    bytes32 public constant _TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    string constant WITNESS_TYPE_STRING =
        "OrderPayload witness)OrderPayload(uint256 amountIn,int64 minExecutionPrice,int64 maxExecutionPrice,uint256 createdAt,uint64 minExecutionTime,uint64 maxExecutionTime,bytes32 oracleFeedId,address tokenIn,bool isRecurring,uint8 customOrderType,OrderParams orderParams)OrderParams(bytes32 trader,bytes32 tokenOut,uint64 minAmountOut,uint64 gasDrop,uint64 cancelFee,uint64 refundFee,uint64 deadline,bytes32 destAddr,uint16 destChainId,bytes32 referrerAddr,uint8 referrerBps,uint8 auctionMode,bytes32 random)TokenPermissions(address token,uint256 amount)";
    
    bytes32 public constant domainSeperator = 0x3b6f35e4fce979ef8eac3bcdc8c3fc38fe7911bb0c69c8fe72bf1fd1a17e6f07 ;

    bytes32 constant FULL_EXAMPLE_WITNESS_TYPEHASH = keccak256(
        "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,OrderPayload witness)OrderPayload(uint256 amountIn,int64 minExecutionPrice,int64 maxExecutionPrice,uint256 createdAt,uint64 minExecutionTime,uint64 maxExecutionTime,bytes32 oracleFeedId,address tokenIn,bool isRecurring,uint8 customOrderType,OrderParams orderParams)OrderParams(bytes32 trader,bytes32 tokenOut,uint64 minAmountOut,uint64 gasDrop,uint64 cancelFee,uint64 refundFee,uint64 deadline,bytes32 destAddr,uint16 destChainId,bytes32 referrerAddr,uint8 referrerBps,uint8 auctionMode,bytes32 random)TokenPermissions(address token,uint256 amount)"
    );

    function setUp() public {
        permit2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3); 
        baseFork = vm.createFork(vm.envString("BASE_L2_RPC"));
    }

    function getPermitWitnessTransferSignature(
        ISignatureTransfer.PermitTransferFrom memory permit,
        uint256 privateKey,
        bytes32 typehash,
        bytes32 witness, 
        address _mayanSwiftX
    ) internal view returns (bytes memory sig) {
        bytes32 tokenPermissions = keccak256(abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));

        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeperator,
                keccak256(abi.encode(typehash, tokenPermissions, _mayanSwiftX, permit.nonce, permit.deadline, witness))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, msgHash);

        return bytes.concat(r, s, bytes1(v));
    }

    function test_CustomPriceOrder() public {
        vm.selectFork(baseFork);
        mayanSwiftX = new MayanSwiftX(0x000000000022D473030F116dDEE9F6B43aC78BA3, 0xC38e4e6A15593f908255214653d3D947CA1c2338, 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);

        (address alice, uint256 alicePk) = makeAddrAndKey("alice");
        uint256 nonce = 0; 

        vm.startPrank(0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3);
        IERC20(usdcAddress).transfer(alice, 500000 * 10 ** 6);
        vm.stopPrank();

        vm.startPrank(alice);
        IERC20(usdcAddress).approve(address(permit2), type(uint256).max);

        IPyth pyth = IPyth(0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);

        bytes32 priceFeedId = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;

        PythStructs.Price memory price = pyth.getPriceNoOlderThan(priceFeedId, 60);

        IMayanSwiftX.OrderPayload memory orderPayload;
        orderPayload.amountIn = 3000 * 10 ** 6;
        orderPayload.minExecutionPrice = price.price - 10; 
        orderPayload.maxExecutionPrice = price.price + 10;
        orderPayload.createdAt = block.timestamp;
        orderPayload.minExecutionTime = uint64(block.timestamp);
        orderPayload.maxExecutionTime = uint64(block.timestamp + 1000);
        orderPayload.oracleFeedId = 0x9d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6;
        orderPayload.tokenIn = usdcAddress;
        orderPayload.isRecurring = false;
        orderPayload.customOrderType = IMayanSwiftX.CustomOrderType.PriceOrder;

        IMayanSwiftX.TransferPayload memory transferPayload = startBuildingTransferPayload(orderPayload, alice, nonce, WITNESS_TYPE_STRING);
        IMayanSwift.OrderParams memory orderParams = getOrderParams(transferPayload, orderPayload, alice, wethAddress, uint64(12 * 10 ** 18), 0xddb9506b6a963cbbd731eb6d0042c36135128ceecb3d0c264002caadeb4200dd, 2, 23);
      
        orderPayload.orderParams = orderParams;

        bytes32 witnessHash = keccak256(abi.encode(orderPayload));
        transferPayload.witness = witnessHash;

        bytes memory sig = getPermitWitnessTransferSignature(
            transferPayload.permit, 
            alicePk, 
            FULL_EXAMPLE_WITNESS_TYPEHASH, 
            transferPayload.witness, 
            address(mayanSwiftX)
        );

        transferPayload.signature = sig;

        vm.stopPrank();

        (address executor, uint256 executorPk) = makeAddrAndKey("executor");
        vm.startPrank(executor);
        vm.deal(executor, 5 ether);
        bytes[] memory priceUpdates = new bytes[](1);
        priceUpdates[0] = hex'504e41550100000003b801000000040d002fb030eb4fc159b6c33a1d53c75f9bd395c39bea47b2ecb8b02f81021473a0ef0ff66ff944d7c524cd973ad07096f2881b8dd5d27e840f4f8f4155f4f904679c00020974a7e74abd4c85c8baa6821cb4a1db2de36696475b77731ac32d4a547b36d27561ab9b8e51f48f609749f574aecea2850572158e5b294688f22912e3431d9d0003797f54a5f3022c17f0f38af74bd11eb706ecf2650f53ae42d6d4732ad55833ac7b670999a503a408a8c2d5051476847ca0d8e66a1570ad97b90572d63e91288b010686c5f43d5ab424628cd092ae27b65fcd63b9a513daac756524febc338ec7ada02bd148cbbccfb22aded8bedcbc8fe5837854a41c53ea9b825b0570dddfb7cb3801081289efa83225878fa61602e81bb1196267c6d759af27ba498d4d3bb5931aad7e746a6e483efe1ab2eb620ff083fd6cb7cb9a1c9f1b94af9b09c00df34445b276010ae104d83db068bbc3e4d5bb25e12c3f775d85112bab1c1a9acce27dec0438c80d75fec817fb3171f5e89fa007642c5a35e253ea42c1ca154cb4a76cf5c372df22010b77bf8807a4156edfce1c8022ff363ebf3e361ba0c53d53899d7443b6abab4a86347773c2562f581af7238dec1e78290fb67419a00f38dd85f6474ee02f74a85f000c5b36e71c1499a3e983abfa5643d46256869ce37677d5ff87fc3bf330f684fad11563d791c14fec14684f0373388cc76f7a4d574438a3eb20a1f614a61bea151e000d56672c8b54252bdf8c318954f43a54022740f59b8625d6083186e31d43ee971a31b2f6af244fb8a12da6f000790289a11411001a48b28a38f3ed3105f4ccd0b3000ec3a2a0712f5e20c9e1e3773307506c018c99afc72897003bd0a65ddd1c3c14fe660b9092972933b67fececc6d876323fa61179024ca96a75a474f6b0552d9ebb010f978b6cbd86f73e9a0a730c9cf7a08bc9092d216be20b9f890ff7c049b2ab4e560571625ab0de39e98660626c0d119896670ceec7f9e4a7e7b231f4580aba9cf6001010875ec516a46b8bfeb096c8cc624dfc90c31a28dfa4a255b464468789c35f395d05aa493ebda6a27c46d4e444333e8e7d142c9b9080f0870705e34b1d08d21800117d7362d409a9eb778c597bc85feafe06835107d5fa7a1ab24f07b5ebd0b2294768833b935eda0e0bcc8c94a699bb575d63cb493b8a8393ddff1a9e4cd8a51fed0067c89e9200000000001ae101faedac5851e32b9b23b5f9411a8c2bac4aae3ed4dd7b811dd1a72ea4aa710000000006ff0bcf014155575600000000000c0c0fe400002710ccd48638ebdc2ce91227c0cb9c2f1087f599ad6e010055009d4294bbcd1174d6f2003ec365831e64cc31d9f6f15a2b85399db8d5000960f6000000333f82ef37000000002c767cdbfffffff80000000067c89e920000000067c89e9100000033037728e80000000023cff6980c370d16de16cfb817278614e7998b4de5583115f1fbf0350819f367670bd58b19804051e64bb91336dfa65005f4204cfa3cce0f26e547b76368bfa86d0e0122ec791965ce57a38020e07402c9d9fb40c3e206d0023d4424d487c9ce473ff5a6a9671992abb1c3a568f862a7ef4a5d6aa1c260b07cd93a3ed06fe9d0d3f3d4e7eca67c39f75aaeea51419c0c233557ffc258fa35f07e6a233f8e849401791779908f4d3b976aa9ee3c7378e54d80cc9cbdba785c452af03fd445e0930b7972b20e27fb3fc2b6e3a09308724f6e2da3ac097c1b599529e6789e89540f3ba4b9f641b88ef7e0884615bd3365a3782cf092d6';
        mayanSwiftX.execute{ value: 3 }(transferPayload, orderPayload, priceUpdates);
        vm.stopPrank();
    }

    function getOrderParams(IMayanSwiftX.TransferPayload memory transferParams, IMayanSwiftX.OrderPayload memory orderPayload, address owner, address tokenOut, uint64 minAmountOut, bytes32 random, uint8 auctionMode, uint16 destChainId) public returns (IMayanSwift.OrderParams memory orderParams) {
        orderParams.trader = addressToBytes32(owner);
        orderParams.tokenOut = addressToBytes32(tokenOut);
        orderParams.minAmountOut = minAmountOut;
        orderParams.gasDrop = 0;
        orderParams.cancelFee = 0;
        orderParams.refundFee = 0;
        orderParams.deadline = orderPayload.maxExecutionTime;
        orderParams.destAddr = addressToBytes32(owner);
        orderParams.destChainId = destChainId;
        orderParams.referrerAddr = bytes32(0);
        orderParams.referrerBps = 0;
        orderParams.auctionMode = auctionMode;
        orderParams.random = random;
        return orderParams;
    }

    // function test_CustomTimeOrder() public {
    //     mayanSwiftX = new MayanSwiftX(0x000000000022D473030F116dDEE9F6B43aC78BA3, 0xC38e4e6A15593f908255214653d3D947CA1c2338, 0x8250f4aF4B972684F7b336503E2D6dFeDeB1487a);
    //     vm.selectFork(baseFork);

    //     (address alice, uint256 alicePk) = makeAddrAndKey("alice");
    //     uint256 nonce = 0; 

    //     vm.startPrank(0x0B0A5886664376F59C351ba3f598C8A8B4D0A6f3);
    //     IERC20(usdcAddress).transfer(alice, 500000 * 10 ** 6);
    //     vm.stopPrank();

    //     vm.startPrank(alice);
    //     IERC20(usdcAddress).approve(address(permit2), type(uint256).max);

    //     IMayanSwiftX.TransferPayload memory transferPayload = startBuildingTransferPayload(alice, 3000 * 10 ** 6, nonce, usdcAddress, uint64(block.timestamp + 100), uint64(block.timestamp + 1000), WITNESS_TYPE_STRING_TIME_ORDER);

    //     bytes memory sig = getPermitWitnessTransferSignature(
    //         transferPayload.permit, 
    //         alicePk, 
    //         FULL_EXAMPLE_WITNESS_TYPEHASH_TIME_ORDER, 
    //         transferPayload.witness, 
    //         address(mayanSwiftX)
    //     );

    //     transferPayload.signature = sig;

    //     IMayanSwiftX.OrderPayload memory orderPayload =  getOrderParams(transferPayload, 3000 * 10 ** 6, usdcAddress, uint64(12 * 10 ** 18), uint64(block.timestamp + 1000), 0xddb9506b6a963cbbd731eb6d0042c36135128ceecb3d0c264002caadeb4200dd, 2, 23);

    //     vm.stopPrank();

    //     (address executor, uint256 executorPk) = makeAddrAndKey("executor");

    //     vm.startPrank(executor);
    //     mayanSwiftX.execute(transferPayload, orderPayload);
    //     vm.stopPrank();
    // }

    function startBuildingTransferPayload(
        IMayanSwiftX.OrderPayload memory orderPayload,
        address owner,
        uint256 nonce,
        string memory witnessTypeString
    ) public returns (IMayanSwiftX.TransferPayload memory payload) {
        payload.permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: orderPayload.tokenIn, amount: orderPayload.amountIn}),
            nonce: nonce, 
            deadline: orderPayload.maxExecutionTime
        });

        payload.transferDetails = ISignatureTransfer.SignatureTransferDetails(address(mayanSwiftX), orderPayload.amountIn);
        payload.owner = owner;
        payload.witnessTypeString = witnessTypeString;
        payload.signature = "";

        return payload;
    }

    // function startBuildingTransferPayload(
    //     address user,
    //     uint256 amount,
    //     uint256 nonce,
    //     address token,
    //     uint256 minExecutionTime,
    //     uint64 deadline,
    //     string memory witnessTypeString
    // ) public returns (IMayanSwiftX.TransferPayload memory payload) {
    //     IMayanSwiftX.CustumTimeOrder memory witnessData = IMayanSwiftX.CustumTimeOrder(uint64(block.timestamp + 100), false);

    //     bytes32 witnessHash = keccak256(abi.encode(witnessData));

    //     payload.permit = ISignatureTransfer.PermitTransferFrom({
    //         permitted: ISignatureTransfer.TokenPermissions({token: token, amount: amount}),
    //         nonce: nonce, 
    //         deadline: block.timestamp + 100000
    //     });

    //     payload.transferDetails = ISignatureTransfer.SignatureTransferDetails(address(mayanSwiftX), amount);
    //     payload.owner = user;
    //     payload.witness = witnessHash;
    //     payload.witnessTypeString = witnessTypeString;
    //     payload.signature = "";

    //     return payload;
    // }

   

    function addressToBytes32(address addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(addr))); 
    }
}












        