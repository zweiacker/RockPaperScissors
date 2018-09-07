pragma solidity ^0.4.23;

contract RockPaperScissors {

    uint frame;
    
    struct Game {
        address opponent;
        uint startedOn;
        uint bet;
        bytes32 encMove;
        uint moveOne;
        uint moveTwo;
        uint stage;  // 1=moveOne completed, 2=moveTwo completed, 3=reveal completed, 4=balances settled
    }

    mapping (address => Game) games;
    mapping (address => uint) balances;
    
    event LogMoveone (address playerOne, address opponent);
    event LogMovetwo (address playerTwo, address playerOne);
    event LogReveal (string move, uint mv);
    event LogSettleByOne(address who, uint stage);
    event LogSettleByTwo(address who, uint stage);
    event LogWithdraw (address who, uint amount);

    constructor (uint _frame) public {
        frame = _frame;
    }
    
    function moveOne(address _opponent, bytes32 _encMove) payable public {
        // must have enough overall funds
        require(balances[msg.sender]+msg.value > 0);
        // must have no pending game
        require(games[msg.sender].startedOn+2*frame < block.timestamp);
        // must be in a settled state, unless first game
        require(games[msg.sender].startedOn==0 || games[msg.sender].stage==4);
        // if value > 0 then play that value, otherwise use your entire balance
        uint val;
        if (msg.value > 0) {val = msg.value;} else {val = balances[msg.sender];}
        // register the new game
        Game memory newGame;
        newGame.opponent = _opponent;
        newGame.startedOn = block.timestamp;
        newGame.bet = val;
        newGame.encMove = _encMove;
        newGame.moveOne = 0;
        newGame.moveTwo = 0;
        newGame.stage = 1;
        games[msg.sender] = newGame;
        emit LogMoveone(msg.sender, _opponent);
    }
    
    function moveTwo(address initiator, uint mv) payable public {
        // there must be a pending game with the initiator and yourself
        require(games[initiator].opponent == msg.sender);
        // time window must still be open
        require(games[initiator].startedOn+frame > block.timestamp);
        // must send sufficient funds
        require(msg.value >= games[initiator].bet);
        // must be a valid move: 1=rock, 2=scissors, 3=paper
        require (mv>0 && mv<=3);
        // in case of too much funds, push excess amount to balance
        balances[msg.sender] += msg.value - games[initiator].bet;
        // store moveTwo in game
        games[initiator].moveTwo=mv;
        // moveTwo stage is completed
        games[initiator].stage=2;
        emit LogMovetwo(msg.sender, games[initiator].opponent);
    }
    
    function revealOne(string move) public {
        // must be after the playing period
        require(games[msg.sender].startedOn+frame < block.timestamp);
        // must be within the reveal period
        require(games[msg.sender].startedOn+2*frame > block.timestamp);
        // check if move is the same as in moveOne
        require(keccak256(move) == games[msg.sender].encMove);
        // determine actual move value, convert from string to uint
        bytes memory b = bytes(move);
        uint mv = uint(b[0]);
        games[msg.sender].moveOne = mv-48;
        // reveal stage is completed
        games[msg.sender].stage = 3;
    }
    
    //
    // to be called by game owner
    //
    function settleByOne() public {
        // must not be settled already
        require(games[msg.sender].stage < 4);
        // must have timed out
        require(games[msg.sender].startedOn+2*frame < block.timestamp);
        // save bet and stage to memory
        uint win = games[msg.sender].bet;
        uint stage = games[msg.sender].stage;
        emit LogSettleByOne(msg.sender, stage);
        // after this, you are done (stage is 4)
        games[msg.sender].stage=4;
        // if no response from opponent you get refunded
        if (stage == 1) {
            balances[msg.sender]+=win;
        }
        // determine winner only if moveOne was revealed
        if (stage == 3) {
            uint m1 = games[msg.sender].moveOne;
            uint m2 = games[msg.sender].moveTwo;
            // 1=rock, 2=scissors, 3=paper
            if (m1==m2) {  // draw
                balances[msg.sender] += win;
                balances[games[msg.sender].opponent] += win;
            }
            if (m1==2 && m2==3 || m1==1 && m2==2 || m1==3 && m2==1) {
                balances[msg.sender] += 2*win;
            } else {
                balances[games[msg.sender].opponent] += 2*win;
            }
        } else { 
            // you ask for settlement, but didn't reveal moveOne, so you lose
            balances[games[msg.sender].opponent] += 2*win;
        }
    }
  
    //
    // to be called by opponent, in case game owner didn't settle by himself
    //
    function settleByTwo(address initiator) public {
        // must be the opponent
        require(games[initiator].opponent == msg.sender);
        // must not be settled already
        require(games[initiator].stage < 4);        
        // must have timed out
        require(games[initiator].startedOn+2*frame < block.timestamp);
        // must have higher stage than moveOne
        require(games[initiator].stage > 1);
        // save bet and stage to memory
        uint win = games[initiator].bet;
        uint stage = games[initiator].stage;
        emit LogSettleByTwo(msg.sender, stage);
        // after this, the game is cleared
        games[initiator].stage = 4;            
        // if stuck in stage 2, you win
        if (stage == 2) {
            balances[msg.sender]+=2*win;
        }
        // as the initiating player didn't want to, take your turn to determine the winner
        if (stage == 3) {
            uint m1 = games[initiator].moveOne;
            uint m2 = games[initiator].moveTwo;
            // 1=rock, 2=scissors, 3=paper
            if (m1==m2) {  // draw
                balances[msg.sender] += win;
                balances[initiator] += win;
            }
            if (m1==2 && m2==3 || m1==1 && m2==2 || m1==3 && m2==1) {
                balances[initiator] += 2*win;
            } else {
                balances[msg.sender] += 2*win;
            }
        }
    }

    function withdraw() public {
        // must have funds
        require(balances[msg.sender] > 0);
        // must currently not own a game
        require(games[msg.sender].startedOn+2*frame < block.timestamp);
        uint val = balances[msg.sender];
        balances[msg.sender] = 0;
        emit LogWithdraw (msg.sender, val);
        if (val > 0) msg.sender.transfer(val);
    }
    
    function betHelper(address addr) public view returns (uint) {
        return games[addr].bet;
    }
    
    function hashHelper(string move) public pure returns(bytes32) {
        return keccak256(move);
    }
}
