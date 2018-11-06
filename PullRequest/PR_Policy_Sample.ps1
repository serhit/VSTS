Import-Module ./AzureCommon.psm1 -Force
Import-Module ./AzurePipeline.psm1 -Force
Import-Module ./AzureRepo.psm1 -Force


function Check-Title {
param (
    [Parameter (Mandatory=$true)]
    [object] $PullRequest
)    
    $titleIsCorrect = $false

    if ($PullRequest | Where-Object -Property title -CMatch '^\[((BUG)|(FEATURE))-[0-9]{6}\] - .*(\w+)$') {
        $titleIsCorrect = $true
    }

    return @{result = $titleIsCorrect}
}


function Check-Build {
param (
    [Parameter (Mandatory=$true)]
    [object] $PullRequest
)    
    # ID of the build that must exist in order to have policy validated
    $buildID_toCheck = 2

    $last_commit = (Get-PullRequestCommits $PullRequest.pullRequestId -context $context).value[0]
        
    $build_list = Get-BuildsForBranch -branchName $PullRequest.sourceRefName -definitionId $buildID_toCheck -context $context
    $last_build = $build_list.value[0]

    $last_build_is_for_last_commit = $last_commit.commitId -EQ $last_build.sourceVersion 

    $last_build_ok = ($last_build.status -EQ 'completed') -AND ($last_build.result -EQ 'succeeded') -AND $last_build_is_for_last_commit
    
    return @{result = $last_build_ok; build = $last_build}
}

function Check-BranchOffset {
param (
    [Parameter (Mandatory=$true)]
    [object] $PullRequest
) 
    $res = Get-BranchOffset -refName $PullRequest.sourceRefName -context $context

    return @{result = (-not ($res.behindCount -GT 0)); behindCount = $res.behindCount; aheadCount = $res.aheadCount}
}

function Check-PR {
param (
    [Parameter (Mandatory=$true)]
    [object] $PullRequest
)
    $pr = $PullRequest

    Write-Host '***************************************************'
    Write-Host '*', $pr.title
    Write-Host '***************************************************'
    Write-Host

    #########################
    #
    # Check title
    #
    #########################

    $res = Check-Title $pr
    Write-Host "PR Title correct:", $res.result
    
    $url = $null
    $msg = "Title format is correct"
    if ($res.result -EQ $false) {
        $url = $url_PRPreparation
        $msg = "Title format is not correct"
    }

    $status_changed = Set-PRStatus -PullRequest $pr -success $res.result -contextName 'check-title' -description $msg -targetUrl $url -context $context

    #########################
    #
    # Check build
    #
    #########################

    $res = Check-Build $pr

    Write-Host ("Last build [{0}] pass:" -f $res.build.id), $res.result

    $url = $null
    if ($res.build.id -GT 0) {
        $url = (Get-ProjectBaseURL) + "/_build/results?buildId={0}" -f $res.build.id
    }
    $status_changed = Set-PRStatus -PullRequest $pr -success $res.result -contextName 'check-build' -description "Build for last update" -targetUrl $url -context $context
    
    #########################
    #
    # Check offset
    #
    #########################

    $res = Check-BranchOffset $pr
    Write-Host ("Offset from develop=[{0}]:" -f $res.behindCount), $res.result

    $msg = "No offset from develop"
    $url = $null
    if ($res.result -EQ $false) {
        $msg = ("Behind develop by {0} commits" -f $res.behindCount)
        $url = $url_ValidationOfNewDevelopment
    }
    $status_changed = Set-PRStatus -PullRequest $pr -success $res.result -contextName 'check-offset' -description $msg -context $context
    
    Write-Host

}


function Set-PRStatus {
param (
    [Parameter (Mandatory=$true)]
    [object] $PullRequest,

    [Parameter (Mandatory=$true)]
    [string]$success,

    [Parameter (Mandatory=$true)]
    [string]$contextName,

    [Parameter (Mandatory=$true)]
    [string]$description,

    [Parameter (Mandatory=$false)]
    [string]$targetUrl,

    [Parameter (Mandatory = $true)]
    [object] $context
)   
    if ($success -EQ $true) {
        $result = 'succeeded'
    } else {
        $result = 'failed'
    }

    if ($targetUrl) {
        $targetUrl = Update-StringWithContext -str $targetUrl -context $context
    }
    
    $res = Set-PullRequestStatus -pullRequestId $PullRequest.pullRequestId -contextGenre 'my-pr-policy' -state $result -contextName $contextName -description $description -targetUrl $targetUrl -context $context

    return $res.status_changed
}

$context = @{
    organization = "<your organization code>";
    project = "<your project name>";
    repositoryId = "<repository name under project>";
    token = "<PAT>"
}

$pr_list = Get-PullRequests -context $context
foreach($pr in ($pr_list.value)) {
    Check-PR $pr
}