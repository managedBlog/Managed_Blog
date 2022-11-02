<#
Name: Update-PrimaryUserWebhook.ps1
Author: Ben Reader, twitter @powers_hell
Updated by: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 1.0
.Synopsis
   This is an updated version of Ben Reader's Add-GraphApiRoleToMSI.ps1 (https://github.com/tabs-not-spaces/CodeDump/blob/master/GraphApiToMSI/Add-GraphApiRoleToMSI.ps1)
.DESCRIPTION
   This version includes two updates:

   1) The $msiparams hashtable is updated prior to calling Invoke-RestMethod. I noticed the script failing when the URI was updated at the same time Invoke-RestMethod was called
   2) The list of roles includes most common roles needed for Intune administration. Please note that the Update-PrimaryUserWebhook specifically needs DeviceManagementManagedDevice.PrivilegedOperations.All.
#>

#region Functions
function Add-GraphApiRoleToMSI {
    [cmdletbinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$ApplicationName,

        [parameter(Mandatory = $true)]
        [string[]]$GraphApiRole,

        [parameter(mandatory = $true)]
        [string]$Token
    )

    $baseUri = 'https://graph.microsoft.com/v1.0/servicePrincipals'
    $graphAppId = '00000003-0000-0000-c000-000000000000'
    $spSearchFiler = '"displayName:{0}" OR "appID:{1}"' -f $ApplicationName, $graphAppId


    try {
        $msiParams = @{
            Method  = 'Get'
            Uri     = '{0}?$search={1}' -f $baseUri, $spSearchFiler
            Headers = @{Authorization = "Bearer $Token"; ConsistencyLevel = "eventual" }
        }
        $spList = (Invoke-RestMethod @msiParams).Value
        $msiId = ($spList | Where-Object { $_.displayName -eq $applicationName }).Id
        $graphId = ($spList | Where-Object { $_.appId -eq $graphAppId }).Id


        $msiParams["Uri"] = "$($baseUri)/$($msiId)?`$expand=appRoleAssignments"
        $msiItem = Invoke-RestMethod @msiParams #-Uri "$($baseUri)/$($msiId)?`$expand=appRoleAssignments"

        $msiParams["Uri"] = "$baseUri/$($graphId)/appRoles"
        $graphRoles = (Invoke-RestMethod @msiParams).Value |   
        Where-Object { $_.value -in $GraphApiRole -and $_.allowedMemberTypes -Contains "Application" } |
        Select-Object allowedMemberTypes, id, value
        foreach ($roleItem in $graphRoles) {
            if ($roleItem.id -notIn $msiItem.appRoleAssignments.appRoleId) {
                Write-Host "Adding role ($($roleItem.value)) to identity: $($applicationName).." -ForegroundColor Green
                $postBody = @{
                    "principalId" = $msiId
                    "resourceId"  = $graphId
                    "appRoleId"   = $roleItem.id
                }
                $postParams = @{
                    Method      = 'Post'
                    Uri         = "$baseUri/$graphId/appRoleAssignedTo"
                    Body        = $postBody | ConvertTo-Json
                    Headers     = $msiParams.Headers
                    ContentType = 'Application/Json'
                }
                $result = Invoke-RestMethod @postParams
                if ( $PSBoundParameters['Verbose'] -or $VerbosePreference -eq 'Continue' ) {
                    $result
                }
            }
            else {
                Write-Host "role ($($roleItem.value)) already found in $($applicationName).." -ForegroundColor Yellow
            }
        }
        
    }
    catch {
        Write-Warning $_.Exception.Message
    }
}
#endregion

#region How to use the function
Connect-AzAccount -Tenant "modernendpoint.dev"
$token = Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com"
$roles = @(
    "DeviceManagementApps.ReadWrite.All", 
    "DeviceManagementRBAC.Read.All", 
    "DeviceManagementServiceConfig.ReadWrite.All", 
    "DeviceManagementManagedDevices.PrivilegedOperations.All"
    "DeviceManagementManagedDevices.ReadWrite.All",
    "DeviceManagementConfiguration.ReadWrite.All",
    "GroupMember.Read.All",
    "User.ReadWrite.All",
    "Directory.ReadWrite.All",
    "Device.ReadWrite.All"


)
Add-GraphApiRoleToMSI -ApplicationName "MME-MMS-DemoLab" -GraphApiRole $roles -Token $token.Token
#endregion



