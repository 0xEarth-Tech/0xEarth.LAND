pragma solidity ^0.5.9;
pragma experimental ABIEncoderV2;

import 'github.com/OpenZeppelin/openzeppelin-solidity/blob/v2.5.0/contracts/token/ERC721/ERC721Full.sol';
import 'github.com/OpenZeppelin/openzeppelin-solidity/blob/v2.5.0/contracts/ownership/Ownable.sol';

contract OwnableDelegateProxy { }

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

contract TradeableERC721Token is ERC721Full, Ownable {
    
    //Website: https://0xEarth.github.io
    //Social: @0xEarth

    //Object for each LAND
    struct LAND {
        uint z;
        uint x;
        uint y;
        bool exist;
        string zxy;
        string metaUrl;
        string imgUrl;
        bool isRentable;
        uint256 rentalRate;
        uint256 rentalTime;
        string message;
        string[] visitorNote;
    }
    
    //Object for a linked NFT
    struct NFT {
        uint256 tokenId;
        uint256 landId;
        address tokenAddress;
        uint256 expirationBlock;
        string imgUrl;
        string metaUrl;
        bool exist;
    }
    
    //Total supply of minted land
    uint256 _totalSupply = 0;
    //max amount of land that can be minted from bulk function
    uint256 _maxBulkMint = 10;
    //Land resolution value (zoom level)
    uint256 _resolutionLevel = 18;
    //Early LAND for lower fee
    uint256 _earlyLANDCap = 1500;
    //Early land fee 0.008
    uint256 _earlyLANDFee = 8000000000000000;
    //Base fee for each LAND 0.013
    uint256 _baseLANDFee = 12500000000000000;
    //default rental amount a LAND owner is paid 0.007
    uint256 _defaultRentalRate = 7000000000000000;
    //default block length of a rental ~6500 blocks per day * 7 days = 45500
    uint256 _defaultRentalBlockLength = 45500;
    //rate of escrow 0xEarth takes for each NFT set during LAND rental 0.0009
    uint256 _0xEarthRentalEscrow = 900000000000000;
    //Visitor msg fee
    uint256 _visitorFee = 2000000000000000;
    
    //URL values for creating land image uri 
    string _urlPrefix = "https://a.tile.openstreetmap.org/";
    string _urlPostfix = ".png";
    //default uri for land 
    string _defaultUri = "https://raw.githubusercontent.com/0xEarth-Tech/0xEarth.LAND/master/meta/default.json";
    
     //default metadata prefix for land 
    string _metaPrefix = "https://raw.githubusercontent.com/0xEarth-Tech/0xEarth.LAND/master/meta/";
    string _metaPostfix = ".json";
    
    //bool flag for controlling open LAND minting
    bool openMintLand = false;

    //bool flags for adjusting open token metadata updates 
    bool canSetCustomUri = true;
    bool canSetCustomImageUri = false;
    bool defaultCanRent = true;
    
    //Event emmissions 
    event LandMint(uint256 _z, uint256 _x, uint256 _y);
    event LandUriUpdate(uint256 _landId, string _uri);
    event LandImageUriUpdate(uint256 _landId, string _uri);
    event LandIsRentableUpdate(uint256 _landId, bool _canRent);
    event LandRentUpdate(uint256 _landId, uint256 _rentRate, uint256 _rentLength);
    event LandFixUpdate(string _uri, string uri);
    event MetaFixUpdate(string _uri, string uri);
    event LandDefaultUriUpdate(string _uri);
    event LandMintDappSale(uint256 _id, uint256 _z, uint256 _x, uint256 _y);
    event LandNftSet(uint256 _tokenId, uint256 _landId, address _tokenAddress, uint256 _expirationBlock, string _imgUrl, string _metaUrl, bool _exist);
    event UpdateLANDMintBool(bool canMintLAND);
    event UpdateDefaultCanRentBool(bool canRent);
    event UpdatedMaxBulkMint(uint256 _amount);
    event UpdatedDefaultRentalRate(uint256 _amount);
    event UpdatedDefaultRentalBlockLength(uint256 _amount);
    event UpdatedBaseLANDFee(uint256 _amount);
    event UpdatedEarlyLANDFee(uint256 _amount);
    event UpdatedEarlyLANDCap(uint256 _amount);
    event CanSetCustomUriUpdate(bool canUpdate);
    event CanSetCustomImageUriUpdate(bool canUpdate);
    event UpdatedProxyAddress(address proxyAddress);
    event UpdatedGatewayAddress(address gatewayAddress);
    event UpdatedTreasuryAddress(address treasuryAddress);
    event VisitorAddedMessage(address visitor, string msg);

    //All Minted land
    mapping (uint256 => LAND) _lands;
    //All Minted land IDs
    uint256[] _landIds;
    //All NFTs linked to a given LAND id
    mapping (uint256 => NFT) _landNfts;
    //for routing proxy purchases (ala opensea)
    address public proxyRegistryAddress;
    //for enabling sending token to off chain gateways (ala layer 2 chains)
    address public gatewayAddress;
    //address to direct land sale revenue 
    address payable treasuryAddress;
    
    constructor(string memory _name, string memory _symbol) ERC721Full(_name, _symbol) public {}

    //Helper function to calculate ETH fee requred for a given # of land
    function getLandFeeEth(uint256 landCount) public view returns(uint256 fee){
        uint256 landPrice;
        if(_totalSupply <= _earlyLANDCap){
           landPrice = _earlyLANDFee;
        }else {
           landPrice = _baseLANDFee;
        }
        fee = landPrice.div(10);
        if(landCount > 1){
            fee = fee.mul(landCount);
        }
    }

    //mints a new token based on ZXY values of the land
    function mintLand(uint256 _z, uint256 _x, uint256 _y) public payable {
        require(openMintLand == true, "Open LAND minting is not currently enabled");
        //validate transaction fees
        uint256 transactionFee = getLandFeeEth(1);
        require(msg.value >= transactionFee, "Insufficient ETH payment sent.");
        string memory _landZXY = generateZXYString(_z, _x, _y);
        internalLandMint(_z, _x, _y, _defaultUri);
    }
    
    //Helper method for owner  (DAO) to mint specific land as needed 
    function externalMintLand(uint256 _z, uint256 _x, uint256 _y) public onlyOwner {
        string memory _landZXY = generateZXYString(_z, _x, _y);
        internalLandMint(_z, _x, _y, _defaultUri);
    }
    
    //Internal function to create new token with associated land  ID + meta 
    function internalLandMint(uint256 _z, uint256 _x, uint256 _y, string memory metaUrl) private {
         //make sure the land resolution level matches
        require(_z == _resolutionLevel, "Land resolution value does not match");
        //Validate tile index
        require(_x >= 0, "Tile index not allowed");
        require(_y >= 0, "Tile index not allowed");

        //Generate the landZXY string based on passed in values
        string memory _landZXY = generateZXYString(_z, _x, _y);

        //Generated the landId based on the full format string of the Land
        uint256 _landId = generateLandId(_z, _x, _y);

        //Require this to be a unique land value
        require(landIdsContains(_landId) == false);
        string[] memory newArray;
        LAND memory land = LAND(_z, _x, _y, true, _landZXY, metaUrl, 
        generateImageURI(_landZXY), defaultCanRent, _defaultRentalRate, _defaultRentalBlockLength, "", newArray);
        _lands[_landId] = land;

        //Increment _totalSupply
        _totalSupply++;

        addLandId(_landId);
        treasuryAddress.transfer(msg.value);
        //Mint and send Land to sender
        _safeMint(msg.sender, _landId);
        emit LandMint(_z, _x, _y);
    }
    
     function addLandId(uint256 landId) private {
        _landIds.push(landId);
    }

    //Generates the land format value ex. "19/10000/19999"
    function generateZXYString(uint256 _z, uint256 _x, uint256 _y) public view returns(string memory){
        return string(abi.encodePacked(uint2str(_z), "/", uint2str(_x), "/", uint2str(_y)));
    }

    //TODO this is just an idea, would require an oracle to listen for mints and generate the meta to match
    //Returns the metadata url for a given landId
    function generateLandURI(string memory _landZXY) public view returns (string memory) {
        return string(abi.encodePacked(_metaPrefix, _landZXY, _metaPostfix));
    }
    
    //Returns the image url for a given landId
    function generateImageURI(string memory _landZXY) public view returns (string memory) {
        return string(abi.encodePacked(_urlPrefix, _landZXY, _urlPostfix));
    }
    
    function regenerateImageURI(uint256 _landId) public  {
        require(landIdsContains(_landId) == true);
        _lands[_landId].imgUrl = generateImageURI(_lands[_landId].zxy);
    }

    //Generated the landId based on the land ZXY format value
    function generateLandId(uint256 _z, uint256 _x, uint256 _y) public view returns (uint) {
        string memory ids = string(abi.encodePacked(uint2str(_z), uint2str(_x), uint2str(_y)));
        return parseInt(ids);
    }

    //check if a given landId has been minted yet
    function landIdsContains(uint256 _landId) public view returns (bool){
        return _lands[_landId].exist;
    }

    //Helper method to input a ZXY value to see if LAND exist
    function landIdsContainsZXY(uint256 _z, uint256 _x, uint256 _y) public view returns (bool){
        return _lands[generateLandId(_z, _x, _y)].exist;
    }

    //Returns the metadata uri for the token
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        return _lands[_tokenId].metaUrl;
    } 

    //Returns the image url for a given landId
    function landImageURI(uint256 _landId) external view returns (string memory) {
        return _lands[_landId].imgUrl;
    }
    
    //Return meta for LandId
    function landMeta(uint256 _landId) external view returns( 
    string memory, string memory, string memory, bool, uint256, uint256, string memory, string memory, bool, string[] memory){
        LAND memory land = _lands[_landId];
        return (land.zxy, land.metaUrl, land.imgUrl, 
        land.isRentable, land.rentalRate, land.rentalTime, land.message, land.message, land.isRentable, land.visitorNote);
    }
    
   //Return meta for NFT of LAND
    function landNftMeta(uint256 _landId) external view returns( 
    uint256, uint256, address, uint256, string memory, string memory){
        NFT memory nft = _landNfts[_landId];
        return (nft.tokenId, nft.landId, nft.tokenAddress, 
        nft.expirationBlock, nft.imgUrl, nft.metaUrl);
    }

    //Returns the if the LAND is rentable
    function landIsRentable(uint256 _landId) external view returns (bool) {
        return _lands[_landId].isRentable;
    }
    
    //returns count of land that exist
    function getLandCount() public view returns (uint256){
        return _landIds.length;
    }
    
    //return all known LAND
    function getAllLandIds() public view returns (uint256[] memory) {
        return _landIds;
    }

    //Returns the landZXY string from landId ex. "19/10000/9999"
    function landZXY(uint256 _landId) external view returns (string memory) {
        return _lands[_landId].zxy;
    }
    
    //check if an NFT has been added for a given LAND
    function nftListContains(uint256 _landId) public view returns (bool){
        return _landNfts[_landId].exist;
    }

    //Allow owner of LAND to control rentability
    function updateLandIsRentable(uint256 _landId, bool _canRent) public {
        address landOwner = ownerOf(_landId);
         if(msg.sender == landOwner){
            _lands[_landId].isRentable = _canRent;
            emit LandIsRentableUpdate(_landId, _canRent);
        }
    }
    
    //Allow owner of LAND to adjust rent cost and time
    function updateLandRent(uint256 _landId, uint256 _rentAmount, uint256 _rentBlockLength) public {
        address landOwner = ownerOf(_landId);
         if(msg.sender == landOwner){
            _lands[_landId].rentalRate = _rentAmount;
            _lands[_landId].rentalTime = _rentBlockLength;
            emit LandRentUpdate(_landId, _rentAmount, _rentBlockLength);
        }
    }
    
    //Allow owner of LAND to change the message
    function updateLandMessage(uint256 _landId, string memory _message) public {
        address landOwner = ownerOf(_landId);
         if(msg.sender == landOwner){
            _lands[_landId].message = _message;
        }
    }
    
    function addVisitorNote(uint256 _landId, string memory _message) public payable {
        require(msg.value >= _visitorFee, "Insufficient ETH payment sent.");
        address landOwner = ownerOf(_landId);
         address(uint160(landOwner)).transfer(msg.value);
        _lands[_landId].visitorNote.push(_message);
        emit VisitorAddedMessage(msg.sender, _message);
    }

    //For updating the meta data of a given land. 
    function updateLandUri(uint256 _landId) public {
        require(landIdsContains(_landId) == true);
        address landOwner = ownerOf(_landId);
        bool canUpdate = false;
        if(msg.sender == owner()){
            canUpdate = true;
        }
         if(canSetCustomUri){
            if(msg.sender == landOwner){
                canUpdate = true;
            }
         }
        
        if(canUpdate){
            string memory newUri = generateLandURI(_lands[_landId].zxy);
            _lands[_landId].metaUrl = newUri;
           emit LandUriUpdate(_landId, newUri);
        }
    }

    //For updating the image uri of a given land. 
    function updateLandImageUri(uint256 _landId, string memory _uri) public {
        bool canUpdate = false;
        address landOwner = ownerOf(_landId);
         if(msg.sender == owner()){
            canUpdate = true;
        }
         if(canSetCustomImageUri){
            if(msg.sender == landOwner){
                canUpdate = true;
            }
         }
        
        if(canUpdate){
            _lands[_landId].imgUrl = _uri;
           emit LandImageUriUpdate(_landId, _uri);
        }
    }
    
    //Allow setting a NFT to a given LAND
    function setLandNFT(uint256 _landId, uint256 _tokenId, address _tokenAddress, 
        string memory _imgUrl, string memory _metaUrl) public payable returns (bool success){
        require(landIdsContains(_landId) == true, "LAND with this ID does not exist");
        //Check if NFT is already set, and that the prior rent paid has expired
        bool canSetNft = true;
        if (nftListContains(_landId) == true){
            if (_landNfts[_landId].expirationBlock <= block.number){
                canSetNft = false;
            }
        }
        if(canSetNft){
            address landOwner = ownerOf(_landId);
            if(msg.sender == landOwner){
                uint256 blockToExpire = block.number + _lands[_landId].rentalTime;
                //Owner of given LAND does not need to pay their own rent
                putLandNft(_landId, _tokenId, _tokenAddress, blockToExpire, _imgUrl, _metaUrl);
                 return true;
            }else{
                //Must pay rent to owner
                require(msg.value >= _lands[_landId].rentalRate, "Insufficient ETH payment sent.");
                uint256 contractFee = 0;
                uint256 landOwnerRent = 0;
                if (_lands[_landId].rentalRate > _0xEarthRentalEscrow){
                    landOwnerRent = _lands[_landId].rentalRate - _0xEarthRentalEscrow;
                    contractFee = _0xEarthRentalEscrow;
                }else{
                    landOwnerRent = _lands[_landId].rentalRate;
                }
                if(landOwnerRent > 0){
                    address(uint160(landOwner)).transfer(landOwnerRent);
                }
                if(contractFee > 0){
                    treasuryAddress.transfer(contractFee);
                }
                uint256 blockToExpire = block.number + _lands[_landId].rentalTime;
                putLandNft(_landId, _tokenId, _tokenAddress,  blockToExpire, _imgUrl, _metaUrl);
                return true;
            }
        }else{
            //return false since we cannot update at this time;
             return false;
        }
    }

    function putLandNft(uint256 _landId, uint256 _tokenId, address _tokenAddress, 
        uint256 _expirationBlock, string memory _imgUrl, string memory _metaUrl) internal {
        NFT memory nft = NFT(_tokenId, _landId, _tokenAddress, _expirationBlock, _imgUrl, _metaUrl, true);
        _landNfts[_landId] = nft;
        emit LandNftSet(_tokenId, _landId, _tokenAddress, _expirationBlock, _imgUrl, _metaUrl, true);
    }
    
    //To update the LAND minting bool
    function updateLANDMintBool(bool _canMint) public onlyOwner{
        openMintLand = _canMint;
        emit UpdateLANDMintBool(_canMint);
    }

    //To update the default rentable bool
    function updatedefaultCanRentBool(bool _canRent) public onlyOwner{
        defaultCanRent = _canRent;
        emit UpdateDefaultCanRentBool(_canRent);
    }

    //To update if setting custom uri is opened
    function updateCanSetCustomUri(bool _canCustomize) public onlyOwner{
        canSetCustomUri = _canCustomize;
        emit CanSetCustomUriUpdate(_canCustomize);
    }
    
     //To update if setting custom uri is opened
    function updateCanSetCustomImageUri(bool _canCustomize) public onlyOwner{
        canSetCustomImageUri = _canCustomize;
        emit CanSetCustomImageUriUpdate(_canCustomize);
    }

    //To update the uri prefix for the land image uri
    function updateUriPrefix(string memory _prefix, string memory _postfix) public onlyOwner{
        _urlPrefix = _prefix;
        _urlPostfix = _postfix;
        emit LandFixUpdate(_prefix, _postfix);
    }
    
    //To update the uri prefix for the land image uri
    function updateMetaFix(string memory _prefix, string memory _postfix) public onlyOwner{
        _metaPrefix = _prefix;
        _metaPostfix = _postfix;
        emit MetaFixUpdate(_prefix, _postfix);
    }

    //To update the default land uri
    function updateDefaultUri(string memory _uri) public onlyOwner{
        _defaultUri = _uri;
        emit LandDefaultUriUpdate(_uri);
    }

    //To update the base LAND fee
    function updateBaseLANDFee(uint256 _amount) public onlyOwner{
        _baseLANDFee = _amount;
        emit UpdatedBaseLANDFee(_amount);
    }
    
    //To update the early LAND fee
    function updateEarlyLANDFee(uint256 _amount) public onlyOwner{
        _earlyLANDFee = _amount;
        emit UpdatedEarlyLANDFee(_amount);
    }
    
    //To update the early LAND Cap
    function updateEarlyLANDCap(uint256 _amount) public onlyOwner{
        _earlyLANDCap = _amount;
        emit UpdatedEarlyLANDCap(_amount);
    }
    
    //To update the max bulk minting amount
    function updateMaxBulkMint(uint256 _amount) public onlyOwner{
        _maxBulkMint = _amount;
        emit UpdatedMaxBulkMint(_amount);
    }
    
    //To update the default rent rate to use LAND 
    function updateDefaultRentalRate(uint256 _amount) public onlyOwner{
        _defaultRentalRate = _amount;
        emit UpdatedDefaultRentalRate(_amount);
    }
    
    //To update the default rental block length to use LAND 
    function updateDefaultRentalBlockLength(uint256 _amount) public onlyOwner{
        _defaultRentalBlockLength = _amount;
        emit UpdatedDefaultRentalBlockLength(_amount);
    }
    
     //Update proxya address, mainly used for OpenSea
    function updateProxyAddress(address _proxy) public onlyOwner {
        proxyRegistryAddress = _proxy;
        emit UpdatedProxyAddress(_proxy);
    }
    
    //Update gateway address, for possible sidechain use
    function updateGatewayAddress(address _gateway) public onlyOwner {
        gatewayAddress = _gateway;
        emit UpdatedGatewayAddress(_gateway);
    }

    //Update treasury address, to change where payments are sent
    function updateTreasuryAddress(address payable _treasury) public onlyOwner {
        treasuryAddress = _treasury;
        emit UpdatedTreasuryAddress(_treasury);
    }

    function removeNftFromLand(uint landId) public {
        require(nftListContains(landId) == true, "Given LAND does not have a NFT");
        //Contract owner can always remove
         if(msg.sender == owner()){
            delete _landNfts[landId];
        }else{
            address landOwner = ownerOf(landId);
            //LAND owner can remove if rent has expired
            if(msg.sender == landOwner){
                if (_landNfts[landId].expirationBlock >= block.number){
                    delete _landNfts[landId];
                }
            }
        }
    }
    
    function depositToGateway(uint tokenId) public {
        safeTransferFrom(msg.sender, gatewayAddress, tokenId);
    }
    
    function getBalanceThis() view public returns(uint){
        return address(this).balance;
    }

    function withdraw() public onlyOwner returns(bool) {
        treasuryAddress.transfer(address(this).balance);
        return true;
    }
    
    /**
   * Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
   */
  function isApprovedForAll(
    address owner,
    address operator
  )
    public
    view
    returns (bool)
  {
    // Whitelist OpenSea proxy contract for easy trading.
    ProxyRegistry proxyRegistry = ProxyRegistry(proxyRegistryAddress);
    if (address(proxyRegistry.proxies(owner)) == operator) {
        return true;
    }

    return super.isApprovedForAll(owner, operator);
  }
  
  //Helpr function for making an from a string (mainly used in generating land IDs / token IDs)
  function parseInt(string memory _value)
        public
        pure
        returns (uint _ret) {
        bytes memory _bytesValue = bytes(_value);
        uint j = 1;
        for(uint i = _bytesValue.length-1; i >= 0 && i < _bytesValue.length; i--) {
            assert(uint8(_bytesValue[i]) >= 48 && uint8(_bytesValue[i]) <= 57);
            _ret += (uint8(_bytesValue[i]) - 48)*j;
            j*=10;
        }
    }
    
    //Helper function to conver int to string (mainly used in generating land Ids / token IDs)
    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

}

/**
 * @title 0xEarthLand
 * 0xEarthLand - a contract for digital land ownership of Earth on Ethereum
 */
contract Land is TradeableERC721Token {
  constructor() TradeableERC721Token("0xEarth", "LAND") public {  }
}
