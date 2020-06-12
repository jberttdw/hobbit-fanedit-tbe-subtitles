Import-Module -Name "$HELPERFOLDER/subtitle-parsing.psm1"
function Process {
    param ($subtitles)
    $temp = Remove-Names $subtitles
    $temp = Remove-Captions $temp
    # Find Bifur's "speaks in dwarvish" caption
    # It's a slightly confusing mumble if we don't edit it back in again
    $bifursCaption = $subtitles | Where-Object { $_.Text -like "*SPEAKS IN DWARVISH*" }

    $temp + $bifursCaption | Sort-Object -Property OriginalNumber
}
