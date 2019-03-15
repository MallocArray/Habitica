#Quest Result Report

#Discord Webook URLs
#Right click on a channel, select Edit Channel, Webhooks, Create Webook and copy the URL into $webhookUrl
#$DiscordWebhookUrl = "https://discordapp.com/api/webhooks/...."

Connect-Habitica
$PartyChat = Get-HabiticaGroupChat -GroupID 'party'
$QuestActions = Get-HabiticaQuestMessage -PartyChat $PartyChat | Get-HabiticaQuestAction
$Report = Format-HabiticaQuestReport -QuestActions $QuestActions

#Checking if the last report was before the last quest completed and if so, will post it
if (Test-HabiticaReportNeeded -PartyChat $PartyChat -QuestActions $QuestActions){
    Publish-HabiticaReport $Report
    #Publish-DiscordReport $Report

    $QuestQueue = Get-HabiticaQuestQueue
    Send-HabiticaQuestQueueReminder -QuestQueue $QuestQueue
    #Publish-DiscordReport "$($QuestQueue[0].user) is up next with quest $($QuestQueue[0].quest)"
    $QuestQueue = Remove-HabiticaQuestQueueEntry -QuestQueue $QuestQueue
    Save-HabiticaQuestQueue -QuestQueue $QuestQueue
}