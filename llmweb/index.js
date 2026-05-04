"use strict";

const pageTitleElement = document.getElementById("page-title");
const refreshListButton = document.getElementById("refresh-list");
const toggleIframeButton = document.getElementById("toggle-iframe");
const llmOpenLinkElement = document.getElementById("llm-open-link");
const statusElement = document.getElementById("status");
const linksList = document.getElementById("links");
const llmIframeElement = document.getElementById("llm-embed");
const breadcrumbElement = document.getElementById("breadcrumb");

const pagesApiBase = "/_pages/";
let currentDirectory = "";

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

function normalizeDirectoryPath(pathValue) {
    return (pathValue || "")
        .split("/")
        .filter(Boolean)
        .map((segment) => {
            try {
                return decodeURIComponent(segment);
            } catch {
                return segment;
            }
        })
        .join("/");
}

function pathSegments(pathValue) {
    return normalizeDirectoryPath(pathValue).split("/").filter(Boolean);
}

function encodePath(pathValue) {
    const segments = pathSegments(pathValue).map((segment) => encodeURIComponent(segment));
    return segments.length ? `${segments.join("/")}/` : "";
}

function displayPath(pathValue) {
    const normalizedPath = normalizeDirectoryPath(pathValue);
    return normalizedPath ? `/${normalizedPath}/` : "/";
}

function listingUrl(pathValue) {
    return `${pagesApiBase}${encodePath(pathValue)}`;
}

function publicHref(pathValue, name) {
    return `/${encodePath(pathValue)}${encodeURIComponent(name)}`.replace(/\/{2,}/g, "/");
}

function parentPath(pathValue) {
    const segments = pathSegments(pathValue);
    segments.pop();
    return segments.join("/");
}

function isHtmlFile(entry) {
    return entry.type === "file" && /\.html?$/i.test(entry.name || "");
}

function isDirectory(entry) {
    return entry.type === "directory";
}

function isHiddenDirectory(entry) {
    return isDirectory(entry) && String(entry.name || "").startsWith("_");
}

function formatSize(size) {
    if (typeof size !== "number") {
        return "";
    }

    if (size < 1024) {
        return `${size} B`;
    }

    if (size < 1024 * 1024) {
        return `${Math.round(size / 1024)} KB`;
    }

    return `${(size / 1024 / 1024).toFixed(1)} MB`;
}

function formatMtime(value) {
    if (!value) {
        return "";
    }

    const date = new Date(value);
    if (Number.isNaN(date.getTime())) {
        return value;
    }

    return date.toLocaleString();
}

function renderBreadcrumb(pathValue) {
    const segments = pathSegments(pathValue);
    breadcrumbElement.innerHTML = "";

    const rootButton = document.createElement("button");
    rootButton.type = "button";
    rootButton.textContent = "root";
    rootButton.addEventListener("click", () => loadDirectory(""));
    breadcrumbElement.appendChild(rootButton);

    let accumulatedPath = "";
    for (const segment of segments) {
        breadcrumbElement.appendChild(document.createTextNode(" "));
        breadcrumbElement.appendChild(document.createTextNode("/"));
        breadcrumbElement.appendChild(document.createTextNode(" "));

        accumulatedPath = accumulatedPath ? `${accumulatedPath}/${segment}` : segment;
        const segmentPath = accumulatedPath;
        const segmentButton = document.createElement("button");
        segmentButton.type = "button";
        segmentButton.textContent = segment;
        segmentButton.addEventListener("click", () => loadDirectory(segmentPath));
        breadcrumbElement.appendChild(segmentButton);
    }
}

function renderLinks(pageItems, pathValue) {
    clearLinks();

    if (pathSegments(pathValue).length > 0) {
        const listItem = document.createElement("li");
        const link = document.createElement("a");

        link.href = "#";
        link.textContent = "../";
        link.addEventListener("click", (event) => {
            event.preventDefault();
            loadDirectory(parentPath(pathValue));
        });

        listItem.appendChild(link);
        linksList.appendChild(listItem);
    }

    for (const item of pageItems) {
        const listItem = document.createElement("li");
        const link = document.createElement("a");
        const meta = document.createElement("span");

        if (isDirectory(item)) {
            const childPath = normalizeDirectoryPath(`${pathValue}/${item.name}`);
            link.href = "#";
            link.textContent = `${item.name}/`;
            link.addEventListener("click", (event) => {
                event.preventDefault();
                loadDirectory(childPath);
            });
        } else {
            link.href = publicHref(pathValue, item.name);
            link.textContent = item.name;
        }

        meta.className = "entry-meta";
        meta.textContent = [item.type, formatSize(item.size), formatMtime(item.mtime)]
            .filter(Boolean)
            .join(" | ");

        listItem.appendChild(link);
        if (meta.textContent) {
            listItem.appendChild(meta);
        }
        linksList.appendChild(listItem);
    }
}

function sortEntries(entries) {
    return entries.sort((left, right) => {
        if (left.type !== right.type) {
            return left.type === "directory" ? -1 : 1;
        }

        return String(left.name || "").localeCompare(String(right.name || ""), undefined, {
            sensitivity: "base"
        });
    });
}

async function loadDirectory(pathValue = currentDirectory) {
    currentDirectory = normalizeDirectoryPath(pathValue);
    const currentPath = displayPath(currentDirectory);

    setStatus(`Loading ${currentPath}...`);
    renderBreadcrumb(currentDirectory);

    try {
        const response = await fetch(listingUrl(currentDirectory), { cache: "no-store" });
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}`);
        }

        const entries = await response.json();
        const visibleEntries = sortEntries(
            entries.filter((entry) => !isHiddenDirectory(entry) && (isDirectory(entry) || isHtmlFile(entry)))
        );

        renderLinks(visibleEntries, currentDirectory);
        setStatus(`Loaded ${visibleEntries.length} item(s) from ${currentPath}.`);
    } catch (error) {
        clearLinks();
        setStatus(`Cannot load ${currentPath}: ${error.message}`);
    }
}

function refreshRemoteList() {
    loadDirectory(currentDirectory);
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
toggleIframeButton.addEventListener("click", toggleIframeVisibility);

// Auto-load on page open.
applyLlmTargets();
updatePageTitle();
loadDirectory();
