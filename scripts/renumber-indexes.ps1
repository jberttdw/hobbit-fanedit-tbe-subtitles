# Picks up all srt files in the current directory, opens each one and rnumbers all
# subtitles so the numbering in each file starts from 1

function Convert-SubRipFile {
    param (
        $file
    )
    $lines = Get-Content -Encoding UTF8 $file
    $number = 1
    $nextRealLineIsNumber = $true
    foreach ($line in $lines)
    {
        if ([string]::IsNullOrWhiteSpace($line)) {
            Write-Output $line
            $nextRealLineIsNumber = $true
        } elseif ($nextRealLineIsNumber) {
            Write-Output $number
            $number++
            $nextRealLineIsNumber = $false
        } else {
            Write-Output $line
        }
    }
}

$subtitleFiles = Get-ChildItem "*.srt"

$subtitleFiles | % { Convert-SubRipFile $_ | Set-Content -Encoding UTF8 $_ ; Write-Host "Updated file $_" }