"use strict";

const pageTitleElement = document.getElementById("page-title");
const directoryInput = document.getElementById("directory-input");
const refreshListButton = document.getElementById("refresh-list");
const statusElement = document.getElementById("status");
const linksList = document.getElementById("links");
const currentDirectoryUrl = new URL(".", window.location.href);
let selectedDirectoryUrl = currentDirectoryUrl;

function setStatus(message) {
    statusElement.textContent = message;
}

function isHtmlPath(pathname) {
    return /\.html?$/i.test(pathname);
}

function extractTitleFromHtml(htmlText) {
    const parser = new DOMParser();
    const documentNode = parser.parseFromString(htmlText, "text/html");
    const title = (documentNode.title || "").trim();
    return title || "(no title)";
}

function getFileNameFromPath(pathname) {
    const pathParts = pathname.split("/").filter(Boolean);
    const lastPathPart = pathParts[pathParts.length - 1] || "";
    return decodeURIComponent(lastPathPart);
}

function clearLinks() {
    linksList.innerHTML = "";
}

function normalizeDirectoryPath(inputValue) {
    const trimmedInput = (inputValue || "").trim();

    if (!trimmedInput) {
        return "/";
    }

    const startsWithSlash = trimmedInput.startsWith("/");
    const withLeadingSlash = startsWithSlash ? trimmedInput : `/${trimmedInput}`;
    return withLeadingSlash.endsWith("/") ? withLeadingSlash : `${withLeadingSlash}/`;
}

function resolveSelectedDirectoryUrl() {
    const normalizedPath = normalizeDirectoryPath(directoryInput.value);
    directoryInput.value = normalizedPath;
    return new URL(normalizedPath, window.location.origin);
}

function getLastPathSegment(pathname) {
    const pathParts = pathname.split("/").filter(Boolean);
    return pathParts[pathParts.length - 1] || "root";
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
    const currentPathPart = getLastPathSegment(currentDirectoryUrl.pathname);
    pageTitleElement.textContent = `HTML Files Index — local: ${localIp} | public: ${publicIp} | ${currentPathPart}`;
}

async function fetchDirectoryListingDocument(directoryUrl) {
    const response = await fetch(directoryUrl.href, { cache: "no-store" });

    if (!response.ok) {
        throw new Error(`Directory request failed (${response.status})`);
    }

    const htmlText = await response.text();
    const parser = new DOMParser();
    return parser.parseFromString(htmlText, "text/html");
}

function collectHtmlFileUrlsFromListing(listingDocument, directoryUrl) {
    const anchors = Array.from(listingDocument.querySelectorAll("a[href]"));
    const urlByPath = new Map();

    for (const anchor of anchors) {
        const rawHref = anchor.getAttribute("href");

        if (!rawHref || rawHref.startsWith("#") || rawHref.startsWith("?")) {
            continue;
        }

        const fileUrl = new URL(rawHref, directoryUrl);

        if (fileUrl.origin !== window.location.origin) {
            continue;
        }

        if (!fileUrl.pathname.startsWith(directoryUrl.pathname)) {
            continue;
        }

        if (!isHtmlPath(fileUrl.pathname)) {
            continue;
        }

        urlByPath.set(fileUrl.pathname, fileUrl);
    }

    return Array.from(urlByPath.values()).sort((left, right) =>
        left.pathname.localeCompare(right.pathname, undefined, { sensitivity: "base" })
    );
}

async function fetchRemotePageTitle(fileUrl) {
    try {
        const response = await fetch(fileUrl.href, { cache: "no-store" });

        if (!response.ok) {
            return "(failed to load title)";
        }

        const htmlText = await response.text();
        return extractTitleFromHtml(htmlText);
    } catch (error) {
        return "(failed to load title)";
    }
}

function renderLinks(fileItems) {
    clearLinks();

    for (const item of fileItems) {
        const listItem = document.createElement("li");
        const link = document.createElement("a");

        link.href = item.url.href;
        link.target = "_blank";
        link.rel = "noopener noreferrer";
        link.textContent = `${item.fileName} — ${item.title}`;

        listItem.appendChild(link);
        linksList.appendChild(listItem);
    }
}

async function refreshRemoteList() {
    selectedDirectoryUrl = resolveSelectedDirectoryUrl();
    setStatus(`Loading .htm/.html files from ${selectedDirectoryUrl.pathname} ...`);

    try {
        const listingDocument = await fetchDirectoryListingDocument(selectedDirectoryUrl);
        const htmlFileUrls = collectHtmlFileUrlsFromListing(listingDocument, selectedDirectoryUrl);

        if (htmlFileUrls.length === 0) {
            clearLinks();
            setStatus("No .htm/.html files found in this server directory listing.");
            return;
        }

        const fileItems = await Promise.all(
            htmlFileUrls.map(async (fileUrl) => ({
                url: fileUrl,
                fileName: getFileNameFromPath(fileUrl.pathname),
                title: await fetchRemotePageTitle(fileUrl)
            }))
        );

        renderLinks(fileItems);
        setStatus(`Found ${fileItems.length} remote HTML file(s).`);
    } catch (error) {
        clearLinks();
        setStatus(`Failed to read server directory listing: ${error.message}`);
    }
}

refreshListButton.addEventListener("click", refreshRemoteList);
directoryInput.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
        refreshRemoteList();
    }
});

// Auto-load on page open.
updatePageTitle();
refreshRemoteList();
