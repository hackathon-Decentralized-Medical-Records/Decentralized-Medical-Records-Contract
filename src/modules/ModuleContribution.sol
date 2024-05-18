// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {LibTypeDef} from "../../src/utils/LibTypeDef.sol";
import {ModuleVRF} from "./ModuleVRF.sol";
import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

contract ModuleContribution is ModuleVRF, AutomationCompatibleInterface {
    error ModuleContribution__UpkeepNotNeeded();

    mapping(address => uint256) private s_userToContributionTimes;
    mapping(bytes32 => uint256) private s_addressTupleToContributionIndex;
    LibTypeDef.ContributionInfo[] private s_tempContributionInfo;
    LibTypeDef.CountingState internal s_countingState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    LibTypeDef.ContributionInfo[] internal s_contributionInfo;
    uint256 internal s_contributionTotalAmount;
    mapping(address => uint256) internal s_TransferFailAddressToAmountInWei;

    event ModuleContribution__UpkeepPerformed(uint256 requestId, uint32 numWords);
    event ModuleContribution__LotteryCompleted();

    constructor(uint256 interval) {
        s_lastTimeStamp = block.timestamp;
        s_countingState = LibTypeDef.CountingState.OFF;
        i_interval = interval;
    }

    //weekly
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory performData)
    {
        bool isOff = s_countingState == LibTypeDef.CountingState.OFF;
        bool TimePassed = block.timestamp - s_lastTimeStamp >= i_interval;
        bool hasPlayer = s_contributionInfo.length > 0;
        bool hasBalance = s_contributionTotalAmount > 0 && address(this).balance >= s_contributionTotalAmount;
        upkeepNeeded = isOff && TimePassed && hasPlayer && hasBalance;
        performData = "";
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");

        if (!upkeepNeeded) {
            revert ModuleContribution__UpkeepNotNeeded();
        }

        s_countingState = LibTypeDef.CountingState.OFF;
        s_lastTimeStamp = block.timestamp;

        uint32 numSize = uint32(s_contributionInfo.length / 10);

        if (numSize == 0) {
            numSize = 1;
        }

        uint256 requestId = super.requestVRF(numSize);

        emit ModuleContribution__UpkeepPerformed(requestId, numSize);
    }
}
