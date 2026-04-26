"use strict";

const pageTitleElement = document.getElementById("page-title");
const refreshListButton = document.getElementById("refresh-list");
const toggleIframeButton = document.getElementById("toggle-iframe");
const llmOpenLinkElement = document.getElementById("llm-open-link");
const statusElement = document.getElementById("status");
const linksList = document.getElementById("links");
const llmIframeElement = document.getElementById("llm-embed");

const staticPages = [
    { fileName: "ai_llama.htm", title: "Local LLM Setup (llama.cpp + uv)" },
    { fileName: "lego.htm", title: "Lego" },
    { fileName: "osel.htm", title: "loki vyvod main" },
    { fileName: "putter.htm", title: "putter" }
];

function setStatus(message) {
    statusElement.textContent = message;
}

function clearLinks() {
    linksList.innerHTML = "";
}

async function fetchPublicIp() {
    try {
        const response = await fetch("https://api.ipify.org?format=json", { cache: "no-store" });
        if (!response.ok) {
            return "unavailable";
        }

        const payload = await response.json();
        return payload.ip || "unavailable";
    } catch {
        return "unavailable";
    }
}

async function updatePageTitle() {
    const localIp = window.location.hostname || "localhost";
    const publicIp = await fetchPublicIp();
    pageTitleElement.textContent = `llm129 home — local: ${localIp} | public: ${publicIp}`;
}

function renderLinks(pageItems) {
    clearLinks();

    for (const item of pageItems) {
        const listItem = document.createElement("li");
        const link = document.createElement("a");

        link.href = item.fileName;
        link.target = "_blank";
        link.rel = "noopener noreferrer";
        link.textContent = `${item.fileName} — ${item.title}`;

        listItem.appendChild(link);
        linksList.appendChild(listItem);
    }
}

function refreshRemoteList() {
    renderLinks(staticPages);
    setStatus(`Loaded ${staticPages.length} known page(s).`);
}

function getLlmUrl() {
    const isLocalPreview =
        window.location.hostname === "127.0.0.1" ||
        window.location.hostname === "localhost";

    if (isLocalPreview) {
        // When previewing via VS Code Live Server, point to the real internet endpoint.
        return "https://llm129.duckdns.org/llama/";
    }

    // On production host keep same-origin routing through nginx.
    return "/llama/";
}

function applyLlmTargets() {
    const llmUrl = getLlmUrl();
    llmOpenLinkElement.href = llmUrl;
    llmIframeElement.src = llmUrl;
}

function toggleIframeVisibility() {
    const isHidden = llmIframeElement.classList.contains("hidden");
    llmIframeElement.classList.toggle("hidden", !isHidden);
    toggleIframeButton.textContent = isHidden ? "Hide embedded LLM" : "Show embedded LLM";
}

refreshListButton.addEventListener("click", refreshRemoteList);
toggleIframeButton.addEventListener("click", toggleIframeVisibility);

// Auto-load on page open.
applyLlmTargets();
updatePageTitle();
refreshRemoteList();
