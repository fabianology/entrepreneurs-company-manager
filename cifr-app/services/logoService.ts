export const getFaviconUrl = (url?: string) => {
    if (!url) return null;

    try {
        // Basic cleanup: remove whitespace and ensure protocol for URL constructor
        let cleanUrl = url.trim();
        if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
            cleanUrl = 'https://' + cleanUrl;
        }

        const urlObj = new URL(cleanUrl);
        const domain = urlObj.hostname;

        // Using Google Favicon API with 128px size for high quality
        return `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;
    } catch (e) {
        console.error('Invalid URL for favicon:', url);
        return null;
    }
};
