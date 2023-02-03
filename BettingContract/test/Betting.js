const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");


describe("Test Betting contract scenarios", function () {


    it("Should deploy betting contract", async function() {

        const team1="India", team2="NZ";
        const [owner, p1, p2] = await ethers.getSigners();
        const betting = await ethers.getContractFactory("Betting");
        const bettingInst =  await upgrades.deployProxy(betting,[team1, team2], { initializer: 'initialize' });
        const val1=  await bettingInst.contractState();
        const match = await bettingInst.matchObj()

        expect(val1).to.equal("DRAFT");
        expect(match.teamOneId.toString()).to.equal("1");
        expect(match.teamTwoId.toString()).to.equal("2");
        expect(match.matchState).to.equal("SCHEDULED");

    })

    it("Should be able to place bet successfully", async function() {

        const team1="India", team2="NZ";
        const [owner, p1, p2] = await ethers.getSigners();
        const addr1 = await p1.address;
        const addr2 =  await p2.address;
        
        const betting = await ethers.getContractFactory("Betting");
        const bettingInst =  await upgrades.deployProxy(betting,[team1, team2], { initializer: 'initialize' });

        await bettingInst.connect(p1).placeBet(1,{ value: ethers.utils.parseEther("0.5") })
        const minBet = await bettingInst.minimumBet()
        await bettingInst.connect(p2).placeBet(2,{ value: ethers.utils.parseEther("0.5") })
        const playerOneInfo = await bettingInst.playerInfo(addr1);
        const playerTwoInfo = await bettingInst.playerInfo(addr2);

        expect(ethers.utils.formatEther(playerOneInfo.betPlaced)).to.equal('0.5');
        expect(ethers.utils.formatEther(playerTwoInfo.betPlaced)).to.equal('0.5');

        const playerOneSelTeam = playerOneInfo.teamSelected.toString()
        const playerTwoSelTeam = playerTwoInfo.teamSelected.toString()

        const contractState=  await bettingInst.contractState();
        expect(contractState).to.equal("AGREED");
        expect(playerOneSelTeam == 1);
        expect(playerTwoSelTeam == 2);

    })

    it("State transition should be fine", async function(){
       
        const team1="India", team2="NZ";
        // let state="";
        const [owner, p1, p2] = await ethers.getSigners();
        const addr1 = await p1.address;
        const addr2 =  await p2.address;

        const betting = await ethers.getContractFactory("Betting");
        const bettingInst =  await upgrades.deployProxy(betting,[team1, team2], { initializer: 'initialize' });

        state =  await bettingInst.contractState();
        expect(state).to.equal("DRAFT");

        await bettingInst.connect(p1).placeBet(1,{ value: ethers.utils.parseEther("0.5") })
        await bettingInst.connect(p2).placeBet(2,{ value: ethers.utils.parseEther("0.5") }) 
        const isAgreedState=  await bettingInst.contractState();
        expect(isAgreedState).to.equal("AGREED");
        
        await bettingInst.connect(owner).startEventAndUpdateState()
        isEffectivetate =  await bettingInst.contractState();
        expect(isEffectivetate).to.equal("EFFECTIVE");

        await bettingInst.connect(owner).endEventAndUpdateState(1)//(addr1)//(1) //player one should be winner in this case.
        const endstate =  await bettingInst.contractState();
        expect(endstate).to.equal("MATURED");

        await bettingInst.connect(owner).terminateContract()//(1) //player one should be winner in this case.
        const terminatestate =  await bettingInst.contractState();
        expect(terminatestate).to.equal("TERMINATED");

    })

    it("Complete flow: Both player agrees with winner", async function() {

        const team1="India", team2="NZ";
        let state="";
        const [owner, p1, p2] = await ethers.getSigners();
        const addr1 = await p1.address;
        const addr2 =  await p2.address;
  
  
        const betting = await ethers.getContractFactory("Betting");
        const bettingInst =  await upgrades.deployProxy(betting,[team1, team2], { initializer: 'initialize' });
    
        await bettingInst.connect(p1).placeBet(1,{ value: ethers.utils.parseEther("0.5") })
        const minBet = await bettingInst.minimumBet()
        await bettingInst.connect(p2).placeBet(2,{ value: ethers.utils.parseEther("0.5") })
    
        const playerOneBet = await bettingInst.playerInfo(addr1);
        const playerTwoBet = await bettingInst.playerInfo(addr2);
        
        expect(ethers.utils.formatEther(playerOneBet.betPlaced)).to.equal('0.5');
        expect(ethers.utils.formatEther(playerTwoBet.betPlaced)).to.equal('0.5');
    
        await bettingInst.connect(owner).startEventAndUpdateState()
        state =  await bettingInst.contractState();
        expect(state).to.equal("EFFECTIVE");
        
        await bettingInst.connect(owner).endEventAndUpdateState(1) //(addr1)//(1) //player one should be winner in this case.
        const endstate =  await bettingInst.contractState();
        expect(endstate).to.equal("MATURED");

        //player one approves. Sca=enario when both player approves
        await bettingInst.connect(p1).approveWinner(true)
        await bettingInst.connect(p2).approveWinner(true) 
        const playerOneApproval =  await bettingInst.playerOneApproval()
        const playerTwoApproval =  await bettingInst.playerTwoApproval()
        expect(playerOneApproval).to.equal(true)
        expect(playerTwoApproval).to.equal(true)
    
        //check the approval, and transfer amount to the winner account
        const addr  =  await bettingInst.address
   
        const preContBal = await ethers.provider.getBalance(addr)
        const preApprovalPlayerOneBal = await ethers.provider.getBalance(addr1)
        const preApprovalPlayerTwoBal = await ethers.provider.getBalance(addr2)
        await bettingInst.connect(owner).checkApproval() 
        const postApprovalPlayerOneBal = await ethers.provider.getBalance(addr1)
        const postApprovalPlayerTwoBal = await ethers.provider.getBalance(addr2)
        const postContBal = await ethers.provider.getBalance(addr)
        const postApprovalState = await bettingInst.contractState()
       
        expect(ethers.utils.formatEther(preContBal)).to.equal("1.0")
        expect(ethers.utils.formatEther(postContBal)).to.equal("0.0")
        expect(preApprovalPlayerOneBal !=  postApprovalPlayerOneBal);
        expect(preApprovalPlayerTwoBal ==  postApprovalPlayerTwoBal);
        expect(postApprovalState).to.equal("SETTLED")
    
    })

    it("Complete flow: Players does not agree with the winner choice", async function() {

        const team1="India", team2="NZ";
        let state="";
        const [owner, p1, p2] = await ethers.getSigners();
        const addr1 = await p1.address;
        const addr2 =  await p2.address;
    
        const betting = await ethers.getContractFactory("Betting");
        
        const bettingInst =  await upgrades.deployProxy(betting,[team1, team2], { initializer: 'initialize' });
    
        const preApprovalPlayerOneBal = await ethers.provider.getBalance(addr1)
        const preApprovalPlayerTwoBal = await ethers.provider.getBalance(addr2)
    
        await bettingInst.connect(p1).placeBet(1,{ value: ethers.utils.parseEther("0.5") })
        const minBet = await bettingInst.minimumBet()
        await bettingInst.connect(p2).placeBet(2,{ value: ethers.utils.parseEther("0.5") })
    
        await bettingInst.connect(owner).startEventAndUpdateState()
        state =  await bettingInst.contractState();
        expect(state).to.equal("EFFECTIVE");
        
        await bettingInst.connect(owner).endEventAndUpdateState(1) //(addr1)//(1) //No one is he winner.
        const endstate =  await bettingInst.contractState();
        expect(endstate).to.equal("MATURED");

        const winner = await bettingInst.winningTeam();
        expect(winner.toString() ==  1);
    
        //player one approves. Sca=enario when both player approves
        await bettingInst.connect(p1).approveWinner(false)
        await bettingInst.connect(p2).approveWinner(false) 
        const playerOneApproval =  await bettingInst.playerOneApproval()
        const playerTwoApproval =  await bettingInst.playerTwoApproval()
        expect(playerOneApproval).to.equal(false)
        expect(playerTwoApproval).to.equal(false)
    
        //check the approval, and transfer amount to the winner account
        const addr  =  await bettingInst.address
        
        const preContBal = await ethers.provider.getBalance(addr)
 
        await bettingInst.connect(owner).checkApproval() 
        const postApprovalPlayerOneBal = await ethers.provider.getBalance(addr1)
        const postApprovalPlayerTwoBal = await ethers.provider.getBalance(addr2)
        const postContBal = await ethers.provider.getBalance(addr)
        const postApprovalState = await bettingInst.contractState()
      
        expect(preApprovalPlayerOneBal ==  postApprovalPlayerOneBal);
        expect(preApprovalPlayerTwoBal ==  postApprovalPlayerTwoBal);
        expect(postApprovalState).to.equal("TERMINATED")
    
      })
      
      it("Complete flow: Player bet for same team and approves the winner", async function() {

        const team1="India", team2="NZ";
        let state="";
        const [owner, p1, p2] = await ethers.getSigners();
        const addr1 = await p1.address;
        const addr2 =  await p2.address;
    
        const betting = await ethers.getContractFactory("Betting");
        const bettingInst =  await upgrades.deployProxy(betting,[team1, team2], { initializer: 'initialize' });
    
        const preApprovalPlayerOneBal = await ethers.provider.getBalance(addr1)
        const preApprovalPlayerTwoBal = await ethers.provider.getBalance(addr2)
    
        await bettingInst.connect(p1).placeBet(2,{ value: ethers.utils.parseEther("0.5") })
        const minBet = await bettingInst.minimumBet()
        await bettingInst.connect(p2).placeBet(2,{ value: ethers.utils.parseEther("0.5") })
    
        await bettingInst.connect(owner).startEventAndUpdateState()
        state =  await bettingInst.contractState();
        expect(state).to.equal("EFFECTIVE");
        
        await bettingInst.connect(owner).endEventAndUpdateState(2)//(addr2)//(2) 
        const endstate =  await bettingInst.contractState();
        expect(endstate).to.equal("MATURED");

       const winner = await bettingInst.winningTeam();
       expect(winner.toString() ==  2);
    
        //player one approves. Scenario when both player approves
        await bettingInst.connect(p1).approveWinner(true)
        await bettingInst.connect(p2).approveWinner(true) 
        const playerOneApproval =  await bettingInst.playerOneApproval()
        const playerTwoApproval =  await bettingInst.playerTwoApproval()
        expect(playerOneApproval).to.equal(true)
        expect(playerTwoApproval).to.equal(true)
    
        //check the approval, and transfer amount to the winner account
        const addr  =  await bettingInst.address

        const preContBal = await ethers.provider.getBalance(addr)

        await bettingInst.connect(owner).checkApproval() 
        const postApprovalPlayerOneBal = await ethers.provider.getBalance(addr1)
        const postApprovalPlayerTwoBal = await ethers.provider.getBalance(addr2)
        const postContBal = await ethers.provider.getBalance(addr)
        const postApprovalState = await bettingInst.contractState()

        expect(preApprovalPlayerOneBal ==  postApprovalPlayerOneBal);
        expect(preApprovalPlayerTwoBal ==  postApprovalPlayerTwoBal);
        expect(postContBal.toString() == 0)
        expect(postApprovalState).to.equal("SETTLED")
    
      })

})
