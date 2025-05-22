// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";

interface IERC6551Account {
    receive() external payable;
    function token() external view returns (uint256 chainId, address tokenContract, uint256 tokenId);
    function state() external view returns (uint256);
    function isValidSigner(address signer, bytes calldata context) external view returns (bytes4 magicValue);
}

interface IERC6551Executable {
    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external payable returns (bytes memory);
}

contract ERC6551Account is IERC165, IERC1271, IERC6551Account, IERC6551Executable {
    uint256 public state;
    
    /// @notice Mapping to store addresses permitted to act on behalf of the account
    mapping(address => bool) public isPermitted;

    receive() external payable {}

    function execute(address to, uint256 value, bytes calldata data, uint8 operation)
        external payable virtual returns (bytes memory result) {
        require(_isValidSigner(msg.sender), "Invalid signer");
        require(operation == 0, "Only call operations are supported");

        ++state;

        bool success;
        (success, result) = to.call{value: value}(data);

        if (!success) {
            assembly {
                revert(add(result, 32), mload(result))
            }
        }
    }

 /// @notice Allows the NFT owner to grant or revoke permission for another address
    function setPermission(address user, bool permitted) external {
        require(msg.sender == owner(), "Only owner can set permissions");
        require(user != msg.sender, "Cannot set permission for yourself");
        isPermitted[user] = permitted;
    }

    function isValidSigner(address signer, bytes calldata) external view virtual returns (bytes4) {
        return _isValidSigner(signer) ? IERC6551Account.isValidSigner.selector : bytes4(0);
    }

    function isValidSignature(bytes32 hash, bytes memory signature)
        external view virtual returns (bytes4 magicValue) {
        return SignatureChecker.isValidSignatureNow(owner(), hash, signature) 
            ? IERC1271.isValidSignature.selector 
            : bytes4(0);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC6551Account).interfaceId
            || interfaceId == type(IERC6551Executable).interfaceId;
    }

    function token() public view virtual returns (uint256, address, uint256) {
        bytes memory footer = new bytes(0x60);

        assembly {
            extcodecopy(address(), add(footer, 0x20), 0x4d, 0x60)
        }

        return abi.decode(footer, (uint256, address, uint256));
    }

    function owner() public view virtual returns (address) {
        (uint256 chainId, address tokenContract, uint256 tokenId) = token();
        return (chainId == block.chainid) ? IERC721(tokenContract).ownerOf(tokenId) : address(0);
    }

    function _isValidSigner(address signer) internal view virtual returns (bool) {
        return signer == owner() || isPermitted[signer];
    }

}
