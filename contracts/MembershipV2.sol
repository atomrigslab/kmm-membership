// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
/**
 * @title Kansong Metaverse Museum Membership NFT
 * @author Atomrigs Lab
 **/

//import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

library Base64 {
    bytes internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF)
                )
                out := shl(8, out)
                out := add(
                    out,
                    and(mload(add(tablePtr, and(input, 0x3F))), 0xFF)
                )
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}

contract Membership is ERC721Upgradeable {

    uint256 public maxSupply;
    uint256 public totalSupply;
    uint256 private _tokenId;
    address private _owner;
    bool public isAggregationActive; // NFT count aggregation service activation
    bool public isSoulboundMode; // If true, NFT becomes not transferrable
    string private _baseImgUrl;

    struct Member {
        uint256 tokenId; 
        bool isExpired;     
        uint16 score; // NFT aggregated score
        string imgName; // a, b, c
    }

    mapping(address => bool)  private _operators;
    mapping(uint256 => Member) public members;

    event SetOperator(address operator, bool isActive);

    modifier onlyOperators() {
        require(_checkOperators(), "Membership: Not an operator");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Membership: Not the owner");
        _;
    }

   function initialize() public initializer {
        __ERC721_init("Kansong Metaverse Museum Membership NFT", "KMM-Membership");        
        _owner = msg.sender;
        //_operators[_operator] = true;
        _operators[_owner] = true;
        _baseImgUrl = "https://kmm.mypinata.cloud/ipfs/QmU5XZYSqcuwBkLeMCm2Gfmjyx11oPNEqJEkneQa3J1wwe/";
        maxSupply = 10_000;
        isSoulboundMode = true;
    }

    function _checkOperators() private view returns (bool) {
        if (msg.sender == _owner || _operators[msg.sender]) {
            return true;
        } 
        return false;
    }

    function getOwner() public view returns (address) {
      return _owner;
    }

    function isOperatorActive(address operatorAddr) public view returns (bool) {
      return _operators[operatorAddr];
    }

    function setOperator(address newOperator, bool isActive) external onlyOwner() {
        _operators[newOperator] = isActive;
        emit SetOperator(newOperator, isActive);
    }

    function setSoulboundMode(bool isActive) external onlyOwner() {
        isSoulboundMode = isActive;
    }

    function transferOwner(address newOwner) public onlyOwner {
        _owner = newOwner;
    }

    function updateBaseImgUrl (string memory newUrl) external onlyOperators {
        _baseImgUrl = newUrl;
    }

    function getBaseImgUrl () public onlyOperators() view returns (string memory) {
        return _baseImgUrl;
    }

    function setAggregation (bool isActive) public onlyOperators {
        isAggregationActive = isActive;
    }

    function updateScore (uint256 tokenId, uint16 score) external onlyOperators {
        members[tokenId].score = score;
    }

    function updateIsExpired (uint256 tokenId, bool isExpired) external onlyOperators {
        members[tokenId].isExpired = isExpired; 
    }

    function safeMint(address toAddr, uint256 tokenId) private returns (bool) {
        _safeMint(toAddr, tokenId);
        return true;
    }

    function mint(address toAddr, uint16 score, string calldata imgName) public onlyOperators {

        require(_tokenId < maxSupply, "Membership: minting count over maxSupply");
        if (isSoulboundMode == true) {
            require(balanceOf(toAddr) == 0, "Membership: only one NFT per address allowed");
        }
        _tokenId++;
        Member memory member = Member(_tokenId, false, score, imgName );
        members[_tokenId] = member;

        require(
            safeMint(toAddr, _tokenId),
            "Membership-NFT: minting failed"
        );
        totalSupply++;
    }

    function batchMint(address[] calldata toAddrs, uint16[] calldata scores, string[] calldata imgNames)
        external onlyOperators {
        for (uint256 i = 0; i < toAddrs.length; i++) {
            mint(toAddrs[i], scores[i], imgNames[i]);
        }
    }

    function getDescription() internal pure returns (string memory) {
        string memory desc = "Kansong Metaverse Museum Membership NFTs entitle holders who own NFTs issued by KMM. This membership NFT is more than just a membership card; it symbolizes the pride of being a Treasure Guardian of Traditional Korean Culture, representing a special experience and responsibility. Created by the renown graphic designer Youngha Park, this NFT is rooted in the distinctive logo of the Kansong Metaverse Museum, a work also attributed to Park. With a modern reinterpretation, it captures the essence of the exquisite characters from the Album of Genre Paintings by Hyewon in 18th century Joseon dynasty.";
        return desc;
    }

    function getAttributes(uint256 tokenId) public view returns (string memory) {

        string memory imgName =  members[tokenId].imgName;  
        if (keccak256(abi.encodePacked(imgName)) == keccak256(abi.encodePacked("kmm_membership_a.jpg"))) {
            return string(abi.encodePacked(
                '[',
                unicode'{"trait_type": "creator", "value": "Youngha Park (박영하)"}', ',',
                unicode'{"trait_type": "hommage_korean_title", "value": "쌍검대무"}', ',',
                '{"trait_type": "hommage_english_title", "value": "Double-sword dance by two performers"},',
                '{"trait_type": "hommage_detail_url", "value": "https://kansong.io/img_detail.html?id=10"}',
                ']'
            ));
        } else if (keccak256(abi.encodePacked(imgName)) == keccak256(abi.encodePacked("kmm_membership_b.jpg"))) {
            return string(abi.encodePacked(
                '[',
                unicode'{"trait_type": "creator", "value": "Youngha Park (박영하)"}', ',',
                unicode'{"trait_type": "hommage_korean_title", "value": "계변가화"}', ',',
                '{"trait_type": "hommage_english_title", "value": "Beauties chatting beside a stream"},',
                '{"trait_type": "hommage_detail_url", "value": "https://kansong.io/img_detail.html?id=18"}',
                ']'
            ));
        } else if (keccak256(abi.encodePacked(imgName)) == keccak256(abi.encodePacked("kmm_membership_c.jpg"))) {
            return string(abi.encodePacked(
                '[',
                unicode'{"trait_type": "creator", "value": "Youngha Park (박영하)"}', ',',
                unicode'{"trait_type": "hommage_korean_title_1", "value": "쌍검대무"}', ',',
                '{"trait_type": "hommage_english_title_1", "value": "Double-sword dance by two performers"},',
                unicode'{"trait_type": "hommage_detail_url_1", "value": "https://kansong.io/img_detail.html?id=10"}', ",",
                unicode'{"trait_type": "hommage_korean_title_2", "value": "계변가화"}', ',',
                '{"trait_type": "hommage_english_title_2", "value": "Beauties chatting beside a stream"},',
                '{"trait_type": "hommage_detail_url_2", "value": "https://kansong.io/img_detail.html?id=18"}',
                ']'
            ));
        }
        return '[]';
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        if (_ownerOf(tokenId) == address(0)) {
          return false;
        }
        return true;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Membership: TokenId not minted yet");
        Member memory member = members[tokenId];
        string memory img = string(abi.encodePacked(_baseImgUrl, member.imgName));
        string memory description = getDescription();
        string memory attributes = getAttributes(tokenId);
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "Kansong Metaverse Museum Membership NFT #',
                        toString(tokenId),
                        '", "description": "',
                        description,
                        '", "image": "',
                        img,
                        '", "score": ',
                        toString(member.score),
                        ', "attributes": ',
                        attributes,
                        '}'
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Membership: Only the owner of the token can burn it.");
        _burn(tokenId);
        totalSupply--;
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        if (isSoulboundMode == true) {
            address from = _ownerOf(tokenId);
            require(from == address(0) || to == address(0), "Membership: This a Soulbound token. It cannot be transferred.");
        }
        return super._update(to, tokenId, auth);
    }

    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT license
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}

