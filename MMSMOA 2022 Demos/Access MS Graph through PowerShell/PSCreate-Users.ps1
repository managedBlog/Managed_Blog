#Invoke-RestMethod_CreatUsers.ps1 and PSCreate-Users were used to demonstrate how to batch create users side by side
#They were also designed to create identical sets of users with both methods. 
#After connecting to Microsoft Graph, they both have a stopwatch item added. This was done to test to see if one method was better than the other
#In my testing, Invoke-RestMethod was faster on a small scale, but at a large scale (50 users) neither option seemed to have an advantage
#These scripts were also used to demonstrate how the parameters used in the SDK match the required items in the body object when calling the API directly

#Import the Microsoft.Graph.Users module and select the v1.0 endpoint
Import-Module Microsoft.Graph.Users  
Select-MgProfile -Name "v1.0"

#Connect to Microsoft Graph interactively with required permissions to create users
Connect-MgGraph -Scopes "User.ReadWrite.All","Directory.ReadWrite.All"

#Initiate a stop watch
$StopWatchMg = [system.diagnostics.stopwatch]::StartNew()

#Read in the users from GraphUser01.csv
$Users = Import-Csv "C:\temp\MMSMOA\GraphUsers01.csv"

#Create each user
#Note that in PowerShell we could use threading to make this run faster. When calling Invoke-RestMethod we could use batching.
#A simple ForEach loop is used in both to give a better performance comparison
ForEach($User in $Users){

    #The params splat matches the body object we had to create when using Invoke-RestMethod
    $params = @{
        AccountEnabled = $User.Enabled
        DisplayName = $User.DisplayName
        MailNickname = $User.MailNickname
        UserPrincipalName = $User.UserPrincipalName
        PasswordProfile = @{
            ForceChangePasswordNextSignIn = $User.forceChangePasswordNextSignIn
            Password = $User.password
        }
    }
    
    #Call New-MgUser to create user
    New-MgUser -BodyParameter $params


}

#Stop stopwatch and show elapsed time
$StopWatchMg.Stop()
$StopWatchMg.Elapsed