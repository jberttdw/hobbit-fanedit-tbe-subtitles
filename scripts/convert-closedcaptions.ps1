# Picks up all closed-caption srt files in the source directory, processes them and joins them to
# create a new srt file in the parent directory.
# This new file will by default be called output-{lang}-{date}.srt

[CmdletBinding()]
param (
    # Path to which to write the final result. Defaults to "..\output-{lang}-{date}.srt"
    [parameter()]
    [string] $outputFile,
    # If true, the sequence identifiers will be of the format xxx0yy where 'x' stands for the run number and y for the original sequence id (starting from 1).
    # The default filename will also be changed to start with "debug".
    [parameter()]
    [switch]
    [bool] $debugId,
    # Whether the end user needs to confirm that the outputfile can be overwritten. Defaults to true.
    [switch] $Confirm = $true
)

if (-not (Test-Path "./config.psm1"))
{
    throw "No config module found"
}

$configModule = $null
try {
    $configModule = Import-Module -PassThru -Name "./config.psm1" -Function Get-SourcePath
    $sourcePath = Get-SourcePath
} finally {
    if ($configModule) {
        Remove-Module $configModule
    }
}

$subtitleFiles = Get-ChildItem -Filter "*.srt" -Path $sourcePath | ForEach-Object { $_.FullName } | Sort-Object

# Scan for 'command' files in current dir
$commandFiles = @{}
$temp = Get-ChildItem "r*.*" | Where-Object { $_.BaseName -imatch "r[0-9].*"}
foreach ($commandFile in $temp) {
    if ($commandFiles.Contains($commandFile.BaseName)) {
        throw "Duplicate command file $($commandFile.FullName)"
    }
    $commandFiles[$commandFile.BaseName] = $commandFile.FullName
}

$currentDateTime = Get-Date -Format "yyyy-MM-dd HH-mm"
$currentLangFolder = Split-Path -Leaf "."

if (-not ($outputFile) -and $debugId) {
    $outputFile = Join-Path (Resolve-Path "..") ("debug-{0}-{1}.srt" -f $currentLangFolder, $currentDateTime)
} elseif (-not ($outputFile)) {
    $outputFile = Join-Path (Resolve-Path "..") ("output-{0}-{1}.srt" -f $currentLangFolder, $currentDateTime)
}

if ((Test-Path $outputFile) -and $Confirm) {
    Remove-Item -Confirm $outputFile
    if (Test-Path $outputFile) {
        throw "$outputFile already exists, need confirmation to continue"
    }
}




##################################################################################################

# Helper functions

##################################################################################################



# Reads an srt file and copies it content to the output, no inserts or deletion is done, only id reformatting
function Copy-SubRipFile {
    param (
        $inputFile,
        $outputStream,
        $debugId,
        $lastNumber
    )
    $inputFileName = Split-Path -Leaf $inputFile
    $fileId = [int] ($inputFileName.Substring(1, $inputFileName.IndexOf(".") - 1))
    $lines = Get-Content -Encoding UTF8 $inputFile

    if ($debugId) {
        $number = 0
        $sequenceFormat = "{1}{0:000}"
    } else {
        $number = $lastNumber
        $sequenceFormat = "{0}"
    }

    $nextRealLineIsNumber = $true
    foreach ($line in $lines)
    {
        if ([string]::IsNullOrWhiteSpace($line)) {
            $nextRealLineIsNumber = $true
        } elseif ($nextRealLineIsNumber) {
            $outputStream.WriteLine()
            $number++
            $sequenceId = $sequenceFormat -f $number, $fileId
            $outputStream.WriteLine($sequenceId)
            $nextRealLineIsNumber = $false
        } else {
            $outputStream.WriteLine($line)
        }
    }
    # Return highest number till now so next invocation of this function can continue
    $number
}

# Reads the time offsets in an srt file and stores them in a subtitle PSObject
function Read-TimeOffsets {
    param(
        $line,
        $subtitle
    )
    $parts = $line -split " "
    $startOffset = [datetime]::ParseExact($parts[0], 'HH:mm:ss,fff', $null)
    $endOffset = [datetime]::ParseExact($parts[2], 'HH:mm:ss,fff', $null)
    $subtitle | Add-Member -NotePropertyMembers @{ Start = $startOffset; End = $endOffset } > $null
}

# Reads an srt file and a processing function.
# The function is then given a bunch of subtitles which it is meant to modify and output
# All the output is then renumbered if necessary and written to the complete subtitle file
function Edit-SubRipFile {
    param (
        $inputFile,
        $outputStream,
        $processingScript,
        $debugId,
        $lastNumber
    )
    $inputFileName = Split-Path -Leaf $inputFile
    $fileId = [int] ($inputFileName.Substring(1, $inputFileName.IndexOf(".") - 1))
    $lines = Get-Content -Encoding UTF8 $inputFile

    if ($debugId) {
        $number = 0
        $sequenceFormat = "{1}{0:000}"
    } else {
        $number = $lastNumber
        $sequenceFormat = "{0}"
    }

    $subtitles = New-Object System.Collections.ArrayList

    $nextRealLineIsNumber = $true
    $currentSubtitle = $null
    foreach ($line in $lines)
    {
        if ([string]::IsNullOrWhiteSpace($line)) {
            $nextRealLineIsNumber = $true
        } elseif ($nextRealLineIsNumber) {
            $nextRealLineIsNumber = $false
            $currentSubtitle = New-Object PSObject -Property @{ OriginalNumber = [int]$line }
            $currentSubtitle | Add-Member -Name "Text" -Value "" -MemberType NoteProperty > $null
            $subtitles.Add($currentSubtitle) > $null
        } elseif ($line -ilike "* --> *") {
            Read-TimeOffsets $line $currentSubtitle
        } else {
            # We read a line before - add newlines in between
            if ($currentSubtitle.Text) {
                $currentSubtitle.Text += "`n" + $line
            } else {
                $currentSubtitle.Text = $line
            }
        }
    }

    $helperModule = $null
    $currentModule = $null
    try {
        $global:HELPERFOLDER = $PSScriptRoot
        $helperModule = Import-Module -PassThru -Name "$HELPERFOLDER/subtitle-parsing.psm1"
        $currentModule = Import-Module -PassThru -Name $processingScript -Function "Process" -DisableNameChecking
        $script = Import-Module -Name $processingScript -AsCustomObject

        $subtitles = $script.Process($subtitles)
    } finally {
        if ($currentModule) {
            Remove-Module $currentModule
        }
        if ($helperModule) {
            Remove-Module $helperModule
        }
    }

    foreach ($subtitle in $subtitles)
    {
            $number++
            if ($debugId) {
                $sequenceId = $sequenceFormat -f $subtitle.OriginalNumber, $fileId
            } else {
                $sequenceId = $sequenceFormat -f $number, $fileId
            }
            $outputStream.WriteLine()
            $outputStream.WriteLine($sequenceId)
            $outputStream.Write(($subtitle.Start | Get-Date -Format "HH:mm:ss,fff"))
            $outputStream.Write(" --> ")
            $outputStream.WriteLine(($subtitle.End | Get-Date -Format "HH:mm:ss,fff"))
            $outputStream.WriteLine($subtitle.Text)
    }
    # Return highest number till now so next invocation of this function can continue counting
    $number
}



##################################################################################################

    # The main processing loop

##################################################################################################

$outputStream = [System.IO.StreamWriter] $outputFile

try {

    $highestNumber = 0

    foreach ($sourceFile in $subtitleFiles) {
        $runFileId = (Get-Item $sourceFile).BaseName
        if (-not $commandFiles.Contains($runFileId)) {
            Write-Warning "Copying srt because there is no command file for $sourceFile"
            $highestNumber = Copy-SubRipFile $sourceFile $outputStream $debugId $highestNumber
        } else {
            $commandFile = $commandFiles[$runFileId]
            $commandType = (Get-Item $commandFile).Extension

            if ($commandType -ieq ".del") {
                Write-Host "Skipped file $sourceFile"

            } elseif ($commandType -ieq ".copy") {
                $highestNumber = Copy-SubRipFile $sourceFile $outputStream $debugId $highestNumber
                Write-Host "Processed file $sourceFile"

            } elseif ($commandType -ieq ".replace") {
                # Copies the "replace" command file instead of the source file
                $highestNumber = Copy-SubRipFile $commandFile $outputStream $debugId $highestNumber
                Write-Host "Replaced run with file $commandFile"

            } elseif ($commandType -ieq ".filter") {
                # Run default processing: filter names and captions
                $highestNumber = Edit-SubRipFile $sourceFile $outputStream `
                        "$PSScriptRoot/default-closedcaption-filter.psm1" $debugId $highestNumber
                Write-Host "Filtered file $sourceFile"

            } elseif ($commandType -ieq ".psm1") {
                # Most flexible command: reads the subtitles, reads a processing function from a script file,
                # executes the function and then writes the modified results to the output
                $highestNumber = Edit-SubRipFile $sourceFile $outputStream $commandFile $debugId $highestNumber
                Write-Host "Processed file $sourceFile"

            } else {
                throw "Command file $sourceFile has unrecognized extension"
            }
        }
    }
} finally {
    $outputStream.Close()
}


Write-Host "Wrote $outputFile"

