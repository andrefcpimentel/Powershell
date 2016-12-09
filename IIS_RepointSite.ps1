function OF_IIS_RepointSite
{
    <#
    .SYNOPSIS
    Changes the Physical path of a IIS Site

    .DESCRIPTION
    Changes the Physical path of a IIS Site
    
    .PARAMETER IISSiteName
    Site Name in IIS (IIS:\)
	
	.PARAMETER PhysicalPath
    Physical Path in local drive 

    .EXAMPLE 
    OF_IIS_RepointSite  TestSite C:\inetpub\MyAwesomeSite
    #>

param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $IISSiteName,
		[Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $PhysicalPath 
    )

    Write-Host "Changing IIS site" $IISSiteName "to path" $PhysicalPath
    set-ItemProperty IIS:\Sites\$IISSiteName -Name physicalpath -Value $PhysicalPath

}

