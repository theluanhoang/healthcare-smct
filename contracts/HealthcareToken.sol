// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract HealthcareToken is ERC20, Ownable, Pausable {
    // Cấu trúc cho khảo sát
    struct Survey {
        uint256 id;
        string title;
        string ipfsHash;      // Chi tiết khảo sát được lưu trên IPFS
        uint256 reward;       // Số token thưởng cho việc hoàn thành
        uint256 startTime;
        uint256 endTime;
        bool isActive;
        mapping(address => bool) hasCompleted;
    }

    // Cấu trúc cho các hoạt động có thể nhận thưởng
    struct RewardActivity {
        uint256 id;
        string name;
        uint256 reward;
        bool isActive;
    }

    // Mapping lưu trữ khảo sát
    mapping(uint256 => Survey) public surveys;
    uint256 public surveyCount;

    // Mapping lưu trữ hoạt động có thưởng
    mapping(uint256 => RewardActivity) public rewardActivities;
    uint256 public activityCount;

    // Mapping theo dõi số token đã thưởng cho mỗi địa chỉ
    mapping(address => uint256) public totalRewardsEarned;

    // Events
    event SurveyCreated(uint256 indexed id, string title, uint256 reward, uint256 startTime, uint256 endTime);
    event SurveyCompleted(uint256 indexed surveyId, address indexed user, uint256 reward);
    event ActivityCreated(uint256 indexed id, string name, uint256 reward);
    event ActivityRewardClaimed(uint256 indexed activityId, address indexed user, uint256 reward);
    event TokensExchangedForGas(address indexed user, uint256 tokenAmount, uint256 gasAmount);

    constructor() ERC20("Healthcare Token", "HCT") {
        // Khởi tạo supply ban đầu cho hệ thống
        _mint(msg.sender, 1000000 * 10**decimals());
    }

    // Tạo khảo sát mới
    function createSurvey(
        string memory title,
        string memory ipfsHash,
        uint256 reward,
        uint256 startTime,
        uint256 endTime
    ) external onlyOwner {
        require(startTime >= block.timestamp, "Start time must be in the future");
        require(endTime > startTime, "End time must be after start time");
        require(reward > 0, "Reward must be greater than 0");

        surveyCount++;
        Survey storage newSurvey = surveys[surveyCount];
        newSurvey.id = surveyCount;
        newSurvey.title = title;
        newSurvey.ipfsHash = ipfsHash;
        newSurvey.reward = reward;
        newSurvey.startTime = startTime;
        newSurvey.endTime = endTime;
        newSurvey.isActive = true;

        emit SurveyCreated(surveyCount, title, reward, startTime, endTime);
    }

    // Hoàn thành khảo sát và nhận thưởng
    function completeSurvey(uint256 surveyId, string memory responseHash) external whenNotPaused {
        Survey storage survey = surveys[surveyId];
        require(survey.isActive, "Survey is not active");
        require(block.timestamp >= survey.startTime, "Survey has not started");
        require(block.timestamp <= survey.endTime, "Survey has ended");
        require(!survey.hasCompleted[msg.sender], "Already completed this survey");

        survey.hasCompleted[msg.sender] = true;
        _mint(msg.sender, survey.reward);
        totalRewardsEarned[msg.sender] += survey.reward;

        emit SurveyCompleted(surveyId, msg.sender, survey.reward);
    }

    // Tạo hoạt động có thưởng mới
    function createRewardActivity(string memory name, uint256 reward) external onlyOwner {
        activityCount++;
        rewardActivities[activityCount] = RewardActivity(
            activityCount,
            name,
            reward,
            true
        );

        emit ActivityCreated(activityCount, name, reward);
    }

    // Cấp thưởng cho hoạt động (chỉ owner mới có quyền)
    function rewardForActivity(uint256 activityId, address user) external onlyOwner whenNotPaused {
        RewardActivity memory activity = rewardActivities[activityId];
        require(activity.isActive, "Activity is not active");

        _mint(user, activity.reward);
        totalRewardsEarned[user] += activity.reward;

        emit ActivityRewardClaimed(activityId, user, activity.reward);
    }

    // Đổi token lấy gas (ETH)
    function exchangeTokensForGas(uint256 tokenAmount) external whenNotPaused {
        require(tokenAmount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= tokenAmount, "Insufficient token balance");

        // Tỉ lệ quy đổi: 100 token = 0.001 ETH (có thể điều chỉnh)
        uint256 gasAmount = (tokenAmount * 1 ether) / 100000;
        require(address(this).balance >= gasAmount, "Insufficient gas balance");

        _burn(msg.sender, tokenAmount);
        payable(msg.sender).transfer(gasAmount);

        emit TokensExchangedForGas(msg.sender, tokenAmount, gasAmount);
    }

    // Các hàm admin
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Cho phép contract nhận ETH
    receive() external payable {}
} 