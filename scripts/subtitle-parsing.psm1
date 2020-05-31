$REGEX_NAME_MONOLOGUE = "^[\[\]A-Z0-9 -]+:$"
$REGEX_NAME_DIALOG = "[\[\]A-Z0-9 -]+: "

function Remove-Names {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [System.Collections.ArrayList] $subtitles
    )

    $output = New-Object System.Collections.ArrayList

    foreach ($subtitle in $subtitles) {
        $alteredSubtitle = $subtitle
        $text = $subtitle.Text
        $lines = $text -split "`r`n|`r|`n"
        if ($lines.Count -gt 2) {
            throw "Expected 2 lines max, found $($lines.Count) lines"
        }
        $firstLine = $lines[0]
        $secondLine = $lines[1]
        # Simple speech: first line contains name, second line contains rest of dialog. Discard first line
        if ($firstLine -cmatch $REGEX_NAME_MONOLOGUE) {
            $firstLine = $secondLine
            $secondLine = $null
        }
        if ($firstLine -cmatch $REGEX_NAME_DIALOG -and $secondLine `
                -and ($secondLine.StartsWith("-") -or $secondLine -cmatch $REGEX_NAME_DIALOG)) {
            # First line has a name because it's not clear who's speaking, second line is for somebody else
            $firstLine = "- " + $firstLine.Substring($firstLine.IndexOf(": ") + 2)
        } elseif ($firstLine -cmatch $REGEX_NAME_DIALOG) {
            # Special case: not a dialog but a name in first line and text which wouldn't fit in second line
            $firstLine = $firstLine.Substring($firstLine.IndexOf(": ") + 2)
        }
        if ($secondLine -cmatch $REGEX_NAME_DIALOG) {
            $secondLine = "- " + $secondLine.Substring($secondLine.IndexOf(": ") + 2)
        }

        if ($secondLine) {
            $text = $firstLine + "`r`n" + $secondLine
        } else {
            $text = $firstLine
        }

        if ([string]::IsNullOrWhiteSpace($text)) {
            # Discard subtitle simply by not adding it to output
            # Shouldn't happen just by removing name tags but let's be sure
        } elseif ($subtitle.Text -ne $text) {
            # Text has been modified, replace subtitle by an updated copy
            $alteredSubtitle = $subtitle.PsObject.Copy()
            $alteredSubtitle.Text = $text
            $output.Add($alteredSubtitle) > $null
        } else {
            $output.Add($subtitle) > $null
        }
    }
    $output
}

$REGEX_CAPTION = "\[[A-Z& -]+\] ?"

Function Remove-Captions {
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [System.Collections.ArrayList] $subtitles
    )

    $output = New-Object System.Collections.ArrayList

    foreach ($subtitle in $subtitles) {
        $alteredSubtitle = $subtitle
        $text = $subtitle.Text

        $text = $text -replace $REGEX_CAPTION, ''
        
        if ([string]::IsNullOrWhiteSpace($text)) {
            # Discard empty subtitle simply by not adding it to output
        } elseif ($subtitle.Text -ne $text) {
            # Text has been modified, replace subtitle by an updated copy
            $alteredSubtitle = $subtitle.PsObject.Copy()
            $alteredSubtitle.Text = $text
            $output.Add($alteredSubtitle) > $null
        } else {
            $output.Add($subtitle) > $null
        }
    }
    $output
}

Export-ModuleMember -Function Remove-Captions, Remove-Names