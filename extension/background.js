let port = null;

browser.runtime.onMessage.addListener(message => {
    if (port == null || port.error) {
        port = browser.runtime.connectNative('cheetah');
    }
    try {
        port.postMessage(message);
    } catch (error) {
        port = null;
    }
});
