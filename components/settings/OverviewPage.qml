import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Quickshell
import Quickshell.Io
import ".."

Item {
    id: overviewRoot

    property string cpuName: ""
    property int cpuCores: 0
    property string gpuName: ""
    property string gpuVram: ""
    property string ramTotal: ""

    readonly property string na: "Недоступно"

    function nz(v) { return (v === undefined || v === null || String(v).trim() === "") ? na : String(v).trim() }

    Process { id: cpuProc; command: ["sh","-c","LC_ALL=C lscpu"]; stdout: StdioCollector { onStreamFinished: {
        var lines=text.split("\n");
        var sockets=1, coresPerSocket=0;
        for(var i=0;i<lines.length;i++){var l=lines[i];
        if(l.indexOf("Model name")===0){var a=l.split(":"); if(a.length>1) overviewRoot.cpuName=a.slice(1).join(":").trim()}
        else if(l.indexOf("Socket(s):")===0){var s=parseInt(l.split(":")[1]); if(!isNaN(s)&&s>0) sockets=s}
        else if(l.indexOf("Core(s) per socket:")===0){var c=parseInt(l.split(":")[1]); if(!isNaN(c)&&c>0) coresPerSocket=c}
        }
        if(coresPerSocket>0) overviewRoot.cpuCores=sockets*coresPerSocket;
        else {
            // fallback
            for(var j=0;j<lines.length;j++){ if(lines[j].indexOf("CPU(s):")===0){ var n=parseInt(lines[j].split(":")[1]); if(!isNaN(n)&&n>0) overviewRoot.cpuCores=n; break } }
        }
        if(!overviewRoot.cpuName) overviewRoot.cpuName=""
    } } }

    Process { id: gpuProc; command: ["sh","-c","if command -v nvidia-smi >/dev/null 2>&1; then nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n1; else lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -n1 | sed 's/.*: //'; fi"]; stdout: StdioCollector { onStreamFinished: {
        var l=text.trim(); if(!l){overviewRoot.gpuName="";overviewRoot.gpuVram="";return}
        if(l.indexOf(",")>=0){var p=l.split(",").map(function(x){return x.trim()}); overviewRoot.gpuName=p[0]; overviewRoot.gpuVram=p[1]+" MB"}
        else { overviewRoot.gpuName=l; overviewRoot.gpuVram=na }
    } } }

    Process { id: ramProc; command: ["sh","-c","grep -E '^MemTotal:' /proc/meminfo"]; stdout: StdioCollector { onStreamFinished: {
        var m=text.match(/MemTotal:\s+(\d+)/); if(m){ overviewRoot.ramTotal=(parseInt(m[1])/1048576).toFixed(1)+" GB" }
    } } }

    Component.onCompleted: { cpuProc.running=true; gpuProc.running=true; ramProc.running=true }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Text { text: "Огляд"; color: Theme.text; font.pixelSize: 22; font.bold: true; font.family: Theme.fontMono }
        Text { text: "Характеристики обладнання"; color: Theme.textSub; font.pixelSize: 12 }

        // CPU + GPU: дві рівні колонки на широких вікнах, одна — на вузьких
        GridLayout {
            Layout.fillWidth: true
            columns: overviewRoot.width >= 760 ? 2 : 1
            columnSpacing: 16
            rowSpacing: 16

            // CPU
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: cpuCol.implicitHeight+28; radius: Theme.radiusMd; color: Theme.glassCard; border.color: Theme.glassBorder; border.width: 1
                ColumnLayout { id: cpuCol; anchors.fill: parent; anchors.margins: 16; spacing: 6
                    Text { text: "ПРОЦЕСОР"; color: Theme.textMuted; font.pixelSize: 11; font.bold: true; font.family: Theme.fontMono }
                    Text { text: "Модель: " + nz(overviewRoot.cpuName); color: Theme.textSub; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WrapAtWordBoundaryOrAnywhere }
                    Text { text: "Ядра: " + (overviewRoot.cpuCores>0?overviewRoot.cpuCores:na); color: Theme.textSub; font.pixelSize: 12 }
                }
            }

            // GPU
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: gpuCol.implicitHeight+28; radius: Theme.radiusMd; color: Theme.glassCard; border.color: Theme.glassBorder; border.width: 1
                ColumnLayout { id: gpuCol; anchors.fill: parent; anchors.margins: 16; spacing: 6
                    Text { text: "ВІДЕОКАРТА"; color: Theme.textMuted; font.pixelSize: 11; font.bold: true; font.family: Theme.fontMono }
                    Text { text: "Назва: " + nz(overviewRoot.gpuName); color: Theme.textSub; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WrapAtWordBoundaryOrAnywhere }
                    Text { text: "VRAM: " + nz(overviewRoot.gpuVram); color: Theme.textSub; font.pixelSize: 12 }
                }
            }
        }

        // RAM
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: ramCol.implicitHeight+28; radius: Theme.radiusMd; color: Theme.glassCard; border.color: Theme.glassBorder; border.width: 1
            ColumnLayout { id: ramCol; anchors.fill: parent; anchors.margins: 16; spacing: 6
                Text { text: "ОПЕРАТИВНА ПАМ'ЯТЬ"; color: Theme.textMuted; font.pixelSize: 11; font.bold: true; font.family: Theme.fontMono }
                Text { text: "Загальний об'єм: " + nz(overviewRoot.ramTotal); color: Theme.textSub; font.pixelSize: 12 }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
