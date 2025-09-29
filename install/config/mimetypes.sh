chronos-refresh-applications

# Open all images with imv
xdg-mime default imv.desktop image/png
xdg-mime default imv.desktop image/jpeg
xdg-mime default imv.desktop image/gif
xdg-mime default imv.desktop image/webp
xdg-mime default imv.desktop image/bmp
xdg-mime default imv.desktop image/tiff

# Open PDFs with the Document Viewer
xdg-mime default org.gnome.Evince.desktop application/pdf

# Use Chromium as the default web browser
xdg-settings set default-web-browser chromium.desktop
xdg-mime default chromium.desktop x-scheme-handler/http
xdg-mime default chromium.desktop x-scheme-handler/https

# Open video types with mpv
xdg-mime default mvp.desktop video/mp4
xdg-mime default mvp.desktop video/x-msvideo
xdg-mime default mvp.desktop video/x-matroska
xdg-mime default mvp.desktop video/x-flv
xdg-mime default mvp.desktop video/x-ms-wmv
xdg-mime default mvp.desktop video/mpeg
xdg-mime default mvp.desktop video/ogg
xdg-mime default mvp.desktop video/webm
xdg-mime default mvp.desktop video/quicktime
xdg-mime default mvp.desktop video/3gpp
xdg-mime default mvp.desktop video/3gpp2
xdg-mime default mvp.desktop video/x-ms-asf
xdg-mime default mvp.desktop video/x-ogm+ogg
xdg-mime default mvp.desktop video/x-theora+ogg
xdg-mime default mvp.desktop application/ogg