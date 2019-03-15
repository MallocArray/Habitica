
################################################################################
# Habitica API related functions
################################################################################

function Get-HabiticaGroup {
    <#
        .SYNOPSIS
            Returns information about a Habitica group

        .DESCRIPTION
            Returns detailed information about a group
            By default, returns information about the user's party

        .PARAMETER GroupID
            The UUID of a group, or common names of 'party' for the user party and 'habitrpg' for tavern are accepted
            Defaults to 'party'

        .PARAMETER Full
            If -Full is included, the full RESTApi response will be included with details such as success, userV, and appVersion.
            If not specified, only the data field is returned

        .LINK
            https://habitica.com/apidoc/#api-Group-GetGroup
    #>
    [CmdletBinding()]
    param (
        [string]$GroupID='party',
        [switch]$Full = $False
    )
    if ($Full) {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$GroupID" -Headers $HabiticaHeader -Method GET
    } Else {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$GroupID" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
    }
}

function Get-HabiticaGroupChat {
    <#
        .SYNOPSIS
            Returns the full group chat log

        .DESCRIPTION
            Returns all group chat log data that is currently available

        .PARAMETER GroupID
            The UUID of a group, or common names of 'party' for the user party and 'habitrpg' for tavern are accepted
            Defaults to 'party'

        .PARAMETER Full
            If -Full is included, the full RESTApi response will be included with details such as success, userV, and appVersion.
            If not specified, only the data field is returned

        .LINK
            https://habitica.com/apidoc/#api-Chat-GetChat
    #>
    [cmdletbinding()]
    param (
        [string]$GroupID = 'party',
        [switch]$Full = $False
    )
    If ($Full) {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$GroupID/chat" -Headers $HabiticaHeader -Method GET
    } Else {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$GroupID/chat" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
    }
}

Function Connect-Habitica {
<#
    .SYNOPSIS
        Sets variables needed for Habitica RESTApi calls and other functions to work properly

    .DESCRIPTION
        Uses provided UserID and API Tokens to set the $HabitcaBaseURI and $HabiticaHeader variables.
        Can also save credentials to a file and if the file exists, will load saved data.
        Once the Save parameter is used, it will attempt to be loaded automatically when no parameters are provided other than a non-default path

    .PARAMETER  UserID
        The Habitica UserID to configure the connection with.
        Can be found by logging into Habitica, clicking the user icon in the upper right corner, selecting Settings, then API.
        A prompt for the API Token will appear after running the fuction to store it securely

    .PARAMETER Save
        UserID and API Token will be saved to a file.
        By default, will be saved to the same folder as the Powershell profile with a name of Habitica.xml unless provided with the Path parameter
        The API Token in the file can only be read by the same user on the same computer.  If accessed by a different user or copied to another device, it will not be readable

    .PARAMETER Credential
        A PSCredential object with UserID for the username and API Token for the Password

    .PARAMETER Path
        The full file path including filename to save credentials to or to load saved credentials from.
        If not provided, the default path is the Powershell Profile folder and file name Habitica.xml

    .EXAMPLE
        Connect-Habitica
        If saved credentials exist, they will be loaded.
        If no saved credentials exist, a prompt for UserID and API Token will appear

    .EXAMPLE
        Connect-Habitica -Save
        After entering a UserID and API Token, credentials will be saved securely to the local computer.

    .EXAMPLE
        Connect-Habbitica -Path C:\Scripts\HabiticaUser.xml
        Loads saved credentials from the specified path.  No prompt for credentials.
#>
    [CmdletBinding()]
    param (
        [Alias("User")]
        [string]$UserID,
        [pscredential]$Credential,
        [switch]$Save,
        $Path = (Join-Path (Split-Path $profile) Habitica.xml) #Powershell Profile path folder
    )
    if (!$Credential -and !$UserID) {
        #If saved credentials exist, use those
        if (Test-Path $Path) {
            Write-Verbose "Loading saved credentials from $Path"
            $Credential = Import-Clixml -Path $Path
        } Else {
            #If no credential object, prompt to get credentials
            Write-Verbose 'No saved credentials found.  Prompting for credentials'
            $Credential = Get-Credential -Message "Enter your Habitica UserID for the Username and API Token for the Password.  This can be found by logging into Habitica, clicking the user icon in the upper right corner, selecting Settings, then API."
        }
    } elseif ($UserID) {
        Write-Verbose 'UserID provided.  Prompting for API Token'
        $Credential = Get-Credential -UserName $UserID -Message "Enter your Habitica API Token as the Password for user $UserID.  This can be found by logging into Habitica, clicking the user icon in the upper right corner, selecting Settings, then API."
    }
    if ($Save) {
        Write-Verbose "Saving credentials to $Path"
        $Credential | Export-Clixml -Path $Path
    }
    $Script:HabiticaBaseURI = 'https://habitica.com/api/v3'
    $Script:HabiticaHeader = @{
        "Content-Type" = "application/json"
        'x-api-user' = $Credential.UserName
        'x-api-key' = $Credential.GetNetworkCredential().Password
    }
}

################################################################################
# Habitica Custom functions
################################################################################

function Get-HabiticaQuestMessage {
    <#
        .SYNOPSIS
            Separates party chat log entries to only those related to a single quest

        .DESCRIPTION
            When provided the party chat log, will return only the chat log related to a single quest from the start to the completion.  Can specific how many quests in the past to return

        .PARAMETER PartyChat
            The party chat log to be parsed.
            If not provided, the current party chat log is retrieved

        .PARAMETER QuestHistory
            The number of the past quest to retrieve.
            Default is 1, indicating the most recent completed quest.  Value of 2 would indicate the second most recent quest, etc.
            If 0, the in progress quest data is returned.

        .EXAMPLE
            Get-HabiticaQuestMessage
            Retrieves the chat log for the most recently completed quest

        .EXAMPLE
            Get-HabiticaQuestMessage -QuestHistory 3
            Retrieves the chat log for the third most recenty completed quest
    #>
    [CmdletBinding()]
    param (
        $PartyChat = (Get-HabiticaGroupChat -GroupID 'party'),
        [int]$QuestHistory = 1
    )
    if ($QuestHistory -gt 0) {
        $QuestCompleted = ($PartyChat | Where-Object {$_.text -match 'receive the rewards|received their rewards'})[($QuestHistory-1)]
        $QuestStarted = $PartyChat | Where-Object {$_.text -like '*Quest*Started*' -and $_.timestamp -lt $Questcompleted.timestamp } | Select-Object -first 1
        $QuestMessages = $PartyChat | Where-Object {$_.timestamp -le $QuestCompleted.timestamp -and $_.timestamp -ge $QuestStarted.timestamp}
    } else {
        $QuestStarted = $PartyChat | Where-Object {$_.text -like '*Quest*Started*'} | Select-Object -first 1
        $QuestMessages = $PartyChat | Where-Object {$_.timestamp -ge $QuestStarted.timestamp}
    }
    $QuestMessages
}

function Get-HabiticaQuestAction {
    <#
        .SYNOPSIS
            Adds values to PartyChat data about specific actions performed by users

        .DESCRIPTION
            When provided the party chat log that is related to a specific quest, will add additional fields for each entry, specifying the username, the action (casts, attacks, found), the target of the action, the damage done, and damage done to the party

        .PARAMETER Data
            A subset of the party chat log that is specific to a single quest

        .EXAMPLE
            $PartyChat = (Get-HabiticaGroupChat)
            $QuestActions = (Get-HabiticaQuestMessage -PartyChat $PartyChat | Get-HabiticaQuestAction)
    #>
    [cmdletbinding()]
    param (
        [Parameter(ValueFromPipeline=$True)]
        [Object[]]$Data = (Get-HabiticaQuestMessage)
    )
    Process{
        foreach ($Message in $Data) {
            #$Message | Add-Member Time $Message.timestamp -Force
            If($Message.text -like '*casts*') {
                $Message | Add-Member User (($Message.text -split ' casts')[0] -replace ('`','')) -Force
                $Message | Add-Member Action 'casts' -Force
                $Message | Add-Member Target ((((($Message.text -split 'casts ')[1]) -split ' for the party.`')[0] -split ' on ')[0]) -Force #Split casting on the party or on a single person
            }
            If($Message.text -like '*attacks*') {
                $Message | Add-Member User (($Message.text -split ' attacks')[0] -replace ('`','')) -Force
                $Message | Add-Member Action 'attacks' -Force
                $Message | Add-Member Target ((($Message.text -split 'attacks ')[1] -split ' for')[0]) -Force
                $Message | Add-Member -Type NoteProperty Damage ([decimal](($Message.text -split 'for ')[1] -split ' damage')[0]) -Force
                $Message | Add-Member -Type NoteProperty PartyDamage ([decimal](($Message.text -split 'for ')[2] -split ' damage')[0]) -Force
            }
            If($Message.text -like '*found*') {
                $Message | Add-Member User (($Message.text -split ' found')[0] -replace ('`','')) -Force
                $Message | Add-Member Action 'found' -Force
                $Message | Add-Member -Type NoteProperty Damage ([decimal](($Message.text -split 'found ')[1] -split ' ')[0]) -Force
                $Message | Add-Member Target (((($Message.text -split "$($Message.damage) ")[1]) -split '.`')[0]) -Force #Split items found on the damage number to end of line
            }
            $Message
        }
    }
}

function Get-HabiticaTopUser {
    <#
        .SYNOPSIS
            Returns the top user(s) of a particular subset of actions

        .DESCRIPTION
            When provided a list of actions, such as all actions where Blessing was used, returns the actions for the user(s) who performed it the most

        .PARAMETER Data
            A subset of QuestActions performing a specific action that only the top user information is returned

        .EXAMPLE
            Get-HabiticaTopUser (Get-HabiticaQuestMessage | Get-HabiticaQuestAction | Where-Object {$_.target -eq 'Blessing'})

            Output:
            User        ActionCount Target   Action
            ----        ----------- ------   ------
            MallocArray           1 Blessing casts
    #>
    [cmdletbinding()]
    param (
        $Data
    )
    Process{
        $Output = @()
        $UniqueUsers = ($Data.User | Select-Object -unique)
        foreach ($User in $UniqueUsers) {
            $TotalActions = [PSCustomObject] @{
                User = $User
                ActionCount = ($Data.user | Where-Object {$_ -eq $User} | Measure-Object).count
                Target = $Data | Where-Object {$_.User -eq $User} | Select-Object -ExpandProperty Target -Unique
                Action = $Data | Where-Object {$_.User -eq $User} | Select-Object -ExpandProperty Action -Unique
            }
            $Output += $TotalActions
        }
        $Output = $Output | Sort-Object ActionCount -Descending #Sort so the highest is on top
        $Output | Where-Object {$_.ActionCount -eq $Output.ActionCount[0]} #Find all items that have the same as the highest in case of multiples
    }
}

function Get-HabiticaAward {
    <#
        .SYNOPSIS
            Generates a line of text for a Quest Report that displays the name of the award, the user, and what action

        .PARAMETER Title
            The Title of the award to be listed as a free text field. Preferrably end with a :
            Space is automatically added to the end of this field
            Defaults to 'MVP:'

        .PARAMETER Action
            The QuestAction object associated with the award, such as the first damage done or the user(s) with the most buffs

        .PARAMETER ActionUser
            The username associated with the action that is being awarded.
            If not provided, the user from the Action object is used

        .PARAMETER ActionCount
            The number of actions performed by the user to be included in the report, such as the number of attacks, the number of buffs, etc
            If not provided, the ActionCount value from the Action object is used

        .PARAMETER ActionName
            The name of the action performed by the user, such as attacking, collecting, or buffs used
            If not provided, the unique targets from the Action object is used

        .PARAMETER HabiticaFormat
            Indicates that the Habitica Markdown formatting should be used.
            ` to use a script block to offset the Title
            ** to bold the ActionName
            ## to increase the size of the header

        .EXAMPLE
            $Actions = ($QuestActions | Where-Object {$_.action -eq 'attacks'})
            $Damage = $Actions | Sort-Object timestamp | Select-Object -First 1
            $Report += Get-HabiticaAward -HabiticaFormat -Title "First Hit" -Action $Damage -ActionUser $Damage.User -ActionCount $Damage.Damage -ActionName 'damage'

            Output: `First Hit:` ARESS with **13.2 damage**
    #>
    [CmdletBinding()]
    param(
        $Title='MVP:',
        $Action,
        $ActionUser = $Action.User,
        $ActionCount = $Action.ActionCount,
        $ActionName = ($Action.target | Select-Object -Unique),
        [switch]$HabiticaFormat
    )
    Begin{ #Change this to Process
        If($Action) {
            If(($Action).count -gt 1) {
                #Multiple actions indicates a tie with multiple users
                if ($HabiticaFormat) {Return "``$($Title):`` Tie! $($ActionUser -join ' and ') with **$($ActionCount[0]) $($ActionName) each**" #`` to escape the ` character
                } Else {
                    Return "$($Title): Tie! $($ActionUser -join ' and ') with $($ActionCount[0]) $($ActionName) each"
                }
            } Else {
                #No tie, so awarding to a single user
                if ($HabiticaFormat) {Return "``$($Title):`` $($ActionUser) with **$($ActionCount[0]) $($ActionName)**"
                } Else {
                        Return "$($Title): $($ActionUser) with $($ActionCount[0]) $($ActionName)"
                }
            }
        }
    }
}

function Format-HabiticaQuestReport {
    <#
        .SYNOPSIS
            Generates a pre-formatted quest report with statistics

        .DESCRIPTION
            Generates a report showing how long a quest took to complete, the number of users that participated, who did first damage, most damage total and in one hit, and various buff statistics

        .PARAMETER QuestActions
            An object of all quest actions generated by the Get-HabiticaQuestAction command.  Can be historic quest data or current

        .PARAMETER Header
            The header of the report to show on the first line before the name of the quest.
            Default is 'Quest Results for:'

        .EXAMPLE
            $PartyChat = Get-HabiticaGroupChat
            $QuestActions = Get-HabiticaQuestMessage -PartyChat $PartyChat | Get-HabiticaQuestAction
            $Report = Format-HabiticaQuestReport -QuestActions $QuestActions
    #>
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$True)]
        [object[]]$QuestActions,
        $Header = 'Quest Results for:'
    )
        $Report = @()
        $QuestTitle = $QuestActions.text | Select-Object -last 1
        # ## for Habitica Markdown formatting for Header 2
        # Splitting after the word quest and before has for the quest name
        $Report += "## $($Header) $(((($QuestTitle) -split ('quest, '))[1] -split (', has '))[0])"
        $Report += '\n'

        #Time for quest
        $Time = (Convertfrom-habiticatimestamp $QuestActions[0].timestamp) - (Convertfrom-habiticatimestamp $QuestActions[-1].timestamp)
        $Report += "``Time to complete:`` **$($Time.Days) days, $($Time.Hours) hours, $($Time.Minutes) minutes**"
        #Total number of members who did some type of action
        $Actions = ($QuestActions | Select-Object User -Unique).count
        $Report += "``Total participating members:`` **$Actions**"

        #Top Total Damage
        $Actions = ($QuestActions | Where-Object {$_.action -eq 'attacks'})
        $UserDamageTotals = @()
        foreach ($User in ($Actions | Select-Object -ExpandProperty User -Unique)) {
            $UserActions = $Actions | Where-Object {$_.user -eq $User}
            $TotalDamage = ($UserActions | Measure-Object Damage -Sum).sum
            $UserActions[0] | Add-Member TotalDamage $TotalDamage -Force
            $UserDamageTotals += $UserActions[0]
        }
        $Damage = $UserDamageTotals | Sort-Object TotalDamage -Desc | Select-Object -First 1
        $Report += Get-HabiticaAward -HabiticaFormat -Title "Most Brutal" -Action $Damage -ActionUser $Damage.User -ActionCount $Damage.TotalDamage -ActionName 'total damage'

        #First Hit
        $Actions = ($QuestActions | Where-Object {$_.action -eq 'attacks'})
        $Damage = $Actions | Sort-Object timestamp | Select-Object -First 1
        $Report += Get-HabiticaAward -HabiticaFormat -Title "First Hit" -Action $Damage -ActionUser $Damage.User -ActionCount $Damage.Damage -ActionName 'damage'

        #Hardest Hit
        $Actions = ($QuestActions | Where-Object {$_.action -eq 'attacks'})
        $Damage = $Actions | Sort-Object Damage -desc | Select-Object -First 1
        $Report += Get-HabiticaAward -HabiticaFormat -Title "Most Potent" -Action $Damage -ActionUser $Damage.User -ActionCount $Damage.Damage -ActionName 'in one hit'

        #Damage to Party
        $Actions = ($QuestActions | Where-Object {$_.action -eq 'attacks'})
        $UserDamageTotals = @()
        foreach ($User in ($Actions | Select-Object -ExpandProperty User -Unique)) {
            $UserActions = $Actions | Where-Object {$_.user -eq $User}
            $TotalDamage = ($UserActions | Measure-Object PartyDamage -Sum).sum
            $UserActions[0] | Add-Member TotalPartyDamage $TotalDamage -Force
            $UserDamageTotals += $UserActions[0]
        }
        $Damage = $UserDamageTotals | Sort-Object TotalPartyDamage -Desc | Select-Object -First 1
        $Report += Get-HabiticaAward -HabiticaFormat -Title "Stop Hitting Yourself" -Action $Damage -ActionUser $Damage.User -ActionCount $Damage.TotalPartyDamage -ActionName 'total damage to the party'

        #Items Found
        $Actions = ($QuestActions | Where-Object {$_.action -eq 'found'})
        $UserItemTotals = @()
        foreach ($User in ($Actions | Select-Object -ExpandProperty User -Unique)) {
            $UserActions = $Actions | Where-Object {$_.user -eq $User}
            $TotalDamage = ($UserActions | Measure-Object Damage -Sum).sum
            $UserActions[0] | Add-Member TotalDamage $TotalDamage -Force
            $UserItemTotals += $UserActions[0]
        }
        $Items = $UserItemTotals | Sort-Object TotalDamage -Desc | Select-Object -First 1
        $Report += Get-HabiticaAward -HabiticaFormat -Title "Shiny Hoarder" -Action $Items -ActionUser $Items.User -ActionCount $Items.TotalDamage -ActionName 'items found'
        #New line to separate damage vs skills
        $Report += '\n'

        #$Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -eq 'Protective Aura'})
        $Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -match 'Protective Aura|Intimidating Gaze'})
        $Report += Get-HabiticaAward -HabiticaFormat -Title 'Most Resilient' -Action $Actions

        $Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -eq 'Blessing'})
        $Report += Get-HabiticaAward -HabiticaFormat -Title 'Most Healing' -Action $Actions

        $Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -eq 'Ethereal Surge'})
        $Report += Get-HabiticaAward -HabiticaFormat -Title 'Most Refreshing' -Action $Actions

        $Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -eq 'Earthquake'})
        $Report += Get-HabiticaAward -HabiticaFormat -Title 'Most Wise' -Action $Actions

        $Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -eq 'Tools of the Trade'})
        $Report += Get-HabiticaAward -HabiticaFormat -Title 'Most Crafty' -Action $Actions

        $Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -eq 'Valorous Presence'})
        $Report += Get-HabiticaAward -HabiticaFormat -Title 'Most Inspiring' -Action $Actions

        #$Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.target -eq 'Intimidating Gaze'})
        #$Report += Get-HabiticaAward -HabiticaFormat -Title 'Fearmonger' -Action $Actions

        $Actions = Get-HabiticaTopUser ($QuestActions | Where-Object {$_.action -eq 'casts'})
        $Report += Get-HabiticaAward -HabiticaFormat -Title 'Most Supportive' -Action $Actions -ActionName 'Party Buffs'
        $Report
}

function Test-HabiticaReportNeeded {
    <#
        .SYNOPSIS
            Tests to see if a quest report is needed

        .DESCRIPTION
            Compares the timestamp of the last quest report and the last time a quest was completed.
            If the last report was before the last completed quest, it returns True

        .PARAMETER PartyChat
            The contents of the party's chat history.  If saved values are not provided, the current chat log is retrieved by default

        .PARAMETER QuestActions
            The contents of quest action provided by Get-HabiticaQuestAction.  If saved values are not provided, current list of actions is generated

        .PARAMETER ReportHeader
            The header used in the quest report that is used to search for the last time it was put into the chat.
            Default value is 'Quest Results for:'

        .EXAMPLE
            Test-HabiticaReportNeeded
    #>
    [CmdletBinding()]
    param (
        $PartyChat = (Get-HabiticaGroupChat -groupid 'party'),
        $QuestActions = (Get-HabiticaQuestMessage -PartyChat $PartyChat | Get-HabiticaQuestAction),
        $ReportHeader = 'Quest Results for:'
    )
    #Get the last time a report was posted to the chat
    $LastReport = $PartyChat | Where-Object {$_.text -like "*$ReportHeader*"} | Select-Object -First 1
    #If the report was last posted before the most recent quest completed, post a new one
    if ($LastReport.timestamp -lt ($QuestActions | Select-Object -ExpandProperty Timestamp -First 1)) {
        Return $True
    } Else {$False}
}

function Format-HabiticaReport {
    <#
        .SYNOPSIS
            Formats a block of text for Habitica's Markdown requirements

        .DESCRIPTION
            Receives report data, formats it for Habitica's Markdown requirements
            Habitica uses two spaces and \n for a new line '  \n'

        .PARAMETER Report
            An array of text to be formatted  Text will be formatted using Habitica's Markdown requirements to ensure line breaks work as expected.

        .EXAMPLE
            Format-HabiticaReport -Report $Report

        .LINK
            https://habitica.fandom.com/wiki/Markdown_Cheat_Sheet
    #>
    [CmdletBinding()]
    param (
        $Report
    )
    $Body = @{
        # Join each line with two spaces and \n for a new line
        'message'=($Report -join '  \n')
    } | ConvertTo-Json
    #ConverTo-Json doubles the slashes, but Habitica wants a single. Replacing with just n leaves \n in the result
    $body = $body -replace ('\\n','n')
    $body
}

function Format-DiscordReport {
    <#
        .SYNOPSIS
            Formats a block of text for Discord's Markdown requirements

        .DESCRIPTION
            Receives report data, formats it for Discord's Markdown requirements
            Discord uses \r\n for a new line
            Also puts a header that tags everyone

        .PARAMETER Report
            An array of text to be formatted.  Text will be formatted using Discord's Markdown requirements to ensure line breaks work as expected.

        .EXAMPLE
            Format-DiscordReport -Report $Report

        .LINK
            https://habitica.fandom.com/wiki/Markdown_Cheat_Sheet
    #>
    [CmdletBinding()]
    param (
        $Report
    )
    $Report[0] = '@everyone - `Quest Results:` ' + ($Report[0] -split 'for: ')[1]

    $Body = @{
        # Join each line with a carriage return and strip out \n from a double space used for Habitica
        'content'=($Report -replace ('\\n',"") -join "`n")
    } | ConvertTo-Json
    #Discord wants \r\n for a new line, replacing \n in the original, but need two slashes due to escape character
    $body = $body -replace ('\\n','\r\n')
    Return $body
}

function Publish-HabiticaReport {
    <#
        .SYNOPSIS
            Publishes information to the party chat

        .DESCRIPTION
            Receives report data, formats it for Habitica's Markdown requirements, and posts it to the party chat

        .PARAMETER Report
            An array of text to be published.  Text will be formatted using Habitica's Markdown requirements to ensure line breaks work as expected.

        .EXAMPLE
            Publish-HabiticaReport -Report $Report

        .LINK
            https://habitica.fandom.com/wiki/Markdown_Cheat_Sheet
    #>
    [CmdletBinding()]
    param (
        $Report
    )
    $Body = Format-HabiticaReport $Report
    Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/party/chat" -Headers $HabiticaHeader -Method POST -Body $Body
}

Function ConvertFrom-HabiticaTimestamp {
    <#
        .SYNOPSIS
            Converts Habitica timestamp fields to human readable date and time

        .DESCRIPTION
            Habitica time is in Unix Epoch time, multipled by 1000. This function converts this to a human readable date and time format

        .PARAMETER HabiticaTimestamp
            The Habitica timestamp to convert

        .EXAMPLE
            $Timestamp = Get-HabiticaGroupChat | Select-Object -ExpandProperty timestamp -First 1
            ConvertFrom-HabiticaTimestamp $Timestamp
            Return the timestamp of the most recent Party chat
    #>
    [cmdletbinding()]
    param (
        [Parameter(ValueFromPipeline=$True)]
        $HabiticaTimestamp
    )
    [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($HabiticaTimestamp/1000))
 }

<#
Quest Result Report

Standalone script to generate a quest report and post it on the party chat
Replace the sections for api user and tokens with valid credentials
#>


#Discord Webook URLs if desired to publish to a Discord Channel as well
#Right click on a channel, select Edit Channel, Webhooks, Create Webook and copy the URL into $webhookUrl
#$DiscordWebhookUrl = "https://discordapp.com/api/webhooks/..."

$HabiticaBaseURI = https://habitica.com/api/v3
$HabiticaHeader = @{
    "Content-Type" = "application/json"
    'x-api-user' = 'YourHabiticaUserIDHere'
    'x-api-key' = 'YourHabiticaAPITokenHere'
}

$PartyChat = Get-HabiticaGroupChat -GroupID 'party'
$QuestActions = Get-HabiticaQuestMessage -PartyChat $PartyChat | Get-HabiticaQuestAction
$Report = Format-HabiticaQuestReport -QuestActions $QuestActions

#Checking if the last report was before the last quest completed and if so, will post it
if (Test-HabiticaReportNeeded -PartyChat $PartyChat -QuestActions $QuestActions){
    Publish-HabiticaReport $Report
    #Publish-DiscordReport $Report
}