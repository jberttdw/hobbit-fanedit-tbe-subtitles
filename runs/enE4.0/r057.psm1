Import-Module -Name "$HELPERFOLDER/subtitle-parsing.psm1"
function Process {
    param ($subtitles)
    # Find Dwalin's bit of speech
    $dwalinsCaptionId = $subtitles | Where-Object { $_.Text.StartsWith("DWALIN:") } `
        | Foreach-Object { $_.OriginalNumber } | Select-Object -First 1

    $temp = Remove-Names $subtitles
    $temp = Remove-Captions $temp

    # Now make this bit of dialog italic - it's spoken in the background
    $caption = $temp | Where-Object { $_.OriginalNumber -eq $dwalinsCaptionId }
    $caption.Text = "<i>" + $caption.Text + "</i>"

    return $temp
}
