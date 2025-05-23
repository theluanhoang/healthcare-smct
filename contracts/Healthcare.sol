// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Healthcare {
    enum Role { NONE, PATIENT, DOCTOR }
    enum RecordType { NONE, EXAMINATION_RECORD, TEST_RESULT, PRESCRIPTION }

    struct User {
        Role role;
        bool isVerified;
        string ipfsHash;
        string fullName;
        string email;
    }

    struct MedicalRecord {
        address patient;
        address doctor;
        string ipfsHash;
        RecordType recordType;
        uint256 timestamp;
        bool isApproved;
    }

    struct SharedRecord {
        address patient;
        address doctor;
        string ipfsHash;
        RecordType recordType;
        uint256 timestamp;
        string notes;
    }

    address[] public userAddresses;
    mapping(address => User) public users;
    mapping(address => uint256) public verificationVotes;
    MedicalRecord[] public medicalRecords;
    SharedRecord[] public sharedRecords;
    uint256 public verifiedDoctorCount;

    event UserRegistered(address indexed user, Role role, string fullName);
    event DoctorVerified(address indexed doctor, string fullName);
    event MedicalRecordAdded(uint256 indexed recordIndex, address indexed patient, address indexed doctor, string ipfsHash);
    event MedicalRecordApproved(uint256 indexed recordIndex, address indexed patient);
    event MedicalRecordShared(uint256 indexed recordIndex, address indexed patient, address indexed doctor, string ipfsHash);

    constructor() {
        userAddresses.push(msg.sender);
        users[msg.sender] = User(Role.DOCTOR, true, "", "Admin Doctor", "admin@healthcare.com");
        verificationVotes[msg.sender] = 1;
        verifiedDoctorCount = 1;
        emit UserRegistered(msg.sender, Role.DOCTOR, "Admin Doctor");
        emit DoctorVerified(msg.sender, "Admin Doctor");
    }

    function register(string memory fullName, string memory email, Role role, string memory ipfsHash) public {
        require(users[msg.sender].role == Role.NONE, "User already registered");
        require(role == Role.PATIENT || role == Role.DOCTOR, "Invalid role");

        users[msg.sender] = User(role, role == Role.PATIENT, ipfsHash, fullName, email);
        userAddresses.push(msg.sender);
        emit UserRegistered(msg.sender, role, fullName);
    }

    function voteForDoctor(address doctorAddress) public {
        require(users[msg.sender].role == Role.DOCTOR && users[msg.sender].isVerified, "Only verified doctors can vote");
        require(users[doctorAddress].role == Role.DOCTOR && !users[doctorAddress].isVerified, "Invalid doctor");
        require(verificationVotes[doctorAddress] < verifiedDoctorCount, "Doctor already verified");

        verificationVotes[doctorAddress]++;
        if (verificationVotes[doctorAddress] >= (verifiedDoctorCount / 2) + 1) {
            users[doctorAddress].isVerified = true;
            verifiedDoctorCount++;
            emit DoctorVerified(doctorAddress, users[doctorAddress].fullName);
        }
    }

    function addMedicalRecord(address patient, string memory ipfsHash, RecordType recordType) public {
        require(users[msg.sender].role == Role.DOCTOR && users[msg.sender].isVerified, "Only verified doctors can add records");
        require(users[patient].role == Role.PATIENT && users[patient].isVerified, "Invalid patient");
        require(recordType != RecordType.NONE, "Invalid record type");

        medicalRecords.push(MedicalRecord(patient, msg.sender, ipfsHash, recordType, block.timestamp, false));
        emit MedicalRecordAdded(medicalRecords.length - 1, patient, msg.sender, ipfsHash);
    }

    function approveMedicalRecord(uint256 recordIndex) public {
        require(recordIndex < medicalRecords.length, "Invalid record index");
        MedicalRecord storage record = medicalRecords[recordIndex];
        require(msg.sender == record.patient, "Only patient can approve");
        require(!record.isApproved, "Record already approved");

        record.isApproved = true;
        emit MedicalRecordApproved(recordIndex, msg.sender);
    }

    function shareMedicalRecord(address doctor, string memory ipfsHash, RecordType recordType, string memory notes) public {
        require(users[msg.sender].role == Role.PATIENT && users[msg.sender].isVerified, "Only verified patients can share");
        require(users[doctor].role == Role.DOCTOR && users[doctor].isVerified, "Invalid doctor");
        require(recordType != RecordType.NONE, "Invalid record type");

        sharedRecords.push(SharedRecord(msg.sender, doctor, ipfsHash, recordType, block.timestamp, notes));
        emit MedicalRecordShared(sharedRecords.length - 1, msg.sender, doctor, ipfsHash);
    }

    function getUser(address userAddress) public view returns (Role, bool, string memory, string memory, string memory) {
        User memory user = users[userAddress];
        return (user.role, user.isVerified, user.ipfsHash, user.fullName, user.email);
    }

    function getAllDoctors() public view returns (address[] memory, bool[] memory, string[] memory, string[] memory) {
        uint256 doctorCount = 0;
        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (users[userAddresses[i]].role == Role.DOCTOR) {
                doctorCount++;
            }
        }

        address[] memory addresses = new address[](doctorCount);
        bool[] memory isVerified = new bool[](doctorCount);
        string[] memory fullNames = new string[](doctorCount);
        string[] memory ipfsHashes = new string[](doctorCount);
        uint256 index = 0;

        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (users[userAddresses[i]].role == Role.DOCTOR) {
                addresses[index] = userAddresses[i];
                isVerified[index] = users[userAddresses[i]].isVerified;
                fullNames[index] = users[userAddresses[i]].fullName;
                ipfsHashes[index] = users[userAddresses[i]].ipfsHash;
                index++;
            }
        }

        return (addresses, isVerified, fullNames, ipfsHashes);
    }

    function getMedicalRecords(address patient) public view returns (MedicalRecord[] memory) {
        uint256 recordCount = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].patient == patient) {
                recordCount++;
            }
        }

        MedicalRecord[] memory result = new MedicalRecord[](recordCount);
        uint256 index = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].patient == patient) {
                result[index] = medicalRecords[i];
                index++;
            }
        }
        return result;
    }

    function getMedicalRecordsByDoctor(address doctor) public view returns (MedicalRecord[] memory) {
        uint256 recordCount = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].doctor == doctor) {
                recordCount++;
            }
        }

        MedicalRecord[] memory result = new MedicalRecord[](recordCount);
        uint256 index = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].doctor == doctor) {
                result[index] = medicalRecords[i];
                index++;
            }
        }
        return result;
    }

    function getAllMedicalRecords() public view returns (MedicalRecord[] memory) {
        return medicalRecords;
    }

    function getMedicalRecordsByType(address patient, RecordType recordType) public view returns (MedicalRecord[] memory) {
        require(recordType != RecordType.NONE, "Invalid record type");

        uint256 recordCount = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].patient == patient && medicalRecords[i].recordType == recordType) {
                recordCount++;
            }
        }

        MedicalRecord[] memory result = new MedicalRecord[](recordCount);
        uint256 index = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].patient == patient && medicalRecords[i].recordType == recordType) {
                result[index] = medicalRecords[i];
                index++;
            }
        }
        return result;
    }

    function getPendingRecords(address patient) public view returns (MedicalRecord[] memory) {
        uint256 recordCount = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].patient == patient && !medicalRecords[i].isApproved) {
                recordCount++;
            }
        }

        MedicalRecord[] memory result = new MedicalRecord[](recordCount);
        uint256 index = 0;
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].patient == patient && !medicalRecords[i].isApproved) {
                result[index] = medicalRecords[i];
                index++;
            }
        }
        return result;
    }

    function getPatientSharedRecords(address patient) public view returns (SharedRecord[] memory) {
        uint256 recordCount = 0;
        for (uint256 i = 0; i < sharedRecords.length; i++) {
            if (sharedRecords[i].patient == patient) {
                recordCount++;
            }
        }

        SharedRecord[] memory result = new SharedRecord[](recordCount);
        uint256 index = 0;
        for (uint256 i = 0; i < sharedRecords.length; i++) {
            if (sharedRecords[i].patient == patient) {
                result[index] = sharedRecords[i];
                index++;
            }
        }
        return result;
    }

    function getVerifiedDoctorCount() public view returns (uint256) {
        return verifiedDoctorCount;
    }

    function getUserAddressesLength() public view returns (uint256) {
        return userAddresses.length;
    }
}