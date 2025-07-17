param(
    [string]$Message = "Automated commit"
)

git add .

git commit -m "$Message"

# Find the latest tag like v1.2.3, sorted as version
$lastTag = git tag --list "v*" | Sort-Object {[version]($_ -replace '^v','')} -Descending | Select-Object -First 1

if($lastTag -notmatch '^v(\d+)\.(\d+)\.(\d+)$') {
    $major, $minor, $patch = 1, 0, 0
    $lastTag = "v0.0.0"
} else {
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
}

Write-Host "Last tag: $lastTag"
$choice = Read-Host "Which part would you like to increment? [major/minor/patch] (default patch)"

switch ($choice.ToLower()) {
    "major" {
        $major++; $minor=0; $patch=0
    }
    "minor" {
        $minor++; $patch=0
    }
    default {
        $patch++
    }
}

$newTag = "v$major.$minor.$patch"
Write-Host "Creating and pushing tag $newTag..."

git tag $newTag
git push
git push origin $newTag

Write-Host "Committed and tagged as $newTag."

# pwsh .\git_release.ps1 "Your commit message"
