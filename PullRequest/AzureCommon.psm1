##################################################################################################
#
# Module contains basic functions to make REST call to VSTS and some additiona utility funcitons
# 
##################################################################################################


#
# Funciton Get-AzureRequestReqults performs follwoing steps:
#  1. replaces placeholders of -URI parameter with values from -context dictionary
#  2. optionally maintain -proxy parameter based on context dictionary
#  3. perform REST call
#  4. return result
#
# 
# Parameter -contest is expected to contain a dictionary for substitution
#
# Example of the content:
#
# $context = @{
#    organization = "your_organization";
#    project = "your_project_id_or_name";
#    repositoryId = "your_repository_id_or_name";
#    proxy = "http://proxy.address:port";
#    token = "your_PAT_token";
# }
#
# Extended content can be amended while making a call to procedure accepting context
#

function Get-AzureRequestReqults {
param (
    [Parameter (Mandatory = $true)]
    [string] $URI,

    [Parameter (Mandatory = $false)]
    [object] $query,

    [Parameter (Mandatory = $false)]
    [object] $proxy, 

    [Parameter (Mandatory = $false)]
    [object] $method = 'GET',

    [Parameter (Mandatory = $true)]
    [object] $context
)

    $ErrorActionPreference = 'Stop'

    $URI = Update-StringWithContext $URI $context

    if (-not ($proxy)) {
        if ($context.proxy) {
            $proxy = $context.proxy
        }
    }

    # Write-Host "Get-AzureRequestReqults: ", $URI, $method, $query

    $res = Invoke-RestMethod -Uri $URI -Method $method -ContentType 'application/json' -Headers @{Authorization = (Get-AzureAutorization -context $context)} -Body $query -Proxy $proxy

    return $res
}


#
# Function prepares authorization string for web call
# Token is taken either from environmental variable (if process ran as part of release/build on VSTS pipeline), or from context dictionary
# 

function Get-AzureAutorization {
param (
    [Parameter (Mandatory = $true)]
    [object] $context
)
    $token = $env:SYSTEM_ACCESSTOKEN

    if (-not ($token) ) {
        $token = $context.token
    }

    $authorization = "Basic {0}" -f ([Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes((":{0}" -f $token))))

    return $authorization
}


#
# Function returns the standard base URL for VisualStudio Team Services
# Created to simplify migration to new domain for Azure * when time will come.
# Uses placeholders which will be later replaced based on context.
#

function Get-ProjectBaseURL {
    return "https://{organization}.visualstudio.com/{project}"
}


#
# Utility funciton that replace string with placeholders with values from context dictionary
#

function Update-StringWithContext {
param (
    [Parameter (Mandatory = $true)]
    [string] $str,

    [Parameter (Mandatory = $false)]
    [object] $context
)  
    if ($context) {
        foreach ($kv in $context.GetEnumerator()) {
            $key = "{" + $kv.key + "}"
            $value = $kv.value

            $str = $str -replace $key, $value
        }

    }

    return $str
}
