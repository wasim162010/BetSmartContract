// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Betting is Initializable, OwnableUpgradeable, UUPSUpgradeable {


     address payable public ownerAddr;
     uint256 public minimumBet;
     address payable[] public players;

    struct Player {
      uint256 amountBet;
      uint teamSelected;
      uint256  betPlaced;
      address addr;
      uint id;
    }  

    mapping(address => Player) public playerInfo;
    Player[] public playerArr;

    struct Team {
        string country;
    }
    Team public teamOneObj;
    Team public teamTwoObj;

    mapping(uint=>Team) public teamMap;

    struct Match {
        uint256 teamOneId;
        uint256 teamTwoId;
        string matchState; 
    }
    Match public matchObj;

    uint256 public startTime;
    uint256 public endTime;
 
    uint256 public winningTeam;
  
    //play id to bool
    bool public playerOneApproval;
    bool public playerTwoApproval;

    string public contractState;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory team1, string memory team2) initializer public {

            __Ownable_init();
            __UUPSUpgradeable_init();
            ownerAddr = payable(msg.sender);
            contractState= "DRAFT";
            teamOneObj =  Team(team1);

            teamMap[1] = teamOneObj;
            teamTwoObj =  Team(team2);      
            teamMap[2] = teamTwoObj;
            matchObj = Match(1,2,"SCHEDULED");
     
    }

    function placeBet(uint256 teamid) external payable {

        //The first require is used to check if the player already exist
        require(!checkPlayerExists(payable(msg.sender)),"Player can only bet once");
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
        require(keccak256(abi.encodePacked(matchObj.matchState)) != keccak256(abi.encodePacked("ENDED")));
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("MATURED"))); 
        
        
        if(minimumBet == 0) {
            minimumBet = msg.value;// amt;

            //We set the player informations : amount of the bet and selected team
            playerInfo[msg.sender].amountBet = msg.value;//amt;
            playerInfo[msg.sender].teamSelected = teamid;
            playerInfo[msg.sender].addr = msg.sender;
            playerInfo[msg.sender].id =  players.length + 1;
            playerInfo[msg.sender].betPlaced = msg.value;
            //then we add the address of the player to the players array
            players.push(payable(msg.sender));

        } else {
            require(minimumBet == msg.value, "Bet amount should be same");

            //We set the player informations : amount of the bet and selected team
            playerInfo[msg.sender].amountBet = msg.value;//amt;
            playerInfo[msg.sender].teamSelected = teamid;
            playerInfo[msg.sender].addr = msg.sender;
            playerInfo[msg.sender].id =  players.length + 1;
            playerInfo[msg.sender].betPlaced = msg.value;
            //then we add the address of the player to the players array
            players.push(payable(msg.sender));

        }

    }

    function checkPlayerExists(address payable player) public view returns(bool){
      for(uint256 i = 0; i < players.length; i++){
         if(players[i] == player) return true;
      }
      return false;
    }

    function startEventAndUpdateState() external onlyOwner{
            require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
            contractState= "EFFECTIVE";
            startTime = block.timestamp;
    }

    /*
    End the event and it sets the id of the winning team.
    */
    function endEventAndUpdateState(uint _winningTeam) external onlyOwner{
            require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
            contractState= "MATURED";
            endTime = block.timestamp;
           // winner 
            winningTeam= _winningTeam;
    } 

    /*
    This method is used to accept/reject the decision made for the winning team selection.
    */
    function approveWinner(bool isApproved) external {
            require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
            require(keccak256(abi.encodePacked(contractState)) == keccak256(abi.encodePacked("MATURED")) );
    
            if(playerInfo[msg.sender].id == 1) {
                playerOneApproval = isApproved;
            } else if(playerInfo[msg.sender].id ==2) {
                playerTwoApproval = isApproved;
            }
    }


    /*
    This nethods verify whether players have accepted the outcome of the event presented to them.
    If they both accpet, then winner gets all the tokens bet, and if there is a tie,then they get their tokens used in bet back.
    But, if they don't accept the the outcome of the event  presented to them then they get their tokens used in bet back.
    */
    function checkApproval() external  onlyOwner{
       
        //require(msg.sender == ownerAddr,"must be an owner");
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
        require(keccak256(abi.encodePacked(contractState)) == keccak256(abi.encodePacked("MATURED")) );
        if(playerOneApproval && playerTwoApproval) {
            //transfer the amount bet to the winner
            //address payable[] public players;
     
            //check for the tie: Bith player bet for same team.
            if(playerInfo[players[0]].teamSelected  == playerInfo[players[1]].teamSelected ) {

                  for(uint i=0;i<2;i++) {
                    address  paddr = players[i];
                    Player memory _player = playerInfo[paddr];
                    uint256  _betPlaced  = _player.betPlaced;
                    address payable paddrpayable = payable(paddr);
                    paddrpayable.transfer(_betPlaced);
                 }// for

            } else {
                for(uint i=0;i<2;i++) {
                    if(playerInfo[players[i]].teamSelected ==  winningTeam) { //winner) {
                        players[i].transfer(address(this).balance);
                    }
                }
            }
            contractState= "SETTLED";
        } else {
             for(uint i=0;i<2;i++) {
                  address  paddr = players[i];
                  Player memory _player = playerInfo[paddr];
                  uint256  _betPlaced  = _player.betPlaced;
                  address payable paddrpayable = payable(paddr);
                  paddrpayable.transfer(_betPlaced);
             }// for
            contractState= "TERMINATED";
        } // else

        matchObj.matchState = "ENDED";

    }

    // function contBal() external view returns(uint256) {
    //     return address(this).balance;
    // }

    // function p1BAl() external view returns(uint256) {
    //     return address(0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2).balance;
    // }

    // function p2BAl() external view returns(uint256) {
    //     return address(0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db).balance;
    // }

    function terminateContract() external onlyOwner {
     //   require(msg.sender == ownerAddr,"must be an owner");
        //pay back the amounts betted by the user
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
        contractState = "TERMINATED";
    }


    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
}
