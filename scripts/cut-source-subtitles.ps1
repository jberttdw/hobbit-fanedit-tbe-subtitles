# This script expects 6 subtitle files meant for the original films and splits
# them into short pieces which can then be synced to match up with the Bilbo
# Edition fanedit using the offset-titles script. Run this script inside the
# runs/<lang>-cut folder.
#
# Simply put there are 3 films which each have 2 editions:
# - the theatrical or "normal" cut
# - the extended edition which got released on home media
# Each subtitle is slightly different.
#
# NOTE: This script assumes these subtitle files are using the UTF-8 encoding.
# Please convert them before running this script or accents might turn into mojibake.
#
[CmdletBinding()]
param (
    $srtFilm1Normal,
    $srtFilm1Extended,
    $srtFilm2Normal,
    $srtFilm2Extended,
    $srtFilm3Normal,
    $srtFilm3Extended
)
$indexFile = "../../index/index-automated-cut.tsv"
if (-not (Test-Path $indexFile)) {
    throw "Index-automated-cut.tsv file not found"
}

if (-not (Test-Path $srtFilm1Normal) -or -not (Test-Path $srtFilm1Extended) `
        -or -not (Test-Path $srtFilm2Normal) -or -not (Test-Path $srtFilm2Extended) `
        -or -not (Test-Path $srtFilm3Normal) -or -not (Test-Path $srtFilm3Extended)) {
    throw "One or more of the subtitle files could not be found"
}
$srtFilm1Normal   = Resolve-Path $srtFilm1Normal
$srtFilm1Extended = Resolve-Path $srtFilm1Extended
$srtFilm2Normal   = Resolve-Path $srtFilm2Normal
$srtFilm2Extended = Resolve-Path $srtFilm2Extended
$srtFilm3Normal   = Resolve-Path $srtFilm3Normal
$srtFilm3Extended = Resolve-Path $srtFilm3Extended

# ################################################################################
#
# Helper type which holds information about each run of subtitles
#
# ################################################################################

Add-Type @"
using System;
using System.Globalization;
public struct RunInfo {
    private int _run;
    private int _film;
    private bool _extended;
    private bool _canBeEmpty;
    private DateTime _start;
    private DateTime _end;
    private string _sourceFile;

    public RunInfo(int run, int film, bool extended, string canBeEmpty, string start, string end) {
        _run = run; _film = film; _extended = extended;
         _canBeEmpty = Boolean.Parse(canBeEmpty);
        _start = DateTime.ParseExact(start, "hh:mm:ss,ff", CultureInfo.InvariantCulture);
        _end = DateTime.ParseExact(end, "hh:mm:ss,ff", CultureInfo.InvariantCulture);
        _sourceFile = null;
    }

    public int Run { get { return _run; } }
    public int Film { get { return _film; } }
    public bool Extended { get { return _extended; } }
    public bool CanBeEmpty { get { return _canBeEmpty; } }
    public DateTime Start { get { return _start; } }
    public DateTime End { get { return _end; } }
    public string SourceFile { get { return _sourceFile; } }

    public void PickSourceFile(string srtFilm1Normal, string srtFilm1Extended, string srtFilm2Normal,
                                string srtFilm2Extended, string srtFilm3Normal, string srtFilm3Extended)
    {
        if (Film == 1 && Extended) {
            _sourceFile = srtFilm1Extended;
        } else if (Film == 1) {
            _sourceFile = srtFilm1Normal;
        } else if (Film == 2 && Extended) {
            _sourceFile = srtFilm2Extended;
        } else if (Film == 2) {
            _sourceFile = srtFilm2Normal;
        } else if (Film == 3 && Extended) {
            _sourceFile = srtFilm3Extended;
        } else if (Film == 3) {
            _sourceFile = srtFilm3Normal;
        } else {
            throw new Exception("Film: " + Film + ", Ext: " + Extended + " did not match anything");
        }
    }
}
"@

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
}

# ################################################################################
#
# Main logic
#
# ################################################################################

$index = Get-Content -Encoding ASCII $indexFile -Raw | ConvertFrom-Csv -Delimiter `t
$sortedRuns = $index | Sort-Object -Property Film, Type, Start | ForEach-Object {
    $temp = New-Object -TypeName RunInfo -ArgumentList @([int]$_.Run, [int]$_.Film, ($_.Type -eq "EXT"),
              $_.CanBeEmpty, $_.Start, $_.End)
    $temp.PickSourceFile($srtFilm1Normal, $srtFilm1Extended, $srtFilm2Normal, $srtFilm2Extended, $srtFilm3Normal, $srtFilm3Extended)
    $temp
}


$currentFile = $null
$currentReader = $null
$currentSubtitle = $null
try {
    foreach ($run in $sortedRuns) {
        if ($run.SourceFile -ne $currentFile) {
            Write-Output "Reading $($run.SourceFile)"
            if ($null -ne $currentReader) {
                $currentReader.Close()
            }
            $currentSubtitle = $null
            $currentFile = $run.SourceFile
            $currentReader = New-Object System.IO.StreamReader -ArgumentList @($currentFile, [System.Text.Encoding]::UTF8)
        }
        Write-Output "Handling run $($run.Run)"
        $subtitles = New-Object System.Collections.ArrayList

        if ($null -eq $currentSubtitle) {
            $currentSubtitle = Get-NextSubtitle $currentReader
        }
        # Discard subtitles when run is later in the file than current subtitle
        while ($currentSubtitle -and $run.Start -gt $currentSubtitle.End) {
            $currentSubtitle = Get-NextSubtitle $currentReader
        }

        # Subtitle starts slightly before run and ends inside run, include it anyway with a warning
        if ($currentSubtitle -and $currentSubtitle.Start -lt $run.Start) {
            Write-Warning "First subtitle in run $($run.Run) hangs over start"
            $subtitles.Add($currentSubtitle) > $null
            $currentSubtitle = Get-NextSubtitle $currentReader
        }
        # Start collecting run's subtitles
        while ($currentSubtitle -and $run.End -gt $currentSubtitle.End) {
            $subtitles.Add($currentSubtitle) > $null
            $currentSubtitle = Get-NextSubtitle $currentReader
        }
        # Last subtitle hangs over end of run, include it anyway with a warning
        if ($currentSubtitle -and $currentSubtitle.Start -lt $run.End) {
            Write-Warning "Last subtitle in run $($run.Run) hangs over end"
            $subtitles.Add($currentSubtitle) > $null
            $currentSubtitle = Get-NextSubtitle $currentReader
        }
        # Write subtitles
        if ($subtitles.Count -gt 0) {
            $currentRunOutput = "r{0:000}.srt" -f $run.Run
            $outputStream = [System.IO.StreamWriter] $currentRunOutput
            try {
                foreach ($subtitle in $subtitles) {
                    $outputStream.WriteLine()
                    $outputStream.WriteLine($subtitle.Number)
                    $outputStream.Write(($subtitle.Start | Get-Date -Format "HH:mm:ss,fff"))
                    $outputStream.Write(" --> ")
                    $outputStream.WriteLine(($subtitle.End | Get-Date -Format "HH:mm:ss,fff"))
                    $outputStream.WriteLine($subtitle.Text)
                }
            } finally {
                $outputStream.Close()
            }
        } elseif (-not $run.CanBeEmpty) {
            Write-Error "Run $($run.Run) did not find any subtitles in file $($run.SourceFile). Check the output"
        } else {
            Write-Output "Run $($run.Run) is empty"
        }
    }
} finally {
    if ($null -ne $currentReader) {
        $currentReader.Close()
    }
}