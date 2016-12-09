Function Jenkins_TriggerBuild
{
    <#
    .SYNOPSIS
    Triggers a build on the Jenkins server

    .DESCRIPTION
    Creates a Jenkins Trigger Build URI from Jenkins Server (name and port) and Configured Build item (name and parameters) and triggers the Build on Jenkins Server
    
    .PARAMETER jenkinsUsername
    Authorised User to trigger build job on Jenkins

    .PARAMETER jenkinsPassword
    Authorised User's password to trigger build job on Jenkins

    .PARAMETER serverName
    Name/Address of the Jenkins Server

    .PARAMETER serverPort
    Port on which Jenkins is available

    .PARAMETER getBuildList
    Items to be built on Jenkins
    
    .PARAMETER preBuildItem
    Name (ID) of the Item to be built on Jenkins CI before actual build

    .PARAMETER postBuildItem
    Name (ID) of the Item to be built on Jenkins CI AFTER actual build

    .PARAMETER buildItemEnvironment
    Instructs Jenkins to run the build on particular Environment e.g. PT-27

    .PARAMETER buildItemSQLServerName
    Build Item Parameter - SQL Server Name e.g. pt-sql-vm2

    .PARAMETER buildItemReplicated
    Parameter Replicated; Allowable Values: Yes No

    .PARAMETER buildItemBrowser
    Browser on which to run the tests e.g. firefox

    .PARAMETER buildItemTFSbranch
    Instructs Jenkins to run the build tests on passed in TFS Branch (for Integration Tests) e.g. Integration

    .PARAMETER buildItemPartner
     Instructs Jenkins to run the build tests for passed in Partner e.g. PO for Post Office

    .PARAMETER buildItemLableName
    Instructs Jenkins to run the build on particular node/node set e.g. Parallel instructs Jenkins to Build on ANY node starting with name Parallel

    .EXAMPLE 
    Jenkins_TriggerBuild -authenticatingUsr "domain\user" -authenticatingPwd "Pa55w0rd" -serverName "tm-jnk-01" -serverPort 8080 `
            -getBuildList "NightlyBuildJobs" -preBuildItem "NightlyBuildSetup" -postBuildItem "NightlyBuildComplete" - buildItemEnvironment "PT-02" `
            -buildItemSQLServerName "pt-sql-vm2" -buildItemReplicated "No" -buildItemBrowser "firefox" -buildItemTFSbranch "Integration" `
            -buildItemPartner "PO" -buildItemLableName "Parallel"
    #>

    param
    (
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $jenkinsUsername, 
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $jenkinsPassword,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $serverName,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [int] $serverPort,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $getBuildList,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $preBuildItem,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $postBuildItem,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $buildItemEnvironment,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $buildItemSQLServerName,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $buildItemReplicated,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $buildItemBrowser,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $buildItemTFSbranch,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $buildItemPartner,
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [string] $buildItemLableName
    )
    
    
    $getBuildListItemUri= [string]::Format("http://{0}:{1}/view/{2}/api/xml",$serverName, $serverPort,$getBuildList)
    $preBuildItemUri= [string]::Format("http://{0}:{1}/job/{2}/build",$serverName, $serverPort, $preBuildItem)
    $postBuildItemUri= [string]::Format("http://{0}:{1}/job/{2}/build",$serverName, $serverPort, $postBuildItem)


    $postParameters =  [string]::Format(    "Environment={0}&Browser={1}&Partner={2}&TFSBranch={3}&LabelName={4}&Replicated={5}&SqlServerName={6}"
                                            ,$buildItemEnvironment
                                            ,$buildItemBrowser
                                            ,$buildItemPartner
                                            ,$buildItemTFSbranch
                                            ,$buildItemLableName
                                            ,$buildItemReplicated
                                            ,$buildItemSQLServerName
                                        )
  
    Write-Host [string]::Format("Getting JobList")                                  
    $buildItemsList = OF_http_GetPostResult -authenticatingUsr $jenkinsUsername -authenticatingPwd $jenkinsPassword -uri $getBuildListItemUri
    $xd = [System.Xml.XmlDocument] $buildItemsList.Content
    $nodelist= $xd.SelectNodes("/dashboard/job") 

    $expectedCode = 201 #Resource Created

    Write-Host "Start PRE Trigger JobList"
    $prebuildTriggerResult = OF_http_GetPostResult -authenticatingUsr $jenkinsUsername -authenticatingPwd $jenkinsPassword -uri $preBuildItemUri

    ForEach ($node in $nodelist) {
    #Create Jenkins Trigger Build URI from Jenkins Server (name and port) and Configured Build item (name and parameters)
                 $triggerUrl = [string]::Format("{0}buildWithParameters?{1}",$node.url,$postParameters)
                 $result = OF_http_GetPostResult -authenticatingUsr $jenkinsUsername -authenticatingPwd $jenkinsPassword -uri $triggerUrl
             
                 WRITE-HOST 
                 if([int]$result.StatusCode -eq $expectedCode) {
                 
                    Write-Host [string]::Format(" Started BuildItem: {0} using URL: {1}",$node.name, $triggerUrl)
                   #Exit 0
    
                 } else {
                 
                    Write-Host [string]::Format(" Cannot Start BuildItem: {0} using URL: {1}",$node.name, $triggerUrl)
                   #Exit 1
            
                 }
    }

    Write-Host "Start POST Trigger JobList"
    $postbuildTriggerResult = OF_http_GetPostResult -authenticatingUsr $jenkinsUsername -authenticatingPwd $jenkinsPassword -uri $postBuildItemUri
   

}
