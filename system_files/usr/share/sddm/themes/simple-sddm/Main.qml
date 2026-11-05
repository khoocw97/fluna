import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: Screen.width
    height: Screen.height
    focus: true
    color: cfgBackground.startsWith("#") ? cfgBackground : "#000000"

    TextConstants { id: textConstants }

    // ============================================================
    //  config helpers
    // ============================================================
    function cfgBool(v, d) { return v === undefined || v === null || v === "" ? d : (typeof v === "boolean" ? v : String(v).toLowerCase() === "true") }
    function keyFromName(name, def) {
        if (!name) return def
        var s = String(name).toUpperCase().trim()
        var m = /^F(\d{1,2})$/.exec(s)
        if (m) { var n = parseInt(m[1]); if (n >= 1 && n <= 35) return Qt.Key_F1 + (n - 1) }
        return s.length === 1 ? s.charCodeAt(0) : def
    }

    property string cfgBackground: config.background || "#000000"

    property bool   cfgShowDate:     cfgBool(config.showDate, true)
    property string cfgDateFormat:   config.dateFormat || "ddd MMM dd yyyy"
    property bool   cfgShowClock:    cfgBool(config.showClock, true)
    property bool   cfgClock12hr:    cfgBool(config.clock12hr, true)
    property bool   cfgClockSeconds: cfgBool(config.clockSeconds, true)
    property string clockFmt: (cfgClock12hr ? "hh" : "HH") + ":mm"
                            + (cfgClockSeconds ? ":ss" : "")
                            + (cfgClock12hr ? " AP" : "")

    property bool   cfgShowShutdown:   cfgBool(config.showShutdownKey, true)
    property string cfgShutdownKey:    config.shutdownKey || "F1"
    property bool   cfgShowReboot:     cfgBool(config.showRebootKey, true)
    property string cfgRebootKey:      config.rebootKey || "F2"
    property bool   cfgShowPassToggle: cfgBool(config.showPasswordToggleKey, true)
    property string cfgPassToggleKey:  config.passwordToggleKey || "F7"

    property int keyShutdown:   keyFromName(cfgShutdownKey,   Qt.Key_F1)
    property int keyReboot:     keyFromName(cfgRebootKey,     Qt.Key_F2)
    property int keyPassToggle: keyFromName(cfgPassToggleKey, Qt.Key_F7)

    property string cfgFontFamily:  config.fontFamily || "Monospace"
    property int    cfgFontSize:    parseInt(config.fontSize) || 15
    property int    cfgBoxFontSize: parseInt(config.boxFontSize || config.fontSize) || 20
    property int    cfgInputLen:    parseInt(config.inputLen) || 20
    property string cfgAsterisk:    config.asterisk !== undefined ? config.asterisk : ""

    property bool   cfgHideBorders:         cfgBool(config.hideBorders, false)
    property bool   cfgBoxBackground:       cfgBool(config.boxBackground, true)
    property string cfgBoxBackgroundColor:  config.boxBackgroundColor || "#000000"

    property string cfgDefaultInput: (config.defaultInput || "user").toLowerCase()

    property int topMonoSize:     cfgFontSize
    property int boxMonoSize:     cfgBoxFontSize
    property int labelWidthChars: 8
    property int charW: Math.round(boxMonoSize * 0.62)

    // theme.conf primaryScreen (case-sensitive):
    property string cfgScreenTarget: String(config.primaryScreen || "").trim()
    property bool _isPrimaryRaw: {
        if (typeof primaryScreen !== "undefined") return primaryScreen
        try {
            if (typeof screenModel !== "undefined" && screenModel && screenModel.primary !== undefined)
                return screenModel.primary === 0
        } catch (e) {}
        return true
    }
    property string _screenName: {
        try {
            if (typeof Screen !== "undefined" && Screen.name && String(Screen.name).length > 0)
                return String(Screen.name).trim()
        } catch (e) {}
        try {
            if (typeof screenModel !== "undefined" && screenModel && screenModel.count > 0) {
                var v = screenModel.data(screenModel.index(0, 0), 257)
                if (v !== undefined && v !== null && String(v).trim() !== "") return String(v).trim()
            }
        } catch (e2) {}
        return ""
    }
    property bool _screenTargetExists: {
        if (cfgScreenTarget === "") return true
        try {
            var arr = Qt.application.screens
            if (arr && arr.length !== undefined) {
                for (var i = 0; i < arr.length; i++) {
                    try { if (String(arr[i].name).trim() === cfgScreenTarget) return true } catch (e) {}
                }
                return false
            }
        } catch (e2) {}
        if (_screenName !== "" && _screenName === cfgScreenTarget) return true
        if (_screenName === "") return true
        return false
    }
    property bool _screenNameMatches: {
        if (cfgScreenTarget === "") return true
        if (_screenName === "") return true
        return _screenName === cfgScreenTarget
    }
    property bool isActive: cfgScreenTarget === "" ? true
                           : (_screenTargetExists ? _screenNameMatches : _isPrimaryRaw)

    // ============================================================
    //  status
    // ============================================================
    property string errorText: ""
    property bool   showPassword: false
    property int    activeRow: cfgDefaultInput === "session" ? 0
                             : cfgDefaultInput === "password" ? 2
                             : 1
    property int currentUserIndex:    userModel    ? userModel.lastIndex    : 0
    property int currentSessionIndex: sessionModel ? sessionModel.lastIndex : 0

    // ============================================================
    //  Model
    // ============================================================
    // Hidden stash to read model roles without hard-coding integers
    // Upstream-approved: sessionModel.data() is not Q_INVOKABLE, use Repeater delegate model.name
    // see https://github.com/akitaonrails/NW-Omarchy/blob/master/default/sddm-theme/Main.qml
    // and https://github.com/cutefishos/sddm-theme/blob/main/SessionMenu.qml (text: model.name)
    // and official sddm src/greeter/theme/Main.qml uses ComboBox { model: sessionModel } + delegate model.name
    Item {
        id: sessionStash
        visible: false
        Repeater {
            id: sessionRepeater
            model: sessionModel
            delegate: Item { property string sessName: (model.name || "").toString() }
        }
    }
    Item {
        id: userStash
        visible: false
        Repeater {
            id: userRepeater
            model: userModel
            delegate: Item { property string usrName: (model.name || "").toString() }
        }
    }

    function _getModelName(m,i){
        if(!m||!m.count) return "";
        if(i<0||i>=m.count) i=0;
        try{
            var v=m.data(m.index(i,0));
            if(v===undefined||v===null) throw "empty";
            if(typeof v==="string") return v;
            if(v.name) return v.name;
            if(v.display) return v.display;
            if(v.text) return v.text;
            return String(v);
        }catch(e){
            try{ var v2=m.data(m.index(i,0),257); if(v2) return String(v2); }catch(e2){}
            try{ var v3=m.data(m.index(i,0),0); if(v3) return String(v3); }catch(e3){}
            return "";
        }
    }
    function userName() {
        if (userModel && userRepeater.count > 0) {
            var it = userRepeater.itemAt(currentUserIndex);
            if (it && it.usrName) return it.usrName;
        }
        return _getModelName(userModel, currentUserIndex)
    }
    function sessionName() {
        if (sessionModel && sessionRepeater.count > 0) {
            var it = sessionRepeater.itemAt(currentSessionIndex);
            if (it && it.sessName) return it.sessName;
        }
        // fallback for early startup (repeater not yet populated): try session-specific roles directly
        if (sessionModel && sessionModel.count) {
            try { var v2 = sessionModel.data(sessionModel.index(currentSessionIndex,0), 260); if (v2 !== undefined && v2 !== null && String(v2).trim() !== "") return String(v2); } catch(e2) {}
            try { var v3 = sessionModel.data(sessionModel.index(currentSessionIndex,0), 258); if (v3 !== undefined && v3 !== null && String(v3).trim() !== "") { var f = String(v3); return f.replace(/\.desktop$/i,""); } } catch(e3) {}
        }
        return _getModelName(sessionModel, currentSessionIndex)
    }

    function doLogin(){ errorText=""; var u=userName(); if(!u){errorText="no user";return} sddm.login(u,passwordField.text,currentSessionIndex) }

    // ============================================================
    //  background
    // ============================================================
    Image {
        id: bgImage
        anchors.fill: parent
        visible: !cfgBackground.startsWith("#") && cfgBackground !== "" && status !== Image.Error
        source: {
            if (cfgBackground.startsWith("#") || cfgBackground === "") return ""
            if (cfgBackground.startsWith("/")) return "file://" + cfgBackground
            return cfgBackground
        }
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
    }

    // ============================================================
    //  top bar
    // ============================================================
    Item {
        id: topBar
        visible: isActive
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        height: 18

        Row {
            id: topLeft
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            Text { visible: cfgShowShutdown;   text: cfgShutdownKey   + " shutdown";        color: "white"; font.family: cfgFontFamily; font.pixelSize: topMonoSize + 1 }
            Text { visible: cfgShowReboot;     text: cfgRebootKey     + " reboot";          color: "white"; font.family: cfgFontFamily; font.pixelSize: topMonoSize + 1 }
            Text { visible: cfgShowPassToggle; text: cfgPassToggleKey + " toggle password"; color: "white"; font.family: cfgFontFamily; font.pixelSize: topMonoSize + 1 }
        }

        Row {
            id: topRight
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Text {
                id: dateText
                visible: cfgShowDate
                color: "white"
                font.family: cfgFontFamily
                font.pixelSize: topMonoSize + 1
                text: Qt.formatDateTime(new Date(), cfgDateFormat)
            }
            Text {
                id: clockText
                visible: cfgShowClock
                color: "white"
                font.family: cfgFontFamily
                font.pixelSize: topMonoSize + 1
                text: Qt.formatDateTime(new Date(), clockFmt)
            }
            Text { visible: !!sddm.capsLock; text: "capslock"; color: "white"; font.family: cfgFontFamily; font.pixelSize: topMonoSize + 1 }
            Text { visible: !!sddm.numLock;  text: "numlock";  color: "white"; font.family: cfgFontFamily; font.pixelSize: topMonoSize + 1 }
        }
    }

    // clock refresh
    Timer {
        id: clockTimer
        interval: cfgClockSeconds ? 1000 : 60000
        running: (cfgShowDate || cfgShowClock) && isActive
        repeat: true
        onTriggered: { var n=new Date(); if(cfgShowDate) dateText.text=Qt.formatDateTime(n,cfgDateFormat); if(cfgShowClock) clockText.text=Qt.formatDateTime(n,clockFmt) }
    }

    // ============================================================
    //  box
    // ============================================================
    Rectangle {
        id: box
        visible: isActive
        width: Math.min((labelWidthChars + cfgInputLen) * charW + 60, root.width - 40)
        height: boxCol.implicitHeight + 60
        anchors.centerIn: parent
        color: cfgBoxBackground ? cfgBoxBackgroundColor : "transparent"
        border.color: cfgHideBorders ? "transparent" : "white"
        border.width: 2

        ColumnLayout {
            id: boxCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 8

            // ---- error msg----
            Item {
                id: infoRow
                Layout.fillWidth: true
                Layout.preferredHeight: errorText !== "" ? boxMonoSize + 8 : 0
                visible: errorText !== ""

                Text { text: "<"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.left: parent.left;  anchors.verticalCenter: parent.verticalCenter }
                Text { text: ">"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }

                Text {
                    id: infoText
                    anchors.centerIn: parent
                    width: parent.width - 24
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    color: "#ff4444"
                    font.family: cfgFontFamily
                    font.pixelSize: boxMonoSize + 1
                    text: errorText
                }
            }

            // ---- session ----
            Row {
                id: sessionRow
                Layout.fillWidth: true
                Layout.preferredHeight: boxMonoSize + 10
                spacing: charW + 8

                Text {
                    width: labelWidthChars * charW
                    text: "session"
                    color: "white"
                    font.family: cfgFontFamily
                    font.pixelSize: boxMonoSize + 1
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: parent.width - labelWidthChars * charW - charW - 8
                    height: boxMonoSize + 10
                    color: "transparent"

                    Text { id: sessionLBracket; text: "<"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "*"; visible: activeRow === 0; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.right: sessionLBracket.left; anchors.rightMargin: 2; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: sessionRBracket; text: ">"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "*"; visible: activeRow === 0; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.left: sessionRBracket.right; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter }

                    Rectangle {
                        anchors.centerIn: parent
                        width: cfgInputLen * charW
                        height: parent.height - 4
                        color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: "white"
                            font.family: cfgFontFamily
                            font.pixelSize: boxMonoSize + 1
                            text: sessionName()
                        }
                    }
                }
            }

            // ---- user ----
            Row {
                id: loginRow
                Layout.fillWidth: true
                Layout.preferredHeight: boxMonoSize + 10
                spacing: charW + 8

                Text {
                    width: labelWidthChars * charW
                    text: "user"
                    color: "white"
                    font.family: cfgFontFamily
                    font.pixelSize: boxMonoSize + 1
                }

                Rectangle {
                    width: parent.width - labelWidthChars * charW - charW - 8
                    height: boxMonoSize + 10
                    color: "transparent"

                    Text { id: userLBracket; text: "<"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "*"; visible: activeRow === 1; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.right: userLBracket.left; anchors.rightMargin: 2; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: userRBracket; text: ">"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "*"; visible: activeRow === 1; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.left: userRBracket.right; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter }

                    Rectangle {
                        anchors.centerIn: parent
                        width: cfgInputLen * charW
                        height: parent.height - 4
                        color: "transparent"
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - 4
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            color: "white"
                            font.family: cfgFontFamily
                            font.pixelSize: boxMonoSize + 1
                            text: userName()
                        }
                    }
                }
            }

            // ---- password  ----
            Row {
                id: passRow
                Layout.fillWidth: true
                Layout.preferredHeight: boxMonoSize + 10
                spacing: charW + 8

                Text {
                    width: labelWidthChars * charW
                    text: "password"
                    color: "white"
                    font.family: cfgFontFamily
                    font.pixelSize: boxMonoSize + 1
                }

                Rectangle {
                    width: parent.width - labelWidthChars * charW - charW - 8
                    height: boxMonoSize + 10
                    color: "transparent"
                    border.color: "transparent"

                    Text { id: passLBracket; text: "<"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.left: parent.left; anchors.leftMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "*"; visible: activeRow === 2; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.right: passLBracket.left; anchors.rightMargin: 2; anchors.verticalCenter: parent.verticalCenter }
                    Text { id: passRBracket; text: ">"; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "*"; visible: activeRow === 2; color: "white"; font.family: cfgFontFamily; font.pixelSize: boxMonoSize + 1; anchors.left: passRBracket.right; anchors.leftMargin: 2; anchors.verticalCenter: parent.verticalCenter }

                    Rectangle {
                        anchors.centerIn: parent
                        width: cfgInputLen * charW
                        height: parent.height - 4
                        color: "transparent"

                        TextInput {
                            id: passwordField
                            anchors.centerIn: parent
                            width: parent.width - 4
                            height: parent.height
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: TextInput.AlignHCenter
                            color: "white"
                            selectionColor: "#7aa2f7"
                            font.family: cfgFontFamily
                            font.pixelSize: boxMonoSize + 1
                            // Linux-style: NoEcho shows nothing (not even length);
                            // set asterisk=# (etc.) for per-character echo instead
                            echoMode: showPassword ? TextInput.Normal : (cfgAsterisk !== "" ? TextInput.Password : TextInput.NoEcho)
                            passwordCharacter: cfgAsterisk
                            focus: activeRow === 2 && isActive
                            activeFocusOnTab: false
                            onAccepted: root.doLogin()
                            cursorVisible: false
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    //  keyboard
    // ============================================================
    Keys.onPressed: (event) => {
        if (!isActive) return
        // function key
        if (event.key === root.keyShutdown && sddm.canPowerOff) { sddm.powerOff();    event.accepted = true; return }
        if (event.key === root.keyReboot && sddm.canReboot) { sddm.reboot();      event.accepted = true; return }
        if (event.key === root.keyPassToggle) { showPassword=!showPassword; event.accepted = true; return }

        // up/down ctrl+j/k activeRow
        if (event.key === Qt.Key_Up   || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier)) {
            activeRow=(activeRow+2)%3; if(activeRow===2) passwordField.forceActiveFocus(); else root.forceActiveFocus(); event.accepted = true; return
        }
        if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier)) {
            activeRow=(activeRow+1)%3; if(activeRow===2) passwordField.forceActiveFocus(); else root.forceActiveFocus(); event.accepted = true; return
        }

        // left/right ctrl+h/l switch
        if (event.key === Qt.Key_Left  || (event.key === Qt.Key_H && event.modifiers & Qt.ControlModifier)) {
            if(activeRow===0&&sessionModel&&sessionModel.count) currentSessionIndex=(currentSessionIndex-1+sessionModel.count)%sessionModel.count; else if(activeRow===1&&userModel&&userModel.count) currentUserIndex=(currentUserIndex-1+userModel.count)%userModel.count
            event.accepted = true; return
        }
        if (event.key === Qt.Key_Right || (event.key === Qt.Key_L && event.modifiers & Qt.ControlModifier)) {
            if(activeRow===0&&sessionModel&&sessionModel.count) currentSessionIndex=(currentSessionIndex+1)%sessionModel.count; else if(activeRow===1&&userModel&&userModel.count) currentUserIndex=(currentUserIndex+1)%userModel.count
            event.accepted = true; return
        }

        // tab/shift+tab active row
        if (event.key === Qt.Key_Tab) {
            activeRow=(activeRow + ((event.modifiers & Qt.ShiftModifier)?2:1))%3; if(activeRow===2) passwordField.forceActiveFocus(); else root.forceActiveFocus()
            event.accepted = true; return
        }

        // enter login
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.doLogin(); event.accepted = true; return
        }
    }

    // ============================================================
    //  SDDM 回调
    // ============================================================
    Connections {
        target: sddm
        function onLoginSucceeded() { errorText = "" }
        function onLoginFailed() {
            errorText = textConstants.loginFailed || "login failed"
            passwordField.clear()
            if (isActive) { activeRow=2; passwordField.forceActiveFocus() }
        }
        function onInformationMessage(msg) { errorText = msg }
    }

    // ============================================================
    //  初始化
    // ============================================================
    Component.onCompleted: { if (!isActive) return; if(activeRow===2) passwordField.forceActiveFocus(); else root.forceActiveFocus() }
}
