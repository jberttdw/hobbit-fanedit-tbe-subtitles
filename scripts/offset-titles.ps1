[CmdletBinding()]
param (
    # Path to TSV file which contains a file id + offset
    [parameter(Mandatory=$true)]
    [string] $offsetsFile,
    [parameter(Mandatory=$true)]
    [string] $outputDir,
    # Optional identifiers of the runs which should be modified. If not specified, all runs will be offset
    [array] $runs,
    # This switch will negate the offsets, i.e. instead of shifting something forward it will shift it backward.
    # Handy to convert TBE x.x subtitles back to original timing of the source movies, then shift those to different edition timing.
    [switch] $Reverse
)

Add-PathVariable -Target Process "C:\Program Files\Subtitle Edit\"

if ( ! (Test-Path $offsetsFile -PathType Leaf)) {
    throw "Offsets file not found"
}

if ( ! (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Write-Host
}
$outputDir = Resolve-Path $outputDir

$offsets = Import-Csv -Path $offsetsFile -Delimiter "`t"

if ($runs) {
    $runs = $runs | Foreach-Object { [int]$_ }
    # Filter offsets array
    $offsets = $offsets | Where-Object { [int]($_.Id) -in $runs }
}

foreach ($runInfo in $offsets) {
    $runFileName = "r{0}.srt" -f $runInfo.Id
    $runFile = Join-Path "." -ChildPath $runFileName
    if (! (Test-Path -PathType Leaf -Path $runFile)) {
        Write-Warning "Subtitle run '$runFile' file not found"
        continue;
    }
    if ($Reverse) {
        if ($runInfo.Diff.StartsWith("-")) {
            $runInfo.Diff = $runInfo.Diff.Substring(1)
        } else {
            $runInfo.Diff = "-" + $runInfo.Diff
        }
    }
    $convertCommandArgs = "/convert", $runFileName, "srt", "/outputfolder:$outputDir", "/offset:$($runInfo.Diff)"
    Write-Host $convertCommandArgs
    Start-Process -FilePath "C:\Program Files\Subtitle Edit\SubtitleEdit.exe" -ArgumentList $convertCommandArgs -NoNewWindow -Wait
}
