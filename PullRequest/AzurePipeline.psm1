##################################################################################################
#
# Module contains functions to retrieve information about Releases
# Please note that funcitons related to build has hardcoded prefix for REST API URLs
# 
##################################################################################################


Import-Module .\AzureCommon.psm1 -Force

function Get-BuildsForBranch{
param(
    [Parameter (Mandatory = $true)]
    [string] $definitionId = 32,

    [Parameter (Mandatory = $true)]
    [string] $branchName,

    [Parameter (Mandatory = $true)]
    [object] $context
)
    $endpoint = (Get-ProjectBaseURL) + "/_apis/build/builds?definitions={definitions}&branchName={branchName}" 

    return Get-AzureRequestReqults -URI $endpoint -context ($context + @{definitions = $definitionId; branchName = $branchName})
}

function Get-ReleasesForBuild{
param(
    [Parameter (Mandatory = $true)]
    [string]$buildId,

    [Parameter (Mandatory = $true)]
    [object] $context
)
    $endpoint = "https://{organization}.vsrm.visualstudio.com/{project}/_apis/release/releases?artifactVersionId={buildId}&artifactTypeId=Build&api-version=4.1"

    return Get-AzureRequestReqults -URI $endpoint -context ($context + @{buildId = $buildId})
}

function Get-Release{
param(
    [Parameter (Mandatory = $true)]
    [string] $releaseId,

    [Parameter (Mandatory = $true)]
    [object] $context
)

    $endpoint = "https://{organization}.vsrm.visualstudio.com/{project}/_apis/release/releases/{releaseId}?api-version=4.1"

    return Get-AzureRequestReqults -URI $endpoint -context ($context + @{releaseId = $releaseId})
}