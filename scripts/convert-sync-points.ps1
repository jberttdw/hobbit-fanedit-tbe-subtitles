# This script takes the sync-point reference SRT files and converts
# the timestamps in them into a format which is easier to use in
# spreadsheets. It can then be used in the Index ODS file.

# Currently all the input and output file paths are hard-coded (see main logic).

$indexFolder = Resolve-Path (Join-Path $PSScriptRoot "../index")

# ################################################################################
#
# Helper methods
#
# ################################################################################

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

function Get-NextSubtitle ($reader) {
    $nextRealLineIsNumber = $true
    $nextSubtitle = $null
    $line = $reader.ReadLine()
    while ($null -ne $line)
    {
        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($nextSubtitle) {
                return $nextSubtitle
            }
            $nextRealLineIsNumber = $true
        } elseif ($nextRealLineIsNumber) {
            $nextRealLineIsNumber = $false
            $nextSubtitle = New-Object PSObject -Property @{ Number = [int]$line }
            $nextSubtitle | Add-Member -Name "Text" -Value "" -MemberType NoteProperty > $null
        } elseif ($line -ilike "* --> *") {
            Read-TimeOffsets $line $nextSubtitle
        } else {
            # We read a line before - add newlines in between
            if ($nextSubtitle.Text) {
                $nextSubtitle.Text += "`n" + $line
            } else {
                $nextSubtitle.Text = $line
            }
        }
        $line = $reader.ReadLine()
    }
    if ($nextSubtitle) {
        return $nextSubtitle
    }
}

# Reads all the reference points from an .srt file, then stores them in a dictionary
function Read-ReferencePoints($file) {
    $fileReader = $null
    $references = @()
    try {
        $fileReader = New-Object System.IO.StreamReader -ArgumentList @($file, [System.Text.Encoding]::UTF8)
        $subtitle = Get-NextSubtitle $fileReader
        while ($null -ne $subtitle) {
            # Parse text - there might be more than one run number, and sometimes there's a couple of words after the run number
            $lines = $subtitle.Text.Split("`n")
            foreach ($line in $lines) {
                if ($line -match "(r\d+) ?.*") {
                    $runId = $matches[1]
                    $reference = [pscustomobject]@{ Run = $runId; Time = $subtitle.Start }
                    $references += $reference
                }
            }
            $subtitle = Get-NextSubtitle $fileReader
        }
    } finally {
        if ($null -ne $fileReader) {
            $fileReader.Close()
        }
    }
    return $references
}

function Write-ReferencePoints($references, $file) {
    $references = $references | Sort-Object -Property Run
    $lines = @()
    foreach ($reference in $references) {
        $lines += $reference.Run + "`t" + ($reference.Time | Get-Date -Format "HH:mm:ss,fff")
    }
    $lines | Out-File -Encoding UTF8 -FilePath $file
    Write-Information -InformationAction Continue "File $file written"
}

# ################################################################################
#
# Main logic
#
# ################################################################################

# Sound reference points

$references =  Read-ReferencePoints (Join-Path $indexFolder "sync_snd_m1_n.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_snd_m1_e.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_snd_m2_n.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_snd_m2_e.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_snd_m3_n.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_snd_m3_e.srt")
Write-ReferencePoints $references (Join-Path $indexFolder "sync_snd_src.tsv")

$references =  Read-ReferencePoints (Join-Path $indexFolder "sync_snd_tbe3.1.srt")
Write-ReferencePoints $references (Join-Path $indexFolder "sync_snd_tbe3.1.tsv")

#$references =  Read-ReferencePoints (Join-Path $indexFolder "sync_snd_tbe4.1.srt")
#Write-ReferencePoints $references (Join-Path $indexFolder "sync_snd_tbe4.1.tsv")

$references =  Read-ReferencePoints (Join-Path $indexFolder "sync_vis_m1_n.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_vis_m1_e.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_vis_m2_n.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_vis_m2_e.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_vis_m3_n.srt")
$references += Read-ReferencePoints (Join-Path $indexFolder "sync_vis_m3_e.srt")
Write-ReferencePoints $references (Join-Path $indexFolder "sync_vis_src.tsv")

$references =  Read-ReferencePoints (Join-Path $indexFolder "sync_vis_tbe3.1.srt")
Write-ReferencePoints $references (Join-Path $indexFolder "sync_vis_tbe3.1.tsv")

#$references =  Read-ReferencePoints (Join-Path $indexFolder "sync_vis_tbe4.1.srt")
#Write-ReferencePoints $references (Join-Path $indexFolder "sync_vis_tbe4.1.tsv")
