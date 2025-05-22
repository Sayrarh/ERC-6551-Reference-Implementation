import { ethers } from "hardhat";

async function main() {
    // Deploy the ERC6551Account implementation
    const ERC6551Account = await ethers.getContractFactory("ERC6551Account");
    const implementation = await ERC6551Account.deploy();
    const implementationAddress = await implementation.getAddress();
    console.log("Implementation deployed to:", implementationAddress);

    // Registry contract address (same on all chains)
    const REGISTRY_ADDRESS = "0x000000006551c19487814612e58FE06813775758";
    //Connect to the ERC6551 Registry
    const REGISTRY = await ethers.getContractAt("IERC6551Registry", REGISTRY_ADDRESS);
    
    const nftContractAddress = "0x6B57b7eDF751829DfB2AeCcF578D6d24C33a45A2";
    const nftTokenId = 1;
    const chainId = 11155111;
    const salt = "0x0000000000000000000000000000000000000000000000000000000000000000";

    // Create a TBA
    const tx = await REGISTRY.createAccount(
        implementationAddress, 
        salt, 
        chainId, 
        nftContractAddress, 
        nftTokenId
    );
    
    // Wait for transaction to be mined
    await tx.wait();
    
    const tbaAccountAddress = await REGISTRY.account(
        implementationAddress, 
        salt, 
        chainId, 
        nftContractAddress, 
        nftTokenId
    );
    console.log("TBA created at:", tbaAccountAddress);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });