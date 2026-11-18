import QtQuick
import "youtube.js" as YouTube

Image {
    required property var player
    readonly property string supplied: player?.trackArtUrl ?? ""
    readonly property string videoId: YouTube.videoId(player?.metadata?.["xesam:url"])
    readonly property string thumbnail: videoId ? "https://i.ytimg.com/vi/" + videoId + "/hqdefault.jpg" : ""
    property string failedCover: ""
    onSuppliedChanged: failedCover = ""
    source: supplied && supplied !== failedCover ? supplied : thumbnail
    onStatusChanged: if (status === Image.Error && supplied && source.toString() !== thumbnail) failedCover = supplied
    fillMode: Image.PreserveAspectCrop
    asynchronous: true
}
