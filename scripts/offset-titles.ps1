[CmdletBinding()]
param (
    # Path to TSV file which contains a file id + offset
    [parameter(Mandatory=$true)]
    [string] $offsetsFile,
    [parameter(Mandatory=$true)]
    [string] $outputDir
)

Add-PathVariable -Target Process "C:\Program Files\Subtitle Edit\"

if ( ! (Test-Path $offsetsFile -PathType Leaf)) {
    throw "Offsets file not found"
}

if ( ! (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Write-Host
}

$offsets = Import-Csv -Path $offsetsFile -Delimiter "`t"

foreach ($runInfo in $offsets) {
    $runFileName = "r{0}.srt" -f $runInfo.Id
    $runFile = Join-Path "." -ChildPath $runFileName
    if (! (Test-Path -PathType Leaf -Path $runFile)) {
        Write-Warning "Subtitle run '$runFile' file not found"
        continue;
    }
    #$convertCommand = "SubtitleEdit.exe /convert $runFileName srt /outputfolder:$outputDir /offset:$($runInfo.Offset)"
    #Invoke-Expression -Command $convertCommand
    $convertCommandArgs = "/convert", $runFileName, "srt", "/outputfolder:$outputDir", "/offset:$($runInfo.Offset)"
    #$convertor = Start-Process -FilePath "C:\Program Files\Subtitle Edit\SubtitleEdit.exe" -ArgumentList $convertCommandArgs -NoNewWindow -PassThru
    #$convertor.WaitForExit()
    Start-Process -FilePath "C:\Program Files\Subtitle Edit\SubtitleEdit.exe" -ArgumentList $convertCommandArgs -NoNewWindow -Wait
}

#$runs = Get-ChildItem -Path (Get-Location) -Filter "r*.srt" | ForEach-Object {
#    if ($_.Name.Contains("_")) {
#        $tempCnt = [int] ($_.Name.Substring(1, $_.Name.LastIndexOf("_") - 1));
#    } else {
#        $tempCnt = [int] ($_.Name.Substring(1, $_.Name.LastIndexOf(".") - 1));
#    }
#    Add-Member -InputObject $_ -Type NoteProperty -Name "Counter" -Value $tempCnt -PassThru
#}
#
## Note about sorting: incrementing counters might cause conflicts when renaming file 1 to file 2 and file 2 exists, so we start renaming from the end
#$runs | Sort-Object -Descending -Property Name | ? { $_.Counter -ge $startOffset } `
#      | % { Move-Item -Path $_.FullName -Destination (Join-Path $_.DirectoryName ("r{0:d3}{1}" -f ($_.Counter + $amount),($_.Name.Substring(4))) ) }
