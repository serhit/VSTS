##################################################################################################
#
# Module contains functions to work with GIT REST API
# 
##################################################################################################

Import-Module .\AzureCommon.psm1 -Force


#
# List active Pull Requests to given branch (by default - to "develop")
#

function Get-PullRequests {
param(
    [Parameter (Mandatory = $true)]
    [object] $context,

    [Parameter (Mandatory = $false)]
    [object] $targetRefName = "refs/heads/develop"
)   
    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullrequests?api-version=4.1&searchCriteria.status=active&searchCriteria.targetRefName={targetRefName}"

    return Get-AzureRequestReqults -URI $endpoint -context ($context + @{targetRefName = $targetRefName})
}


#
# List Pull Requests Iterations
#

function Get-PullRequestIterations {
param(
    [Parameter (Mandatory = $true)]
    [string] $pullRequestId,

    [Parameter (Mandatory = $true)]
    [object] $context
)    
    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullrequests/{pullRequestId}/iterations?api-version=4.1"

    return Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId})
}


#
# List Pull Requests Changes for an Iteration
#

function Get-PullRequestIterationChanges {
param(
    [Parameter (Mandatory = $true)]
    [string] $pullRequestId,

    [Parameter (Mandatory = $true)]
    [string] $iterationNo,

    [Parameter (Mandatory = $true)]
    [object] $context
)    
    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullrequests/{pullRequestId}/iterations/{iterationNo}/changes?api-version=4.1"

    return Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId; iterationNo = $iterationNo})
}


#
# List Pull Requests Changes
#

function Get-PullRequestChanges {
param(
    [Parameter (Mandatory = $true)]
    [string] $pullRequestId,

    [Parameter (Mandatory = $true)]
    [object] $context
)    
    $iters = Get-PullRequestIterations $pullRequestId -context $context
    $changes = Get-PullRequestIterationChanges $pullRequestId $iters.count -context $context

    return $changes
}


#
# List Pull Requests Commits
#

function Get-PullRequestCommits {
param(
    [Parameter (Mandatory = $true)]
    [string] $pullRequestId,

    [Parameter (Mandatory = $true)]
    [object] $context
)    
    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullRequests/{pullRequestId}/commits?api-version=4.1"

    return Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId})
}


#
# Return information on offset between given branches
#

function Get-BranchOffset {
param(
    [Parameter (Mandatory = $true)]
    [string] $refName,

    [Parameter (Mandatory = $false)]
    [string] $baseBranchName = "develop",

    [Parameter (Mandatory = $true)]
    [object] $context
)   
    $branchName = $refName.Substring(11)

    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/diffs/commits?baseVersion=$baseBranchName&targetVersion={branchName}&api-version=4.1"

    $res = Get-AzureRequestReqults -URI $endpoint -context ($context + @{branchName = $branchName})

    return @{behindCount = $res.behindCount; aheadCount = $res.aheadCount}
}


#
# Set status of Pull Request
#

function Set-PullRequestStatus {
param(
    [Parameter (Mandatory = $true)]
    [string] $pullRequestId,

    [Parameter (Mandatory = $true)]
    [string] $state,

    [Parameter (Mandatory = $true)]
    [string] $description,

    [Parameter (Mandatory = $true)]
    [string] $contextName,

    [Parameter (Mandatory = $false)]
    [string] $contextGenre,

    [Parameter (Mandatory = $false)]
    [string] $targetUrl,

    [Parameter (Mandatory = $true)]
    [object] $context
)    

    $b = @{
        state = $state;
        description = $description;
        context = @{
            name = $contextName;
            genre = $contextGenre;
        };
        targetUrl = $targetUrl;
    }

    $body = ConvertTo-Json $b

    #
    # Get current list of statuses
    #

    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullRequests/{pullRequestId}/statuses?api-version=4.1-preview.1"
    $res = Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId})

    #
    # Try to find a status for a given context genre and name. Start looking from the last one. If found - check if it has same values.
    #

    $i = $res.count
    $foundSameStatus = $false

    while ($i -GT 0) {
        $r = $res.value[$i-1]

        if (($r.context.name -EQ $contextName) -AND ($r.context.genre -EQ $contextGenre)) {
            $foundSameStatus = ($r.state -EQ $state) -AND ($r.description -EQ $description) -AND ($r.targetUrl -EQ $targetUrl)
            
            break
        }
        $i--
    }
    
    $res = $r

    #
    # If same status / values was not found - add new record.
    #
    
    if (-not $foundSameStatus) {
        $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullRequests/{pullRequestId}/statuses?api-version=4.1-preview.1"

        $res = Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId}) -method POST -query $body
    }

    return @{status = $res; status_changed = $(-not $foundSameStatus)}
}


#
# Remove all statuses for a given Pull Request
#

function Remove-PullRequestStatuses {
param(
    [Parameter (Mandatory = $true)]
    [string] $pullRequestId,

    [Parameter (Mandatory = $true)]
    [object] $context
)    

    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullRequests/{pullRequestId}/statuses?api-version=4.1-preview.1"
    $res = Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId})

    $i = $res.count

    $foundSameStatus = $false
    while ($i -GT 0) {
        $r = $res.value[$i-1]

        $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullRequests/{pullRequestId}/statuses/{statusId}?api-version=4.1-preview.1"
        $x = Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId; statusId = $i}) -method DELETE

        $i--
    }
}


#
# Remove all statuses of given genre for a given Pull Request
#

function Remove-PullRequestStatusForGenre {
param(
    [Parameter (Mandatory = $true)]
    [string] $pullRequestId,

    [Parameter (Mandatory = $true)]
    [string] $contextGenre,

    [Parameter (Mandatory = $true)]
    [object] $context
)    

    $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullRequests/{pullRequestId}/statuses?api-version=4.1-preview.1"
    $res = Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId})

    $i = $res.count

    $foundSameStatus = $false
    while ($i -GT 0) {
        $r = $res.value[$i-1]

        if ($r.context.genre -EQ $contextGenre) {            
            $endpoint = (Get-ProjectBaseURL) + "/_apis/git/repositories/{repositoryId}/pullRequests/{pullRequestId}/statuses/{statusId}?api-version=4.1-preview.1"
            $x = Get-AzureRequestReqults -URI $endpoint -context ($context + @{pullRequestId = $pullRequestId; statusId = $i}) -method DELETE

        }
        $i--
    }
}