#Use a client secret to authenticate to Microsoft Graph using MSAL
$authparams = @{
    ClientId    = '[App Registration Client ID]'
    TenantId    = 'yourdomain.xyz'
    ClientSecret = ('[YourClientSecret]' | ConvertTo-SecureString -AsPlainText -Force )
}

$auth = Get-MsalToken @authParams

#Set Access token variable for use when making API calls
$AccessToken = $Auth.AccessToken

#Function to make Microsoft Graph API calls
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

#Create required variables
#The following example will update the management name of the device at the following URI
#$URI = "https://graph.microsoft.com/beta/deviceManagement/managedDevices('[DeviceID]')"
#$Body = @{ "managedDeviceName" = "New_Device_Management_Name" } | ConvertTo-Json
#$Method = "PATCH"

#The following example will return all Azure AD Users
$URI = "https://graph.microsoft.com/beta/users"
$Method = "GET"

#Call Invoke-MsGraphCall
$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

$LastStatusCode = $MSGraphCall[0]
$ReturnedValue = $MSGraphCall[1].value



$ReturnedValue
Write-Host "SCV is $LastStatusCode"