import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    readonly property var bindings: [
        { keys: "SUPER  SPACE", title: "Лаунчер", detail: "Приложения и файлы" },
        { keys: "SUPER  ESC", title: "Control Center", detail: "Настройки оболочки и системы" },
        { keys: "SUPER  END", title: "Immersive bar", detail: "Компактная панель поверх fullscreen" },
        { keys: "SUPER  F1", title: "Буфер обмена", detail: "История и поиск" },
        { keys: "SUPER  F2", title: "Подсказки", detail: "Карта биндов" },
        { keys: "SUPER  F3", title: "Docker", detail: "Запущенные контейнеры" },
        { keys: "SUPER  F4", title: "Таймер", detail: "Обратный отсчёт" },
        { keys: "SUPER  F5", title: "Уведомления", detail: "История и DND" },
        { keys: "SUPER  F7", title: "Trust Wallet", detail: "Баланс и позиции" },
        { keys: "SUPER  F8", title: "Производительность", detail: "CPU, GPU и память" },
        { keys: "SUPER  F9", title: "Аудиоустройства", detail: "Выбор выхода" },
        { keys: "SUPER  F10", title: "Медиаплеер", detail: "Трек и управление" },
        { keys: "SUPER  F11", title: "Календарь", detail: "Месяц и дата" },
        { keys: "SUPER  F12", title: "Погода", detail: "Прогноз" },
        { keys: "SUPER  M", title: "Питание", detail: "Сон, выход, reboot" },
        { keys: "SUPER  W", title: "Обои", detail: "Карусель фонов" },
        { keys: "SUPER  SHIFT  R", title: "Перезапуск", detail: "Перезагрузить оболочку" }
    ]

    function open() { isOpen = true; }
    function close() { isOpen = false; }
    function toggle() { isOpen ? close() : open(); }

    IpcHandler {
        target: "bindings"
        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function status(): bool { return root.isOpen; }
    }
}
