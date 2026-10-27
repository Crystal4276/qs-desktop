// Lien ouvert par la web app dans un nouvel onglet ou une nouvelle fenêtre ordinaire : envoyé au profil Chromium principal
// (hôte natif qs_desktop.open_link, dotfiles/webapps/open-link), puis l'onglet est fermé. Les fenêtres popup (connexion OAuth,
// window.open avec dimensions) restent dans la web app.

const HOST = "qs_desktop.open_link";
const targets = new Map();   // nouvel onglet → promesse « fenêtre ordinaire ? » (window.open puis location : about:blank d'abord)

function web(url) {
    return /^https?:/.test(url);
}

async function normal(tabId) {
    const tab = await chrome.tabs.get(tabId).catch(() => null);
    const win = tab && await chrome.windows.get(tab.windowId).catch(() => null);
    return win?.type === "normal";
}

async function send(tabId, url) {
    const isNormal = targets.get(tabId);
    targets.delete(tabId);   // avant toute attente : un seul envoi par onglet
    if (!await isNormal)
        return;
    try {
        await chrome.runtime.sendNativeMessage(HOST, { url });
    } catch (e) {
        console.error("open-link :", e);
        return;   // hôte absent : le lien reste dans la web app
    }
    chrome.tabs.remove(tabId).catch(() => {});
}

// Inscrit avant toute attente : la navigation de l'onglet peut suivre aussitôt.
chrome.webNavigation.onCreatedNavigationTarget.addListener(({ tabId, url }) => {
    targets.set(tabId, normal(tabId));
    if (web(url))
        send(tabId, url);
});

chrome.webNavigation.onBeforeNavigate.addListener(({ tabId, frameId, url }) => {
    if (frameId === 0 && targets.has(tabId) && web(url))
        send(tabId, url);
});

chrome.tabs.onRemoved.addListener(tabId => targets.delete(tabId));
