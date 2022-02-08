<#
Name: Create-AutomationAccount
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 1.0
.Synopsis
   Creates a new AAzure Automation Account, enables the managed identity, and creates an Access Policy in Azure Key Vault 
.DESCRIPTION
   Create-AutomationAccount is a script designed to allow an administrator to quickly create a new Azure Automation Account. If the -CreateNewResource value is set to True, a new resource group will also be created. The administrator can also pass in the Subscription, region,
   and an existing resource group name. If those parameters are not specified, the user will be prompted to select them if needed.
#>
#Requires -modules Az

[cmdletBinding()]
param(

    [Parameter(Mandatory=$False)]
    [System.Boolean]$CreateNewResource,
    [Parameter(Mandatory=$False)]
    [string]$Subscription,
    [Parameter(Mandatory=$False)]
    [string]$ResourceGroup,
    [Parameter(Mandatory=$False)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$False)]
    [string]$Region,
    [Parameter(Mandatory=$False)]
    [string]$AzKeyVaultName,
    [Parameter(Mandatory=$True)]
    [string]$AzAutomationAcctName

)

#Connect to Azure Active Directory if not already connected
$AzConnTest = Get-AzSubscription -ErrorAction SilentlyContinue

if(!$AzConnTest){

    If(!$Credential){

        $Credential = Get-Credential

    }

    Try{
        
        Connect-AzAccount -Credential $Credential

    } Catch {

        Write-Output "Unable to connect to Azure, please re-enter credentials and try again"
        $Credential = Get-Credential
        Connect-AzAccount -Credential $Credential

    }

}

#If a subscription name was entered, check to see if it exists. If it does not, clear the value of $subscriptions
If($Subscription){

    Try{
        
        $Sub = Get-AzSubscription $Subscription

    } Catch {

        Write-Output "Subscription $Subscription not found. Please select a subscription."
        $Subscription = $null
    }

}

#If Subscription is null, get all subscriptions. If multiple subscriptions exist, show grid to have user select correct subscription
If(!$Subscription){
$Subs = Get-AzSubscription 

    If($Subs.count -ne 1){

        $Sub = $Subs | Out-GridView -passthru
        set-AzContext -SubscriptionName $Sub.name

    } Else {

        $Sub = $Subs

    }

}

$SubId = $Sub.Id

#Return all valid Azure regions for validation
$RegionList = Get-AzLocation | Select-Object displayname,location 

#If $Region value exists, check to make sure region is valid. If not, set region to null
If($Region){

    If($region -notin $RegionList.Location){

        Write-Output "Region is not found, please select a region from the list."
        $Region = $null
    } 

}

#If $region is null, select the correct region from a grid view
If(!$Region){

    $Region = $RegionList | Out-GridView -passthru | Select-Object -ExpandProperty Location

}

#If CreteNewResource is True, check to see if a Resource group name was entered, if not, prompt the user for a resource group name
If($CreateNewResource){

    If(!$ResourceGroupName){

        Write-Host "Please enter a name for your new resource group."
        $ResourceGroupName = Read-Host

    }

    New-AzResourceGroup -Name $ResourceGroupName -Location $Region

} else {
    
    #If using an existing resource group, show the grid view for user to select new RG
    $List = Get-AzResourceGroup 
    $ResourceGroupName = $List | Out-GridView -PassThru | Select-Object -ExpandProperty ResourceGroupName

}

If(!$AzKeyVaultName){

    $Vaults = Get-AzKeyVault
    
    If($Vaults.count -gt 1){

        $AKV = $Vaults | Out-GridView -passthru
        

    } Else {

        $AKV = $Vaults

    }

    $AzKeyVaultName = $AKV.VaultName


}

#Create new Automation Account
$NewAutoAccount = New-AzAutomationAccount -Name $AzAutomationAcctName -Location $Region -ResourceGroupName $ResourceGroupName

#Enable system Identity
$AssignId = Set-AzAutomationAccount -ResourceGroupName $resourceGroupName -Name $AzAutomationAcctName -AssignSystemIdentity
$AutIdentityId = $AssignId.identity.PrincipalId  

#Assign Role assignment and grant GET permissions to get keys from Azure Key Vault
New-AzRoleAssignment -ObjectId $AutIdentityId -Scope "/subscriptions/$subId" -RoleDefinitionName "Contributor"

#Set key vault access policy to allow managed identity to retrieve keys from vault
Set-AzKeyVaultAccessPolicy -VaultName $AzKeyVaultName -ObjectId $AutIdentityId -PermissionsToKeys GET -PermissionsToSecrets GET
