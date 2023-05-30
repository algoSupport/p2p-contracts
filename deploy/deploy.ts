import { ethers, upgrades } from "hardhat";

async function main() {
  // const cilFactory = await ethers.getContractFactory("CIL");
  // const cil = await cilFactory.deploy('0x0b79045257d19416109D2dBD3CaE20494A80Cc2b');
  // console.log("CIL address: ", cil.address);

  const mockERC721Factory = await ethers.getContractFactory("MockERC721");
  const mockERC721 = await mockERC721Factory.deploy("Cilistia NFT", 'CN');
  console.log("NFT address:", mockERC721.address);

  const cilStakingFactory = await ethers.getContractFactory("NewStake");
  const cilStaking = await upgrades.deployProxy(cilStakingFactory, ['0xcE9007bbD935289c85689472e26FC67D410c9F5A', mockERC721.address]);
  console.log("Staking address: ", cilStaking.address);

  const marketplaceFactory = await ethers.getContractFactory("NewMarketPlace");
  const marketPlace = await upgrades.deployProxy(marketplaceFactory, [cilStaking.address]);
  console.log("Marketplace address: ", marketPlace.address);
  await cilStaking.setMarketPlace(marketPlace.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
