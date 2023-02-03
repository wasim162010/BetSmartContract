const { ethers, upgrades } = require("hardhat");

async function main() {

	const [deployer] = await ethers.getSigners();

	console.log(
	"Deploying contracts with the account:",
	deployer.address
	);

	console.log("Account balance:", (await deployer.getBalance()).toString());

	const Betting = await ethers.getContractFactory("Betting");
	// const contract = await Betting.deploy();

    const betting = await upgrades.deployProxy(Betting, ["India", "NZ"], {
        initializer: "initialize",
      });

      await betting.deployed();
	console.log("Contract deployed at:", betting.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
	console.error(error);
	process.exit(1);
  });