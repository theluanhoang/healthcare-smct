// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Healthcare is ERC20, Ownable, Pausable {
    // Custom errors for better revert handling
    error InvalidRecordIndex();
    error OnlyPatientCanApprove(address user);
    error RecordAlreadyApproved();
    error InvalidRole();
    error UserAlreadyRegistered();
    error InvalidDoctor();
    error InvalidPatient();
    error InvalidRecordType();
    error OnlyVerifiedPatient();
    error OnlyVerifiedDoctor();
    error AccessAlreadyGranted();
    error AccessNotGranted();
    error InvalidAppointmentId();
    error AppointmentNotFound();
    error OnlyAssignedDoctor();

    enum Role { NONE, PATIENT, DOCTOR }
    enum RecordType { NONE, EXAMINATION_RECORD, TEST_RESULT, PRESCRIPTION }
    enum AppointmentStatus { PENDING, APPROVED, REJECTED, COMPLETED, CANCELLED }

    // Token reward structures
    struct Survey {
        uint256 id;
        string title;
        string ipfsHash;      // Chi tiết khảo sát được lưu trên IPFS
        uint256 reward;       // Số token thưởng cho việc hoàn thành
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        uint256 responseCount;
        Role targetRole;      // Role mục tiêu của khảo sát (PATIENT hoặc DOCTOR)
        mapping(address => bool) hasCompleted;
    }

    struct RewardActivity {
        uint256 id;
        string name;
        string description;
        uint256 reward;
        bool isActive;
        uint256 participantCount;
    }

    struct User {
        Role role;
        bool isVerified;
        string ipfsHash;
        string fullName;
        string email;
        uint256 tokenBalance;      // Số dư token của user
        uint256 totalRewardsEarned; // Tổng số token đã nhận được
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

    struct Appointment {
        uint256 id;
        address patient;
        address doctor;
        string date;
        string time;
        string reason;
        AppointmentStatus status;
        uint256 timestamp;
    }

    struct AvailabilitySlot {
        string date;
        string startTime;
        string endTime;
        bool isBooked;
        uint256 appointmentId;
    }

    address[] public userAddresses;
    mapping(address => User) public users;
    mapping(address => uint256) public verificationVotes;
    MedicalRecord[] public medicalRecords;
    SharedRecord[] public sharedRecords;
    uint256 public verifiedDoctorsCount;

    Appointment[] public appointments;
    mapping(address => AvailabilitySlot[]) public doctorAvailability;
    uint256 public appointmentCounter;

    mapping(address => mapping(address => bool)) public patientDoctorAccess;

    // Token reward mappings
    mapping(uint256 => Survey) public surveys;
    uint256 public surveyCount;
    mapping(uint256 => RewardActivity) public rewardActivities;
    uint256 public activityCount;
    uint256 public tokenToGasRate = 100000; // 100000 token = 1 ETH

    event UserRegistered(address indexed user, Role role, string fullName);
    event DoctorVerified(address indexed doctor, string fullName);
    event MedicalRecordAdded(uint256 indexed recordIndex, address indexed patient, address indexed doctor, string ipfsHash);
    event MedicalRecordApproved(uint256 indexed recordIndex, address indexed patient);
    event MedicalRecordShared(uint256 indexed recordIndex, address indexed patient, address indexed doctor, string ipfsHash);
    event AppointmentCreated(uint256 indexed appointmentId, address indexed patient, address indexed doctor, string date, string time);
    event AppointmentStatusUpdated(uint256 indexed appointmentId, AppointmentStatus status);
    event AvailabilityAdded(address indexed doctor, string date, string startTime, string endTime);
    event AccessGranted(address indexed patient, address indexed doctor);
    event AccessRevoked(address indexed patient, address indexed doctor);
    event SurveyCreated(uint256 indexed id, string title, uint256 reward, uint256 startTime, uint256 endTime);
    event SurveyCompleted(uint256 indexed surveyId, address indexed user, uint256 reward);
    event ActivityCreated(uint256 indexed id, string name, uint256 reward);
    event ActivityRewardClaimed(uint256 indexed activityId, address indexed user, uint256 reward);
    event TokensExchangedForGas(address indexed user, uint256 tokenAmount, uint256 gasAmount);
    event RewardRateUpdated(uint256 newRate);
    event SurveyStatusUpdated(uint256 surveyId, bool isActive);

    constructor() ERC20("Healthcare Token", "HCT") {
        // Khởi tạo admin với role DOCTOR và token ban đầu
        userAddresses.push(msg.sender);
        users[msg.sender] = User(Role.DOCTOR, true, "", "Admin Doctor", "admin@healthcare.com", 0, 0);
        verificationVotes[msg.sender] = 1;
        verifiedDoctorsCount = 1;
        appointmentCounter = 1;
        
        // Mint initial supply cho admin
        _mint(msg.sender, 1000000 * 10**decimals());
        users[msg.sender].tokenBalance = 1000000 * 10**decimals();
        
        emit UserRegistered(msg.sender, Role.DOCTOR, "Admin Doctor");
        emit DoctorVerified(msg.sender, "Admin Doctor");
    }

    function register(string memory fullName, string memory email, Role role, string memory ipfsHash) public {
        if (users[msg.sender].role != Role.NONE) revert UserAlreadyRegistered();
        if (role != Role.PATIENT && role != Role.DOCTOR) revert InvalidRole();

        users[msg.sender] = User(role, role == Role.PATIENT, ipfsHash, fullName, email, 0, 0);
        userAddresses.push(msg.sender);
        emit UserRegistered(msg.sender, role, fullName);
    }

    function voteForDoctor(address doctorAddress) public {
        if (users[msg.sender].role != Role.DOCTOR || !users[msg.sender].isVerified) revert OnlyVerifiedDoctor();
        if (users[doctorAddress].role != Role.DOCTOR || users[doctorAddress].isVerified) revert InvalidDoctor();
        if (verificationVotes[doctorAddress] >= verifiedDoctorsCount) revert InvalidDoctor();

        verificationVotes[doctorAddress]++;
        if (verificationVotes[doctorAddress] >= (verifiedDoctorsCount / 2) + 1) {
            users[doctorAddress].isVerified = true;
            verifiedDoctorsCount++;
            emit DoctorVerified(doctorAddress, users[doctorAddress].fullName);
        }
    }

    function addMedicalRecord(address patient, string memory ipfsHash, RecordType recordType) public {
        if (users[msg.sender].role != Role.DOCTOR || !users[msg.sender].isVerified) revert OnlyVerifiedDoctor();
        if (users[patient].role != Role.PATIENT || !users[patient].isVerified) revert InvalidPatient();
        if (recordType == RecordType.NONE) revert InvalidRecordType();

        medicalRecords.push(MedicalRecord(patient, msg.sender, ipfsHash, recordType, block.timestamp, false));
        emit MedicalRecordAdded(medicalRecords.length - 1, patient, msg.sender, ipfsHash);
    }

    function approveMedicalRecord(uint256 recordIndex) public {
        if (recordIndex >= medicalRecords.length) revert InvalidRecordIndex();
        MedicalRecord storage record = medicalRecords[recordIndex];
        if (msg.sender != record.patient) revert OnlyPatientCanApprove(msg.sender);
        if (record.isApproved) revert RecordAlreadyApproved();

        record.isApproved = true;
        emit MedicalRecordApproved(recordIndex, msg.sender);
    }

    function shareMedicalRecord(address doctor, string memory ipfsHash, RecordType recordType, string memory notes) public {
        if (users[msg.sender].role != Role.PATIENT || !users[msg.sender].isVerified) revert OnlyVerifiedPatient();
        if (users[doctor].role != Role.DOCTOR || !users[doctor].isVerified) revert InvalidDoctor();
        if (recordType == RecordType.NONE) revert InvalidRecordType();

        sharedRecords.push(SharedRecord(msg.sender, doctor, ipfsHash, recordType, block.timestamp, notes));
        emit MedicalRecordShared(sharedRecords.length - 1, msg.sender, doctor, ipfsHash);
    }

    function grantAccessToDoctor(address doctor) public {
        if (users[msg.sender].role != Role.PATIENT || !users[msg.sender].isVerified) revert OnlyVerifiedPatient();
        if (users[doctor].role != Role.DOCTOR || !users[doctor].isVerified) revert InvalidDoctor();
        if (patientDoctorAccess[msg.sender][doctor]) revert AccessAlreadyGranted();

        patientDoctorAccess[msg.sender][doctor] = true;
        emit AccessGranted(msg.sender, doctor);
    }

    function revokeAccessFromDoctor(address doctor) public {
        if (users[msg.sender].role != Role.PATIENT || !users[msg.sender].isVerified) revert OnlyVerifiedPatient();
        if (!patientDoctorAccess[msg.sender][doctor]) revert AccessNotGranted();

        patientDoctorAccess[msg.sender][doctor] = false;
        emit AccessRevoked(msg.sender, doctor);
    }

    function hasAccessToPatient(address patient, address doctor) public view returns (bool) {
        return patientDoctorAccess[patient][doctor];
    }

    function addAvailabilitySlot(string memory date, string memory startTime, string memory endTime) public {
        if (users[msg.sender].role != Role.DOCTOR || !users[msg.sender].isVerified) revert OnlyVerifiedDoctor();
        
        doctorAvailability[msg.sender].push(AvailabilitySlot(date, startTime, endTime, false, 0));
        emit AvailabilityAdded(msg.sender, date, startTime, endTime);
    }

    function bookAppointment(address doctor, string memory date, string memory time, string memory reason) public {
        if (users[msg.sender].role != Role.PATIENT || !users[msg.sender].isVerified) revert OnlyVerifiedPatient();
        if (users[doctor].role != Role.DOCTOR || !users[doctor].isVerified) revert InvalidDoctor();

        uint256 appointmentId = appointmentCounter++;
        appointments.push(Appointment(appointmentId, msg.sender, doctor, date, time, reason, AppointmentStatus.PENDING, block.timestamp));
        
        emit AppointmentCreated(appointmentId, msg.sender, doctor, date, time);
    }

    function updateAppointmentStatus(uint256 appointmentId, AppointmentStatus status) public {
        if (appointmentId == 0 || appointmentId >= appointmentCounter) revert InvalidAppointmentId();
        
        bool found = false;
        for (uint256 i = 0; i < appointments.length; i++) {
            if (appointments[i].id == appointmentId) {
                if (appointments[i].doctor != msg.sender) revert OnlyAssignedDoctor();
                appointments[i].status = status;
                found = true;
                break;
            }
        }
        if (!found) revert AppointmentNotFound();
        
        emit AppointmentStatusUpdated(appointmentId, status);
    }

    function getAvailabilitySlots(address doctor) public view returns (AvailabilitySlot[] memory) {
        return doctorAvailability[doctor];
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
        if (recordType == RecordType.NONE) revert InvalidRecordType();

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

    function getSharedRecordsByDoctor(address doctor) public view returns (SharedRecord[] memory) {
        uint256 recordCount = 0;
        for (uint256 i = 0; i < sharedRecords.length; i++) {
            if (sharedRecords[i].doctor == doctor) {
                recordCount++;
            }
        }

        SharedRecord[] memory result = new SharedRecord[](recordCount);
        uint256 index = 0;
        for (uint256 i = 0; i < sharedRecords.length; i++) {
            if (sharedRecords[i].doctor == doctor) {
                result[index] = sharedRecords[i];
                index++;
            }
        }
        return result;
    }

    function getAuthorizedPatients(address doctor) public view returns (address[] memory, string[] memory) {
        uint256 patientCount = 0;
        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (users[userAddresses[i]].role == Role.PATIENT && patientDoctorAccess[userAddresses[i]][doctor]) {
                patientCount++;
            }
        }

        address[] memory patientAddresses = new address[](patientCount);
        string[] memory patientNames = new string[](patientCount);
        uint256 index = 0;

        for (uint256 i = 0; i < userAddresses.length; i++) {
            if (users[userAddresses[i]].role == Role.PATIENT && patientDoctorAccess[userAddresses[i]][doctor]) {
                patientAddresses[index] = userAddresses[i];
                patientNames[index] = users[userAddresses[i]].fullName;
                index++;
            }
        }

        return (patientAddresses, patientNames);
    }

    function getAppointmentsByPatient(address patient) public view returns (Appointment[] memory) {
        uint256 appointmentCount = 0;
        for (uint256 i = 0; i < appointments.length; i++) {
            if (appointments[i].patient == patient) {
                appointmentCount++;
            }
        }

        Appointment[] memory result = new Appointment[](appointmentCount);
        uint256 index = 0;
        for (uint256 i = 0; i < appointments.length; i++) {
            if (appointments[i].patient == patient) {
                result[index] = appointments[i];
                index++;
            }
        }
        return result;
    }

    function getAppointmentsByDoctor(address doctor) public view returns (Appointment[] memory) {
        uint256 appointmentCount = 0;
        for (uint256 i = 0; i < appointments.length; i++) {
            if (appointments[i].doctor == doctor) {
                appointmentCount++;
            }
        }

        Appointment[] memory result = new Appointment[](appointmentCount);
        uint256 index = 0;
        for (uint256 i = 0; i < appointments.length; i++) {
            if (appointments[i].doctor == doctor) {
                result[index] = appointments[i];
                index++;
            }
        }
        return result;
    }

    function getDoctorAvailability(address doctor) public view returns (AvailabilitySlot[] memory) {
        return doctorAvailability[doctor];
    }

    function getVerifiedDoctorsCount() public view returns (uint256) {
        return verifiedDoctorsCount;
    }

    function getUserAddressesLength() public view returns (uint256) {
        return userAddresses.length;
    }

    function getRecordIndex(address patient, address doctor, string memory ipfsHash) public view returns (uint256) {
        for (uint256 i = 0; i < medicalRecords.length; i++) {
            if (medicalRecords[i].patient == patient &&
                medicalRecords[i].doctor == doctor &&
                keccak256(bytes(medicalRecords[i].ipfsHash)) == keccak256(bytes(ipfsHash)) &&
                !medicalRecords[i].isApproved) {
                return i;
            }
        }
        revert InvalidRecordIndex();
    }

    // Token reward functions
    function createSurvey(
        string memory title,
        string memory ipfsHash,
        uint256 reward,
        uint256 startTime,
        uint256 endTime,
        Role targetRole
    ) external onlyOwner whenNotPaused {
        require(startTime >= block.timestamp, "Start time must be in the future");
        require(endTime > startTime, "End time must be after start time");
        require(reward > 0, "Reward must be greater than 0");
        require(targetRole == Role.PATIENT || targetRole == Role.DOCTOR, "Invalid target role");

        surveyCount++;
        Survey storage newSurvey = surveys[surveyCount];
        newSurvey.id = surveyCount;
        newSurvey.title = title;
        newSurvey.ipfsHash = ipfsHash;
        newSurvey.reward = reward;
        newSurvey.startTime = startTime;
        newSurvey.endTime = endTime;
        newSurvey.isActive = true;
        newSurvey.responseCount = 0;
        newSurvey.targetRole = targetRole;

        emit SurveyCreated(surveyCount, title, reward, startTime, endTime);
    }

    function completeSurvey(uint256 surveyId, string memory responseHash) external whenNotPaused {
        Survey storage survey = surveys[surveyId];
        require(survey.isActive, "Survey is not active");
        require(block.timestamp >= survey.startTime, "Survey has not started");
        require(block.timestamp <= survey.endTime, "Survey has ended");
        require(!survey.hasCompleted[msg.sender], "Already completed this survey");
        require(users[msg.sender].role == survey.targetRole, "Not authorized for this survey");

        survey.hasCompleted[msg.sender] = true;
        survey.responseCount++;
        
        // Mint tokens và cập nhật số dư
        _mint(msg.sender, survey.reward);
        users[msg.sender].tokenBalance += survey.reward;
        users[msg.sender].totalRewardsEarned += survey.reward;

        emit SurveyCompleted(surveyId, msg.sender, survey.reward);
    }

    function createRewardActivity(
        string memory name,
        string memory description,
        uint256 reward
    ) external onlyOwner whenNotPaused {
        activityCount++;
        rewardActivities[activityCount] = RewardActivity(
            activityCount,
            name,
            description,
            reward,
            true,
            0
        );

        emit ActivityCreated(activityCount, name, reward);
    }

    function rewardForActivity(uint256 activityId, address user) external onlyOwner whenNotPaused {
        RewardActivity storage activity = rewardActivities[activityId];
        require(activity.isActive, "Activity is not active");

        // Mint tokens và cập nhật số dư
        _mint(user, activity.reward);
        users[user].tokenBalance += activity.reward;
        users[user].totalRewardsEarned += activity.reward;
        activity.participantCount++;

        emit ActivityRewardClaimed(activityId, user, activity.reward);
    }

    function exchangeTokensForGas(uint256 tokenAmount) external whenNotPaused {
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(users[msg.sender].tokenBalance >= tokenAmount, "Insufficient token balance");

        // Tính toán số ETH sẽ nhận được (100,000 token = 1 ETH)
        uint256 gasAmount = tokenAmount / tokenToGasRate;
        require(gasAmount > 0, "Exchange amount too small");
        require(address(this).balance >= gasAmount, "Insufficient gas balance in contract");

        // Burn tokens và cập nhật số dư
        _burn(msg.sender, tokenAmount);
        users[msg.sender].tokenBalance -= tokenAmount;

        // Chuyển ETH cho user
        (bool success, ) = payable(msg.sender).call{value: gasAmount}("");
        require(success, "Failed to send ETH");

        emit TokensExchangedForGas(msg.sender, tokenAmount, gasAmount);
    }

    function updateTokenToGasRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be greater than 0");
        tokenToGasRate = newRate;
        emit RewardRateUpdated(newRate);
    }

    // View functions for token rewards
    function getSurveyDetails(uint256 surveyId) external view returns (
        string memory title,
        uint256 reward,
        uint256 startTime,
        uint256 endTime,
        bool isActive,
        uint256 responseCount,
        Role targetRole
    ) {
        Survey storage survey = surveys[surveyId];
        return (
            survey.title,
            survey.reward,
            survey.startTime,
            survey.endTime,
            survey.isActive,
            survey.responseCount,
            survey.targetRole
        );
    }

    function toggleSurveyStatus(uint256 surveyId) external onlyOwner whenNotPaused {
        require(surveyId > 0 && surveyId <= surveyCount, "Invalid survey ID");
        Survey storage survey = surveys[surveyId];
        survey.isActive = !survey.isActive;
        emit SurveyStatusUpdated(surveyId, survey.isActive);
    }

    function hasSurveyCompleted(uint256 surveyId, address user) external view returns (bool) {
        return surveys[surveyId].hasCompleted[user];
    }

    function getTokenBalance(address user) external view returns (uint256) {
        return users[user].tokenBalance;
    }

    function getTotalRewardsEarned(address user) external view returns (uint256) {
        return users[user].totalRewardsEarned;
    }

    // Override transfer functions to update user balances
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        
        // Update user balances
        users[owner].tokenBalance -= amount;
        users[to].tokenBalance += amount;
        
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        
        // Update user balances
        users[from].tokenBalance -= amount;
        users[to].tokenBalance += amount;
        
        return true;
    }

    // Allow contract to receive ETH
    receive() external payable {}
}