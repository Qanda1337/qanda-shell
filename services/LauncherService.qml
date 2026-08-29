import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property bool isOpen: false
    property string query: ""
    property int selectedIndex: 0
    property var appResults: []
    property var fileResults: []
    property var actionResults: []
    property var calculatorResults: []
    property var calculatorHistory: []
    property var commandResults: []
    readonly property bool filesOnly: query.startsWith("/")
    readonly property bool commandOnly: query.startsWith(">")
    readonly property bool calculatorExplicit: query.startsWith("=")
    readonly property bool calculatorOnly: calculatorExplicit || (!filesOnly && !commandOnly && looksLikeMath(query))
    readonly property string calculatorExpression: {
        let expression = calculatorExplicit ? query.substring(1).trim() : query.trim();
        if (expression.endsWith("="))
            expression = expression.substring(0, expression.length - 1).trim();
        return expression;
    }
    readonly property string effectiveQuery: calculatorOnly ? calculatorExpression
        : ((filesOnly || commandOnly) ? query.substring(1).trim() : query.trim())
    readonly property var results: filesOnly ? fileResults
        : (calculatorOnly ? calculatorResults
        : (commandOnly ? commandResults : actionResults.concat(appResults, fileResults)))
    readonly property var moduleActions: [
        { title: "Уведомления", subtitle: "Открыть центр уведомлений", keywords: "notifications уведомления dnd", target: "notifications" },
        { title: "Таймер", subtitle: "Запустить обратный отсчёт", keywords: "timer таймер pomodoro", target: "timer" },
        { title: "Буфер обмена", subtitle: "История буфера обмена", keywords: "clipboard буфер история", target: "clipboard" },
        { title: "Docker", subtitle: "Запущенные контейнеры", keywords: "docker containers контейнеры", target: "docker" },
        { title: "Календарь", subtitle: "Открыть календарь", keywords: "calendar календарь дата", target: "calendar" },
        { title: "Медиаплеер", subtitle: "Управление воспроизведением", keywords: "media музыка player", target: "media" },
        { title: "Погода", subtitle: "Открыть прогноз", keywords: "weather погода прогноз", target: "weather" },
        { title: "Аудиоустройства", subtitle: "Вывод и микрофон", keywords: "audio звук microphone микрофон", target: "audio" },
        { title: "Производительность", subtitle: "Мониторинг системы", keywords: "performance cpu gpu память", target: "performance" },
        { title: "Trust Wallet", subtitle: "Баланс и позиции", keywords: "wallet кошелек balance", target: "wallet" },
        { title: "Обои", subtitle: "Выбор фона", keywords: "wallpaper обои фон", target: "wallpaper" },
        { title: "Питание", subtitle: "Меню питания", keywords: "power питание reboot shutdown", target: "power" }
    ]

    function open() {
        query = "";
        selectedIndex = 0;
        isOpen = true;
        updateResults();
    }

    function close() {
        isOpen = false;
        query = "";
        selectedIndex = 0;
        appResults = [];
        fileResults = [];
        actionResults = [];
        calculatorResults = [];
        commandResults = [];
        fileDebounce.stop();
        if (fileSearch.running)
            fileSearch.running = false;
        if (calculatorProcess.running)
            calculatorProcess.running = false;
    }

    function toggle() {
        if (isOpen)
            close();
        else
            open();
    }

    function setQuery(value) {
        query = value;
        selectedIndex = 0;
        updateResults();
    }

    function currentSearchTerm() {
        return effectiveQuery;
    }

    function looksLikeMath(value) {
        let expression = String(value || "").trim();
        if (expression.endsWith("="))
            expression = expression.substring(0, expression.length - 1).trim();
        if (expression.length === 0 || !/\d/.test(expression))
            return false;

        const allowed = /^(?:\s|\d|[.,+\-*/%^()!]|sqrt|cbrt|abs|sin|cos|tan|asin|acos|atan|log|ln|exp|floor|ceil|round|pi|e)+$/i;
        const operation = /[+\-*/%^()!]/.test(expression)
            || /(?:sqrt|cbrt|abs|sin|cos|tan|asin|acos|atan|log|ln|exp|floor|ceil|round)\s*\(/i.test(expression);
        return allowed.test(expression) && operation;
    }

    function startFileSearch() {
        if (!isOpen)
            return;
        const term = currentSearchTerm();
        if (term.length < 2)
            return;
        fileSearch.requestedQuery = term;
        fileSearch.command = [
            "fd", "--ignore-case", "--hidden",
            "--exclude", ".git", "--exclude", "node_modules",
            "--exclude", ".cache", "--exclude", ".local/share",
            "--max-results", "8", "--", term,
            Quickshell.env("HOME")
        ];
        fileSearch.running = true;
    }

    function updateResults() {
        fileDebounce.stop();
        fileResults = [];
        calculatorResults = [];
        commandResults = [];
        updateApplications();
        updateActions();
        updateCommandResult();
        if (calculatorOnly) {
            appResults = [];
            actionResults = [];
            calculatorResults = calculatorHistory;
            return;
        }
        if (commandOnly) {
            appResults = [];
            actionResults = [];
            return;
        }
        if (effectiveQuery.length >= 2)
            fileDebounce.restart();
    }

    function updateActions() {
        if (filesOnly || calculatorOnly || commandOnly || effectiveQuery === "") {
            actionResults = [];
            return;
        }
        const needle = effectiveQuery.toLowerCase();
        actionResults = moduleActions.filter(action =>
            action.title.toLowerCase().includes(needle) || action.keywords.includes(needle)
        ).slice(0, 3).map(action => ({
            kind: "action",
            id: "action:" + action.target,
            title: action.title,
            subtitle: action.subtitle,
            command: ["qs", "-c", "qanda-shell", "ipc", "call", action.target, "open"],
            glyph: "\uf0e7",
            label: "ДЕЙСТВИЕ"
        }));
    }

    function updateCommandResult() {
        commandResults = commandOnly && effectiveQuery !== "" ? [{
            kind: "command",
            id: "command:" + effectiveQuery,
            title: effectiveQuery,
            subtitle: "Выполнить в терминале",
            commandText: effectiveQuery,
            glyph: "\uf120",
            label: "КОМАНДА"
        }] : [];
    }

    function scoreApp(app, needle) {
        const name = String(app.name || "").toLowerCase();
        const generic = String(app.genericName || "").toLowerCase();
        const comment = String(app.comment || "").toLowerCase();
        const command = app.command ? Array.from(app.command).join(" ").toLowerCase() : "";

        if (!needle)
            return 1;
        if (name === needle)
            return 100;
        if (name.startsWith(needle))
            return 80;
        if (name.includes(needle))
            return 60;
        if (generic.includes(needle))
            return 35;
        if (command.includes(needle))
            return 30;
        if (comment.includes(needle))
            return 20;

        let position = 0;
        for (let i = 0; i < name.length && position < needle.length; ++i) {
            if (name[i] === needle[position])
                position++;
        }
        return position === needle.length ? 12 : 0;
    }

    function updateApplications() {
        if (filesOnly || calculatorOnly || commandOnly) {
            appResults = [];
            return;
        }

        const needle = effectiveQuery.toLowerCase();
        const applications = DesktopEntries.applications?.values || [];
        const scored = [];

        for (let i = 0; i < applications.length; ++i) {
            const app = applications[i];
            if (!app || app.noDisplay || app.hidden)
                continue;
            const score = scoreApp(app, needle);
            if (score <= 0)
                continue;
            scored.push({ app: app, score: score });
        }

        scored.sort((a, b) => b.score - a.score || String(a.app.name).localeCompare(String(b.app.name)));
        appResults = scored.slice(0, needle ? 7 : 6).map(entry => ({
            kind: "app",
            id: "app:" + (entry.app.id || entry.app.name),
            title: entry.app.name || "Приложение",
            subtitle: entry.app.genericName || entry.app.comment || "Приложение",
            icon: entry.app.icon || "application-x-executable",
            source: entry.app
        }));
    }

    function selectNext() {
        if (results.length > 0)
            selectedIndex = (selectedIndex + 1) % results.length;
    }

    function selectPrevious() {
        if (results.length > 0)
            selectedIndex = (selectedIndex - 1 + results.length) % results.length;
    }

    function activate(index) {
        if (calculatorOnly) {
            if (index !== undefined) {
                const historyEntry = calculatorResults[index];
                if (historyEntry)
                    setQuery(historyEntry.expression);
            } else {
                calculate();
            }
            return;
        }

        const targetIndex = index === undefined ? selectedIndex : index;
        const result = results[targetIndex];
        if (!result)
            return;

        close();
        Qt.callLater(() => {
            if (result.kind === "app")
                result.source.execute();
            else if (result.kind === "file")
                Quickshell.execDetached(["xdg-open", result.path]);
            else if (result.kind === "action")
                Quickshell.execDetached(result.command);
            else if (result.kind === "command")
                Quickshell.execDetached(["kitty", "--hold", "/bin/sh", "-lc", result.commandText]);
        });
    }

    function calculate() {
        const expression = calculatorExpression;
        if (!calculatorOnly || expression.length === 0 || expression.length > 256 || calculatorProcess.running)
            return;
        calculatorProcess.requestedExpression = expression;
        calculatorProcess.command = [Quickshell.shellDir + "/scripts/calculate", expression];
        calculatorProcess.running = true;
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggle(); }
        function open(): void { root.open(); }
        function close(): void { root.close(); }
        function openQuery(value: string): void {
            root.open();
            root.setQuery(value);
        }
    }

    Timer {
        id: fileDebounce
        interval: 160
        onTriggered: {
            if (fileSearch.running)
                fileSearch.running = false;
            Qt.callLater(root.startFileSearch);
        }
    }

    Process {
        id: calculatorProcess
        property string requestedExpression: ""
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("Calculator failed:", exitCode, stderr.text.trim());
            const value = stdout.text.trim();
            if (exitCode !== 0 || value === "")
                return;
            const entry = {
                kind: "calculator",
                id: "calculator:" + Date.now(),
                title: value,
                subtitle: requestedExpression,
                expression: requestedExpression,
                value: value,
                glyph: "\uf1ec",
                label: "РАСЧЁТ"
            };
            root.calculatorHistory = [entry].concat(root.calculatorHistory).slice(0, 20);
            if (root.isOpen && root.calculatorOnly)
                root.calculatorResults = root.calculatorHistory;
            root.selectedIndex = 0;
        }
    }

    Process {
        id: fileSearch
        property string requestedQuery: ""
        stdout: StdioCollector {}

        onExited: exitCode => {
            if (!root.isOpen || requestedQuery !== root.currentSearchTerm())
                return;
            const home = Quickshell.env("HOME") + "/";
            const paths = stdout.text.split("\n").filter(path => path.length > 0);
            root.fileResults = paths.slice(0, 8).map(path => {
                const normalized = path.endsWith("/") ? path.substring(0, path.length - 1) : path;
                const parts = normalized.split("/");
                return {
                    kind: "file",
                    id: "file:" + normalized,
                    title: parts[parts.length - 1] || normalized,
                    subtitle: normalized.startsWith(home) ? "~/" + normalized.substring(home.length) : normalized,
                    path: normalized,
                    icon: path.endsWith("/") ? "folder" : "text-x-generic"
                };
            });
            if (root.selectedIndex >= root.results.length)
                root.selectedIndex = Math.max(0, root.results.length - 1);
        }
    }
}
