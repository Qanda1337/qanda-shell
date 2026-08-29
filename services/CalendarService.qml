import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    property bool yearPickerOpen: false
    property date selectedDate: new Date()
    property date visibleMonth: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
    property int yearPageStart: Math.floor(new Date().getFullYear() / 12) * 12

    function open() {
        const today = new Date();
        selectedDate = today;
        visibleMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        yearPageStart = Math.floor(today.getFullYear() / 12) * 12;
        yearPickerOpen = false;
        isOpen = true;
    }

    function close() {
        isOpen = false;
        yearPickerOpen = false;
    }

    function toggle() { isOpen ? close() : open(); }

    function previous() {
        if (yearPickerOpen)
            yearPageStart -= 12;
        else
            visibleMonth = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth() - 1, 1);
    }

    function next() {
        if (yearPickerOpen)
            yearPageStart += 12;
        else
            visibleMonth = new Date(visibleMonth.getFullYear(), visibleMonth.getMonth() + 1, 1);
    }

    function showToday() {
        const today = new Date();
        selectedDate = today;
        visibleMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        yearPickerOpen = false;
    }

    function chooseYear(year) {
        visibleMonth = new Date(year, visibleMonth.getMonth(), 1);
        selectedDate = new Date(year, selectedDate.getMonth(), selectedDate.getDate());
        yearPickerOpen = false;
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
    }
}
