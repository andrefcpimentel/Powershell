function IIS_StartSiteAndAppPool{
    <#
    .SYNOPSIS
    Starts a site and an application pool based on the paramters passed

    .DESCRIPTION
    Checks first if the app pool to start is stopped and if it is, it starts it
    The same with the website
    
    .PARAMETER appPoolName
    Name of the application pool to start
    
    .PARAMETER $siteName
    Name of the website to start to start

    .EXAMPLE 
    StartOrStopSiteAndAppPool -appPoolName "DefaultAppPool" 
    
    #>
    param(

        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string]  $appPoolName,

        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string]  $siteName

    )

    import-module WebAdministration

    if($appPoolName -eq ""){
		throw "Application pool name cannot be empty"
	}

    if($siteName -eq ""){
		throw "Site name cannot be empty"
	}
    
    ############ APPLICATION POOL #################
    
    try{
        Write "The application pool $appPoolName is currently:" (Get-WebAppPoolState $appPoolName).Value
        if((Get-WebAppPoolState $appPoolName).Value -eq 'Stopped')
        {
            Start-WebAppPool -Name $appPoolName
            while ((Get-WebAppPoolState $appPoolName).Value -ne 'Started')
            {
                Write "Waiting for start..."
                sleep -s 1
            }
            Write "Now Started."
        }
        elseif((Get-WebAppPoolState $appPoolName).Value -eq 'Stopping')
        {
            while ((Get-WebAppPoolState $appPoolName).Value -ne 'Stopped')
            {
                Write "Waiting for stop..."
                sleep -s 1
            }
            Start-WebAppPool -Name $appPoolName
            while ((Get-WebAppPoolState $appPoolName).Value -ne 'Started')
            {
                Write "Waiting for start..."
                sleep -s 1
            }
            Write "Now started."
        }
        elseif((Get-WebAppPoolState $appPoolName).Value -eq 'Starting')
        {
            while ((Get-WebAppPoolState $appPoolName).Value -ne 'Started')
            {
                Write "Waiting for start..."
                sleep -s 1
            }
            Write "Now Started."
        }
        elseif((Get-WebAppPoolState $appPoolName).Value -eq 'Started')
        {
            Write "Already started, no action to perform."
        }
        else
        {
            Write-Warning "Application Pool $appPoolName is in the unknown state of" (Get-WebAppPoolState $appPoolName).Value
        }
    }catch [Exception]{
        Write-Host "Exception:" $_.Exception.Message
        if ($_.Exception.Message -like '*Cannot find path*')
        {
            Write-Host "Application Pool $appPoolName does not exist"
        }
        else
        {
            throw $_.Exception 
        }
    }  
    
    ############# WEB SITE ################
    
    try{
        Write "The Web Site $siteName is currently:" (Get-WebSiteState $siteName).Value
        if((Get-WebSiteState $siteName).Value -eq 'Stopped')
        {
            Start-WebSite -Name $siteName
            while ((Get-WebSiteState $siteName).Value -ne 'Started')
            {
                Write "Waiting for start..."
                sleep -s 1
            }
            Write "Now Started."
        }
        elseif((Get-WebSiteState $siteName).Value -eq 'Stopping')
        {
            while ((Get-WebSiteState $siteName).Value -ne 'Stopped')
            {
                Write "Waiting for stop..."
                sleep -s 1
            }
            Start-WebSite -Name $siteName
            while ((Get-WebSiteState $siteName).Value -ne 'Started')
            {
                Write "Waiting for start..."
                sleep -s 1
            }
            Write "Now started."
        }
        elseif((Get-WebSiteState $siteName).Value -eq 'Starting')
        {
            while ((Get-WebSiteState $siteName).Value -ne 'Started')
            {
                Write "Waiting for start..."
                sleep -s 1
            }
            Write "Now Started."
        }
        elseif((Get-WebSiteState $siteName).Value -eq 'Started')
        {
            Write "Already started, no action to perform."
        }
        else
        {
            Write-Warning "Web site $siteName is in the unknown state of" (Get-WebSiteState $siteName).Value
        }
    }catch [Exception]{
        Write-Host "Exception:" $_.Exception.Message
        if ($_.Exception.Message -like '*Cannot find path*')
        {
            Write-Host "Website $siteName does not exist"
        }
        else
        {
            throw $_.Exception 
        }
    }  
}
