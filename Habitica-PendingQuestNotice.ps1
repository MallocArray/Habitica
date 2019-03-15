<#
Pending Quest Notice

Sends a Habitica private message to the Quest Leader and the Party Leader after the quest timer (default 24 hours) is exceeded,
asking them to start the quest.  If the script is run with the Party Leader credentials, the quest will be started automatically

#>
Connect-Habitica
$PendingHeader = 'Invites sent for pending quest'
$PendingQuestTimer = 24 #How many hours before trying to start the quest or send a private message to the owner

$PartyData = Get-HabiticaGroup
$QuestStatus = $PartyData | Get-HabiticaQuestStatus
if ($QuestStatus -eq 'Pending') { #If there is a pending quest
    $PartyChat = Get-HabiticaGroupChat -GroupID 'party'
    $QuestActions = (Get-HabiticaQuestMessage -PartyChat $PartyChat | Get-HabiticaQuestAction)
    $PendingNotice = $PartyChat | Where-Object {$_.text -like "*$PendingHeader*"} | Select-Object -First 1

    #If no pending notice posted or it was last posted before previous quest ended
    if (!$PendingNotice -or $PendingNotice.timestamp -lt $QuestActions[0].timestamp) {
        Publish-HabiticaReport "$PendingHeader started by $(Get-HabiticaGroupMember -id $PartyData.quest.leader)"
    } else {
        #See if the PendingQuestTimer has been exceeded
        if ((ConvertFrom-HabiticaTimestamp $pendingnotice.timestamp).addhours($PendingQuestTimer-0.1) -lt (Get-Date)) { #Subtracting 0.1 so it is just before a full 24 hours
            #If the user running this script is the QuestLeader or GroupLeader, force start it
            Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/party/quests/force-start" -Headers $HabiticaHeader -Method POST -ErrorAction Continue -ErrorVariable RestError
            If ($RestError) {
                #If an error is logged (Because quest is in progress or you don't have permission to start it) send a private message to quest owner
                #First check to see if the desired message has already been sent
                $Messages = Get-HabiticaInboxMessage
                $Body = "The current quest invite has been pending for more than $PendingQuestTimer hours. Please start the quest"
                $PrivateMessage = $Messages | Where-Object {$_.text -eq $Body} | Select-Object -First 1
                #If never sent a private message or the last private message with the proper header was sent was prior to the pending quest notice, send the message
                if (!$PrivateMessage -or (Get-Date $PrivateMessage.timestamp) -lt (ConvertFrom-HabiticaTimestamp $pendingnotice.timestamp)) {
                    Send-HabiticaPrivateMessage -UserID $PartyData.quest.leader -Message $Body #Quest Leader
                    Send-HabiticaPrivateMessage -UserID $PartyData.leader.id -Message $Body #Party Leader
                }
                $RestError = $Null
            }
        }
    }
}