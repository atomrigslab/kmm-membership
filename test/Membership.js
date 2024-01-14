const chai = require("chai");
const { ethers, upgrades } = require("hardhat");
const chaiAsPromised  = require('chai-as-promised');
chai.use(chaiAsPromised);
const expect = chai.expect;

const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Contract core", function () {

  let Contract;
  let contract;
  let owner;
  let operator;
  let user1;
  let user2;
  let beacon;
 
  beforeEach(async function () {
    Contract = await ethers.getContractFactory("Membership");
    [owner, operator, user1, user2] = await ethers.getSigners();

    //beacon proxy
    beacon = await upgrades.deployBeacon(Contract);
    await beacon.waitForDeployment();
    contract = await upgrades.deployBeaconProxy(beacon, Contract, []);
    await contract.waitForDeployment();
    return { contract, beacon };
  });

  it("transferOwner() should set a new owner", async function () {

    await contract.connect(owner).transferOwner(operator.address);
    let operatorAddr = await contract.getOwner();
    expect(operatorAddr).to.equal(operator.address);
  
  });

  it("setOperator() should set a new operator", async function () {

    await contract.connect(owner).setOperator(operator.address, true);
    let isActive = await contract.isOperatorActive(operator.address);
    expect(isActive).to.equal(true);
  
  });

  it("updateBaseImgUrl() should work", async function () {
    let newUrl = "https://google.com"
    await contract.connect(owner).updateBaseImgUrl(newUrl);
    let url = await contract.getBaseImgUrl();
    expect(url).to.equal(newUrl);
  });

  it("setAggregation() should work", async function() {
    await contract.connect(owner).setAggregation(true);
    let isAggregation = await contract.isAggregationActive();
    expect(isAggregation).to.equal(true);
  });

  it("mint should work", async function () {
    await contract.connect(owner).setOperator(operator.address, true);
    await contract.connect(operator).mint(user1.address, 0, "kmm_membership_a.jpg");    
    
  });

  it("updateScore should work", async function () {
    await contract.connect(owner).setOperator(operator.address, true);
    await contract.connect(operator).mint(user1.address, 0, "kmm_membership_a.jpg");    
    await contract.connect(operator).updateScore(user1.address, 1);
    let member = await contract.members(user1.address);
    expect(member.score).to.equal(1n);

  });


});