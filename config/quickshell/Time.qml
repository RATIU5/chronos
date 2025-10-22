pragma Singleton
import Quickshell

Singleton {
  readonly property string time: Qt.fromDateTime(new Date(), "hh:mm:ss")

  SystemClock {
    id: clock
    precision: SystemClock.Seconds
  }
}