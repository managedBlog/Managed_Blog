<#
.SYNOPSIS
    Detects if Microsoft Defender Antivirus definitions are outdated.
.DESCRIPTION
    Checks the age of the latest Defender signature update.
    If older than 1 day, remediation will be triggered.
#>

try {
    # Get Defender signature age
    $defenderStatus = Get-MpComputerStatus -ErrorAction Stop
    $sigAge = (Get-Date) - $defenderStatus.AntispywareSignatureLastUpdated

    if ($sigAge.TotalDays -gt 1) {
        Write-Output "Outdated"
        exit 1  # Non-zero exit triggers remediation
    }
    else {
        Write-Output "Up to date"
        exit 0
    }
}
catch {
    Write-Output "Error checking Defender status: $_"
    exit 1
}
