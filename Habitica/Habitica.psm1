# https://habitica.fandom.com/wiki/Application_Programming_Interface
# https://habitica.com/apidoc/
# Habitica Markdown formatting https://habitica.fandom.com/wiki/Markdown_Cheat_Sheet

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

function Get-HabiticaUser {
    <#
        .SYNOPSIS
            Returns user information

        .DESCRIPTION
            Returns all user data found in the export of userdata from Habitica

        .LINK
            https://habitica.com/apidoc/#api-DataExport-ExportUserDataJson
    #>
    $UserData = Invoke-RestMethod -Uri "https://habitica.com/export/userdata.json" -Headers $HabiticaHeader -Method GET
    Return $UserData
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

function Send-HabiticaPrivateMessage {
    <#
        .SYNOPSIS
            Sends a private message to another Habitica user

        .PARAMETER Message
            The message to be sent to another user, surrounded in quotes

        .PARAMETER UserID
            The UUID of a particular member to send the message to in the format of '11111111-2222-3333-4444-555555555555'
            If a username is provided, the user's party will be searched for matching usernames to resolve to a UUID

        .EXAMPLE
            Send-HabiticaPrivateMessage -Message 'Hi there!' -UserID (Get-HabiticaGroup -Group 'party').leader.id
            Sends a message to the leader of the party

        .LINK
            https://habitica.com/apidoc/#api-Member-SendPrivateMessage
    #>
    [cmdletbinding()]
    param (
        $UserID,
        $Message
    )
    if ($UserID -notmatch '\w\w\w\w\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w\w\w\w\w\w\w\w\w') {
        $SearchResult = Get-HabiticaGroupMember -Group 'party' | Where-Object {$_.profile.name -like "*$UserID*"} | Select-Object -ExpandProperty id
        if (!$SearchResult) {
            #Searching Challenges Here
            $SearchResult = Get-HabiticaUserChallenge | Get-HabiticaChallengeMember | Where-Object {$_.profile.name -like "*$UserID*"} | Select-Object -ExpandProperty id
        }
        if (!$SearchResult) { Write-Error "Unable to match UserID.  Message not sent" -ErrorAction Stop}
        Else {$UserID = $SearchResult}
    }
    $Body = @{
        # Join each line with two spaces and \n for a new line
        'message'=($Message)
        'toUserId'=$UserID
    } | ConvertTo-Json
    Invoke-RestMethod -Uri "$HabiticaBaseURI/members/send-private-message" -Headers $HabiticaHeader -Method POST -Body $Body
}

Function Get-HabiticaInboxMessage {
    <#
        .SYNOPSIS
            Returns all inbox messages for the user

        .PARAMETER Full
            If -Full is included, the full RESTApi response will be included with details such as success, userV, and appVersion.
            If not specified, only the data field is returned

        .EXAMPLE
            Get-HabiticaInboxMessage
            Returns all inbox messages for the user

            .LINK
            https://habitica.com/apidoc/#api-Inbox-GetInboxMessages
    #>
    [cmdletbinding()]
    param (
        $Full = $False
    )
    If ($Full) {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/inbox/messages" -Headers $HabiticaHeader -Method GET
    } Else {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/inbox/messages" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
    }
}

Function Get-HabiticaGroupMember {
    <#
        .SYNOPSIS
            Returns information about members of a specific group

        .DESCRIPTION
            Returns detailed information about members in a group or party including their name and ID

        .PARAMETER Group
            The UUID of a group or 'party' for the user's current party
            If not provided, the default is 'party'

        .PARAMETER ID
            The UUID of a particular member to return in the format of '11111111-2222-3333-4444-555555555555'
            Only the Username will be returned

        .PARAMETER UserName
            The name of the user in the party to return.
            Only the user's ID will be returned
            If both the ID and UserName as provided, then the complete information for that user will be returned

        .PARAMETER Full
            If -Full is included, the full RESTApi response will be included with details such as success, userV, and appVersion.
            If not specified, only the data field is returned

        .PARAMETER includeAllPublicFields
            If specified, includes all public fields for members, similar to Get-HabiticaMember for each group member

        .EXAMPLE
            Get-HabiticaGroupMember
            Return information about members in the current party

        .EXAMPLE
            Get-HabitiaGroupMember -Group '11111111-2222-3333-4444-555555555555'
            Return the members of the group with specified UUID

        .EXAMPLE
            Get-HabitiaGroupMember -ID '11111111-2222-3333-4444-555555555555'
            Return the username of the specified UUID

        .EXAMPLE
            Get-HabitiaGroupMember -UserName 'Example'
            Return the UUID of the specified group member

        .LINK
            https://habitica.com/apidoc/#api-Member-GetMembersForGroup
    #>
    # May need to add Query Parameters for more than 30 members and to include more public fields
    [cmdletbinding()]
    param (
        $Group = 'party',
        $ID,
        $UserName,
        [switch]$Full=$False,
        [switch]$includeAllPublicFields
    )
    $parameters = ''
    if ($includeAllPublicFields) {
        $parameters += "?includeAllPublicFields=true" #true is case sensitive
    }
    If ($Full) {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$Group/members$parameters" -Headers $HabiticaHeader -Method GET
    } Else {
        if (!$ID -and !$UserName) { #If no parameters provided for userid or username
            Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$Group/members$parameters" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
        } elseif ($ID -and !$UserName) { #If only UserID provided, return the username
            Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$Group/members$parameters" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data | Where-Object {$_.id -eq $ID} | Select-Object -ExpandProperty Profile | Select-Object -ExpandProperty Name
        } ElseIf ($UserName -and !$ID) { #If only the Username provided, return the user ID
            Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$Group/members$parameters" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data | Where-Object {$_.Profile.Name -eq $Username} | Select-Object -ExpandProperty ID
        } ElseIf ($ID -and $UserName) {
            Return Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/$Group/members$parameters" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data | Where-Object {$_.id -eq $ID -and $_.Profile.Name -eq $Username}
        }
    }
}

Function Get-HabiticaMember {
    <#
        .SYNOPSIS
            Returns information about a specified Habitia user

        .DESCRIPTION
            Returns detailed information about a specific user/member including their name, party, inventory, achieviments, etc.

        .PARAMETER ID
            The UUID of the member in the format of '11111111-2222-3333-4444-555555555555'
            This can often be found by listing members in a party which only displays the UUID and then using Get-HabiticaMember to resolve it to a username

        .EXAMPLE
            Get-HabitiaMember -ID '11111111-2222-3333-4444-555555555555'
            Return the specified member based on UUID

        .LINK
            https://habitica.com/apidoc/#api-Member-GetMember
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias("memberID")]
        $ID,
        $Full = $False
    )
    If ($Full) {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/members/$ID" -Headers $HabiticaHeader -Method GET
    } Else {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/members/$ID" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
    }
}

Function Get-HabiticaTag {
        <#
        .SYNOPSIS
            Returns tags from Habitica

        .DESCRIPTION
            Returns either all tags for a user, tags containing a particular name, or tags with a specific ID.
            By default, returns all tags for the user

        .PARAMETER Name
            A partial name of a tag to search for.  If not provided, all available tags are returned for the user

        .PARAMETER TagID
            The UUID of a specific tag to return

        .EXAMPLE
            Get-HabiticaTag
            Returns all tags for the user

        .EXAMPLE
            Get-HabiticaTag -Name 'work'
            Returns tags with 'work' in the name for the user

        .EXAMPLE
            Get-HabitiaTag -tagID '11111111-2222-3333-4444-555555555555'
            Return the specified tag based on its UUID

        .LINK
            https://habitica.com/apidoc/#api-Tag-GetTag
    #>
    [CmdletBinding()]
    param (
        [string]$Name,
        [Alias("id")]
        $TagID
    )
    if ($Name) {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/tags" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data | Where-Object {$_.name -like "*$Name*"}
    } elseif ($TagID) {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/tags/$TagID" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
    } else {
        Return Invoke-RestMethod -Uri "$HabiticaBaseURI/tags" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
    }
}

Function Get-HabiticaTask {
    <#
        .SYNOPSIS
            Returns a task object from Habitica

        .DESCRIPTION
            Returns a user, group, or challenge task.

        .PARAMETER Name
            A partial name of a task to search for.  If not provided, all available tasks are returned for the scope

        .PARAMETER Type
            The type of task to return [habits, dailys, todos, rewards, completedTodos]

        .PARAMETER taskID
            The exact taskID to return, in the format of 11111111-2222-3333-4444-555555555555

        .PARAMETER Scope
            The scope of tasks to return [user, group, challenge]
            Defaults to current user.  If group or challenge, use the ID parameter to provide the ID.
            If only group is provided, it defaults to the user's current Party

        .PARAMETER ID
            Used with Scope value of Group or Challenge for the full ID of the group or challenge to return

        .PARAMETER Tag
            A single UUID or name of a tag to retrieve tasks associated

        .EXAMPLE
            Get-HabiticaTask
            Returns all tasks for the user

        .EXAMPLE
            Get-HabiticaTask -Scope group
            Returns all tasks for the user's current party since no ID was provided

        .EXAMPLE
            Get-HabitiaTask -Scope Challenge -ID '11111111-2222-3333-4444-555555555555'
            Returns all tasks for the specified challenge

        .EXAMPLE
            Get-HabiticaTask -Tag 'work'
            Returns all tasks for the user that have the tag "work"

        .LINK
            https://habitica.com/apidoc/#api-Task-GetUserTasks
            https://habitica.com/apidoc/#api-Task-GetTask
            https://habitica.com/apidoc/#api-Task-GetGroupTasks
            https://habitica.com/apidoc/#api-Task-GetChallengeTasks
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [string]$Name,
        [ValidateSet("habits", "dailys", "todos", "rewards", "completedTodos","")]
        $Type,
        $taskId,
        [ValidateSet('user','group','challenge','party')]
        $Scope = 'user',
        $ID, #Party or challenge ID. If not provided, will use current party ID
        $Tag
    )
    $parameters = ''
    if ($Type) {
        $parameters += "?type=$Type"
    }
    #Change URI depending on the scope to retrieve
    switch ($Scope) {
        'user' { $Uri = "$HabiticaBaseURI/tasks/user$parameters"; break }
        'group' {
            if (!$ID) {
                $ID = Get-HabiticaGroup -Group 'party' | Select-Object -ExpandProperty id
                $Uri = "$HabiticaBaseURI/tasks/group/$ID/$parameters"; break
            }
            $Uri = "$HabiticaBaseURI/tasks/group/$ID/$parameters"; break
        }
        'challenge' {$Uri = "$HabiticaBaseURI/tasks/challenge/$ID/$parameters"; break}
        'party' {
                $ID = Get-HabiticaGroup -Group 'party' | Select-Object -ExpandProperty id
                $Uri = "$HabiticaBaseURI/tasks/group/$ID/$parameters"; break
        }
        Default {}
    }
    if ($taskID) {
        #If a specific Task UUID was provided, retrieve only that task
        $Uri = "$HabiticaBaseURI/tasks/$TaskID"
    }

    #If a name was specified, return only tasks that contain that name
    if ($Name) {
        $Result = Invoke-RestMethod -Uri $Uri -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data | Where-Object {$_.text -like "*$name*"}
    } Else {
        $Result = Invoke-RestMethod -Uri $Uri -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
    }

    if ($Tag) {
        #Ensure it matches UUID format or look up the UUID
        if ($Tag -notmatch '\w\w\w\w\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w\w\w\w\w\w\w\w\w') {
            Write-Verbose "Not a valid UUID.  Looking up the UUID based on name"
            $TagUUID += (Get-HabiticaTag $Tag | Select-Object -ExpandProperty id)
        } else {$TagUUID += $Tag}
        $Result = $Result | Where-Object {$_.tags -contains $TagUUID}
    }

    Return $Result
}

Function New-HabiticaTask {
    <#
        .SYNOPSIS
            Creates a new task

        .DESCRIPTION
            Creates a new task for a user, group, or challenge.
            Defaults to creating a Todo task for a user with normal priority
            See the link in Related Links for full documentation

        .PARAMETER Text
            The text to be displayed with the task.  May also be considered the name.

        .PARAMETER Type
            Type of task to create [habit, daily, todo, or reward]
            Defaults to todo

        .PARAMETER Tags
            Tags to assign to the task.
            A tag ID is needed, but if text is provided, the matching tag id is attempted to be found

        .PARAMETER Scope
            The scope of the task to be created. [user, challenge, group]
            Defaults to User.  If challenge or group, also provide -ScopeID

        .PARAMETER ScopeID
            If the Scope parameter is challenge or group, the full ID of the challenge or group to create the task for

        .EXAMPLE
            New-HabiticaTask -Text 'Example Task'

        .EXAMPLE
            New-HabiticaTask -Text 'Hard Task' -Priority 'Hard'

        .LINK
            https://habitica.com/apidoc/#api-Task-CreateUserTasks
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [Alias("Name")]
        [string]$Text,
        [ValidateSet("habit", "daily", "todo", "reward")]
        $Type = "todo",
        [Alias("Tag")]
        [string[]]$Tags,
        [string]$Alias,
        [ValidateSet("str", "int", "per", "con")]
        $Attribute,
        [switch]$CollapseChecklist = $False,
        [string]$Notes,
        [string]$Date,
        [ValidateSet("0.1", "1", "1.5", "2","Trivial","Easy","Medium","Hard")]
        [string]$Priority = '1',
        [string[]]$Reminders,
        [ValidateSet("weekly", "daily")]
        [string]$Frequency='weekly',
        [string]$Repeat,
        [int]$Every=1,
        [int]$Streak=0,
        [datetime]$StartDate,
        [switch]$UpDisabled=$False,
        [switch]$DownDisabled=$False,
        [int]$Value=0,
        [ValidateSet('user','challenge','group')]
        $Scope='user',
        $ScopeID
    )
    $Body = @{}
    $Body.add('text', $Text)
    $Body.add('type', $Type)
    if ($Tags) {
        $TagUUID = @() #Array of tags in UUID format
        foreach ($Tag in $Tags) {
            #Ensure it matches UUID format or look up the UUID
            if ($Tag -notmatch '\w\w\w\w\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w-\w\w\w\w\w\w\w\w\w\w\w\w') {
                Write-Verbose "Not a valid UUID.  Looking up the UUID based on name"
                $TagUUID += (Get-HabiticaTag $Tag | Select-Object -ExpandProperty id)
            } else {$TagUUID += $Tag}
        }
        $Body.add('tags', $TagUUID)
    }
    if ($Alias) {$Body.add('alias', $Alias)}
    if ($Attribute) {$Body.add('attribute', $Attribute)}
    if ($CollapseChecklist) {$Body.add('collapseChecklist', $CollapseChecklist)}
    if ($Notes) {$Body.add('notes', $Notes)}
    if ($Date -and $Type -eq 'todo') {$Body.add('date', $Date)}
    if ($Priority -ne '1') {
        Switch ($Priority) {
            'Trivial' {$Priority = '0.1'}
            'Easy' {$Priority = '1'}
            'Medium' {$Priority = '1.5'}
            'Hard' {$Priority = '2'}
        }
        $Body.add('priority', $Priority)
    }
    if ($Reminders) {$Body.add('reminders', $Reminders)}
    if ($Frequency -ne 'weekly' -and $Type -eq 'daily') {$Body.add('frequency', $Frequency)}
    if ($Repeat -and $Type -eq 'daily') {$Body.add('repeat', $Repeat)} #This will need more work
    if ($Every -gt 1 -and $Type -eq 'daily') {$Body.add('everyX', $Every)}
    if ($Streak -gt 0 -and $Type -eq 'daily') {$Body.add('streak', $Streak)}
    if ($StartDate -and $Type -eq 'daily') {$Body.add('startDate', $StartDate)}
    if ($UpDisabled) {$Body.add('up', $Up)}
    if ($DownDisabled) {$Body.add('down', $Down)}
    if ($Value -and $Type -eq 'reward') {$Body.add('value', $Value)}

    $body | ConvertTo-Json
    if ($Scope -eq 'user') {Invoke-RestMethod -Uri "$HabiticaBaseURI/tasks/user" -Headers $HabiticaHeader -Method POST -Body ($Body | Convertto-Json) }
    else {Invoke-RestMethod -Uri "$HabiticaBaseURI/tasks/$Scope/$ScopeID" -Headers $HabiticaHeader -Method POST -Body ($Body | Convertto-Json) }
}

Function Remove-HabiticaTask {
    <#
        .SYNOPSIS
            Deletes/Removes a task without marking it as complete.
            Named Remove-HabiticaTask instead of Delete-HabiticaTask as Remove is a supported Powershell verb

        .PARAMETER  Name
            The text name of a task to remove.
            The more specific the name of the task the better as it will do a search for tasks containing the provided test

        .PARAMETER _ID
            The Habitica _ID value of the task to delete.
            Can be found by using Get-HabiticaTask and piping it to Remove-HabiticaTask

        .EXAMPLE
            Remove-HabiticaTask "Document Functions"
            Removes a task with a name containing "Document Functions"

        .EXAMPLE
            Remove-HabiticaTask -_ID '11111111-2222-3333-4444-555555555555'
            Remove the task with the specified ID

        .LINK
            https://habitica.com/apidoc/#api-Task-DeleteTask
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias("id")]
        $_id

    )
    if ($Name) {$_id = Get-HabiticaUserTask -name $Name | Select-Object -ExpandProperty _id}
    Invoke-RestMethod -Uri "$HabiticaBaseURI/tasks/$_id" -Headers $HabiticaHeader -Method Delete
}

Function Complete-HabiticaTask {
    <#
        .SYNOPSIS
            Marks a specified task as complete

        .DESCRIPTION
            Habitca API calls this "Scoring a task"
            At this time, supports a single task at a time.  Potential future improvements may include handling multiple tasks

        .PARAMETER  Name
            The text name of a task to complete.
            The more specific the name of the task the better as it will do a search for tasks containing the provided test

        .PARAMETER _ID
            The Habitica _ID value of the task to mark as complete.
            Can be found by using Get-HabiticaTask and piping it to Complete-HabiticaTask

        .PARAMETER Direction
            The direction to mark a task as complete.
            By default, the direction is Up.  If task is a Habit with a negative effect, Down will mark as such

        .EXAMPLE
            Complete-HabiticaTask "Document Functions"
            Completes a task with a name containing "Document Functions"

        .EXAMPLE
            Complete-HabiticaTask -_ID '11111111-2222-3333-4444-555555555555'
            Completes the task with the specified ID

        .EXAMPLE
            Get-HabiticaTask 'Document Functions' | Complete-HabiticaTask
            The task object with a name containing 'Document Functions' is returned and passed through the pipeline to Complete-HabiticaTask and is marked complete

        .LINK
        https://habitica.com/apidoc/#api-Task-ScoreTask
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Alias("id")]
        $_id,
        [ValidateSet("up","down")]
        $Direction = "up"
    )
    if ($Name) {$_id = Get-HabiticaTask -name $Name | Select-Object -ExpandProperty _id}
    Invoke-RestMethod -Uri "$HabiticaBaseURI/tasks/$_id/score/$Direction" -Headers $HabiticaHeader -Method POST | Select-Object -ExpandProperty Data
}

Function Connect-Habitica {
<#
    .SYNOPSIS
        Sets variables needed for Habitica RESTApi calls and other functions to work properly

    .DESCRIPTION
        Uses provided UserID and API Tokens to set the $HabitcaBaseURI and $HabiticaHeader variables.
        Can also save credentials to a file and if the file exists, will load saved data.
        Once the Save parameter is used, it will attempt to be loaded automatically when no parameters are provided other than a non-default path
        If using Powershell Core on Linux or MacOS, saving encrypted credentials to file is not available and will be saved as plain text

    .PARAMETER  UserID
        The Habitica UserID to configure the connection with.
        Can be found by logging into Habitica, clicking the user icon in the upper right corner, selecting Settings, then API.
        A prompt for the API Token will appear after running the fuction to store it securely

    .PARAMETER Save
        UserID and API Token will be saved to a file.
        By default, will be saved to the same folder as the Powershell profile with a name of Habitica.xml unless provided with the Path parameter
        If saved on Windows, the API Token in the file can only be read by the same user on the same computer.  If accessed by a different user or copied to another device, it will not be readable
        If using Powershell Core on Linux or MacOS, saving encrypted credentials to file is not available and will be saved as plain text

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
        $Credential,
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
        If(!(Test-Path $path))
        #If the folder or file does not exist, a particular problem if the folder structure does not exist
        {
            New-Item -ItemType 'file' -Force -Path $path
        }
        Write-Verbose "Saving credentials to $Path"
        if ($isLinux -or $isMacOs) {
            #Unable to save encrypted credentials with non-Windows OS, so converting to plain text
            $CredentialPlain = [PSCustomObject] @{
                UserName = $Credential.UserName
                Password = $Credential.GetNetworkCredential().Password
            }
            [PSCustomObject]$Credential = $CredentialPlain
        }
        $Credential | Export-Clixml -Path $Path
    }
    $Global:HabiticaBaseURI = 'https://habitica.com/api/v3'
    if ($isLinux -or $isMacOs) {
        $Global:HabiticaHeader = @{
            "Content-Type" = "application/json"
            'x-api-user' = $Credential.UserName
            'x-api-key' = $Credential.Password
        }
    } Else {
        $Global:HabiticaHeader = @{
            "Content-Type" = "application/json"
            'x-api-user' = $Credential.UserName
            'x-api-key' = $Credential.GetNetworkCredential().Password
        }
    }
}

Function Disconnect-Habitica {
    <#
    .SYNOPSIS
        Removes variables needed for Habitica RESTApi connections

    .DESCRIPTION
        Removes $HabiticaBaseURI and $HabiticaHeader variables used by the Connect-Habitica function which prevents future API calls from functioning
    #>
    Try {Remove-Variable -Name 'HabiticaHeader','HabiticaBaseURI' -Scope 'Script' -ErrorAction Stop}
    Catch {Write-Error 'Not configured to connect to Habitica'}
}

Function Get-HabiticaUserChallenges {
    <#
        .SYNOPSIS
            Returns all challenges available to the user

        .DESCRIPTION
            Get challenges the user has access to.
            Includes public challenges, challenges belonging to the user's group, and challenges the user has already joined.

        .LINK
            https://habitica.com/apidoc/#api-Challenge-GetUserChallenges
    #>
    Return Invoke-RestMethod -Uri "$HabiticaBaseURI/challenges/user" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
}

Function Get-HabiticaUserChallenge {
    <#
        .SYNOPSIS
            Returns challenges currently associated with the current user

        .DESCRIPTION
            Returns only challenges the current user is a part of.
            This is a smaller list compared to Get-HabiticaUserChallenges which lists all challenges a user COULD join

    #>
    $Challenges = Get-HabiticaUser | Select-Object -ExpandProperty Challenges
    $Output = @()
    foreach ($Challenge in $Challenges) {
        $Output += Get-HabiticaChallenge -ChallengeID $Challenge
    }
    Return $Output
}

Function Get-HabiticaChallenge {
    <#
        .SYNOPSIS
            Returns a challenge, given it's UUID

        .DESCRIPTION
            Returns details about a specific challenge, based on it's UUID

        .EXAMPLE
            Get-HabiticaChallenge -ChallengeID 'd46d09fb-760b-4945-9aa1-28184699d158'

        .LINK
            https://habitica.com/apidoc/#api-Challenge-GetChallenge
    #>
    [CmdletBinding()]
    param (
        [Alias('ID')]
        $ChallengeID
    )
    Return Invoke-RestMethod -Uri "$HabiticaBaseURI/challenges/$ChallengeID" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
}

Function Get-HabiticaChallengeMember {
    <#
        .SYNOPSIS
            Returns members of a challenge, given it's UUID

        .DESCRIPTION
            Returns members of a specific challenge, based on it's UUID

        .EXAMPLE
            Get-HabiticaChallengeMembers -ChallengeID 'd46d09fb-760b-4945-9aa1-28184699d158'

        .LINK
            https://habitica.com/apidoc/#api-Member-GetMembersForChallenge
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('ID')]
        $ChallengeID
    )
    Return Invoke-RestMethod -Uri "$HabiticaBaseURI/challenges/$ChallengeID/members" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
}

Function Get-HabiticaChallengeTask {
    <#
        .SYNOPSIS
            Returns tasks for a challenge, given it's UUID

        .DESCRIPTION
            Returns all tasks a specific challenge, based on it's UUID

        .EXAMPLE
            Get-HabiticaChallengeTask -ChallengeID 'd46d09fb-760b-4945-9aa1-28184699d158'

        .EXAMPLE
            Get-HabiticaUserChallenge | Get-HabiticaChallengeTask

        .LINK
            https://habitica.com/apidoc/#api-Task-GetChallengeTasks
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True,ValueFromPipelineByPropertyName=$True)]
        [Alias('ID')]
        $ChallengeID
    )
    Return Invoke-RestMethod -Uri "$HabiticaBaseURI/tasks/challenge/$ChallengeID" -Headers $HabiticaHeader -Method GET | Select-Object -ExpandProperty Data
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
        Return $Report
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
    #Remove special characters that cause problems in Habitica and Discord
    $Report = $Report -replace 'ï','i'

    $Body = Format-HabiticaReport $Report
    Invoke-RestMethod -Uri "$HabiticaBaseURI/groups/party/chat" -Headers $HabiticaHeader -Method POST -Body $Body
}

function Publish-DiscordReport {
    <#
        .SYNOPSIS
            Posts information to a Discord channel

        .DESCRIPTION
            Receives report data, formats it for Discord's Markdown requirements, and posts it to the Discord Webhook URL
            To create or retrieve a Webhook URL, in Discord:
            Right click on a channel, select Edit Channel, Webhooks, Create Webook and copy the URL into $DiscordWebhookUrl

        .PARAMETER Report
            An array of text to be published.  Text will be formatted using Discords Markdown requirements to ensure line breaks work as expected.

        .PARAMETER DiscordWebhookUrl
            The full Webhook URL for the desired Discord channel

        .EXAMPLE
            Publish-DiscordReport -Report $Report -DiscordWebhookUrl https://discordapp.com/api/webhooks/100899273626745649/WzfQpTrK...

        .LINK
            https://www.gngrninja.com/script-ninja/2018/3/10/using-discord-webhooks-with-powershell
    #>
    [CmdletBinding()]
    param (
        $Report = $Report,
        $DiscordWebhookUrl = $DiscordWebhookUrl
    )
    #Remove special characters that cause problems in Habitica and Discord
    $Report = $Report -replace 'ï','i'

    $content = Format-DiscordReport $Report
    Invoke-RestMethod -Uri $DiscordWebhookUrl -Method Post -Body $content
}

Function Get-HabiticaQuestStatus {
    <#
        .SYNOPSIS
            Returns the status of a party quest

        .DESCRIPTION
            Returns the status of a party quest, either none, pending, or active.  Pending is one that invites have been sent, but has not been started

        .PARAMETER PartyData
            Output of Get-HabiticaGroup that contains information about the party.  If parameter is not supplied, it will get current party data.
            If previous Get-HabiticaGroup information was saved for a point-in-time reference or if an attempt to limit traffic, it can be supplied.

        .EXAMPLE
            Get-HabiticaGroup
            Pending
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$True)]
        $PartyData = (Get-HabiticaGroup)
    )
    Process {
        #$PartyData.quest.members is not a string by default but multiple properties.  Converting to string for comparison
        if ($PartyData.quest.active -eq $False -and ($PartyData.quest.members | Out-String) -notlike '*:*') {
            Write-Verbose 'No Quest is active or pending'
            Return 'None'
        } Elseif ($PartyData.quest.active -eq $False -and $PartyData.quest.key -ne $Null) {
            Write-Verbose "Quest $($PartyData.quest.key) is pending"
            Return 'Pending'
        } Else {Return 'Active'}
    }
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

 Function ConvertTo-HabiticaTimestamp {
    <#
        .SYNOPSIS
            Converts datetime fields to Habitica timestamp fields

        .DESCRIPTION
            Habitica time is in Unix Epoch time, multipled by 1000. This function converts a human readable date and time to the Habitica format

        .PARAMETER Date
            A date field to convert

        .EXAMPLE
            ConvertTo-HabiticaTimestamp
            Converts the current date and time into Habitica timestamp format

        .EXAMPLE
            ConvertTo-HabiticaTimestamp '1/1/2018 4:00 pm'
            Converts the specified date and time into Habitica timestamp
    #>
    [cmdletbinding()]
    param (
        #Casting as Decimal to keep it from casting as a string
        $Date = (Get-Date)
    )
    [decimal]$DateTime = Get-Date $Date -UFormat %s
    #Habitica time is in Unix Epoc time multiplied by 1000. Using Long to round to whole number
    Return [long]($DateTime * 1000)
 }


Function Get-HabiticaQuestQueue {
    <#
        .SYNOPSIS
            Retrieves a saved list of users and what quest they are scheduled to complete next

        .DESCRIPTION
            Retrieves a saved list of quests from the -Path location to be used with sending reminders to users

        .PARAMETER Path
            The full file path including filename to load saved quest queue from.
            If not provided, the default path is the Powershell Profile folder and file name HabiticaQuestQueue.xml

        .EXAMPLE
            $QuestList = Get-HabiticaQuestQueue
    #>
    [CmdletBinding()]
    param (
        $Path = (Join-Path (Split-Path $profile) HabiticaQuestQueue.xml) #Powershell Profile path folder
    )
    if (Test-Path $Path) {
        Write-Verbose "Loading saved quest queue from $Path"
        Return Import-Clixml -Path $Path
    } Else {
        #If no credential object, prompt to get credentials
        Write-Verbose 'No saved quest queue found. Please use Save-HabiticaQuestQueue to create a saved list'
    }
}

Function Save-HabiticaQuestQueue {
    <#
        .SYNOPSIS
            Saves list of users and what quest they are scheduled to complete next

        .DESCRIPTION
            Saves a list of quests to the -Path location to be used with sending reminders to users

        .PARAMETER QuestQueue
            Variable containing the quest queue to be saved

        .PARAMETER Path
            The full file path including filename to save quest queue list
            If not provided, the default path is the Powershell Profile folder and file name HabiticaQuestQueue.xml

        .EXAMPLE
            Save-HabiticaQuestQueue
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        $QuestQueue,
        $Path = (Join-Path (Split-Path $profile) HabiticaQuestQueue.xml) #Powershell Profile path folder
    )
        Write-Verbose "Saving quest queue to $Path"
        $QuestQueue | Export-Clixml -Path $Path
}

Function Send-HabiticaQuestQueueReminder {
    <#
        .SYNOPSIS
            Sends a private message to the next user in the queue to remind them to start the quest

        .PARAMETER QuestQueue
            Variable containing the quest queue to use or can use Get-HabiticaQuestQueue to load current queue from saved file

        .EXAMPLE
            Send-HabiticaQuestQueueReminder -QuestQueue (Get-HabiticaQuestQueue)
    #>
    [CmdletBinding()]
    param (
        $QuestQueue
    )
    write-Verbose "Sending private message to $($QuestQueue[0].User) asking them to please start $($QuestQueue[0].Quest)"
    Send-HabiticaPrivateMessage -UserID $QuestQueue[0].User -Message "Your quest is next.  Please start $($QuestQueue[0].Quest)"
}

Function Add-HabiticaQuestQueueEntry {
    <#
        .SYNOPSIS
            Adds another entry to the end of the quest queue list

        .PARAMETER QuestQueue
            Variable containing the existing quest queue to use or can use Get-HabiticaQuestQueue

        .PARAMETER User
            The Habitica name of the user to be added to the queue

        .PARAMETER Quest
            The name of the Habitica quest for the user to start

        .EXAMPLE
            $QuestQueue = Get-HabiticaQuestQueue
            $QuestQueue = Add-HabiticaQuestQueueEntry $QuestQueue -user 'User1' -quest 'Recidivate, Part 1: The Moonstone Chain'
            Save-HabiticaQuestQueue -QuestQueue $QuestQueue
    #>
    [CmdletBinding()]
    param (
        [Object[]]$QuestQueue,
        [Parameter(Mandatory=$True)]
        [string]$User,
        [Parameter(Mandatory=$True)]
        [string]$Quest
    )

    $QuestQueue += [PSCustomObject] @{
        User = $User
        Quest = $Quest
    }
    Return $QuestQueue
}

Function Remove-HabiticaQuestQueueEntry {
    <#
        .SYNOPSIS
            Removes the first entry of the QuestQueue and returns the remaining entries

        .PARAMETER QuestQueue
            Variable containing the quest queue to use or can use Get-HabiticaQuestQueue

        .EXAMPLE
            $QuestQueue = Remove-HabiticaQuestQueueEntry -QuestQueue $QuestQueue
    #>
    [CmdletBinding()]
    param (
        $QuestQueue = (Get-HabiticaQuestQueue)
    )
    for ($i=1; $i -le $QuestQueue.count; $i++) {$QuestQueue | Select-Object -Index $i}
}

Function Skip-HabiticaQuestQueueEntry {
    <#
        .SYNOPSIS
            Skips the next entry of the QuestQueue and saves the remaining entries

        .Description
            Used if a player will not be starting the next quest entry and needs to be skipped

        .PARAMETER QuestQueue
            Variable containing the quest queue to use or can use Get-HabiticaQuestQueue

        .EXAMPLE
            Skip-HabiticaQuestQueueEntry
    #>
    [CmdletBinding()]
    param (
        $QuestQueue = (Get-HabiticaQuestQueue)
    )
    $QuestQueue = Remove-HabiticaQuestQueueEntry -QuestQueue $QuestQueue
    Save-HabiticaQuestQueue -QuestQueue $QuestQueue
}

Function Connect-Discord {
    <#
        .SYNOPSIS
            Sets variables needed for Discord Webhook usage

        .DESCRIPTION
            Used to configure a Discord Webhook connection for any functions that can post to a channel
            To get the Webhook URL if you have appropriate Discord permissions:
                Right click on a Discord channel, select Edit Channel, Webhooks, Create Webook
            When prompted, but the URL into the Password field of the credential prompt

        .PARAMETER Save
            Webook URL will be saved to a file.
            By default, will be saved to the same folder as the Powershell profile with a name of Discord- followed by the computer name unless provided with the Path parameter
            File is saved in XML format.
            If saved on Windows, the Webhook URL in the file can only be read by the same user on the same computer.  If accessed by a different user or copied to another device, it will not be readable
            If using Powershell Core on Linux or MacOS, saving encrypted text to file is not available and will be saved as plain text

        .PARAMETER Path
            The full file path including filename to save credentials to or to load saved credentials from.
            If not provided, the default path is the Powershell Profile folder and file name Discord-'ComputerName'.xml

        .EXAMPLE
            Connect-Discord
            If saved Webhook exist, they will be loaded.
            If no saved Webhook exist, a prompt for the URL will appear

        .EXAMPLE
            Connect-Discord -Save
            After being prompted for the URL, it will be saved securely to the local computer if on Windows

        .EXAMPLE
            Connect-Discord -Path C:\Scripts\Discord-Testing.xml
            Load saved URL from the specified path.  No prompt for a URL
    #>
    [CmdletBinding()]
    param (
        [switch]$Save,
        $Path = (Join-Path (Split-Path $profile) "Discord-$env:Computername.xml") #Powershell Profile path folder
    )

    #If saved file exists, use it
    if ((Test-Path $Path) -and !$Save) {
        Write-Verbose "Loading Webhook from $Path"
        $Credential = Import-Clixml -Path $Path
    } Else {
        #If no saved file, prompt for URL
        Write-Verbose 'No saved file found.  Prompting for Webhook'
        $Credential = Get-Credential -UserName "Discord" -Message "Enter your full Discord Webhook URL in the Password field.  This can be found by logging into Discord, Right click on a Discord channel, select Edit Channel, Webhooks, Create Webook"
    }

    if ($Save) {
        If(!(Test-Path $path))
        #If the folder or file does not exist, a particular problem if the folder structure does not exist
        {
            New-Item -ItemType 'file' -Force -Path $Path
        }
        Write-Verbose "Saving credentials to $Path"
        if ($isLinux -or $isMacOs) {
            #Unable to save encrypted credentials with non-Windows OS, so converting to plain text
            $CredentialPlain = [PSCustomObject] @{
                UserName = $Credential.UserName
                Password = $Credential.GetNetworkCredential().Password
            }
            [PSCustomObject]$Credential = $CredentialPlain
        }
        $Credential | Export-Clixml -Path $Path
    }
    #Making variable available outside of this function for use with others.
    #Powershell Core on Linux does not appear to work like Windows does with $Script:DiscordWebhookUrl so changed to Global
    if ($isLinux -or $isMacOs) {
        $Global:DiscordWebhookUrl = $Credential.Password
    } Else {
        $Global:DiscordWebhookUrl = $Credential.GetNetworkCredential().Password
    }
    #Return $Global:DiscordWebhookUrl
}

Function Publish-HabiticaQuestReport {
    <#
    .SYNOPSIS
        Generates a report to the Party chat with stats about the most recent quest

    .DESCRIPTION
        Generates a Quest Results report showing details about the most recent quest.
        Originally designed by Habitica user Dispatch009
        Shows various stats including how long the quest took, who did the most damage, who did the most party buffs and more
        Will only send the report if one has not been generated since the last quest was completed, allowing it to be ran on a schedule such as every hour without spammming the chat

    .PARAMETER Discord
        If desired, the same report can be sent to a Discord channel through a Webhook.  See Connect-Discord for details on where to get the URL and save credentials

    .PARAMETER QueueReminder
        Reminders will be sent to the next user in the queue to being their quest as a private message.
        To setup a queue, use the following commands
        $QuestQueue = Add-HabiticaQuestQueueEntry -user 'User1' -quest 'Recidivate, Part 1: The Moonstone Chain'
        $QuestQueue = Add-HabiticaQuestQueueEntry $QuestQueue -user 'User2' -quest 'Recidivate, Part 3: The Moonstone Chain'
        Save-HabiticaQuestQueue -QuestQueue $QuestQueue

    .EXAMPLE
        Publish-HabiticaQuestReport
        Generates the report using default credentials from Connect-Habitica and publishes them to the chat if it has not already done so

    .EXAMPLE
        Publish-HabiticaQuestReport -Discord
        Generates the report and also publishes it to a Discord channel
    #>
    [CmdletBinding()]
    param (
        [switch]$Discord,
        [switch]$QueueReminder
    )
    Connect-Habitica
    $PartyChat = Get-HabiticaGroupChat -GroupID 'party'
    $QuestActions = Get-HabiticaQuestMessage -PartyChat $PartyChat | Get-HabiticaQuestAction
    $Report = Format-HabiticaQuestReport -QuestActions $QuestActions

    #Checking if the last report was before the last quest completed and if so, will post it
    if (Test-HabiticaReportNeeded -PartyChat $PartyChat -QuestActions $QuestActions){
        Publish-HabiticaReport $Report
        if ($Discord) {
            if (!$DiscordWebhookUrl) {
                Write-Verbose "Not already connected to Discord.  Running Connect-Discord to load saved data or prompt for the URL"
                Connect-Discord
            }
            Publish-DiscordReport $Report
        }
        if ($QueueReminder) {
            Write-Verbose 'Processing quest queue'
            $QuestQueue = Get-HabiticaQuestQueue
            Send-HabiticaPrivateMessage -UserID $QuestQueue[0].User -Message "Your quest is next.  Please start $($QuestQueue[0].Quest)"
            if ($Discord) {Publish-DiscordReport "$($QuestQueue[0].user) is up next with quest $($QuestQueue[0].quest)"}
            $QuestQueue = Remove-HabiticaQuestQueueEntry -QuestQueue $QuestQueue
            Save-HabiticaQuestQueue -QuestQueue $QuestQueue
        }
    }
}

Function Publish-HabiticaQuestPendingNotice {
    <#
    .SYNOPSIS
        Checks how long a quest has been in the pending state and attempts to start the quest or notify leaders to start the quest

    .DESCRIPTION
        When ran, checks to see if a quest is pending.  If so, a custom chat message is published to reference the elapsed time.
        When the PendingQuestTimer value is exceeded (defaults to 24 hours minus 0.1 hours) the quest is attempted to be started using the Habitica quest account running the command.
        If the account is the party or quest leader, the quest will automatically start.
        If the account is not the party or quest leader, a private message will be sent to both leaders asking them to start the quest

    .PARAMETER PendingHeader
        The header text to be put into the party chat followed by "started by <QuestLeaderName>".  Defaults to:
        Invites sent for pending quest

    .PARAMETER PendingQuestTimer
        Number of hours the quest will be pending before a message is sent.  Defaults to 24 hours.
        Is actually subtracting 0.1 hours so if ran on an hourly schedule it will not run for an extra cycle.

    .EXAMPLE
        Publish-HabiticaQuestPendingNotice
        Uses default values to send pending notices to the party chat and reminders to the quest owner and party leader after 24 hours

    .EXAMPLE
        Publish-HabiticaQuestPendingNotice -PendingHeader 'Fly you fools! In 6 hours we begin a quest' -PendingQuestTimer 6
        Modifies the party chat message to custom text and will send messages to the quest owner and party leader after 6 hours
    #>
    [CmdletBinding()]
    param (
        [string]$PendingHeader = 'Invites sent for pending quest',
        [int]$PendingQuestTimer = 24
    )
    Connect-Habitica

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
}



New-Alias -Name Get-HabiticaPartyChat -Value Get-HabiticaGroupChat
New-Alias -Name Get-HabiticaParty -Value Get-HabiticaGroup
Export-ModuleMember -Alias * -Function *
