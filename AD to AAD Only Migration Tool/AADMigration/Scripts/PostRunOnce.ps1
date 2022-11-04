Start-Transcript -Path C:\ProgramData\AADMigration\Logs\AD2AADJ-R1.txt -NoClobber
$MigrationConfig = Import-LocalizedData -BaseDirectory "C:\ProgramData\AADMigration\scripts\" -FileName "MigrationConfig.psd1"
$PPKGName = $MigrationConfig.ProvisioningPack
$MigrationPath = $MigrationConfig.MigrationPath

#Block user input, load user32.dll and set block input to true
$code = @"
    [DllImport("user32.dll")]
    public static extern bool BlockInput(bool fBlockIt);
"@ 

$userInput = Add-Type -MemberDefinition $code -Name Blocker -Namespace UserInput -PassThru

$null = $userInput::BlockInput($true)

#Display form with user input block message
[void][reflection.assembly]::loadwithpartialname("system.drawing")
[void][reflection.assembly]::loadwithpartialname("system.Windows.Forms")
$file = (get-item "C:\ProgramData\AADMigration\Files\MigrationInProgress.bmp")
$img = [System.Drawing.Image]::Fromfile((get-item $file))

[System.Windows.Forms.Application]::EnableVisualStyles()
$form = new-object Windows.Forms.Form
$form.Text = "Migration in Progress"
$form.WindowState = 'Maximized'
$form.BackColor = "#000000"
$form.topmost = $true

$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.Width =  $img.Size.Width;
$pictureBox.Height =  $img.Size.Height;
$pictureBox.Dock = "Fill"
$pictureBox.SizeMode = "StretchImage"


$pictureBox.Image = $img;
$form.controls.add($pictureBox)
$form.Add_Shown( { $form.Activate() } )
$form.Show();

Write-Output "Writing Run Once for Post Reboot 2" 
$RunOnceKey = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

set-itemproperty $RunOnceKey "NextRun" ('C:\Windows\System32\WindowsPowerShell\v1.0\Powershell.exe -executionPolicy Unrestricted -File ' + "C:\ProgramData\AADMigration\Scripts\PostRunOnce2.ps1")

# Install Provisioning PPKG
Install-ProvisioningPackage -PackagePath "$MigrationPath\Files\$PPKGName" -ForceInstall -QuietInstall

Stop-Transcript

$Null = $userInput::BlockInput($false)

$form.Close()

restart-computer


