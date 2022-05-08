#This script can be used to remove all of the users created with the two demo scripts. It will run using Invoke-RestMethod
#Use interactive authentication to connect to Microsoft Graph and return a token
$authParams = @{
    ClientId    = '[Enter your App Registration Client ID here]'
    TenantId    = '[Enter your tenant ID or primary domain here]'
    Interactive = $true
}
$auth = Get-MsalToken @authParams


$AccessToken = $auth.AccessToken


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


#Return all devices with a displayName that starts with "MMSBlog"
#These devices were created in the side by side comparison of the PowerShell SDK and using Invoke-RestMethod
$URI = "https://graph.microsoft.com/v1.0/users?`$filter=startswith(displayName,'MMSBlog')"
$Method = "GET"

$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

$Users = $MSGraphCall.value

#Delete all returned users
ForEach($User in $Users){

    $UPN = $User.userPrincipalName
    $UPN

    $URI = "https://graph.microsoft.com/v1.0/users/$UPN"
    $URI
    $Method = "DELETE"

    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

}
    