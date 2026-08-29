import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "../config" as Config

Item {
    id: root

    property bool isOpen: false
    property bool doNotDisturb: false
    property var currentNotification: null
    property bool paused: false
    property var history: []
    property var liveNotifications: ({})
    readonly property int unreadCount: history.filter(entry => !entry.read).length

    function open() {
        isOpen = true;
        hideCurrent();
        markAllRead();
    }

    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }
    function toggleDoNotDisturb() { doNotDisturb = !doNotDisturb; }

    function setPaused(value) {
        paused = value;
        if (value)
            hideTimer.stop();
        else if (currentNotification)
            hideTimer.restart();
    }

    function hideCurrent() {
        currentNotification = null;
        hideTimer.stop();
    }

    function showSilentToast(summary, body, image) {
        if (doNotDisturb || isOpen)
            return false;
        currentNotification = {
            appName: "Музыка",
            appIcon: "",
            summary: summary || "Следующий трек",
            body: body || "",
            image: image || "",
            urgency: NotificationUrgency.Normal,
            actions: [],
            dismiss: function() {}
        };
        if (!paused)
            hideTimer.restart();
        return true;
    }

    function closeCurrent(dismissed) {
        const notification = currentNotification;
        hideCurrent();
        if (dismissed && notification && typeof notification.dismiss === "function")
            notification.dismiss();
    }

    function markAllRead() {
        history = history.map(entry => Object.assign({}, entry, { read: true }));
    }

    function removeEntry(key) {
        const live = liveNotifications[key];
        if (live)
            live.dismiss();
        history = history.filter(entry => entry.key !== key);
        const next = Object.assign({}, liveNotifications);
        delete next[key];
        liveNotifications = next;
    }

    function clearHistory() {
        const values = Object.values(liveNotifications);
        for (let index = 0; index < values.length; ++index)
            values[index]?.dismiss();
        history = [];
        liveNotifications = ({});
        hideCurrent();
    }

    function invokeFirstAction(key) {
        const live = liveNotifications[key];
        if (live?.actions?.length > 0)
            live.actions[0].invoke();
    }

    function isTelegram(notification) {
        const identity = [notification.appName, notification.desktopEntry,
            notification.appIcon].join(" ").toLowerCase();
        return identity.includes("telegram") || identity.includes("org.telegram.desktop");
    }

    NotificationServer {
        keepOnReload: true
        persistenceSupported: true
        imageSupported: true
        actionsSupported: true
        bodyMarkupSupported: false

        onNotification: notification => {
            notification.tracked = true;
            const key = Date.now() + "-" + notification.id;
            const entry = {
                key: key,
                appName: notification.appName || "Приложение",
                appIcon: notification.appIcon || "",
                summary: notification.summary || "Уведомление",
                body: notification.body || "",
                image: notification.image || "",
                urgency: notification.urgency,
                receivedAt: Date.now(),
                read: root.isOpen
            };

            if (!notification.transient) {
                root.history = [entry].concat(root.history).slice(0, 80);
                const next = Object.assign({}, root.liveNotifications);
                next[key] = notification;
                root.liveNotifications = next;
            }

            notification.closed.connect(reason => {
                const next = Object.assign({}, root.liveNotifications);
                delete next[key];
                root.liveNotifications = next;
                if (root.currentNotification === notification)
                    root.hideCurrent();
            });

            if (root.doNotDisturb || root.isOpen)
                return;

            root.currentNotification = notification;
            if (!root.paused)
                hideTimer.restart();

            const sound = root.isTelegram(notification)
                ? Quickshell.shellDir + "/assets/telegram-message.mp3"
                : "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga";
            Quickshell.execDetached([
                "pw-play", "--volume", "0.70", "--media-role", "Notification",
                sound
            ]);
        }
    }

    Timer {
        id: hideTimer
        interval: Config.Preferences.notificationDuration
        onTriggered: root.hideCurrent()
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function clear(): void { root.clearHistory(); }
        function dnd(): void { root.toggleDoNotDisturb(); }
        function status(): bool { return root.isOpen; }
    }
}
