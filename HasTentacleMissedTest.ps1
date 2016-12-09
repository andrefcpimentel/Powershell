
# This function is called at the foot of the script!

function HasTentacleMissedRelease{
    <#
    .SYNOPSIS
    Check if the tentacle running this script has missed a release

    .DESCRIPTION
    Check if the NuGet packages in the offline drop folder are already installed on this tentacle. The function will return true once it finds the first out of date package, otherwise, it will return false.

    .PARAMETER OfflineDropBase
    The full path to the Offline Package Drop Base Folder used by Octopus Deploy
    
    .PARAMETER OfflineDropBatch
    The name of the batch file in the above folder to copy and deploy the offline package installation

    .PARAMETER JournalFile
    The full path to the local Octopus Deploy Tentacle Journal File

    .EXAMPLE 
    HasTentacleMissedRelease -OfflineDropBase "\\fi.pri\autdfs\TESScripts\Deployments" -OfflineDropBatch "POBTP_Offline.cmd" -JournalFile "c:\Octopus\DeploymentJournal.xml"
    #>
    param
    (
        [Parameter(mandatory=$true)]
        [string] $OfflineDropBase,
        [Parameter(mandatory=$true)]
        [string] $OfflineDropBatch,
        [Parameter(mandatory=$true)]
        [string] $JournalFile
        
    )

    LogToFile -logEntry " "

    # Check for and load the tentacles journal file
    if (-not (Test-Path -Path $JournalFile))
    {
        LogToFile -logEntry "Could not find the journal file ($JournalFile) so it's assumed this is the first release for this tentacle."
        return $true
    }
    $journalXml = [Xml](Get-Content $JournalFile)
    LogToFile -logEntry "Journal file loaded: $journalXml."

    # Check for and load the Offline Package Drop Batch file
    $OfflineDropBatchFilePath = [System.IO.Path]::Combine($OfflineDropBase, $OfflineDropBatch)
    if (-not (Test-Path -Path $OfflineDropBatchFilePath))
    {
        LogToFile -logEntry "Could not find the offline package drop batch file ($OfflineDropBatchFilePath) This is required to know which release to check."
        throw [System.IO.FileNotFoundException] "File $OfflineDropBatchFilePath not found."
    }
    $OfflineDropBatchFileText = (Get-Content -Path $OfflineDropBatchFilePath)[0]
    LogToFile -logEntry "The first line of the offline drop file is: $OfflineDropBatchFileText."
	
    # Get the correct release package location from the Offline Package Drop Batch file
    $OfflineDropReleasePath = ($OfflineDropBatchFileText.Substring(4)).Trim("`"")
    LogToFile -logEntry "The offline drop release path is: $OfflineDropReleasePath."
    if (-not (Test-Path -Path $OfflineDropReleasePath))
    {
        LogToFile -logEntry "Could not find the offline package drop location ($OfflineDropReleasePath) This is required to know which packages to check"
        throw [System.IO.DirectoryNotFoundException] "Directory $OfflineDropReleasePath not found."
    }

    # Get a list of packages in the offline package drop location
    $packagesFolder = [System.IO.Path]::Combine($OfflineDropReleasePath, "Packages")
    LogToFile -logEntry "The packages folder is $packagesFolder."
    LogToFile -logEntry " "

    $packagesDirectoryInfo = New-Object System.IO.DirectoryInfo($packagesFolder)
    $packagesFiles = $packagesDirectoryInfo.GetFiles()
    LogToFile -logEntry ([string]::Format("Found {0} files in the packages folder ({1})", $packagesFiles.Count, $packagesDirectoryInfo.FullName))
    LogToFile -logEntry " "

    # Cycle through the packages to see if they're up to date
    foreach ($packageFile in $packagesFiles)
    {
        # Get the offline drop package and check the journal for matches on the tentacle
        $nugetPackageName = [System.Io.Path]::GetFileNameWithoutExtension($packageFile.FullName)
        LogToFile -logEntry "NuGet package name without extension: $nugetPackageName."
        if (-not $nugetPackageName -match "^*\d{1,}\.\d{1,}\.\d{1,}\.\d{1,}$")
        {
            LogToFile -logEntry "Could not find the NuGet version number from the package file name."
            throw [System.IO.FileNotFoundException] "Could not find the NuGet version number from the package file name."

        }
        $regexResult = $nugetPackageName -match "^*\d{1,}\.\d{1,}\.\d{1,}\.\d{1,}$"
        $nugetPackageVersion = $Matches[0]
        LogToFile -logEntry "NuGet Package Version: $nugetPackageVersion."
        $nugetPackageId = $nugetPackageName -replace $nugetPackageVersion, ""
        $nugetPackageId = $nugetPackageId.TrimEnd(".")
        LogToFile -logEntry "NuGet Package Id: $nugetPackageId."
        $xpath = [string]::Format("/Deployments/Deployment[@PackageId='{0}']", $nugetPackageId)
        LogToFile -logEntry "Searching journal using XPath: $xpath."
        $journalMatches = $journalXml.SelectNodes($xpath)
        LogToFile -logEntry ([string]::Format("found {0} matching nodes.", $journalMatches.Count))

        if ($journalMatches.Count -lt 1)
        {
            # No matches
            LogToFile -logEntry ([string]::Format("No matching Journal Entries on this tentacle for packages with an Id of {0}.", $nugetPackageId))
            return $true
        }
        else
        {
            # There were matches, get the last release of this package on the tentacle the same version as the drop folder
            # $sortedMatches = $journalMatches | Sort-Object -Property InstalledOn -Descending
            #$sortedMatches = $journalMatches[$journalMatches.Count-1]
            $sortedMatches = $journalMatches.Item($journalMatches.Count-1)
            LogToFile -logEntry ([string]::Format("Returning node with Id: {0}, Name: {1}", $sortedMatches.Id, $sortedMatches.PackageId))
            $packageVersion = $sortedMatches.PackageVersion
            LogToFile -logEntry "and version $packageVersion."

            if ($packageVersion -eq $nugetPackageVersion)
            {
                $wasSuccessful = [System.Convert]::ToBoolean($sortedMatches.WasSuccessful)
                
                if ($wasSuccessful)
                {
                    # Yes, check more packages
                    LogToFile -logEntry ([string]::Format("Version {0} of package {1} is already installed on this tentacle.", $nugetPackageVersion, $nugetPackageId))
                    LogToFile -logEntry " "
                }
                else
                {
                    # Yes, but it didn't install correctly
                    LogToFile -logEntry ([string]::Format("Version {0} of package {1} didn't previously install correctly on this tentacle.", $nugetPackageVersion, $nugetPackageId))
                    LogToFile -logEntry ([string]::Format("Therefore, the update package must be run to get version {0}.", $nugetPackageVersion))
                    LogToFile -logEntry " "
                    return $true
                }
                
            }
            else
            {
                # No, update required
                LogToFile -logEntry ([string]::Format("The most recent version of {0} installed on this tentacle is {1}.", $nugetPackageId, $packageVersion))
                LogToFile -logEntry ([string]::Format("Therefore, the offline package must be run to get version {0}.", $nugetPackageVersion))
                LogToFile -logEntry " "
                return $true
            }
        }
    }
    return $false
}

function LogToFile
{
    param
    (
        [Parameter(mandatory=$true)]
        [string] $logEntry
    )

    if (-not (Test-Path -Path "c:\temp"))
    {
        New-Item -Path "c:\temp" -ItemType Directory
    }
    Add-Content -Path "c:\temp\HasPOTentacleMissedRelease.log" -Value "`n$logEntry"
}

$dttmNow = [System.DateTime]::Now.ToString("dd/MM/yyyy HH:mm:ss")
LogToFile -logEntry "--------------------------------------------------------------"
LogToFile -logEntry "--- Starting new run at $dttmNow ---"
LogToFile -logEntry "--------------------------------------------------------------"
    
#Get Computer's DN
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$objSearcher.SearchRoot = New-Object System.DirectoryServices.DirectoryEntry
$objSearcher.Filter = "(&(objectCategory=Computer)(SamAccountname=$($env:COMPUTERNAME)`$))"
$objSearcher.SearchScope = "Subtree"
$obj = $objSearcher.FindOne()
$Computer = $obj.Properties["distinguishedname"]
LogToFile -logEntry "This computer is: $Computer"

#Now get the members of the group
$Group = "Flame Deployment Exceptions"
$objSearcher.Filter = "(&(objectCategory=group)(SamAccountname=$Group))"
$objSearcher.SearchScope = "Subtree"
$obj = $objSearcher.FindOne()
[String[]]$Members = $obj.Properties["member"]
LogToFile -logEntry ([string]::Format("Found {0} computers in Flame Deployment Exceptions", $Members.Count))

# If the computer has been returned from the group, there is nothing to do.
If ($Members -contains $Computer)
{   
    LogToFile -logEntry "This computer is in that list, skipping the remaining script."
}
else
{
    LogToFile -logEntry "This computer is not in that list, continue running the script..."
    LogToFile -logEntry " "

    $OfflinePackageDropLocation = "\\fi.pri\autdfs\TESScripts\Deployments"
    $OfflinePackageBatchFile = "FIBTP_OfflineX.cmd"
    $TentacleJournalFile = "c:\Octopus\DeploymentJournal.xml"

    LogToFile -logEntry "OfflinePackageDropLocation = $OfflinePackageDropLocation"
    LogToFile -logEntry "OfflinePackageBatchFile = $OfflinePackageBatchFile"
    LogToFile -logEntry "TentacleJournalFile = $TentacleJournalFile"

    $RunBatchFile = HasTentacleMissedRelease -OfflineDropBase $OfflinePackageDropLocation -OfflineDropBatch $OfflinePackageBatchFile -JournalFile $TentacleJournalFile
    
    if ($RunBatchFile)
    {
        LogToFile -logEntry "HasTentacleMissedRelease returned $true, running package install batch file."
    
        Add-Type -AssemblyName System.Windows.Forms

        $label1 = new-object System.Windows.Forms.Label
        $label1.Text = "DO NOT attempt to Launch Post Office (PO) Flame"
        $label1.Size = new-object System.Drawing.Size(315, 20)
        $label1.Location = new-object System.Drawing.Point(15, 15)
        $label1.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]12), [System.Drawing.FontStyle]'Bold', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $label2a = new-object System.Windows.Forms.Label
        $label2a.Text = "Your PC is in the process of downloading the latest software for PO Flame."
        $label2a.Size = new-object System.Drawing.Size(500, 20)
        $label2a.Location = new-object System.Drawing.Point(15, 45)
        $label2a.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]11), [System.Drawing.FontStyle]'Regular', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $label2b = new-object System.Windows.Forms.Label
        $label2b.Text = "Please do not attempt to log into PO Flame whilst this action is taking place."
        $label2b.Size = new-object System.Drawing.Size(500, 20)
        $label2b.Location = new-object System.Drawing.Point(15, 65)
        $label2b.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]11), [System.Drawing.FontStyle]'Regular', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $label2c = new-object System.Windows.Forms.Label
        $label2c.Text = "This process should take no longer than 5 minutes."
        $label2c.Size = new-object System.Drawing.Size(400, 20)
        $label2c.Location = new-object System.Drawing.Point(15, 85)
        $label2c.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]11), [System.Drawing.FontStyle]'Regular', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $label2d = new-object System.Windows.Forms.Label
        $label2d.Text = "When this message box closes, you can proceed and log into PO Flame. Thank you for your patience."
        $label2d.Size = new-object System.Drawing.Size(700, 20)
        $label2d.Location = new-object System.Drawing.Point(15, 105)
        $label2d.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]11), [System.Drawing.FontStyle]'Regular', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $label2e = new-object System.Windows.Forms.Label
        $label2e.Text = "If you experience any issues during this process then please contact the I.T. Service Desk on x2121."
        $label2e.Size = new-object System.Drawing.Size(700, 20)
        $label2e.Location = new-object System.Drawing.Point(15, 125)
        $label2e.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]11), [System.Drawing.FontStyle]'Regular', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $form1 = New-Object System.Windows.Forms.Form
        $form1.AutoScaleDimensions = New-Object System.Drawing.SizeF([single]6, [single]13)
        $form1.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]'Font'
        $form1.ClientSize = New-Object System.Drawing.Size(720, 165)
        $form1.Controls.Add($label1)
        $form1.Controls.Add($label2a)
        $form1.Controls.Add($label2b)
        $form1.Controls.Add($label2c)
        $form1.Controls.Add($label2d)
        $form1.Controls.Add($label2e)
        $form1.ResumeLayout($False)
        $form1.PerformLayout()

        $form1.Show()
        $form1.TopMost = $True
        $form1.Refresh()
    
        $BatchFileToRun = [System.IO.Path]::Combine($OfflinePackageDropLocation, $OfflinePackageBatchFile)
        LogToFile -logEntry "BatchFileToRun = $BatchFileToRun"
        Start-Process -FilePath $BatchFileToRun -RedirectStandardOutput "c:\temp\HasPOTentacleMissedRelease.out" -RedirectStandardError "c:\temp\HasPOTentacleMissedRelease.err" -Wait
    
        LogToFile -logEntry "Standard Output has been redirected to: c:\temp\HasPOTentacleMissedRelease.out"
        LogToFile -logEntry "STandard Error Output has been redirected to: c:\temp\HasPOTentacleMissedRelease.err"
    
        $label3 = new-object System.Windows.Forms.Label
        $label3.Text = "Post Office Flame Update Complete"
        $label3.Size = new-object System.Drawing.Size(315, 20)
        $label3.Location = new-object System.Drawing.Point(15, 15)
        $label3.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]12), [System.Drawing.FontStyle]'Bold', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $label4 = new-object System.Windows.Forms.Label
        $label4.Text = "You may now continue to log into PO Flame."
        $label4.Size = new-object System.Drawing.Size(315, 20)
        $label4.Location = new-object System.Drawing.Point(15, 45)
        $label4.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", ([single]11), [System.Drawing.FontStyle]'Regular', [System.Drawing.GraphicsUnit]'Point', ([byte]0))

        $form2 = New-Object System.Windows.Forms.Form
        $form2.AutoScaleDimensions = New-Object System.Drawing.SizeF([single]6, [single]13)
        $form2.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]'Font'
        $form2.ClientSize = New-Object System.Drawing.Size(345, 75)
        $form2.Controls.Add($label3)
        $form2.Controls.Add($label4)
        $form2.ResumeLayout($False)
        $form2.PerformLayout()

        $form1.Close()

        $form2.Show()
        $form2.TopMost = $True
        $form2.Refresh()

        Sleep -Seconds 5

        $form2.Close()
    }
    else
    {
        LogToFile -logEntry "HasTentacleMissedRelease returned $false, so this tentacle is up to date."
    }

    if (-not (test-path -Path "c:\flame\log"))
    {
        New-Item -Path "c:\flame\LOG" -ItemType Directory -Force
    }

    if (-not (test-path -Path "c:\flame\notes"))
    {
        New-Item -Path "c:\flame\NOTES" -ItemType Directory -Force
    }

    if (-not (test-path -Path "c:\flame\batch"))
    {
        New-Item -Path "c:\flame\BATCH" -ItemType Directory -Force
    }
}

$dttmNow = [System.DateTime]::Now.ToString("dd/MM/yyyy HH:mm:ss")
LogToFile -logEntry "--------------------------------------------------------------"
LogToFile -logEntry "--- Finished run at $dttmNow ---"
LogToFile -logEntry "--------------------------------------------------------------"