pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
	property var clock: SystemClock {
		id: clock
		precision: SystemClock.Seconds
	}

	property string time: Qt.locale().toString(clock.date, "hh:mm")
	property string shortDate: Qt.locale().toString(clock.date, "dd/MM")
}
