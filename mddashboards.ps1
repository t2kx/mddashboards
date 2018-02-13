
<#
.SYNOPSIS
    Adds a Web App Dashboard to your Azure "Ibiza" Portal. 
.DESCRIPTION
    The Add-AzureRMDashboardStarterWebAppMD creates a new resource group per subscription and generates a dashboard resources which will be visible as a shared source.
    On this dashboard following parts will be created:
        * A clock (still in the  default setting)
        * A Markdown part with an overview of all the available Web Apps per that subscription. This overview is in table form and contains:
            - the hostname
            - the website url(s)
            - the Kudu Link
            - the Monaco / App Service Editor Link
    This generation will be ARM based and the json files can be adapted afterwards or redeployed if needed. Also a rerun will regenerate the files and update the dashboard.
.PARAMETER yourlocation
    The location where you an tto desploy the resource group.
.PARAMETER yourmdtitle
    The text you want as a header or title for the Markdown part
.PARAMETER yourmdsubtitle
    The text you want as a subtitle for the Markdown part
.EXAMPLE
    PS C:\> Add-AzureRMDashboardStarterWebAppMD "West Europe"
    Generates a default dashboard with all the parts mentioned and with the generic title and substitle for the MD part. 
#>

function Add-AzureRMDashboardStarterWebAppMD {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$yourlocation,
        [Parameter(Mandatory = $false)]
        [string]$yourmdtitle,
        [Parameter(Mandatory = $false)]
        [string]$yourmdsubtitle
    )

    Add-AzureRmAccount
    new-item .\mddashsub -ItemType Directory -Force
    $azuresubs = (Get-AzureRmSubscription|Out-GridView -PassThru)
    
    foreach ($sub in $azuresubs) {
        Select-AzureRmSubscription -SubscriptionName $sub.Name
        $mdfile = ".\mddashsub\$($sub.Name)webapp.md"
        $yourtitle = $sub.Name + " Site Overview for subscription"
        $yourname = "mddashboardstarter"+ $sub.Id
        $locpartid = 2
        $partsjson = ''      
        $partY = 8
        $webappsenvs = Get-AzureRmAppServicePlan
        if ($webappsenvs.Count -gt 0) {
            Set-Content -Path $mdfile -Value "|hostname|default url|kudu console|monaco/app service editor|\r\n"
            add-Content -Path $mdfile -Value "|---|---|---|---|\r\n"             
            foreach ($webappenv in $webappsenvs) {
                $webapps = Get-AzureRmWebApp -AppServicePlan $webappenv
                $webappshostnames = $webapps|select name, DefaultHostName,ID   #($webapps |  select Name,  EnabledHostNames) 
                $partX = 0
                for ($pt = 1; $pt -lt 4; $pt++) {
                    $partsjson += ',' + ( New-AzureRMDashboardStarterWebAppPart -partID $locpartid  -posX $partX -posY $partY -resID $webappenv.Id -partType $pt)
                    $partX += 4
                    $locpartid++
                }
                foreach ($wh in $webappshostnames) {
                    $mdstring = "|$($wh.name) |[$($wh.DefaultHostName)](http://$($wh.DefaultHostName)) |[go](https://$($wh.name).scm.azurewebsites.net)| [go](https://$($wh.name).scm.azurewebsites.net/dev)|\r\n"
                    add-content -path $mdfile -Value $mdstring
                    $partsjson += ',' + ( New-AzureRMDashboardStarterWebAppPart -partID $locpartid  -posX $partX -posY $partY -resID $wh.Id -partType 4)
                    $partX+=4
                    $locpartid++
                }           
                $partY += 2
            }        

        }        
        $yourmdfile = Get-Content $mdfile
        $jsonout = ".\mddashsub\$($sub.Name)_deploymddashboard.json"
        $jsonoutparam = ".\mddashsub\$($sub.Name)_deploymddashboard.parameters.json"        
        #Copy-Item .\mddashboards.json $jsonout
        $rsdepjson = Get-Content .\mddashboards.parameters.json
        Write-Verbose 'Following parameters will be written to the .parameters.json file'
        #$exportparams = @{$yourtitle,$yourname,$yourmdfile, $yourmdtitle,$yourmdsubtitle }
        #Write-Verbose $exportparams
        $armjson = get-content .\mddashboards.json
        $armjson | foreach {$PSItem -replace '<"XXX":{}>',$partsjson} | out-file $jsonout
        $rsdepjson | foreach { $PSItem -replace '<YOURTITLE>' , $yourtitle      } |
            foreach { $PSItem -replace '<YOURNAME>'  , $yourname       } |
            foreach { $PSItem -replace '<YOURMDFILE>', $yourmdfile     } | 
            foreach { $PSItem -replace '<YOURMDTITLE>', $yourmdtitle    } |
            foreach { $PSItem -replace '<YOURMDSUBTITLE>', $yourmdsubtitle } |
            out-file $jsonoutparam
        New-AzureRmResourceGroup -Name $yourname -Location $yourlocation
        New-AzureRmResourceGroupDeployment -Name $yourname -ResourceGroupName $yourname -TemplateFile $jsonout -TemplateParameterFile $jsonoutparam  
    }
}
function Add-AzureRMDashboardStarterVMMD {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$yourlocation,
        [Parameter(Mandatory = $false)]
        [string]$yourmdtitle,
        [Parameter(Mandatory = $false)]
        [string]$yourmdsubtitle
    )
    Add-AzureRmAccount
    new-item .\mddashsub -ItemType Directory -Force
    $azuresubs = (Get-AzureRmSubscription|Out-GridView -PassThru)
    foreach ($sub in $azuresubs) {
        Select-AzureRmSubscription -SubscriptionName $sub.Name
        $subID = $sub.Id
        $mdfile = ".\mddashsub\$($sub.Name)vm.md"
        $yourtitle = "$($sub.name) Site Overview for subscription"
        $yourname = "mddashboardstarter$($sub.name)"
        $rgs = Get-AzureRmResourceGroup
        foreach ($rg in $rgs) {
            $rgID = $rg.ResourceId
            $vms = Get-AzureRmVM -ResourceGroupName $rg.ResourceGroupName
            $i = ($vms | measure).Count
            if ($i -ne 0) {
                foreach ($vm in $vms) {
                    $tag = "$($vm.Id)"
                }                
            }
        }
    }
}

function New-AzureRMDashboardStarterWebAppPart {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [int]$partID,
        [Parameter(Mandatory = $true)]
        [int]$posX,
        [Parameter(Mandatory = $true)]
        [int]$posY,
        [Parameter(Mandatory = $true)]
        [string]$resID,
        [Parameter(Mandatory = $true)]
        [int]$partType
    )

    switch ($partType) {
        #microsoft.web/serverfarms - CPU/MEM
        1 {
            $partmetrics = "{
                              ""resourceId"": ""$resID"",
                              ""name"": ""CpuPercentage""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""MemoryPercentage""
                          }"    
        }
        #microsoft.web/serverfarms - IO
        2 {
            $partmetrics = "{
                              ""resourceId"": ""$resID"",
                              ""name"": ""DiskQueueLength""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""HttpQueueLength""
                          }"
        }
        #microsoft.web/serverfarms - bandwidth
        3 {
            $partmetrics = "{
                              ""resourceId"": ""$resID"",
                              ""name"": ""BytesReceived""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""BytesSent""
                          }"
        }
        #microsoft.web/sites - http codes
        4 {
            $partmetrics = "{
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http2xx""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http3xx""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http401""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http403""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http404""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http406""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http4xx""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Http5xx""
                          },
                          {
                              ""resourceId"": ""$resID"",
                              ""name"": ""Requests""
                          }"
        }
    }
    $partoutput = """$partID"": {
                        ""position"": {
                            ""x"": $posX,
                            ""y"": $posY,
                            ""rowSpan"": 2,
                            ""colSpan"": 4
                        },
                        ""metadata"": {
                            ""inputs"": [
                                {
                                    ""name"": ""queryInputs"",
                                    ""value"": {
                                        ""metrics"": [
                                            $partmetrics
                                        ],
                                        ""timespan"": {
                                            ""duration"": ""PT1H"",
                                            ""start"": null,
                                            ""end"": null
                                        },
                                        ""chartType"": 0
                                    }
                                }
                            ],
                            ""type"": ""Extension/Microsoft_Azure_Monitoring/PartType/MetricsChartPart"",
                            ""settings"": {}
                        }
                    }"
    return $partoutput 
}