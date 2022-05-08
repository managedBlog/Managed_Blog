#Invoke-RestMethod_CreatUsers.ps1 and PSCreate-Users were used to demonstrate how to batch create users side by side
#They were also designed to create identical sets of users with both methods. 
#After connecting to Microsoft Graph, they both have a stopwatch item added. This was done to test to see if one method was better than the other
#In my testing, Invoke-RestMethod was faster on a small scale, but at a large scale (50 users) neither option seemed to have an advantage
#These scripts were also used to demonstrate how the parameters used in the SDK match the required items in the body object when calling the API directly

#In this example we are connecting programmatically with a Client Secret. Because this is outside of the stopwatch timer it has no impact on the performance comparison
#Create authparams splat to get access token
$authparams = @{
    ClientId    = '[Your App registration Client ID goes here]'
    TenantId    = '[Your tenant ID goes here]'
    ClientSecret = ('[Your client secret goes here]' | ConvertTo-SecureString -AsPlainText -Force )
}

#Use get-msaltoken to return token
$auth = Get-MsalToken @authParams

#Set access token
$AccessToken = $auth.AccessToken

#Initiate stopwatch
$StopWatchIRM = [system.diagnostics.stopwatch]::StartNew()

#Import users from GraphUsers02.csv
$Users = Import-Csv "C:\temp\MMSMOA\GraphUsers02.csv"

#Read Invoke-MsGraphCall into memory. This accounts for most of the "bulk" in the length of this script
Function Invoke-MsGraphCall {

    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$AccessToken,
        [Parameter(Mandatory=$True)]
        [string]$URI,
        [Parameter(Mandatory=$True)]
        [string]$Method,
        [Parameter(Mandatory=$False)]
        [string]$Body
    )


    #Create Splat hashtable
    $graphSplatParams = @{
        Headers     = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $($AccessToken)"
        }
        Method = $Method
        URI = $URI
        ErrorAction = "SilentlyContinue"
        StatusCodeVariable = "scv"
    }

    #If method requires body, add body to splat
    If($Method -in ('PUT','PATCH','POST')){

        $graphSplatParams["Body"] = $Body 
    }

    #Return API call result to script
    $MSGraphResult = Invoke-RestMethod @graphSplatParams

    #Return status code variable to script
    Return $SCV, $MSGraphResult

}

#Perform a ForEach loop to create each individual user
ForEach($User in $Users){

    #Create body hashtable, compare this to the Params splat in the SDK demo
    $Body= @{ 

        "accountEnabled" = $User.Enabled
        "displayName" = $User.displayName
        "mailNickname" = $User.mailNickname
        "userPrincipalName" = $User.userPrincipalName
        "passwordProfile"  = @{
          "forceChangePasswordNextSignIn" = $User.forceChangePasswordNextSignIn
          "password" = $User.password
        
        }
    }


    #Create required variables to pass into Invoke-MsGraphCall
    $URI = "https://graph.microsoft.com/beta/users"
    $Method = "POST"

    #Convert Body hashtable to Json
    $Body = $Body | ConvertTo-Json
    
    #Call Invoke-MsGraphCall
    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body
    $MSGraphCall.value
    
}

#Stop stopwatch and return elapsed time
$StopWatchIRM.Stop()
$StopWatchIRM.Elapsed