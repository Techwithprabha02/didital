// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Digital Will Contract
 * @dev A blockchain-based smart contract for creating and managing digital wills
 * @author Digital Will Contract Team
 */
contract Project {
    
    // Struct to represent a Digital Will
    struct DigitalWill {
        address testator;           // Person creating the will
        string willDocument;        // IPFS hash or encrypted content of the will
        uint256 activationTime;     // Timestamp when will becomes executable
        bool isActive;             // Current status of the will
        bool isExecuted;           // Whether the will has been executed
        address[] beneficiaries;   // List of beneficiary addresses
        uint256[] inheritanceShares; // Percentage shares for each beneficiary
        uint256 totalAssets;       // Total ETH locked in the will
        uint256 creationTimestamp; // When the will was created
    }
    
    // Mapping from testator address to their digital will
    mapping(address => DigitalWill) public digitalWills;
    
    // Mapping to check if an address has created a will
    mapping(address => bool) public hasCreatedWill;
    
    // Events for transparency and logging
    event WillCreated(
        address indexed testator,
        uint256 activationTime,
        uint256 totalAssets,
        address[] beneficiaries,
        uint256[] shares
    );
    
    event WillExecuted(
        address indexed testator,
        uint256 distributedAmount,
        address[] beneficiaries,
        uint256[] amounts
    );
    
    event WillModified(
        address indexed testator,
        uint256 newActivationTime,
        string newDocument
    );
    
    // Modifiers for access control
    modifier onlyTestator() {
        require(hasCreatedWill[msg.sender], "No will found for this address");
        require(digitalWills[msg.sender].testator == msg.sender, "Unauthorized access");
        _;
    }
    
    modifier willNotExecuted() {
        require(!digitalWills[msg.sender].isExecuted, "Will already executed");
        _;
    }
    
    modifier validBeneficiariesAndShares(address[] memory _beneficiaries, uint256[] memory _shares) {
        require(_beneficiaries.length > 0, "At least one beneficiary required");
        require(_beneficiaries.length == _shares.length, "Mismatched beneficiaries and shares");
        
        uint256 totalShares = 0;
        for(uint256 i = 0; i < _shares.length; i++) {
            require(_beneficiaries[i] != address(0), "Invalid beneficiary address");
            require(_shares[i] > 0, "Share must be greater than zero");
            totalShares += _shares[i];
        }
        require(totalShares == 100, "Total shares must equal 100%");
        _;
    }
    
    /**
     * @dev Core Function 1: Create a new digital will
     * @param _willDocument IPFS hash or encrypted content of the will
     * @param _activationTime Timestamp when the will becomes executable
     * @param _beneficiaries Array of beneficiary addresses
     * @param _inheritanceShares Array of percentage shares (must sum to 100)
     */
    function createDigitalWill(
        string memory _willDocument,
        uint256 _activationTime,
        address[] memory _beneficiaries,
        uint256[] memory _inheritanceShares
    ) external payable validBeneficiariesAndShares(_beneficiaries, _inheritanceShares) {
        require(!hasCreatedWill[msg.sender], "Will already exists for this address");
        require(_activationTime > block.timestamp, "Activation time must be in future");
        require(msg.value > 0, "Must send ETH to fund the will");
        require(bytes(_willDocument).length > 0, "Will document cannot be empty");
        
        // Create new digital will
        DigitalWill storage newWill = digitalWills[msg.sender];
        newWill.testator = msg.sender;
        newWill.willDocument = _willDocument;
        newWill.activationTime = _activationTime;
        newWill.isActive = true;
        newWill.isExecuted = false;
        newWill.beneficiaries = _beneficiaries;
        newWill.inheritanceShares = _inheritanceShares;
        newWill.totalAssets = msg.value;
        newWill.creationTimestamp = block.timestamp;
        
        hasCreatedWill[msg.sender] = true;
        
        emit WillCreated(msg.sender, _activationTime, msg.value, _beneficiaries, _inheritanceShares);
    }
    
    /**
     * @dev Core Function 2: Execute the digital will and distribute assets
     * @param _testatorAddress Address of the testator whose will to execute
     */
    function executeDigitalWill(address _testatorAddress) external {
        require(hasCreatedWill[_testatorAddress], "No will exists for this address");
        
        DigitalWill storage will = digitalWills[_testatorAddress];
        require(will.isActive, "Will is not active");
        require(!will.isExecuted, "Will has already been executed");
        require(block.timestamp >= will.activationTime, "Will activation time not reached");
        require(will.totalAssets > 0, "No assets available for distribution");
        
        uint256 totalAssets = will.totalAssets;
        address[] memory beneficiaries = will.beneficiaries;
        uint256[] memory shares = will.inheritanceShares;
        uint256[] memory distributedAmounts = new uint256[](beneficiaries.length);
        
        // Mark will as executed to prevent reentrancy
        will.isExecuted = true;
        will.totalAssets = 0;
        
        // Distribute assets to beneficiaries
        for (uint256 i = 0; i < beneficiaries.length; i++) {
            uint256 inheritanceAmount = (totalAssets * shares[i]) / 100;
            distributedAmounts[i] = inheritanceAmount;
            
            if (inheritanceAmount > 0) {
                (bool success, ) = beneficiaries[i].call{value: inheritanceAmount}("");
                require(success, "Asset transfer failed");
            }
        }
        
        emit WillExecuted(_testatorAddress, totalAssets, beneficiaries, distributedAmounts);
    }
    
    /**
     * @dev Core Function 3: Modify an existing digital will
     * @param _newWillDocument Updated IPFS hash or encrypted content
     * @param _newActivationTime New activation timestamp
     * @param _newBeneficiaries Updated array of beneficiary addresses
     * @param _newInheritanceShares Updated array of percentage shares
     */
    function modifyDigitalWill(
        string memory _newWillDocument,
        uint256 _newActivationTime,
        address[] memory _newBeneficiaries,
        uint256[] memory _newInheritanceShares
    ) external payable onlyTestator willNotExecuted validBeneficiariesAndShares(_newBeneficiaries, _newInheritanceShares) {
        require(_newActivationTime > block.timestamp, "New activation time must be in future");
        require(bytes(_newWillDocument).length > 0, "Will document cannot be empty");
        
        DigitalWill storage will = digitalWills[msg.sender];
        
        // Add any additional funds sent with the modification
        if (msg.value > 0) {
            will.totalAssets += msg.value;
        }
        
        // Update will details
        will.willDocument = _newWillDocument;
        will.activationTime = _newActivationTime;
        will.beneficiaries = _newBeneficiaries;
        will.inheritanceShares = _newInheritanceShares;
        
        emit WillModified(msg.sender, _newActivationTime, _newWillDocument);
    }
    
    // View Functions
    

    function getWillDetails(address _testator) external view returns (
        address testator,
        string memory willDocument,
        uint256 activationTime,
        bool isActive,
        bool isExecuted,
        address[] memory beneficiaries,
        uint256[] memory inheritanceShares,
        uint256 totalAssets,
        uint256 creationTimestamp
    ) {
        require(hasCreatedWill[_testator], "No will exists for this address");
        
        DigitalWill storage will = digitalWills[_testator];
        return (
            will.testator,
            will.willDocument,
            will.activationTime,
            will.isActive,
            will.isExecuted,
            will.beneficiaries,
            will.inheritanceShares,
            will.totalAssets,
            will.creationTimestamp
        );
    }
    
    /**
     * @dev Check if a will is ready for execution
     * @param _testator Address of the testator
     * @return Whether the will can be executed
     */
    function isWillExecutable(address _testator) external view returns (bool) {
        if (!hasCreatedWill[_testator]) return false;
        
        DigitalWill storage will = digitalWills[_testator];
        return (
            will.isActive &&
            !will.isExecuted &&
            block.timestamp >= will.activationTime &&
            will.totalAssets > 0
        );
    }
    
    /**
     * @dev Get current blockchain timestamp
     * @return Current block timestamp
     */
    function getCurrentTime() external view returns (uint256) {
        return block.timestamp;
    }
    
    // Emergency function
    
    /**
     * @dev Emergency withdrawal function for testator
     * @notice Can only be called before activation time
     */
    function emergencyWithdrawal() external onlyTestator willNotExecuted {
        DigitalWill storage will = digitalWills[msg.sender];
        require(block.timestamp < will.activationTime, "Cannot withdraw after activation time");
        require(will.totalAssets > 0, "No assets to withdraw");
        
        uint256 withdrawalAmount = will.totalAssets;
        will.totalAssets = 0;
        will.isActive = false;
        
        (bool success, ) = msg.sender.call{value: withdrawalAmount}("");
        require(success, "Emergency withdrawal failed");
    }
}
