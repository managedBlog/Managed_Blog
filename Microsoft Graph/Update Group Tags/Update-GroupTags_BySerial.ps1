
#Use a client secret to authenticate to Microsoft Graph using MSAL
$authparams = @{
    ClientId    = '[Your Client Id]'
    TenantId    = 'YourDomain.com'
    ClientSecret = ('[Your Client Secret]' | ConvertTo-SecureString -AsPlainText -Force )
}

$auth = Get-MsalToken @authParams

#Set Access token variable for use when making API calls
$AccessToken = $Auth.AccessToken

#Get content of CSV containing serial numbers
#This should be a single column with no headers
$Serials = Get-Content "C:\Temp\serials.csv"

#If assigning the same group tag to all devices, update this variable
$NewGroupTag = "Updated-Group-Tag"

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



#Return all Autopilot device identities
#Create parameters to use in Invoke-MSGraphCall
$URI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/"
$Method = "GET"

#Call Invoke-MsGraphCall
$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

#Create list of objects with serialNumber, id, and GroupTag
$Devices = $MSGraphCall[1].value | Select-Object -Property SerialNumber,id,groupTag

#For each device listed in serial numbers find the associate Autopilot Device ID, and update the group tag
ForEach($s in $serials){

    $DeviceToUpdate = $Devices | Where-Object serialNumber -eq $s
    $id = $DeviceToUpdate.id

    
    $Body = @{ "groupTag" = "$NewGroupTag" } | ConvertTo-Json  
    $URI  = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$id/UpdateDeviceProperties"
    $Method = "POST"

    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

}
