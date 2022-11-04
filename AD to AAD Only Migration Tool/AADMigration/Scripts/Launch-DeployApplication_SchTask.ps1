$ServiceUI = "c:\ProgramData\AADMigration\Files\ServiceUI.exe"
$ExePath = "c:\ProgramData\AADMigration\Toolkit\Deploy-Application.exe"

$targetprocesses = @(Get-WmiObject -Query "Select * FROM Win32_Process WHERE Name='explorer.exe'" -ErrorAction SilentlyContinue)
if ($targetprocesses.Count -eq 0) {
    Try {
        Write-Output "No user logged in, running without SerivuceUI"
        Start-Process $ExePath -Wait -ArgumentList '-DeployMode "NonInteractive"'
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        $ErrorMessage
    }
}
else {
    Foreach ($targetprocess in $targetprocesses) {
        $Username = $targetprocesses.GetOwner().User
        Write-output "$Username logged in, running with ServiceUI"
    }
    Try {
        #$ServiceUI -Process:explorer.exe $ExePath
        Start-Process $ServiceUI -ArgumentList "-Process:explorer.exe $ExePath"

    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        $ErrorMessage
    }
}
Write-Output "Install Exit Code = $LASTEXITCODE"
Exit $LASTEXITCODE