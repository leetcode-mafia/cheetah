let updateFrequency = 1000;

function update() {
    let editor = window.wrappedJSObject.editor;
    if (!editor) {
        return;
    }

    let modeId = document.querySelector('.react-monaco-editor-react')?.dataset.modeId;
    let fileUri = document.querySelector('.monaco-editor[role="code"]')?.dataset.uri;
    let terminal = document.querySelector('.terminal .xterm-accessibility')?.innerText.trim();
    
    let message = {
        mode: modeId,
        files: { [fileUri]: editor.getValue() },
        logs: { terminal }
    };

    message.navigationStart = performance.timing.navigationStart;
    browser.runtime.sendMessage(message);
}

setInterval(update, updateFrequency);
