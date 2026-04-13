export const getFaviconUrl = (url?: string) => {
    if (!url) return null;

    try {
        let cleanUrl = url.trim();
        if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
            cleanUrl = 'https://' + cleanUrl;
        }

        // Extremely simple domain parser to bypass React Native's lack of native 'URL' robust parsing sometimes
        const domainMatch = cleanUrl.replace(/^(?:https?:\/\/)?(?:www\.)?/i, '').split('/')[0];
        const domain = domainMatch;

        if (!domain || !domain.includes('.')) return null;

        return `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;
    } catch (e) {
        return null;
    }
};
