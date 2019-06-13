pragma solidity >=0.4.25 <0.6.0;

import "./Ownable.sol";
import "./ProjectHubContract.sol";

/**
 * @title ProjectContract
 * @author Nils Kirchhof
 * @notice The ProjectContract is a contract for a specific project, founded by the owner
 * of the contract. Users can invest into the project to become investors. The owner can add
 * new options which tell the user how much ether is needed to become an investor. The owner can
 * make a request to retrive a set amount of ether to use for expenses of the project. The
 * investors can vote on these requests and reject it if they think the reason given is fraudulent.
 */
contract ProjectContract is Ownable{

    string projectTitle;
    string projectDescription;
    uint backerOptionsID = 1;
    bool wasFirstRequestGiven = false;
    bool backingAddingPeriodeIsOver = false;
    uint fundingGoal;
    uint fundingClosingDate;
    Request currentRequest;
    ProjectHubContract projectHub;
    BackingOption[] backingOptions;
    address payable[] investorAddresses;
    mapping(address => Investor) Investors;


    struct BackingOption{
        string optionTitle;
        string optionDescription;
        uint optionAmountEther;
        int optionAvailability;
        uint id;
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
        address payable investorAddress;
        uint choosenBackingOptionID;
        Vote currentVote;
        int investorExists; //is needed because a mapping contains "all" possible keys
    }

    enum Vote{
        Accepted,
        Rejected,
        NoVoteGiven
    }

    /**
    * @notice Contrutor of the new ProjectContract, usually called by the ProjectContractHub. Creates the new ProjectContract
    * and sets the caller of the addNewProject() function in the ProjectContractHub as the owner of this new ProjectContract.
    * @param _owner The caller of addNowProject(), which will become the owner of the new ProjectContract
    * @param _projectTitle The new title for the ProjectContract
    * @param _projectHub Reference to the ProjectHubContract
    * @param _fundingGoal Goal in Wei there the funding is reached
    * @param _fundingCloseDate Date where the funding goal need to be met
    */
    constructor(address _owner, string memory _projectTitle, string memory _projectDescription, uint _fundingGoal,
                uint _fundingCloseDate, ProjectHubContract _projectHub) public
    {
        owner = _owner;
        projectTitle = _projectTitle;
        projectDescription = _projectDescription;
        fundingGoal = _fundingGoal;
        fundingClosingDate = _fundingCloseDate;
        projectHub = _projectHub;
    }

    /**
    * @notice Adds a new backing option to the ProjectContract. This is only possible while the
    * backing option adding periode is not over, otherwise an exeption is thown. Only callable by the
    * owner.
    * @param _optionTitle The title of the new backing option
    * @param _optionDescription The discription of the new backing option
    * @param _optionAmountWei The amount of Ether the investor has to pay for this backing option in Wei.
    * @param _optionAvailability The number of investors who can take this option before it is sold out
    */
    function addBackingOption(string memory _optionTitle, string memory _optionDescription,
    uint _optionAmountWei, int _optionAvailability) public onlyOwner
    {
        require(!backingAddingPeriodeIsOver, "The periode of adding backing options to the contract is over");
        BackingOption memory backingOption = BackingOption(_optionTitle, _optionDescription, _optionAmountWei,
            _optionAvailability, backerOptionsID);
        backingOptions.push(backingOption);
        backerOptionsID++;
    }

    /**
    * @notice This function closes the backing option adding periode. After is has been closed it can not
    * be opened again. After the periode was closed, investors are able to invest into the Project Contract.
    */
    function closeAddingBackingOptionPeriode() public onlyOwner
    {
        backingAddingPeriodeIsOver = true;
    }

    /**
    * @notice This function return the number of backing options inside the ProjectContract.
    * @return Number of backing options inside the ProjectContracts
    */
    function getBackingOptionsCount()public view returns (uint){
        return backingOptions.length;
    }

    /**
    * @notice This function returns a specific backing option
    * given an index. It is used in conjunction with getBackingOptionsCount() to retrive
    * all avaiable backing options inside ProjectContracs. It throws
    * exception if the index if larger then the list size.
    * @param index Index of the backing option
    * @return Title of the backing option
    * @return Description of the backing option
    * @return Price in Wei of the backing option
    * @return Availability of the backing option
    * @return ID of the backing option
    */
    function getBackingOption(uint index) public view returns(string memory, string memory, uint, int, uint)
    {
        require(index < backingOptions.length, "The index is out of bounds");
        return (backingOptions[index].optionTitle, backingOptions[index].optionDescription,
            backingOptions[index].optionAmountEther, backingOptions[index].optionAvailability,
            backingOptions[index].id);
    }

    /**
    * @notice This function adds a new investor to the ProjectContract. It thows an exeption if the
    * adding backing options persiode is not over, the specified backing option wasn't found, the
    * sended ether didn't match the backing options price, the backing option is no longer available or
    * if the investor has already invested. Otherwise the investor is added and the backing option availablity
    * is decresed by one. The sended ether amount is added to the contract.
    * @param backingOptionID ID of the backing option the investor wants to invest in
    */
    function addInvestor(uint backingOptionID) public payable
    {
        require(backingAddingPeriodeIsOver, "The adding backing option periode is not over yet");
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

        require(block.timestamp < fundingClosingDate, "The funding is closed, date is reached");

        Investors[msg.sender] = Investor(msg.sender, backingOptionID, Vote.NoVoteGiven, 1);
        projectHub.addProjectToInvestor(msg.sender, address(this), owner, projectTitle, projectDescription, fundingGoal, fundingClosingDate);
        backingOptions[optionIndex].optionAvailability--;
    }

    /**
    * @notice This function return the number of investors of the ProjectContract
    * @return Number of investors
    */
    function getInvestorCount() public view returns (uint)
    {
        return investorAddresses.length;
    }

    /**
    * @notice This function allows the owner of the ProjectContract to add an request for payout. As
    * long as a request is active, adding new requests throws an exception. The funding Goal needs to
    * be reached before a request can be requested
    * @param _requestTitle Title of the new request
    * @param _requestDescription Description of the new request
    * @param _valideUntil Date till which the request is valide, in seconds since 1970
    * @param _amount The amount the owner requested in Wei
    */
    function addRequest(string memory _requestTitle, string memory _requestDescription,
    uint256 _valideUntil, uint _amount) public onlyOwner
    {
        require(fundingGoal < address(this).balance, "Funding Goal was not reached yet");

        if(wasFirstRequestGiven){
            require(currentRequest.valideUntil < block.timestamp, "Current Request is still valide");
        }
        wasFirstRequestGiven = true;
        currentRequest = Request(_requestTitle, _requestDescription, _valideUntil, _amount, 0, 0, false);
        for(uint i = 0; i<investorAddresses.length; i++){
            Investors[investorAddresses[i]].currentVote = Vote.NoVoteGiven;
        }
    }

    /**
    * @notice The function allows the investors to vote on the current request. If the caller of this
    * function is not an investor or this the caller has already voted, an exception is thrown.
    * @param isAccepted Bool parameter where true is accpetance and false is rejection of the request
    */
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

    /**
    * @notice This function return the current active request
    * @return Title of the request
    * @return Description of the request
    * @return Timestamp until the request is valide in seconds since 1970
    * @return Requested amount of ehter in Wei
    * @return Number of votes for accept
    * @return Number of votes for reject
    * @return Boolean for if the request was payed out
    */
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

    /**
    * @notice This function allows the owner to pay out the amount they requested in the request.
    * If the needed vote where not reached or if the request was already payed out, an exceptin
    * is thrown.
    */
    function requestPayout() public onlyOwner
    {
        require(((currentRequest.numberAcceptedVotes / 2) > int256 (investorAddresses.length)), "Majority was not reached");

        require(!currentRequest.wasPayed, "Request was already payed out");
        
        msg.sender.transfer(currentRequest.amount);
        currentRequest.wasPayed = true;
        wasFirstRequestGiven = false;
    }

    /**
    * @notice The function allows the payed in ether to by payed back if the funding goal was
    * not reached and the funding periode is over. Anyone can trigger this function.
    */
    function requestPayback() public
    {
        require(fundingGoal > address(this).balance, "The funding goal was reached");

        require(block.timestamp > fundingClosingDate, "The funding periode is not over jet");

        for(uint i = 0; i<investorAddresses.length; i++){
            uint choosenBackingOptionIndex = Investors[investorAddresses[i]].choosenBackingOptionID - 1;
            address payable investorAddress = investorAddresses[i];
            uint backingAmount = backingOptions[choosenBackingOptionIndex].optionAmountEther;
            investorAddress.transfer(backingAmount);
        }

    }

    function () external payable {
    }
}