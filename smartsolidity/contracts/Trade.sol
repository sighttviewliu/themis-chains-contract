pragma solidity ^0.4.18;

import "./Ownable.sol";
import "./librarys/strings.sol";
import "./FeeManager.sol";
import "./Vss.sol";

contract Trade is Ownable {

    using strings for *;

    string constant SEPARATE = ",";

    FeeManager feeManager;
    Vss vss;

    struct TradeOrder {

        // Address of seller/buyer
        // User type => user address
        mapping(uint256 => address) user;

        // Hoster whose public key used to encrypt buyer/seller's shard
        // Hoster type => hoster ids
        mapping(uint256 => address[]) hosters;

        // Hosted buyer/seller's encrypted shard
        // Hoster's id(address) => user type => info
        mapping(address => mapping(uint256 => EncryptedShard)) hosterShard;

        // Decrypted shard
        mapping(uint256 => mapping(address => EncryptedShard)) decryptedShard;

        // Record how many shard of buyer/seller have been uploaded
        // User type => len
        mapping(uint256 => uint256) decryptedShardLen;

        // Info of judge
        JudgeInfo judgeInfo;
    }

    uint256 constant BUYER = 1;
    uint256 constant SELLER = 2;

    struct EncryptedShard {
        // Encrypted shard string
        string shard;
    }

    struct JudgeInfo {
        // Private key recovered only when conflict occurs
        string recoverPrivKey;

        // state of this order
        // can indicate who(user/seller) wins when conflict occurs
        uint256 state;
    }

    mapping(uint256 => TradeOrder) order;

    event CreateOrder(uint256 orderID, address indexed buyer, address indexed seller);

    event UploadEncryptedShard(uint256 orderID, address indexed who, uint256 userType, string shards);

    event RecoverPrivKey(uint256 orderID, uint256 userType, string privKey);

    event UploadDecryptedShards(uint256 orderID, address indexed hoster, uint256 userType, string decryptedShard);

    // Function can be call by seller or buyer
    modifier BuyerOrSeller(uint256 orderID, uint256 userType) {
        require(userType == BUYER || userType == SELLER);
        require(msg.sender == order[orderID].user[userType]);
        _;
    }


    // Function can only be called by buyer
    modifier OnlyBuyer(uint256 orderID) {
        require(msg.sender == order[orderID].user[BUYER]);
        _;
    }


    // Function can only be called by seller
    modifier OnlySeller(uint256 orderID) {
        require(msg.sender == order[orderID].user[SELLER]);
        _;
    }


    // Function can only be called by hoster
    modifier OnlyHoster(uint256 orderID, uint256 userType) {
        require(userType == BUYER || userType == SELLER);
        bool isHoster = false;
        for (uint256 i = 0; i < order[orderID].hosters[userType].length; i++) {
            if (order[orderID].hosters[userType][i] == msg.sender) {
                isHoster = true;
                break;
            }
        }

        require(isHoster == true);
        _;
    }


    // Init with feeManager and vss
    function Trade(address _feeManager, address _vss) public {
        require(_feeManager != address(0));
        require(_vss != address(0));

        feeManager = FeeManager(_feeManager);
        vss = Vss(_vss);
    }


    // This should be called when buyer/seller generate a new trade order(tmp?)
    // TODO workflow may be changed to this situation ?:
    // TODO 1. buyer create/upload a new order
    // TODO 2. seller confirm info on chain
    function CreateNewTradeOrder(uint256 orderID, address buyer, address seller) public onlyOwner returns(bool){
        // Ensure orderID haven't been used before
        require(order[orderID].user[BUYER] == address(0));
        require(order[orderID].user[SELLER] == address(0));
        require(buyer != address(0));
        require(seller != address(0));

        order[orderID].user[BUYER] = buyer;
        order[orderID].user[SELLER] = seller;
        CreateOrder(orderID, buyer, seller);
        return true;
    }



    // Buyer/Seller upload encrypted Buyer/Seller's shard
    // Buyer/Seller should know Buyer/Seller's shard is encrypted by whose public key
    // Should only be called by Buyer/Seller
    // Buyer upload seller's shard
    // Seller upload buyer's shard
    // userType indicate msg send from buyer or seller
    function UploadBuyerOrSellerShard(uint256 orderID, uint256 userType, string _shard, address[] _hosterID) BuyerOrSeller(orderID, userType) public returns(bool) {
        // No need to check order again for it has been check by BuyerOrSeller

        uint256 storageType;
        if (userType == BUYER) {
            storageType = SELLER;
        }
        if (userType == SELLER) {
            storageType = BUYER;
        }

        var delim = SEPARATE.toSlice();
        var s = _shard.toSlice();
        var shardArrayLength = s.count(delim) + 1;
        // _shard like "encryptedShard,encryptedShard,......", and it's length should be same with _hosterID
        require(shardArrayLength == _hosterID.length);

        // Will cover value before if this is not the first time
        order[orderID].hosters[storageType] = _hosterID;
        for (uint256 i = 0; i < shardArrayLength; i++) {
            var tmpShard = s.split(delim).toString();

            order[orderID].hosterShard[_hosterID[i]][storageType].shard = tmpShard;
        }

        UploadEncryptedShard(orderID, msg.sender, storageType, _shard);

        // Pay judge fee
        assert(feeManager.PayFee(orderID, feeManager.GetJudgeService(), msg.sender, _hosterID));
        return true;
    }


    // Hoster/any other's can get encrypted shard
    // userType indicate buyer/seller's shard stored on chain
    function GetShardByHosterID(uint256 orderID, address _hosterID, uint256 userType) public view returns(string) {
        // Simple Check
        require(userType == BUYER || userType == SELLER);

        return order[orderID].hosterShard[_hosterID][userType].shard;
    }


    // Get buyer/seller's id(address) with orderID
    function GetBuyerOrSeller(uint256 orderID, uint256 userType) public view returns(address) {
        require(userType == BUYER || userType == SELLER);

        return order[orderID].user[userType];
    }


    // Get buyer/seller's hoster's id
    function GetHosters(uint256 orderID, uint256 userType) public view returns(address[]) {
        require(userType == BUYER || userType == SELLER);

        return order[orderID].hosters[userType];
    }


    // Get shard decrypted by hoster
    function GetDecryptedShard(uint256 orderID, uint256 userType, address hoster) BuyerOrSeller(orderID, userType) public view returns(string) {
        require(userType == BUYER || userType == SELLER);

        return order[orderID].decryptedShard[userType][hoster].shard;
    }


    // Hoster upload decrypted shard which indicate that he judged buyer/seller has win the conflict
    // The shard will be used to recover buyer's private key which is used only in this order
    // Upload buyer shard means Seller has win the conflict
    // userType means whose' shard you upload
    function UploadDecryptedShard(uint256 orderID, uint256 userType, string decryptedShard) OnlyHoster(orderID, userType) public returns(bool) {

        // Ensure only one can win
        // TODO may reject all uploads after private key can be recovered
        if(order[orderID].judgeInfo.state != 0) {
            if (userType == BUYER) {
                require(order[orderID].judgeInfo.state == SELLER);
            }

            if (userType == SELLER) {
                require(order[orderID].judgeInfo.state == BUYER);
            }
        }

        // Hoster can only upload one of user or seller's shard indicate only one win conflict
        if (userType == BUYER) {
            require(order[orderID].decryptedShard[SELLER][msg.sender].shard.toSlice().empty());
        } else if (userType == SELLER) {
            require(order[orderID].decryptedShard[BUYER][msg.sender].shard.toSlice().empty());
        }

        // Check this share is right or not
        require(vss.verifyShare(decryptedShard));

        // Indicate first upload
        if (order[orderID].decryptedShard[userType][msg.sender].shard.toSlice().empty()) {
            order[orderID].decryptedShardLen[userType] = order[orderID].decryptedShardLen[userType] + 1;
        }
        order[orderID].decryptedShard[userType][msg.sender].shard = decryptedShard;

        // Cover private key when shards length is bigger than N
        // TODO wait for vss completed to change
        if (order[orderID].decryptedShardLen[userType] >= vss.GetN()) {
            // This mean who wins
            if (userType == BUYER) {
                order[orderID].judgeInfo.state = SELLER;
            }

            if (userType == SELLER) {
                order[orderID].judgeInfo.state = BUYER;
            }
        }

        UploadDecryptedShards(orderID, msg.sender, userType, decryptedShard);
        return true;
    }
}
