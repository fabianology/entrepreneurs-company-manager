// --- MOCK DATABASE FOR SIMULATOR ---
const mockData = {
    aura: {
        name: "Aura SaaS",
        structure: "C-Corp",
        burn: "$1,420",
        runway: "24 Mos",
        stackCount: "8 Tools",
        subs: [
            { name: "AWS Cloud Hosting", cost: "$432", cycle: "Monthly", payment: "Amex •••• 1002", renewal: "Jun 14, 2026", status: "Active" },
            { name: "OpenAI API", cost: "$380", cycle: "Monthly", payment: "Amex •••• 1002", renewal: "Jun 20, 2026", status: "Active" },
            { name: "Slack Workspace", cost: "$120", cycle: "Monthly", payment: "Visa •••• 4590", renewal: "Jun 11, 2026", status: "Active" },
            { name: "GitHub Enterprise", cost: "$48", cycle: "Monthly", payment: "Visa •••• 4590", renewal: "Jul 01, 2026", status: "Active" },
            { name: "Figma Design Pro", cost: "$45", cycle: "Monthly", payment: "Visa •••• 4590", renewal: "Jun 08, 2026", status: "Trial" },
            { name: "Intercom Chat", cost: "$240", cycle: "Monthly", payment: "Amex •••• 1002", renewal: "Jun 19, 2026", status: "Active" },
            { name: "Stripe Premium", cost: "$115", cycle: "Monthly", payment: "Bank Transfer", renewal: "Jul 05, 2026", status: "Active" },
            { name: "Google Workspace", cost: "$40", cycle: "Monthly", payment: "Visa •••• 4590", renewal: "Jun 15, 2026", status: "Active" }
        ],
        vault: [
            { type: "API Key", name: "Stripe Secret Key", user: "sk_live_51N...", pass: "whsec_AuraSaaSLiveKey2026_X91" },
            { type: "Credential", name: "SVB Bank Login", user: "aurafounder", pass: "SvbPass_AuraSecure99!" },
            { type: "Login", name: "AWS Root Console", user: "root@aurasaas.com", pass: "AwsRoot_MultiFactorToken88#" }
        ]
    },
    eclipse: {
        name: "Eclipse E-Commerce",
        structure: "LLC",
        burn: "$3,200",
        runway: "12 Mos",
        stackCount: "6 Tools",
        subs: [
            { name: "Shopify Plus", cost: "$2,000", cycle: "Monthly", payment: "Visa •••• 8821", renewal: "Jun 28, 2026", status: "Active" },
            { name: "Klaviyo Marketing", cost: "$650", cycle: "Monthly", payment: "Visa •••• 8821", renewal: "Jun 15, 2026", status: "Active" },
            { name: "Gorgias Helpdesk", cost: "$300", cycle: "Monthly", payment: "Visa •••• 8821", renewal: "Jun 18, 2026", status: "Active" },
            { name: "ShipStation", cost: "$120", cycle: "Monthly", payment: "Visa •••• 8821", renewal: "Jun 12, 2026", status: "Active" },
            { name: "Google Ads Manager", cost: "$100", cycle: "Monthly", payment: "Amex •••• 7730", renewal: "Jun 30, 2026", status: "Active" },
            { name: "Canva Pro", cost: "$30", cycle: "Monthly", payment: "Amex •••• 7730", renewal: "Jun 10, 2026", status: "Trial" }
        ],
        vault: [
            { type: "Login", name: "Shopify Admin", user: "admin@eclipsebrands.co", pass: "ShopifyEclipseMasterPwd1!" },
            { type: "Credential", name: "Chase Business Card", user: "chase_eclipse", pass: "ChaseEclipseSecureCard77" },
            { type: "API Key", name: "Klaviyo Private Key", user: "pk_eclipse...", pass: "klaviyo_EclipseMarketingKey_00" }
        ]
    },
    nexus: {
        name: "Nexus Consulting",
        structure: "Sole Prop",
        burn: "$850",
        runway: "36 Mos",
        stackCount: "5 Tools",
        subs: [
            { name: "HubSpot CRM", cost: "$500", cycle: "Monthly", payment: "Amex •••• 4401", renewal: "Jul 05, 2026", status: "Active" },
            { name: "Zoom Pro", cost: "$150", cycle: "Yearly", payment: "Amex •••• 4401", renewal: "Dec 12, 2026", status: "Active" },
            { name: "QuickBooks Online", cost: "$80", cycle: "Monthly", payment: "Bank Link", renewal: "Jun 14, 2026", status: "Active" },
            { name: "DocuSign", cost: "$80", cycle: "Monthly", payment: "Amex •••• 4401", renewal: "Jun 22, 2026", status: "Active" },
            { name: "Calendly Team", cost: "$40", cycle: "Monthly", payment: "Amex •••• 4401", renewal: "Jun 18, 2026", status: "Active" }
        ],
        vault: [
            { type: "Login", name: "HubSpot Login", user: "billing@nexusconsult.com", pass: "HubspotNexusSecuredPass99$" },
            { type: "Credential", name: "QuickBooks Accountant", user: "nexus_books", pass: "QbAccountantPass2026!" }
        ]
    }
};

let currentCompany = "aura";
let activeScreen = "home"; // "home" or "details"
let activeTab = "stack"; // "stack" or "vault" or "assistant"

document.addEventListener("DOMContentLoaded", () => {
    // --- IPHONE APP ELEMENT REFS ---
    const appBackBtn = document.getElementById("app-back-btn");
    const appHeaderTitle = document.getElementById("app-header-title");
    const iphoneTabBar = document.getElementById("iphone-tab-bar");
    const phoneScreenHome = document.getElementById("phone-screen-home");
    const phoneScreenDetails = document.getElementById("phone-screen-details");
    const phoneContentArea = document.getElementById("phone-content-area");
    
    // Details Screen Refs
    const iosStatBurn = document.getElementById("ios-stat-burn");
    const iosStatRunway = document.getElementById("ios-stat-runway");
    const iosStackListBody = document.getElementById("ios-stack-list-body");
    const iosVaultListBody = document.getElementById("ios-vault-list-body");
    
    // Sub-Views and Tabs
    const iosTabBtns = document.querySelectorAll(".ios-tab-btn");
    const iosSubviews = document.querySelectorAll(".ios-subview");
    
    // Dynamic Island
    const dynamicIsland = document.getElementById("dynamic-island");

    // Chat
    const iosChatHistory = document.getElementById("ios-chat-history");

    // --- CONTROLLER ELEMENT REFS ---
    const ctrlBtnHome = document.getElementById("ctrl-btn-home");
    const ctrlBtnAura = document.getElementById("ctrl-btn-aura");
    const ctrlBtnEclipse = document.getElementById("ctrl-btn-eclipse");
    const aiPromptBtns = document.querySelectorAll(".ai-prompt-btn");
    
    // Waitlist Form
    const waitlistForm = document.getElementById("waitlist-form");
    const formMessage = document.getElementById("form-message");

    // --- TRANSITIONS & NAVIGATION ---
    function navigateToDetails(companyKey) {
        currentCompany = companyKey;
        const data = mockData[companyKey];

        // Highlight controller button
        updateControllerState(companyKey);

        // Update Phone Header
        appHeaderTitle.textContent = data.name;
        appBackBtn.classList.remove("hidden");
        iphoneTabBar.classList.remove("hidden");

        // Update Stats in details screen
        iosStatBurn.textContent = data.burn;
        iosStatRunway.textContent = data.runway;

        // Render Stack and Vault
        renderStack(data.subs);
        renderVault(data.vault);

        // Switch Views
        phoneScreenHome.classList.remove("active");
        phoneScreenDetails.classList.add("active");
        activeScreen = "details";
        phoneContentArea.scrollTop = 0;

        // Default to Stack Tab when entering details
        switchTab("stack");
    }

    function navigateToHome() {
        updateControllerState("home");

        appHeaderTitle.textContent = "miloom";
        appBackBtn.classList.add("hidden");
        iphoneTabBar.classList.add("hidden");

        phoneScreenDetails.classList.remove("active");
        phoneScreenHome.classList.add("active");
        activeScreen = "home";
        phoneContentArea.scrollTop = 0;
    }

    function switchTab(tabName) {
        activeTab = tabName;
        iosTabBtns.forEach(btn => {
            if (btn.getAttribute("data-tab") === tabName) {
                btn.classList.add("active");
            } else {
                btn.classList.remove("active");
            }
        });

        iosSubviews.forEach(view => {
            if (view.id === `ios-subview-${tabName}`) {
                view.classList.add("active");
            } else {
                view.classList.remove("active");
            }
        });
    }

    function updateControllerState(activeItem) {
        [ctrlBtnHome, ctrlBtnAura, ctrlBtnEclipse].forEach(btn => btn.classList.remove("active"));
        if (activeItem === "home") ctrlBtnHome.classList.add("active");
        if (activeItem === "aura") ctrlBtnAura.classList.add("active");
        if (activeItem === "eclipse") ctrlBtnEclipse.classList.add("active");
    }

    // --- RENDERING INTERNAL SCREENS ---
    function renderStack(subs) {
        iosStackListBody.innerHTML = "";
        subs.forEach(sub => {
            const div = document.createElement("div");
            div.className = "ios-stack-item";
            div.id = `ios-sub-row-${sub.name.toLowerCase().split(' ')[0]}`;
            div.innerHTML = `
                <div class="ios-stack-info">
                    <div class="ios-stack-logo" style="background: ${getRandomColorGradient()}"></div>
                    <div>
                        <div class="ios-stack-name">${sub.name}</div>
                        <div class="ios-stack-payment">${sub.payment}</div>
                    </div>
                </div>
                <div class="ios-stack-meta">
                    <div class="ios-stack-cost">${sub.cost}</div>
                    <div class="ios-stack-renewal">${sub.renewal}</div>
                    <div class="ios-badge-row"><span class="status-badge ${sub.status.toLowerCase()}">${sub.status}</span></div>
                </div>
            `;
            iosStackListBody.appendChild(div);
        });
    }

    function renderVault(vault) {
        iosVaultListBody.innerHTML = "";
        vault.forEach((item, index) => {
            const div = document.createElement("div");
            div.className = "ios-vault-item";
            div.id = `ios-vault-card-${item.name.toLowerCase().split(' ')[0]}`;
            div.innerHTML = `
                <div class="ios-vault-header">
                    <div class="ios-vault-title">🔑 ${item.name}</div>
                    <span class="sim-badge" style="font-size: 0.55rem; padding: 1px 4px;">${item.type}</span>
                </div>
                <div class="ios-vault-field">
                    <div class="ios-vault-label">Identity</div>
                    <div class="ios-vault-value-row">
                        <span class="ios-vault-val">${item.user}</span>
                        <button class="vault-btn btn-copy" data-text="${item.user}">📋</button>
                    </div>
                </div>
                <div class="ios-vault-field">
                    <div class="ios-vault-label">Passcode</div>
                    <div class="ios-vault-value-row">
                        <span class="ios-vault-val font-mono mask-pwd" id="ios-pwd-${currentCompany}-${index}">••••••••••••</span>
                        <div class="vault-actions">
                            <button class="vault-btn btn-reveal" data-target="ios-pwd-${currentCompany}-${index}" data-real="${item.pass}">👁️</button>
                            <button class="vault-btn btn-copy" data-text="${item.pass}">📋</button>
                        </div>
                    </div>
                </div>
            `;
            iosVaultListBody.appendChild(div);
        });
        setupVaultEventHandlers();
    }

    function getRandomColorGradient() {
        const gradients = [
            "linear-gradient(135deg, #4f46e5, #06b6d4)",
            "linear-gradient(135deg, #10b981, #3b82f6)",
            "linear-gradient(135deg, #f59e0b, #ef4444)",
            "linear-gradient(135deg, #8b5cf6, #ec4899)"
        ];
        return gradients[Math.floor(Math.random() * gradients.length)];
    }

    // --- VAULT INTERACTION SETUP ---
    function setupVaultEventHandlers() {
        const revealBtns = document.querySelectorAll(".btn-reveal");
        revealBtns.forEach(btn => {
            btn.addEventListener("click", (e) => {
                e.stopPropagation();
                const targetId = btn.getAttribute("data-target");
                const realVal = btn.getAttribute("data-real");
                const span = document.getElementById(targetId);
                
                if (span.classList.contains("revealed")) {
                    span.textContent = "••••••••••••";
                    span.classList.remove("revealed");
                    btn.textContent = "👁️";
                } else {
                    span.textContent = realVal;
                    span.classList.add("revealed");
                    btn.textContent = "🔒";
                }
            });
        });

        const copyBtns = document.querySelectorAll(".btn-copy");
        copyBtns.forEach(btn => {
            btn.addEventListener("click", (e) => {
                e.stopPropagation();
                const text = btn.getAttribute("data-text");
                navigator.clipboard.writeText(text).then(() => {
                    const originalText = btn.textContent;
                    btn.textContent = "✅";
                    setTimeout(() => btn.textContent = originalText, 1500);
                });
            });
        });
    }

    // --- CHAT SYSTEM ---
    function appendChatMessage(sender, text) {
        const bubble = document.createElement("div");
        bubble.className = `ios-chat-bubble ${sender}`;
        bubble.textContent = text;
        iosChatHistory.appendChild(bubble);
        iosChatHistory.scrollTop = iosChatHistory.scrollHeight;
    }

    function triggerGeminiCommand(promptType) {
        // Switch to the Assistant tab first
        switchTab("assistant");

        // Clear previous highlights
        document.querySelectorAll(".ios-stat-card, .ios-stack-item, .ios-vault-item").forEach(el => {
            el.classList.remove("highlighted-ios-card");
        });

        // 1. Play listening state on Dynamic Island
        dynamicIsland.classList.add("listening");

        // 2. Add Gemini status indicator
        const loadBubble = document.createElement("div");
        loadBubble.className = "ios-chat-bubble bot typing-indicator";
        loadBubble.textContent = "Auditing financial logs...";
        iosChatHistory.appendChild(loadBubble);
        iosChatHistory.scrollTop = iosChatHistory.scrollHeight;

        setTimeout(() => {
            loadBubble.remove();
            dynamicIsland.classList.remove("listening");
            dynamicIsland.classList.add("alerting");
            
            let responseText = "";
            const currentName = mockData[currentCompany].name;

            if (promptType === "burn") {
                responseText = `Monthly stack burn for ${currentName} is ${mockData[currentCompany].burn} across ${mockData[currentCompany].stackCount} active integrations.`;
                
                // Switch back to Stack to highlight
                setTimeout(() => {
                    switchTab("stack");
                    const burnCard = document.getElementById("ios-stat-burn-card");
                    if (burnCard) {
                        burnCard.classList.add("highlighted-ios-card");
                    }
                }, 400);

            } else if (promptType === "stripe") {
                responseText = `Accessing Secure Vault... Stripe credentials for ${currentName} have been located and highlighted below.`;
                
                // Switch to Vault tab and highlight Stripe Card
                setTimeout(() => {
                    switchTab("vault");
                    const stripeItem = document.getElementById("ios-vault-card-stripe");
                    if (stripeItem) {
                        stripeItem.classList.add("highlighted-ios-card");
                        stripeItem.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    }
                }, 400);

            } else if (promptType === "leak") {
                if (currentCompany === "aura") {
                    responseText = `⚠️ LEAK AUDIT: Active trial for Figma ($45/mo) renewing in 2 days. It has not been linked to any corporate email (root@aurasaas.com) yet. Cancel to prevent unwanted renewals.`;
                    setTimeout(() => {
                        switchTab("stack");
                        const figmaRow = document.getElementById("ios-sub-row-figma");
                        if (figmaRow) {
                            figmaRow.classList.add("highlighted-ios-card");
                            figmaRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        }
                    }, 400);
                } else if (currentCompany === "eclipse") {
                    responseText = `⚠️ LEAK AUDIT: Shopify trial ended. Active billing has started on Visa •••• 8821. Canva Pro trial ($30/mo) is active but hasn't been logged in over 14 days.`;
                    setTimeout(() => {
                        switchTab("stack");
                        const canvaRow = document.getElementById("ios-sub-row-canva");
                        if (canvaRow) {
                            canvaRow.classList.add("highlighted-ios-card");
                        }
                    }, 400);
                } else {
                    responseText = `All 5 stack products match bank logs. No duplicates or active leaks found for Nexus Consulting. Runway is solid at 36 months.`;
                }
            }

            appendChatMessage("bot", responseText);

            // Turn off dynamic island alerting after response finishes
            setTimeout(() => {
                dynamicIsland.classList.remove("alerting");
            }, 1000);

        }, 1500);
    }

    // --- EVENT LISTENERS ---

    // Click company cards inside phone screen
    const phoneCompanyCards = document.querySelectorAll(".ios-company-card");
    phoneCompanyCards.forEach(card => {
        card.addEventListener("click", () => {
            const companyKey = card.getAttribute("data-company");
            navigateToDetails(companyKey);
        });
    });

    // App Back Button
    appBackBtn.addEventListener("click", navigateToHome);

    // App Tab Buttons
    iosTabBtns.forEach(btn => {
        btn.addEventListener("click", () => {
            const targetTab = btn.getAttribute("data-tab");
            switchTab(targetTab);
        });
    });

    // Controller: Home Button
    ctrlBtnHome.addEventListener("click", navigateToHome);

    // Controller: Company Switcher Buttons
    ctrlBtnAura.addEventListener("click", () => navigateToDetails("aura"));
    ctrlBtnEclipse.addEventListener("click", () => navigateToDetails("eclipse"));

    // Controller: Gemini Chat Prompt Buttons
    aiPromptBtns.forEach(btn => {
        btn.addEventListener("click", () => {
            // First ensure we are in details view
            if (activeScreen !== "details") {
                navigateToDetails(currentCompany);
            }
            
            const text = btn.textContent.trim();
            const promptType = btn.getAttribute("data-prompt");

            // User Chat Bubble
            appendChatMessage("user", text);

            // Bot Typing Response
            triggerGeminiCommand(promptType);
        });
    });

    // --- WAITLIST FORM HANDLING ---
    if (waitlistForm) {
        waitlistForm.addEventListener("submit", (e) => {
            e.preventDefault();
            const emailInput = document.getElementById("email");
            const email = emailInput.value.trim();
            
            if (!email) return;

            formMessage.textContent = "Securing slot on the private queue...";
            formMessage.className = "form-message";

            setTimeout(() => {
                formMessage.textContent = "✓ Slot confirmed! We've added your business email to the waitlist.";
                formMessage.className = "form-message success";
                emailInput.value = "";
            }, 1200);
        });
    }

    // Initialize home state
    navigateToHome();
});
