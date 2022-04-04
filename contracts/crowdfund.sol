// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// Importing OpenZeppelin's SafeMath Implementation
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract Campaign {
    using SafeMath for uint256;

    enum State {
        Fundraising,
        Expired,
        Successful
    }

    address payable public organizer;
    string title;
    string description;
    uint deadline;
    uint public completeAt;
    uint targetAmt;
    uint256 public currentBalance;
    State public state = State.Fundraising; // initialize on create
    mapping (address => uint) public donations;

    constructor (
        address payable campaignOrganizer,
        string memory campaignTitle,
        string memory campaignDesc,
        uint campaignDeadline,
        uint goalAmount
    ) {
        title = campaignTitle;
        description = campaignDesc;
        deadline = block.timestamp.add(campaignDeadline.mul(1 days)); 
        targetAmt = goalAmount;
        organizer = campaignOrganizer;
        currentBalance = 0;
    }

    // Events
    event DonationReceived(address donor, uint amount, uint currentTotal);
    event OrganizerDisbursed(address recipient);

    // Modifier to check current state
    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    // Modifier to check if the function caller is the project creator
    modifier isOrganizer() {
        require(msg.sender == organizer);
        _;
    }


    function donate() external inState(State.Fundraising) payable {
        // require(msg.sender != organizer);
        donations[msg.sender] = donations[msg.sender].add(msg.value);
        currentBalance = currentBalance.add(msg.value);
        emit DonationReceived(msg.sender, msg.value, currentBalance);
        checkIfFundingCompleteOrExpired();

    }

    function checkIfFundingCompleteOrExpired() public {
        if (currentBalance >= targetAmt) {
            state = State.Successful;
            payOut();
        } else if (block.timestamp > deadline)  {
            state = State.Expired;
        }
        completeAt = block.timestamp;
    }

    function payOut() internal inState(State.Successful) returns(bool) {
        uint256 totalRaised = currentBalance;
        currentBalance = 0;

        if (organizer.send(totalRaised)) {
            emit OrganizerDisbursed(organizer);
            return true;
        } else {
            currentBalance = totalRaised;
            state = State.Successful;
        }

        return false;
    }

    function getRefund() public inState(State.Expired) returns (bool) {
        require(donations[msg.sender] > 0);

        uint amountToRefund = donations[msg.sender];
        donations[msg.sender] = 0;

        if (!payable(msg.sender).send(amountToRefund)) {
            donations[msg.sender] = amountToRefund;
            return false;
        } else {
            currentBalance = currentBalance - amountToRefund;
        }

        return true;
    }

    function getDetails() public view returns 
    (
        address payable projectStarter,
        string memory projectTitle,
        string memory projectDesc,
        uint256 projectdeadline,
        State currentState,
        uint256 currentAmount,
        uint256 goalAmount
    ) {
        projectStarter = organizer;
        projectTitle = title;
        projectDesc = description;
        projectdeadline = deadline;
        currentState = state;
        currentAmount = currentBalance;
        goalAmount = targetAmt;
    }



}

contract Crowdfunding {

    // List of existing campaigns
    Campaign[] private campaigns;

    // Event that will be emitted whenever a new campaign is started
    event CampaignStarted(
        address contractAddress,
        address campaignOrganizer,
        string campaignTitle,
        string campaignDesc,
        uint256 deadline,
        uint256 targetAmt
    );

    function startCampaign(
        string calldata title,
        string calldata description,
        uint durationInDays,
        uint amountToRaise
    ) external {
        Campaign newCampaign = new Campaign(payable(msg.sender), title, description, durationInDays, amountToRaise);
        campaigns.push(newCampaign);
        emit CampaignStarted(
            address(newCampaign),
            msg.sender,
            title,
            description,
            durationInDays,
            amountToRaise
        );
    }

    function returnAllCampaigns() external view returns(Campaign[] memory){
        return campaigns;
    }
}