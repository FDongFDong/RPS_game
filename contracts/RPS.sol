// //SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract RPS {
    constructor() payable {} // 해당 컨트렉트는 송금이 가능함을 명시

    // 가위, 바위, 보 값에 대한 enum
    enum Hand {
        rock, // 바위
        paper, // 보
        scissors // 가위
    }

    // 플레이어의 상태 (enum은 각 순서에 따라 0,1,2...로 초기값이 정해진다.)
    enum PlayerStatus {
        STATUS_WIN, // 게임을 이김
        STATUS_LOSE, // 게임을 짐
        STATUS_TIE, // 게임 비김
        STATUS_PENDING // 게임 대기중
    }

    // 게임 방의 상태
    enum GameStatus {
        STATUS_NOT_STARTED, // 시작하지 않은 상태
        STATUS_STARTED, // 시작한 상태
        STATUS_COMPLETE, // 게임이 끝난 상태
        STATUS_ERROR // 게임이 에러난 상태
    }
    struct Player {
        // 참여한 플레이어의 주소와 베팅금액, 낸 값, 현재 상태를 알기 위한 구조체
        address payable addr; // 주소
        uint256 playerBetAmount; // 베팅 금액
        Hand hand; // 참여자의 손 상태
        PlayerStatus playerStatus; // 플레이어의 상태
    }

    struct Game {
        Player originator; //  방장의 정보
        Player taker; // 참여자 정보
        uint256 betAmount; // 총 베팅 금액
        GameStatus gameStatus; // 게임의 현 상태
    }

    mapping(uint256 => Game) rooms; //Game 구조체 형식으로 각 방을 만들기 위함
    uint256 roomLen = 0; // rooms의 키 값, 방이 생성될 때마다 1씩 올라감.

    function createRoom(Hand _hand)
        public
        payable
        isValidHand(_hand)
        returns (uint256 roomNum)
    {
        // 베팅 금액을 입금하기 때문에 payable 키워드 사용
        // 생성한 방의 번호를 반환
        rooms[roomLen] = Game({
            betAmount: msg.value,
            gameStatus: GameStatus.STATUS_STARTED,
            originator: Player({
                hand: _hand,
                addr: payable(msg.sender),
                playerStatus: PlayerStatus.STATUS_PENDING,
                playerBetAmount: msg.value
            }),
            taker: Player({
                hand: Hand.rock,
                addr: payable(msg.sender),
                playerStatus: PlayerStatus.STATUS_PENDING,
                playerBetAmount: 0
            })
        });
        roomNum = roomLen; // 현재 방 번호를 할당
        roomLen = roomLen + 1; // 다음 새롭게 만들어질 방을 위해 1 올려준다.
        return roomNum;
    }

    modifier isValidHand(Hand _hand) {
        require(
            (_hand == Hand.rock) ||
                (_hand == Hand.paper) ||
                (_hand == Hand.scissors)
        );
        _;
    }

    function joinRoom(uint256 _roomNum, Hand _hand)
        public
        payable
        isValidHand(_hand)
    {
        // 해당 게임의 참여자 정보
        rooms[_roomNum].taker = Player({
            hand: _hand,
            addr: payable(msg.sender),
            playerStatus: PlayerStatus.STATUS_PENDING,
            playerBetAmount: msg.value
        });
        rooms[_roomNum].betAmount = rooms[_roomNum].betAmount + msg.value;
        compareHands(_roomNum); //  게임 결과 업데이트 함수
    }

    function compareHands(uint256 _roomNum) private {
        uint8 originator = uint8(rooms[_roomNum].originator.hand);
        uint8 taker = uint8(rooms[_roomNum].taker.hand);

        // 게임 상태를 시작으로 변경
        rooms[_roomNum].gameStatus = GameStatus.STATUS_STARTED;

        if (taker == originator) {
            // 비긴 경우
            rooms[_roomNum].originator.playerStatus = PlayerStatus.STATUS_TIE;
            rooms[_roomNum].taker.playerStatus = PlayerStatus.STATUS_TIE;
        } else if ((taker + 1) % 3 == originator) {
            // 방장이 이긴 경우
            rooms[_roomNum].originator.playerStatus = PlayerStatus.STATUS_WIN;
            rooms[_roomNum].taker.playerStatus = PlayerStatus.STATUS_LOSE;
        } else if ((taker + 1) % 3 == taker) {
            // 참가자가 이긴 경우
            rooms[_roomNum].originator.playerStatus = PlayerStatus.STATUS_LOSE;
            rooms[_roomNum].taker.playerStatus = PlayerStatus.STATUS_WIN;
        } else {
            // 그 외의 상황은 에러
            rooms[_roomNum].gameStatus = GameStatus.STATUS_ERROR;
        }
    }

    // 비긴 경우에는 베팅금액을 돌려받고, 이긴 경우에는 전체 베팅 금액을 돌려 받습니다.
    function payout(uint256 _roomNum)
        public
        payable
        isPlayer(_roomNum, msg.sender)
    {
        if (
            // 비긴 경우
            rooms[_roomNum].originator.playerStatus ==
            PlayerStatus.STATUS_TIE &&
            rooms[_roomNum].taker.playerStatus == PlayerStatus.STATUS_TIE
        ) {
            rooms[_roomNum].originator.addr.transfer(
                rooms[_roomNum].originator.playerBetAmount
            );
            rooms[_roomNum].taker.addr.transfer(
                rooms[_roomNum].taker.playerBetAmount
            );
        } else {
            //  누군가 이긴경우
            if (
                rooms[_roomNum].originator.playerStatus ==
                PlayerStatus.STATUS_WIN
            ) {
                // 방장이 이긴 경우
                rooms[_roomNum].originator.addr.transfer(
                    rooms[_roomNum].betAmount
                );
            } else if (
                rooms[_roomNum].taker.playerStatus == PlayerStatus.STATUS_WIN
            ) {
                // 참여자가 이긴 경우
                rooms[_roomNum].taker.addr.transfer(rooms[_roomNum].betAmount);
            } else {
                // 아무도 이기지 않은 경우
                rooms[_roomNum].originator.addr.transfer(
                    rooms[_roomNum].originator.playerBetAmount
                );
                rooms[_roomNum].taker.addr.transfer(
                    rooms[_roomNum].taker.playerBetAmount
                );
            }
            rooms[_roomNum].gameStatus = GameStatus.STATUS_COMPLETE; // 종료 되었으므로 게임 상태 변경
        }
    }

    modifier isPlayer(uint256 _roomNum, address _sender) {
        require(
            _sender == rooms[_roomNum].originator.addr ||
                _sender == rooms[_roomNum].taker.addr
        );
        _;
    }
    // 가스비 절약
    // 초기값 확인 - Enum의 초기값은 무엇이 들어갈까
    // modifier 함수에 대한 설명 추가
    // msg.sender, msg.value
}

// function hash(string memory _string) public pure returns (bytes32) {
//     return keccak256(abi.encodePacked(_string));
// }
