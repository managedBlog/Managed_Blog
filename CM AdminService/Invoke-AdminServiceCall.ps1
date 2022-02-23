<#
Name: Update-ManagementName
Author: Sean Bulger, twitter @managed_blog, http://managed.modernendpoint.com
Version: 0.1
.Synopsis
   This script will run a REST API call against the Configuration Manager Admin Service. It was create specifically for use in Azure Automation. Note: Azure Automation does not handle hashtable parameter input well, so the $Body parameter uses a JSON-like string instead of a hash table. 
   If running outside of Azure Automation, chang the parameter type to obj or hashtable based on your needs.
.DESCRIPTION
   Invoke-AdminServiceCall is a function built to call the Microsoft Configuration Manager AdminService and run any approved method.
#>

[cmdletBinding()]
param(
    [Parameter(Mandatory=$False)]
    [string]$URI,
    [Parameter(Mandatory=$False)]
    [string]$Method,
    [Parameter(Mandatory=$False)]
    [string]$BodyInput  
)


#Azure Automation cannot handle hashtable as a parameter, convert string pseudo-hash to hash table
$BodyInput = $BodyInput.replace("=",":")

#Convert the string to an actual hashtable
$BodyHash = @{}
$jsonobj = $BodyInput | ConvertFrom-Json
foreach($p in $jsonobj.psobject.properties){$BodyHash[$p.name] = $p.value}


#Create function to call the Admin Service
Function Invoke-AdminServiceCall {

    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$URI,
        [Parameter(Mandatory=$True)]
        [string]$Method,
        [Parameter(Mandatory=$False)]
        [string]$Body
    )


    #Create Splat hashtable
    $SplatParams = @{
        Headers     = @{
            "Content-Type"  = "application/json"
                    }
        Method = $Method
        URI = $URI
        UseDefaultCredentials = $True

    }

    #If method requires body, add body to splat
    If($Method -in ('PUT','PATCH','POST')){

        $SplatParams["Body"] = $Body

    }

    Write-Output $SplatParams

    #Return API call result to script
    $AsInvokeResult = Invoke-RestMethod @SplatParams #-UseDefaultCredentials

    #Return status code variable to script
    Return $AsInvokeResult

}

#Convert $BodyJson to hashtable
$BodyJson = $BodyHash | ConvertTo-Json

#Make REST API call to AdminService
$AdminServiceCall = Invoke-AdminServiceCall -URI $URI -Method $Method -Body $BodyJson

#Write results to output stream
Write-Output $AdminServiceCall