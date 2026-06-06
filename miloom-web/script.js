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
let activeView = "dashboard";

document.addEventListener("DOMContentLoaded", () => {
    // --- ELEMENT REFS ---
    const companyBtn = document.getElementById("company-btn");
    const companyList = document.getElementById("company-list");
    const currentCompanyTitle = document.getElementById("current-company-title");
    const currentCompanyStructure = document.getElementById("current-company-structure");
    
    const statBurn = document.getElementById("stat-burn");
    const statRunway = document.getElementById("stat-runway");
    const statStack = document.getElementById("stat-stack");
    
    const subTableBody = document.getElementById("sub-table-body");
    const vaultItemsGrid = document.getElementById("vault-items-grid");
    
    const btnShowDashboard = document.getElementById("btn-show-dashboard");
    const btnShowVault = document.getElementById("btn-show-vault");
    
    const viewDashboard = document.getElementById("view-dashboard");
    const viewVault = document.getElementById("view-vault");
    
    const aiChatHistory = document.getElementById("ai-chat-history");
    const aiPromptBtns = document.querySelectorAll(".ai-prompt-btn");
    
    const waitlistForm = document.getElementById("waitlist-form");
    const formMessage = document.getElementById("form-message");

    // --- RENDER FUNCTIONS ---
    function renderCompany() {
        const data = mockData[currentCompany];
        
        // Update Title & Badge
        currentCompanyTitle.textContent = data.name;
        currentCompanyStructure.textContent = data.structure;
        
        // Update Selector Button
        companyBtn.innerHTML = `
            <span class="company-color-indicator" style="background-color: ${getCompanyColor(currentCompany)};"></span>
            <span class="company-name-text">${data.name}</span>
            <span class="dropdown-chevron">▼</span>
        `;
        
        // Update Stats
        statBurn.textContent = data.burn;
        statRunway.textContent = data.runway;
        statStack.textContent = data.stackCount;
        
        // Render Subscriptions
        subTableBody.innerHTML = "";
        data.subs.forEach(sub => {
            const tr = document.createElement("tr");
            tr.id = `sub-row-${sub.name.toLowerCase().split(' ')[0]}`;
            tr.innerHTML = `
                <td>
                    <div class="sub-name-cell">
                        <div class="sub-logo" style="background: ${getRandomColorGradient()}"></div>
                        ${sub.name}
                    </div>
                </td>
                <td class="font-mono font-bold">${sub.cost}</td>
                <td>${sub.cycle}</td>
                <td class="text-muted font-mono">${sub.payment}</td>
                <td>${sub.renewal}</td>
                <td><span class="status-badge ${sub.status.toLowerCase()}">${sub.status}</span></td>
            `;
            subTableBody.appendChild(tr);
        });
        
        // Render Vault
        vaultItemsGrid.innerHTML = "";
        data.vault.forEach((item, index) => {
            const card = document.createElement("div");
            card.className = "vault-card";
            card.id = `vault-card-${item.name.toLowerCase().split(' ')[0]}`;
            card.innerHTML = `
                <div class="vault-card-header">
                    <span class="vault-card-icon">${item.type === 'API Key' ? '🔑' : '🔒'}</span>
                    <span class="vault-card-title">${item.name}</span>
                    <span class="sim-badge" style="margin-left: auto; font-size: 0.6rem;">${item.type}</span>
                </div>
                <div class="vault-field-group">
                    <div class="vault-label">Username / Identity</div>
                    <div class="vault-value-row">
                        <span class="vault-value">${item.user}</span>
                        <button class="vault-btn btn-copy" data-text="${item.user}">📋</button>
                    </div>
                </div>
                <div class="vault-field-group">
                    <div class="vault-label">Password / Value</div>
                    <div class="vault-value-row">
                        <span class="vault-value font-mono mask-pwd" id="pwd-${currentCompany}-${index}">••••••••••••</span>
                        <div class="vault-actions">
                            <button class="vault-btn btn-reveal" data-target="pwd-${currentCompany}-${index}" data-real="${item.pass}">👁️</button>
                            <button class="vault-btn btn-copy" data-text="${item.pass}">📋</button>
                        </div>
                    </div>
                </div>
            `;
            vaultItemsGrid.appendChild(card);
        });

        // Setup Vault Interactions after rendering
        setupVaultEventHandlers();
    }

    function getCompanyColor(company) {
        if (company === "aura") return "#4f46e5";
        if (company === "eclipse") return "#8b5cf6";
        return "#10b981";
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
        // Password Reveal Handler
        const revealBtns = document.querySelectorAll(".btn-reveal");
        revealBtns.forEach(btn => {
            btn.addEventListener("click", () => {
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

        // Copy Handler
        const copyBtns = document.querySelectorAll(".btn-copy");
        copyBtns.forEach(btn => {
            btn.addEventListener("click", () => {
                const text = btn.getAttribute("data-text");
                navigator.clipboard.writeText(text).then(() => {
                    const originalText = btn.textContent;
                    btn.textContent = "✅";
                    setTimeout(() => btn.textContent = originalText, 1500);
                });
            });
        });
    }

    // --- SWITCH VIEWS ---
    function switchView(view) {
        activeView = view;
        if (view === "dashboard") {
            btnShowDashboard.classList.add("active");
            btnShowVault.classList.remove("active");
            viewDashboard.classList.add("active");
            viewVault.classList.remove("active");
        } else {
            btnShowDashboard.classList.remove("active");
            btnShowVault.classList.add("active");
            viewDashboard.classList.remove("active");
            viewVault.classList.add("active");
        }
    }

    btnShowDashboard.addEventListener("click", () => switchView("dashboard"));
    btnShowVault.addEventListener("click", () => switchView("vault"));

    // --- COMPANY DROPDOWN SWITCHER ---
    companyBtn.addEventListener("click", (e) => {
        e.stopPropagation();
        companyList.classList.toggle("active");
    });

    document.addEventListener("click", () => {
        companyList.classList.remove("active");
    });

    const options = document.querySelectorAll(".company-option");
    options.forEach(opt => {
        opt.addEventListener("click", () => {
            options.forEach(o => o.classList.remove("active"));
            opt.classList.add("active");
            currentCompany = opt.getAttribute("data-company");
            renderCompany();
        });
    });

    // --- SIMULATED GEMINI ASSISTANT ---
    function appendChatMessage(sender, text) {
        const msgDiv = document.createElement("div");
        msgDiv.className = `ai-msg ${sender}`;
        msgDiv.textContent = text;
        aiChatHistory.appendChild(msgDiv);
        aiChatHistory.scrollTop = aiChatHistory.scrollHeight;
    }

    function simulateTypingAndResponse(promptType) {
        // Clear previous highlight classes
        document.querySelectorAll(".sim-stat-card, .sim-table tr, .vault-card").forEach(el => {
            el.classList.remove("highlighted-vault-card");
            el.style.boxShadow = "none";
            el.style.borderColor = "var(--border-light)";
        });

        // 1. Add loading state
        const loadDiv = document.createElement("div");
        loadDiv.className = "ai-msg bot typing-indicator";
        loadDiv.textContent = "Gemini is auditing data...";
        aiChatHistory.appendChild(loadDiv);
        aiChatHistory.scrollTop = aiChatHistory.scrollHeight;

        setTimeout(() => {
            // Remove loading indicator
            loadDiv.remove();

            let responseText = "";
            const currentName = mockData[currentCompany].name;

            if (promptType === "burn") {
                const burnVal = mockData[currentCompany].burn;
                responseText = `Based on my real-time audit, ${currentName} currently has a monthly tech stack burn of ${burnVal}/mo across ${mockData[currentCompany].stackCount} active subscriptions.`;
                
                // Highlight Burn Stat Card
                const card = document.getElementById("stat-burn").parentElement;
                card.classList.add("highlighted-vault-card");
                card.style.borderColor = "var(--accent-cyan)";
                card.style.boxShadow = "0 0 15px rgba(0, 240, 255, 0.2)";
                
            } else if (promptType === "stripe") {
                // Force switch to vault tab
                switchView("vault");
                
                responseText = `I have navigated to the Secure Vault. The credentials card for "Stripe Secret Key" is highlighted for your convenience. You can click the eye icon to reveal the secret token.`;
                
                // Highlight Stripe Card
                setTimeout(() => {
                    const stripeCard = document.getElementById("vault-card-stripe");
                    if (stripeCard) {
                        stripeCard.classList.add("highlighted-vault-card");
                        stripeCard.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    }
                }, 100);

            } else if (promptType === "leak") {
                if (currentCompany === "aura") {
                    responseText = `⚠️ MONEY LEAK ALERT: You have an active trial for Figma Design Pro ($45/mo) renewing on Jun 08, 2026 (in 2 days). It is currently billed to Amex •••• 1002, but is not linked to your corporate Google Workspace email (root@aurasaas.com). Recommend cancelling or linking to avoid rogue charges.`;
                    
                    // Highlight Figma subscription row
                    switchView("dashboard");
                    setTimeout(() => {
                        const figmaRow = document.getElementById("sub-row-figma");
                        if (figmaRow) {
                            figmaRow.style.background = "rgba(245, 158, 11, 0.1)";
                            figmaRow.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        }
                    }, 100);
                } else if (currentCompany === "eclipse") {
                    responseText = `⚠️ TRIAL WARNING: Canva Pro ($30/mo) is on a trial ending in 4 days. HubSpot sync was not detected, which means your marketing team isn't using it. Cancel to save $30/mo.`;
                    switchView("dashboard");
                    setTimeout(() => {
                        const row = document.getElementById("sub-row-canva");
                        if (row) {
                            row.style.background = "rgba(245, 158, 11, 0.1)";
                        }
                    }, 100);
                } else {
                    responseText = `All subscriptions for Nexus Consulting are active and matched with your financial institutions. No leaking trials or duplicate SaaS seats detected! Runway is stable at 36 months.`;
                }
            }

            appendChatMessage("bot", responseText);

        }, 1500);
    }

    aiPromptBtns.forEach(btn => {
        btn.addEventListener("click", () => {
            const promptText = btn.textContent.trim();
            const promptType = btn.getAttribute("data-prompt");
            
            // Add user message
            appendChatMessage("user", promptText);
            
            // Trigger bot response
            simulateTypingAndResponse(promptType);
        });
    });

    // --- WAITLIST FORM FLOW ---
    if (waitlistForm) {
        waitlistForm.addEventListener("submit", (e) => {
            e.preventDefault();
            const emailInput = document.getElementById("email");
            const email = emailInput.value.trim();
            
            if (!email) return;

            formMessage.textContent = "Securing your invitation slot...";
            formMessage.className = "form-message";

            setTimeout(() => {
                formMessage.textContent = "✓ Success! You've been added to the exclusive private beta. Check your inbox soon.";
                formMessage.className = "form-message success";
                emailInput.value = "";
            }, 1000);
        });
    }

    // --- INITIALIZE DEFAULT STATE ---
    renderCompany();
});
