// Lien ouvert par la web app dans un nouvel onglet ou une nouvelle fenêtre ordinaire : envoyé au profil Chromium principal
// (hôte natif qs_desktop.open_link, dotfiles/webapps/open-link), puis l'onglet est fermé. Restent dans la web app : les
// fenêtres popup (connexion OAuth, window.open avec dimensions) et les liens qui ne quittent pas les domaines de l'app
// (document Word ouvert depuis Word, page Notion en nouvel onglet).
// Limite : l'onglet a déjà demandé la page quand il est fermé (un lien à usage unique est consommé par la web app).

const HOST = "qs_desktop.open_link";

// Domaines d'une même application : un lien de l'un vers l'autre reste dans la web app.
const SITES = [
    ["cloud.microsoft", "office.com", "office365.com", "microsoft365.com", "sharepoint.com", "onedrive.com", "1drv.ms",
     "live.com", "office.net", "microsoftonline.com"],
    ["notion.so", "notion.com", "notion.site"],
];

// Onglet ouvert vide (window.open puis location) : suivi le temps de recevoir son adresse, pas au-delà (sinon un lien cliqué
// plus tard dans une page écrite par l'app partirait au navigateur, onglet fermé).
const PENDING_MS = 10000;

const targets = new Map();   // nouvel onglet → promesse de son origine

function web(url) {
    return /^https?:\/\//.test(url);
}

// Groupe de domaines d'une adresse, ou null.
function sites(url) {
    let host;
    try {
        host = new URL(url).hostname;
    } catch {
        return null;
    }
    return SITES.find(group => group.some(d => host === d || host.endsWith("." + d))) ?? null;
}

// Fenêtre de l'onglet ordinaire (pas une popup), et groupe de domaines de la page qui a ouvert le lien (lue aussitôt : elle
// peut changer d'adresse ou se fermer, ex. popup de connexion).
async function origin(tabId, sourceTabId) {
    const [win, source] = await Promise.all([
        chrome.tabs.get(tabId).then(tab => chrome.windows.get(tab.windowId)).catch(() => null),
        chrome.webNavigation.getFrame({ tabId: sourceTabId, frameId: 0 }).catch(() => null),
    ]);
    return { normal: win?.type === "normal", sites: source ? sites(source.url) : null };
}

async function send(tabId, url) {
    const from = targets.get(tabId);
    targets.delete(tabId);   // avant toute attente : un seul envoi par onglet
    const { normal, sites: group } = await from;
    if (!normal || (group && group === sites(url)))
        return;
    let reply;
    try {
        reply = await chrome.runtime.sendNativeMessage(HOST, { url });
    } catch (e) {
        console.error("open-link :", e);
    }
    if (reply?.ok)   // hôte absent ou adresse refusée : le lien reste dans la web app
        chrome.tabs.remove(tabId).catch(() => {});
}

// Inscrit avant toute attente : la navigation de l'onglet peut suivre aussitôt.
chrome.webNavigation.onCreatedNavigationTarget.addListener(({ tabId, sourceTabId, url }) => {
    const from = origin(tabId, sourceTabId);
    targets.set(tabId, from);
    if (web(url))
        send(tabId, url);
    else
        setTimeout(() => targets.get(tabId) === from && targets.delete(tabId), PENDING_MS);
});

chrome.webNavigation.onBeforeNavigate.addListener(({ tabId, frameId, url }) => {
    if (frameId === 0 && targets.has(tabId) && web(url))
        send(tabId, url);
});

chrome.tabs.onRemoved.addListener(tabId => targets.delete(tabId));
