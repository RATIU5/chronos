pragma once
import QtQuick

Singleton {
  id: fonts

  readonly property FontLoader displayRegular: FontLoader {
    name: "SF Pro Display"
  }

  readonly property string sfProDisplay: displayRegular.name
}