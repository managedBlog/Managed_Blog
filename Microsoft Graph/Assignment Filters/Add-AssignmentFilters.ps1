<#
Name: Add-AssignmentFilters
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 1.0
.Synopsis
   Adds an assignment filter to selected application assignments
.DESCRIPTION
   Add-AssignmentFilters is a script designed to allow an administrator to select an existing filter in Microsoft Endpoint Manager and apply it to an application (or applications) that they select from a separate list.
#>
#Requires -modules MSAL.ps

[cmdletBinding()]
param(

    [Parameter(Mandatory=$True)]
    [ValidateSet("include","exclude")]
        [string]$FilterMode

)

#Authenticate to MS Graph with app registration using MSAL library
$authparams = @{
    ClientId    = '[Your Client ID]'
    TenantId    = '[Your Tenant ID]'
    ClientSecret = ('[Your Client Secret]' | ConvertTo-SecureString -AsPlainText -Force )
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


#Return a list of all filters
$Method = "GET"
$URI = "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters"

$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

#Parse returned object to set Filters variable
$Filters = $MSGraphCall.value

#Show user grid view to select filter
Write-Host "Please select a filter to continue..." -ForegroundColor Yellow
$FilterId = $Filters | Out-GridView -PassThru | Select-Object -ExpandProperty id


#Get a list of all assigned applications. Script will only update applications with existing assignments
$Method = "GET"
$URI = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps?`$filter=isAssigned eq true"

$MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

#Pipe a list of all assigned apps to Out-GridView. User may select one or many apps.
$AssignedApps = $MSGraphCall[1].value

Write-Host "Please select the apps you would like to update to continue. ***NOTE: App types must match application type used in filter!" -ForegroundColor Yellow
$AppsToUpdate = $AssignedApps | Select-Object displayName,`@odata.type,id | Out-GridView -PassThru

#Process each selected app to udpate filter
ForEach($ATU in $AppsToUpdate){

    #Null values used to create hashtable. Apps of different odata types may not have all properties, and failing to null variables before running may cause script to fail!
    $Target = $null
    $Settings = $null
    $TargetHash = $null
    $SettingsHash = $null

    #Get App Assignments
    $AppID = $ATU.id

    $Method = "GET"
    $URI = "https://graph.microsoft.com/beta/deviceAppManagement/MobileApps/$AppID/assignments"

    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

    #Process each app assignment on applications to apply filter. Script is currently built to apply same filter to ALL assignments.
    $AssignmentIDs = $MSGraphCall.value

    ForEach($AID in $AssignmentIDs){}

    #Set values to create hashtable. Settings will use all existing values, target will update app assignment with filter information. All other values remain the same
    $Target = $AID.target
    $Settings = $AID.settings

    $Target.deviceAndAppManagementAssignmentFilterId = $FilterId
    $Target.deviceAndAppManagementAssignmentFilterType = $FilterMode

    #Create target hashtable
    $TargetHash = [ordered]@{}
    $Target.psobject.Properties | ForEach-Object { $TargetHash[$_.Name] = $_.Value }

    #Create hashtable for API call body
    $Hash = [ordered]@{ 

        "@odata.type" = "#microsoft.graph.mobileAppAssignment"
        "intent" = "Required"
        "target" = $TargetHash
        
    } 

    #If settings were returned with assignments, create settings hash and add it to hash
    If($Settings){

        $SettingsHash = [ordered]@{}
        $Settings.psobject.Properties | ForEach-Object { $SettingsHash[$_.Name] = $_.Value }
        $Hash.Insert(2, 'settings', $SettingsHash)

    }

    #Note: Different app types have different JSON depths. I haven't found any that go deeper than 4, but this is a potential point of failure.
    $MobAppAssignments = @{ "mobileAppAssignments" = @($Hash) } | ConvertTo-Json -Depth 5


    #Update the management name of the device at the URI for each device ID
    $URI = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$AppId/assign"
    $Body = $MobAppAssignments
    $Method = "POST"

    #Call Invoke-MsGraphCall to assign filters to applications
    $MSGraphCall = Invoke-MsGraphCall -AccessToken $AccessToken -URI $URI -Method $Method -Body $Body

}


