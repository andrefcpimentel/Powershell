function NLBDrainStop
{
    <#
    .SYNOPSIS
    Drain Stop/Start/Check Status NLB

    .DESCRIPTION
    Drain Stop/Start/Check Status NLB
    
    .PARAMETER Command
    STOP or START or check STATUS the NLB
	
	.PARAMETER Server
    Server to run  

    .EXAMPLE 
    NLBDrainStop  Stop PP-app-01
    #>    
    
    param
    (
    [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
    [String] $Command, 
    [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
    [String] $Server
    )
   
    Import-Module NetworkLoadBalancingClusters

    If ($Command -eq "STOP"){
	    Write-Host "Stopping NLB on"$Server
		    Stop-NlbClusterNode -Drain -HostName $Server -Timeout 10 
		    start-sleep -seconds 600
    }
    ElseIf ($Command -eq "START")
		    {
		    Write-Host "Starting NLB on " $Server
		    Start-NlbClusterNode -HostName $Server 
		    }
    Else{
	    Write-Host " Command " + $Command + " Not Understood"
	    
	    }
}
