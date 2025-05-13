// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

contract Healthcare {
    enum Role { NONE, PATIENT, DOCTOR, ADMIN }

    struct User {
        Role role;
        bool isVerified;
        string ipfsHash;
        string fullName;
        string email;
    }

    struct MedicalRecord {
        string ipfsHash;
        address doctor;
        uint256 timestamp;
    }

    address public admin;
    address[] public userAddresses;

    mapping(address => User) public users;
    mapping(address => MedicalRecord[]) public medicalRecords;
    mapping(address => address[]) public accessList;

    event UserRegistered(address indexed user, Role role, string ipfsHash);
    event DoctorVerified(address indexed doctor);
    event MedicalRecordAdded(address indexed patient, string ipfsHash, address indexed doctor);
    event AccessGranted(address indexed patient, address indexed doctor);
    event UserRemoved(address indexed user);
    event AdminTransferred(address indexed oldAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }

    modifier onlyPatient() {
        require(users[msg.sender].role == Role.PATIENT, "Only patients can call this function");
        _;
    }

    modifier onlyVerifiedDoctor() {
        require(users[msg.sender].role == Role.DOCTOR && users[msg.sender].isVerified, "Only verified doctors can call this function");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function register(string memory fullName, string memory email, Role role, string memory ipfsHash) external {
        require(users[msg.sender].role == Role.NONE, "User already registered");
        require(role == Role.PATIENT || role == Role.DOCTOR, "Invalid role");
        
        bool isVerified = (role == Role.PATIENT);
        users[msg.sender] = User(role, isVerified, ipfsHash, fullName, email);
        userAddresses.push(msg.sender);

        emit UserRegistered(msg.sender, role, ipfsHash);
    }

    function verifyDoctor(address doctorAddress) external onlyAdmin {
        require(users[doctorAddress].role == Role.DOCTOR, "User is not a doctor");
        require(!users[doctorAddress].isVerified, "Doctor already verified");

        users[doctorAddress].isVerified = true;
        emit DoctorVerified(doctorAddress);
    }

    function addMedicalRecord(address patientAddress, string memory ipfsHash) external onlyVerifiedDoctor {
        require(users[patientAddress].role == Role.PATIENT, "Invalid patient address");

        medicalRecords[patientAddress].push(MedicalRecord({
            ipfsHash: ipfsHash,
            doctor: msg.sender,
            timestamp: block.timestamp
        }));

        emit MedicalRecordAdded(patientAddress, ipfsHash, msg.sender);
    }

    function grantAccess(address doctorAddress) external onlyPatient {
        require(users[doctorAddress].role == Role.DOCTOR && users[doctorAddress].isVerified, "Invalid or unverified doctor");

        for (uint i = 0; i < accessList[msg.sender].length; i++) {
            if (accessList[msg.sender][i] == doctorAddress) {
                revert("Doctor already has access");
            }
        }
        
        accessList[msg.sender].push(doctorAddress);
        emit AccessGranted(msg.sender, doctorAddress);
    }

    function getUser(address userAddress) external view returns (string memory fullName, string memory email, Role role, bool isVerified, string memory ipfsHash) {
        User memory user = users[userAddress];
        return (user.fullName, user.email, user.role, user.isVerified, user.ipfsHash);
    }

    function getMedicalRecords(address patientAddress) external view returns (MedicalRecord[] memory) {
        require(
            msg.sender == patientAddress || 
            users[msg.sender].role == Role.DOCTOR && hasAccess(patientAddress, msg.sender),
            "No access to medical records"
        );

        return medicalRecords[patientAddress];
    }

    function hasAccess(address patientAddress, address doctorAddress) public view returns (bool) {
        for (uint i = 0; i < accessList[patientAddress].length; i++) {
            if (accessList[patientAddress][i] == doctorAddress) {
                return true;
            }
        }
        return false;
    }

    function getAccessList(address patientAddress) external view returns (address[] memory) {
        require(msg.sender == patientAddress, "Only patient can view their access list");
        return accessList[patientAddress];
    }

    function getAllUsers() external view onlyAdmin returns (address[] memory addresses, User[] memory userData) {
        addresses = userAddresses;
        User[] memory allUsers = new User[](userAddresses.length);
        for (uint i = 0; i < userAddresses.length; i++) {
            allUsers[i] = users[userAddresses[i]];
        }
        return (addresses, allUsers);
    }

    function removeUser(address userAddress) external onlyAdmin {
        require(userAddress != admin, "Cannot remove admin");
        require(users[userAddress].role != Role.NONE, "User not registered");

        delete users[userAddress];
        delete medicalRecords[userAddress];
        delete accessList[userAddress];

        for (uint i = 0; i < userAddresses.length; i++) {
            if (userAddresses[i] == userAddress) {
                userAddresses[i] = userAddresses[userAddresses.length - 1];
                userAddresses.pop();
                break;
            }
        }

        emit UserRemoved(userAddress);
    }

    function transferAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "Invalid new admin address");
        require(newAdmin != admin, "New admin must be different");

        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminTransferred(oldAdmin, newAdmin);
    }

    function getMedicalRecordsByAdmin(address patientAddress) external view onlyAdmin returns (MedicalRecord[] memory) {
        return medicalRecords[patientAddress];
    }
}