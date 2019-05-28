pragma solidity >=0.4.25 <0.6.0;

import "./Ownable.sol";
import "./ProjectHubContract.sol";

contract ProjectContract is Ownable{

    string projectTitle;
    string projectDescription;
    int backerOptionsID = 1;
    bool wasFirstRequestGiven = false;
    Request currentRequest;
    ProjectHubContract projectHub;
    BackingOption[] backingOptions;
    address[] investorAddresses;
    mapping(address => Investor) Investors;


    struct BackingOption{
        string optionTitle;
        string optionDescription;
        uint optionAmountEther;
        int optionAvailability;
        int id;
    }

    struct Request{
        string requestTitle;
        string requestDescription;
        uint valideUntil;
        uint amount;
        int numberAcceptedVotes;
        int numberRejectedVotes;
        bool wasPayed;
    }

    struct Investor{
        address investorAddress;
        int choosenBackingOptionID;
        Vote currentVote;
        int investorExists; //is needed because a mapping contains all possible keys
    }

    enum Vote{
        Accepted,
        Rejected,
        NoVoteGiven
    }

    constructor(address _owner, string memory _projectTitle, string memory _projectDescription, ProjectHubContract _projectHub) public
    {
        owner = _owner;
        projectTitle = _projectTitle;
        projectDescription = _projectDescription;
        projectHub = _projectHub;
    }

    function addBackingOption(string memory _optionTitle, string memory _optionDescription,
    uint _optionAmountEther, int _optionAvailability) public onlyOwner
    {
        BackingOption memory backingOption = BackingOption(_optionTitle, _optionDescription, _optionAmountEther,
            _optionAvailability, backerOptionsID);
        backingOptions.push(backingOption);
        backerOptionsID++;
    }

    function getBackingOption(uint index) public view returns(string memory, string memory, uint, int, int)
    {
        if(index >= backingOptions.length){
            return ("", "", 0, 0, 0);
        }
        return (backingOptions[index].optionTitle, backingOptions[index].optionDescription,
            backingOptions[index].optionAmountEther, backingOptions[index].optionAvailability,
            backingOptions[index].id);
    }

    function getBackingOptionsCount()public view returns (uint){
        return backingOptions.length;
    }

    function addInvestor(int backingOptionID) public payable returns (bool)
    {
        uint  optionIndex;
        for (uint i = 0; i<backingOptions.length; i++){
            if(backingOptions[i].id == backingOptionID){
                optionIndex = i;
                break;
            }
        }

        require(backingOptions[optionIndex].id != 0, "BackingOption was not found");

        require(msg.value == backingOptions[optionIndex].optionAmountEther, "Send Ether amount is not equal to backing price");

        require(backingOptions[optionIndex].optionAvailability > 0, "Choosen Option is no longer available");

        require(Investors[msg.sender].investorExists == 0, "Investor has already invested");

        Investors[msg.sender] = Investor(msg.sender, backingOptionID, Vote.NoVoteGiven, 1);
        projectHub.addProjectToInvestor(msg.sender, address(this), owner, projectTitle, projectDescription);
        backingOptions[optionIndex].optionAvailability--;
        return true;
    }

    function getInvestorCount() public view returns (uint)
    {
        return investorAddresses.length;
    }

    function addRequest(string memory _requestTitle, string memory _requestDescription,
    uint256 _valideUntil, uint _amount) public onlyOwner returns (bool)
    {
        if(wasFirstRequestGiven){
            require(currentRequest.valideUntil < block.timestamp, "Current Request is still valide");
        }
        wasFirstRequestGiven = true;
        currentRequest = Request(_requestTitle, _requestDescription, _valideUntil, _amount, 0, 0, false);
        for(uint i = 0; i<investorAddresses.length; i++){
            Investors[investorAddresses[i]].currentVote = Vote.NoVoteGiven;
        }
        return true;
    }

    function voteForCurrentRequest(bool isAccepted) public
    {

        require(Investors[msg.sender].investorExists != 0, "Sender address is not investor");

        require(Investors[msg.sender].currentVote == Vote.NoVoteGiven, "Investor has already voted");

        if(isAccepted){
            Investors[msg.sender].currentVote = Vote.Accepted;
            currentRequest.numberAcceptedVotes++;
        }
        else{
            Investors[msg.sender].currentVote = Vote.Rejected;
            currentRequest.numberRejectedVotes++;
        }
    }

    function getCurrentRequest() public view returns (string memory requestTitle,
            string memory requestDescription,
            uint256 valideUntil,
            uint amount,
            int numberAcceptedVotes,
            int numberRejectedVotes,
            bool wasPayed
        )
    {
        return (currentRequest.requestTitle,
            currentRequest.requestDescription,
            currentRequest.valideUntil,
            currentRequest.amount,
            currentRequest.numberAcceptedVotes,
            currentRequest.numberRejectedVotes,
            currentRequest.wasPayed
        );
    }

    function requestPayout() public onlyOwner
    {
        require(((currentRequest.numberAcceptedVotes / 2) > int256 (investorAddresses.length)), "Majority was not reached");
        
        require(!currentRequest.wasPayed, "Request was already payed out");
        
        msg.sender.transfer(currentRequest.amount);
        currentRequest.wasPayed = true;
        wasFirstRequestGiven = false;
    }

    function () external payable {
    }
}
