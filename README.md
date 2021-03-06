# Habitica
Powershell Module and scripts for interacting with Habitica.com

Originally created to automate a quest report for a party, it was expanded to include regular day-to-day Habitica activities in a Powershell module.

# Powershell Module Installation
Ensure that Powershell 5+ (Windows) or Powershell Core 6+ (Windows, Linux, MacOS) is installed
https://www.thomasmaurer.ch/2019/03/how-to-install-and-update-powershell-6/

Install the latest version of the Habitica Module

_Install for all users (must run with administrator rights)_

`Install-Module Habitica`

_Install for the current user_

`Install-Module Habitica -Scope CurrentUser`

# Connecting to Habitica
Once the Powershell module has been installed, run the following command

`Connect-Habitica -Save`

A prompt will appear for a Habitica UserID and API Token which can be retrieved by logging into the Habitica website, clicking the user icon in the upper right, Settings, API
The -Save option will save these credentials to disk.  Subsequent runs can just use `Connect-Habitica` to load the saved credentials

# Quest Report
The Quest Report will detect when the last quest was completed and if a report has not been generated since then.  If not, it will run the report and post it to the Party Chat.  If desired, Discord webhooks can also be used to post the report to a channel. This report was originally designed by Habitica user Dispatch009
 <br /> ![alt text](./images/Quest-Results.jpg)

## Using the Quest Report
From the Powershell prompt, run the following command

`Publish-HabiticaQuestReport`

This can also be placed into a script file and ran on a regular schedule using Task Scheduler, cron, or other repeating task.

If the Powershell module is not installed, the file "Habitica-QuestResultReport-Standalone.ps1" can be modified with the API User and Token information and ran without the module.

## Quest Pending Notice
To help keep quests going in parties where not every member may accept or decline the command a reminder can be send using the command:

`Publish-HabiticaQuestPendingNotice`

By default it will check to see if a quest is pending and if so, put a message in the party chat, starting a counter.  When the PendingQuestTimer value (24 hours by default) has elapsed, the command will attempt to start the quest if ran with Party or Quest leader credentials, or send a private message to the Party and Quest Leader asking them to start the quest.

It is best to run this as part of a scheduled script on a repeating basis so the messages go out in a timely manner.

## Powershell command examples
Various powershell commands are available after installing the module.  Each command has its own help file.
Examples:

`New-HabiticaTask -Text 'Example Task'`

`New-HabiticaTask -Text 'Document Function' -Priority 'Hard'`

`Complete-HabiticaTask "Document Functions"`

`Send-HabiticaPrivateMessage -Message 'Hi there!' -UserID (Get-HabiticaGroup -Group 'party').leader.id`
