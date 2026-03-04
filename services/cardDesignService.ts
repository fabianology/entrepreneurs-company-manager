
export interface CardDesign {
    gradient: string;
    logoColor?: string;
    textColor?: string;
    issuerLogo?: string;
}

const PREMIUM_CARDS: Record<string, CardDesign> = {
    'amex platinum': {
        gradient: 'from-slate-200 via-slate-100 to-slate-400',
        textColor: 'text-slate-800',
        logoColor: 'text-slate-900'
    },
    'amex gold': {
        gradient: 'from-amber-400 via-amber-300 to-amber-600',
        textColor: 'text-amber-950',
        logoColor: 'text-amber-900'
    },
    'amex green': {
        gradient: 'from-emerald-700 via-emerald-600 to-emerald-900',
        textColor: 'text-white'
    },
    'chase sapphire reserve': {
        gradient: 'from-[#0A1F44] via-[#153462] to-[#0D2B5B]',
        textColor: 'text-white'
    },
    'chase sapphire preferred': {
        gradient: 'from-[#1E3A8A] via-[#2563EB] to-[#1D4ED8]',
        textColor: 'text-white'
    },
    'apple card': {
        gradient: 'from-white via-slate-50 to-slate-200',
        textColor: 'text-slate-900',
        logoColor: 'text-slate-400'
    },
    'marriott bonvoy': {
        gradient: 'from-[#1C1C1E] via-[#2C2C2E] to-[#000000]',
        textColor: 'text-white'
    },
    'venture x': {
        gradient: 'from-[#004A99] via-[#0066CC] to-[#003366]',
        textColor: 'text-white'
    },
    'brent': {
        gradient: 'from-[#B8860B] via-[#DAA520] to-[#8B4513]',
        textColor: 'text-white'
    }
};

export const getCardDesign = (name: string, network: string): CardDesign => {
    const lowerName = name.toLowerCase();

    // Try to match specific premium cards
    for (const [key, design] of Object.entries(PREMIUM_CARDS)) {
        if (lowerName.includes(key)) {
            return design;
        }
    }

    // Fallback to network-based gradients
    switch (network) {
        case 'Amex':
            return { gradient: 'from-blue-600 via-blue-700 to-cyan-500', textColor: 'text-white' };
        case 'Mastercard':
            return { gradient: 'from-slate-800 via-slate-900 to-orange-950', textColor: 'text-white' };
        case 'Visa':
            return { gradient: 'from-indigo-700 via-indigo-800 to-purple-900', textColor: 'text-white' };
        case 'Discover':
            return { gradient: 'from-orange-500 via-orange-600 to-amber-700', textColor: 'text-white' };
        default:
            return { gradient: 'from-slate-700 via-slate-800 to-slate-900', textColor: 'text-white' };
    }
};
