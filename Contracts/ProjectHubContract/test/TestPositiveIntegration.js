const ContractHub = artifacts.require("ProjectHubContract");
const ProjectContract = artifacts.require("ProjectContract");


contract("ContractHub", accounts => {

    it("Should return the right Contract Name", async () => {
        let hub = await ContractHub.deployed();
        let creatorAccount = accounts[0];
        let date = new Date();
        let timestamp = date.getTime();
        timestamp = Math.floor(timestamp/1000);
        timestamp += 86400;
        hub.addNewProject("TestProject", "TestDescription", 100, timestamp, {from: creatorAccount});
        let project = await hub.getProjects(0, {from: creatorAccount});

        assert.equal("TestProject", project[2]);
    });

    it("Should have the right Backing Option ID", async () => {
        let hub = await ContractHub.deployed();
        let creatorAccount = accounts[0];
        let investorAccountOne = accounts[1];

        let project = await hub.getProjects(0, {from: creatorAccount});
        let projectContract = await ProjectContract.at(project[1]);
        projectContract.addBackingOption("TestOption", "TestOptionDescription", 500, 400, {from: creatorAccount});
        projectContract.addBackingOption("TestOption", "TestOptionDescription", 500, 400, {from: creatorAccount});
        let backingOption = await projectContract.getBackingOption(1, {from: investorAccountOne});
        let state  = await projectContract.getContractState({from: investorAccountOne});

        assert.equal(0, state);
        assert.equal("TestOption", backingOption[0]);
        assert.equal("TestOptionDescription", backingOption[1]);
        assert.equal(500, backingOption[2]);
        assert.notEqual(0, backingOption[3]);
        assert.equal(2, backingOption[4]);
    });

    it("Should transfer 500 Wei to Contract", async () => {
        let hub = await ContractHub.deployed();
        let creatorAccount = accounts[0];
        let investorAccountOne = accounts[1];

        let project = await hub.getProjects(0, {from: creatorAccount});
        let projectContract = await ProjectContract.at(project[1]);
        await projectContract.closeAddingBackingOptionPeriode({from: creatorAccount})
        let state  = await projectContract.getContractState({from: investorAccountOne});
        await projectContract.addInvestor(1, {from: investorAccountOne, value: 500});
        

        assert.equal(1, state);
        let currentContractBalance = await web3.eth.getBalance(project[1]);

        assert.equal(currentContractBalance, 500);

    });

    it("Should accept a request from creator", async () =>{
        let hub = await ContractHub.deployed();
        let creatorAccount = accounts[0];

        let project = await hub.getProjects(0, {from: creatorAccount});
        let projectContract = await ProjectContract.at(project[1]);
        let date = new Date();
        let timestamp = date.getTime();
        timestamp = Math.floor(timestamp/1000);
        timestamp += 86400;
        await projectContract.addRequest("TestRequest", "TestRequestDescription", timestamp, 1000, {from: creatorAccount});
        let state  = await projectContract.getContractState({from: creatorAccount});

        try{
        await projectContract.addRequest("TestRequest1", "TestRequestDescription1", timestamp, 1000, {from: creatorAccount});
        }
        catch(Error){
            assert.notEqual(Error, undefined, 'Error must be thrown');
        }
        
        let request = await projectContract.getCurrentRequest();
        assert.equal(2, state);
        assert.equal(request[0], "TestRequest");
        assert.equal(request[1], "TestRequestDescription");
        assert.equal(request[2], timestamp);
        assert.equal(request[3], 1000);
        assert.equal(request[4], 0);
        assert.equal(request[5], 0);
        assert.equal(request[6], false);
    })

    it("Should let investors vote for Request", async () => {
        let hub = await ContractHub.deployed();
        let creatorAccount = accounts[0];
        let investorAccountOne = accounts[1];
        let investorAccountTwo = accounts[2];
        let investorAccountThree = accounts[3];
        let investorAccountFour = accounts[4];
        let investorAccountFive = accounts[5];

        let project = await hub.getProjects(0, {from: creatorAccount});
        let projectContract = await ProjectContract.at(project[1]);


        await projectContract.addInvestor(0, {from: investorAccountTwo, value: 500});
        await projectContract.addInvestor(0, {from: investorAccountThree, value: 500});
        await projectContract.addInvestor(0, {from: investorAccountFour, value: 500});
        await projectContract.voteForCurrentRequest(true, {from: investorAccountOne});
        await projectContract.voteForCurrentRequest(true, {from: investorAccountTwo});
        await projectContract.voteForCurrentRequest(true, {from: investorAccountThree});
        await projectContract.voteForCurrentRequest(false, {from: investorAccountFour});
        
        try{
            await projectContract.voteForCurrentRequest(true, {from: investorAccountFive});
        }
        catch (Error){
            assert.notEqual(Error, undefined, 'Error must be thrown');
        }

        let request = await projectContract.getCurrentRequest();

        assert.equal(request[0], "TestRequest");
        assert.equal(request[1], "TestRequestDescription");
        assert.equal(request[3], 1000);
        assert.equal(request[4], 3);
        assert.equal(request[5], 1);
        assert.equal(request[6], false);
    })

    it("Should get the correct investor count", async () => {
        let hub = await ContractHub.deployed();
        let creatorAccount = accounts[0];

        let project = await hub.getProjects(0, {from: creatorAccount});
        let projectContract = await ProjectContract.at(project[1]);
        let investorCount  = await projectContract.getInvestorCount({from: creatorAccount});
        assert.equal(4, investorCount);
    })

    it("Should pay the Creator", async () => {
        let hub = await ContractHub.deployed();
        let creatorAccount = accounts[0];

        let project = await hub.getProjects(0, {from: creatorAccount});
        let projectContract = await ProjectContract.at(project[1]);
        await projectContract.requestPayout({from: creatorAccount});
        let currentInvestorBalanceAfter = await web3.eth.getBalance(creatorAccount);
        let request = await projectContract.getCurrentRequest();


        let difference = currentInvestorBalanceAfter.toString();
        difference = difference.slice(-4);

        assert.equal(difference, "1000");
        assert.equal(request[0], "TestRequest");
        assert.equal(request[1], "TestRequestDescription");
        assert.equal(request[3], 1000);
        assert.equal(request[4], 3);
        assert.equal(request[5], 1);
        assert.equal(request[6], true);
    })

    it("Should retrive all Projects for Investors from Hub", async () => {
        let hub = await ContractHub.deployed();
        let investorAccountOne = accounts[1];
        let investorAccountFive = accounts[5]

        let investorBackingsOne = await hub.getProjectCountForInvestor({from: investorAccountOne});
        let investorBackingsFive = await hub.getProjectCountForInvestor({from: investorAccountFive});

        let project = await hub.getProjectByInvestorForIndex(0, {from: investorAccountOne});

        assert.equal(investorBackingsOne, 1);
        assert.equal(investorBackingsFive, 0);
        assert.equal(project[2], "TestProject");
    })


})