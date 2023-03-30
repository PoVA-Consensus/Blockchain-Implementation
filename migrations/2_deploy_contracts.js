const Reputation = artifacts.require("Reputation");

module.exports = function (deployer) {
  deployer.deploy(Reputation, "0x79f560e000E8c7878c5Db87C1e640f0b5A6DD674", 10000000000);
};

