function ConfigTransform_SetValueUsingXPath{
    <#
    .SYNOPSIS
    Updates an XML file using XPath

    .DESCRIPTION
    Allows changing any text or attribute in an XML file passing the XPath to the value to be changed

    .PARAMETER FilePath
    The complete path to the XML file that needs changing

    .PARAMETER XPath
    The XPath of the setting to be changed
    
    .PARAMETER Value
    The value to set the setting specified in the XPath

    .EXAMPLE 
    ConfigTransform_SetValueUsingXPath -FilePath "D:\WebPublic\web.config" -XPath "/configuration/connectionStrings/add[@name='LamdaContext']/@connectionString" -Value "Data Source=SQL_MAchine_name;Initial Catalog=pt_db_33R;Integrated Security=SSPI;"
    #>
    param
    (
        [Parameter(mandatory=$true)]
        [string] $FilePath,
        [Parameter(mandatory=$true)]
        [string] $XPath,
        [Parameter(mandatory=$false)]
        [string] $Value = ""
    )


        Write-Host "OF_ConfigTransform_SetValueUsingXPath will update setting " $XPath " with value " $Value

        $xml = [xml](Get-Content $FilePath)
        $nodes= $xml.SelectNodes($XPath)
        $maxTries = 3
        $triesSoFar = 0


        Do {
            Try{
                foreach ($node in $nodes){
                    if ($node -ne $null){
                        $node.InnerXml = $Value
                    }
                    else{
                        $node.Value = $Value
                    }
                }
                $xml.save($FilePath)
                Write-Host "Setting updated"
                return
                }
             Catch [System.Xml.XPath.XPathException]
             {
                Write-Host "The Xpath {" $XPath "} did not produce any nodes in file " $FilePath
                return
             }
             Catch [System.Exception]
             {
                # Sometimes there are issues because the file is being used by another process
                # We wait 200 milliseconds and we try up to again 3 times
                $triesSoFar++
                Start-Sleep -m 200
             }
        } while ($triesSoFar -lt $maxTries)
        
        if ($triesSoFar -eq $maxTries)
        {
            Write-Warning "Setting NOT updated."
        }
}
