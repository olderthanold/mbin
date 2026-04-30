"use strict";

const pageTitleElement = document.getElementById("page-title");
const refreshListButton = document.getElementById("refresh-list");
const localBasePathInput = document.getElementById("local-base-path");
const toggleIframeButton = document.getElementById("toggle-iframe");
const llmOpenLinkElement = document.getElementById("llm-open-link");
const statusElement = document.getElementById("status");
const linksList = document.getElementById("links");
const llmIframeElement = document.getElementById("llm-embed");

const staticPages = [
    { fileName: "ai_llama.htm", title: "Local LLM Setup (llama.cpp + uv)" },
    { fileName: "lego.htm", title: "Lego" },
    { fileName: "modely.htm", title: "LLM modely" },
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
    const currentTitle = pageTitleElement.textContent.trim();
    if (currentTitle && currentTitle !== "llm129 home") {
        return;
    }

    const localIp = window.location.hostname || "localhost";
    const publicIp = await fetchPublicIp();
    pageTitleElement.textContent = `llm129 home - local: ${localIp} | public: ${publicIp}`;
}

function normalizeBasePath(pathValue) {
    let basePath = (pathValue || "/").trim();

    if (basePath === "") {
        basePath = "/";
    }

    if (!basePath.startsWith("/")) {
        basePath = `/${basePath}`;
    }

    if (!basePath.endsWith("/")) {
        basePath = `${basePath}/`;
    }

    return basePath;
}

function getLocalPageHref(fileName) {
    return `${normalizeBasePath(localBasePathInput.value)}${fileName}`.replace(/\/{2,}/g, "/");
}

function renderLinks(pageItems) {
    clearLinks();

    for (const item of pageItems) {
        const listItem = document.createElement("li");
        const link = document.createElement("a");

        link.href = getLocalPageHref(item.fileName);
        link.textContent = `${item.fileName} - ${item.title}`;

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
        // When previewing locally, point to the real internet endpoint.
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
localBasePathInput.addEventListener("change", refreshRemoteList);
toggleIframeButton.addEventListener("click", toggleIframeVisibility);

// Auto-load on page open.
applyLlmTargets();
updatePageTitle();
refreshRemoteList();
