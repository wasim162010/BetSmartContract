// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Betting is Initializable, OwnableUpgradeable, UUPSUpgradeable {


    address payable public ownerAddr;
    uint256 public minimumBet;
    address payable[] public players;
    address payable[] public testarr;

    struct Player {
      uint256 amountBet;
      uint teamSelected;
      address addr;
      uint id;
      bool  playerApproval;
    }  
    mapping(address => Player) public playerInfo;
  

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
        uint256  startTime;
        uint256  endTime;
        uint256  winningTeam;
    }
    Match public matchObj;
  
    string public contractState;
    uint betCounter;

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
            matchObj = Match(1,2,"SCHEDULED",0,0,0);
    }

    function testlen() external view returns (uint256) {
        return testarr.length;
    }


    function placeBet(uint256 teamid) external payable {

        require(teamid == 1 || teamid == 2, "Team id must be either 1 or 2");
        require(players.length < 2,"Only 2 players can place the bet");
        require(msg.value > 0,"Bet amount must be greater then zero");
        require(playerInfo[msg.sender].addr == 0x0000000000000000000000000000000000000000, "Bet can only be placed once by a player");
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
        require(keccak256(abi.encodePacked(matchObj.matchState)) != keccak256(abi.encodePacked("ENDED")));
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("MATURED"))); 
    
        if(players.length > 0) {
            //
            require( playerInfo[players[players.length-1]].teamSelected !=  teamid, "Both the players cannot bet for the same team");
            require(minimumBet == msg.value, "Bet amount should be same");
            playerInfo[msg.sender].amountBet = msg.value;
            playerInfo[msg.sender].teamSelected = teamid;
            playerInfo[msg.sender].addr = msg.sender;
            playerInfo[msg.sender].id =  players.length + 1;
            playerInfo[msg.sender].amountBet = msg.value;
            players.push(payable(msg.sender));   
            contractState = "AGREED";
        } else {
            minimumBet = msg.value;
            playerInfo[msg.sender].amountBet = msg.value;
            playerInfo[msg.sender].teamSelected = teamid;
            playerInfo[msg.sender].addr = msg.sender;
            playerInfo[msg.sender].id =  players.length + 1;
            playerInfo[msg.sender].amountBet = msg.value;
            players.push(payable(msg.sender));
        }
 
    }

   

    function startEventAndUpdateState() external onlyOwner{
            require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
            contractState= "EFFECTIVE";
            matchObj.startTime= block.timestamp;
    }

    /*
    End the event and it sets the id of the winning team.
    */
    function endEventAndUpdateState(uint _winningTeam) external onlyOwner{
            require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
            contractState= "MATURED";
            matchObj.endTime = block.timestamp;
            matchObj.winningTeam= _winningTeam;
            matchObj.matchState = "ENDED";
    } 

    /*
    This method is used to accept/reject the decision made for the winning team selection.
    */
    function approveWinner(bool isApproved) external {
            
            require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
            require(keccak256(abi.encodePacked(contractState)) == keccak256(abi.encodePacked("MATURED")) );
    
            if(playerInfo[msg.sender].id == 1) {
                playerInfo[players[0]].playerApproval = isApproved;
            } else if(playerInfo[msg.sender].id ==2) {
                playerInfo[players[1]].playerApproval = isApproved;
            }
    }


    /*
    This nethods verify whether players have accepted the outcome of the event presented to them.
    If they both accpet, then winner gets all the tokens bet, and if there is a tie,then they get their tokens used in bet back.
    But, if they don't accept the the outcome of the event  presented to them then they get their tokens used in bet back.
    */
    function checkApproval() external  onlyOwner{
       
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
        require(keccak256(abi.encodePacked(contractState)) == keccak256(abi.encodePacked("MATURED")) );
        
     
        if(playerInfo[players[0]].playerApproval && playerInfo[players[1]].playerApproval) {
            for(uint i=0;i<2;i++) {
                    if(playerInfo[players[i]].teamSelected ==  matchObj.winningTeam) { //winner) {
                        players[i].transfer(address(this).balance);
                    }
            }
            contractState= "SETTLED";
        } else {
             for(uint i=0;i<2;i++) {
                  address  paddr = players[i];
                  Player memory _player = playerInfo[paddr];
                  uint256  _betPlaced  = _player.amountBet;
                  address payable paddrpayable = payable(paddr);
                  paddrpayable.transfer(_betPlaced);
             }// for
            contractState= "TERMINATED";
        } // else
     

    }

    function terminateContract() external onlyOwner {
        require(keccak256(abi.encodePacked(contractState)) != keccak256(abi.encodePacked("TERMINATED")));
        contractState = "TERMINATED";
    }

    function checkPlayerExists(address _playerAddr) public view returns(bool) {

        if(playerInfo[_playerAddr].addr != 0x0000000000000000000000000000000000000000) {
            return true;
        }
        return false;
        
    }
    

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}
    
}


/*. 

For testing :

    A) Both the player bet for different teams, and both agree on outcome(winner[winning team] selection).- Going to test this
    
    1) deploying contract and state must be "DRAFT",and let players place their bet[function : placeBet].
        Once both the players have placed their bet. state must be "AGREED".

    2) starting the event[function : startEventAndUpdateState], and check the contract state[ state var. :contractState].
        state[state var: contractState] must be "EFFECTIVE"

    3)  Ending the event[function : endEventAndUpdateState]  ,and deciding the winner.State should become "MATURED".

    4) Player 1 and 2 approve(agree)[function : approveWinner] on the outcome.

    5) Now, admin check the approval[function : checkApproval] . the player whose team selection while placing the bet matches the outcome, 
            will be the winner,and the state must be changed to "SETTLED"

    6) Terminate the contract so that it cannot be used again and state must be "TERMINATED" now.

    ----

    B) Both the player bet for different teams, but they does not agree on the outcome(winner[winning team] selection)..

    1) deploying contract,and let players place their bet[function : placeBet].

    2) starting the event[function : startEventAndUpdateState], and check the contract state[ state var. :contractState].
        state[state var: contractState] must be "EFFECTIVE"

    3) Ending the event[function : endEventAndUpdateState]  ,and deciding the winner.State should become "MATURED".

    4) Player 1 and 2 disapprove the outcome[function : approveWinner]

    5) Now, admin check the approval[function : checkApproval].  In this case as players have not agreed on the winner[winning team] selection,
        both the players will get the amount they had put while placing the bet, and contract must be "TERMINATED".
    

*/

