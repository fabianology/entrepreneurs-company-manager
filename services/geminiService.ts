import { GoogleGenAI, Type } from "@google/genai";

// Initialize Gemini API according to guidelines, using process.env.API_KEY directly
const getAiClient = () => {
  return new GoogleGenAI({ apiKey: process.env.API_KEY });
};

const FALLBACK_QUOTES = [
  "The best way to predict the future is to create it. - Peter Drucker",
  "The way to get started is to quit talking and begin doing. - Walt Disney",
  "Your time is limited, so don't waste it living someone else's life. - Steve Jobs",
  "If you are not embarrassed by the first version of your product, you've launched too late. - Reid Hoffman",
  "Sustain a vision of who you want to be. - Oprah Winfrey",
  "Success is not final, failure is not fatal: it is the courage to continue that counts. - Winston Churchill",
  "Risk more than others think is safe. Dream more than others think is practical. - Howard Schultz"
];

const isQuotaError = (error: any) => {
  return error?.status === 429 ||
    error?.code === 429 ||
    error?.message?.includes('429') ||
    error?.message?.includes('quota') ||
    error?.status === 'RESOURCE_EXHAUSTED';
};

export const getEntrepreneurialQuote = async () => {
  const prompt = `Provide one short, highly inspiring quote for entrepreneurs or business owners. Return only the quote and the author name. Example: "The way to get started is to quit talking and begin doing. - Walt Disney"`;

  try {
    const ai = getAiClient();
    // Using gemini-1.5-flash for basic text tasks
    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: prompt,
      config: {
        temperature: 0.9,
      }
    });
    return response.text ? response.text.trim() : FALLBACK_QUOTES[0];
  } catch (error: any) {
    if (isQuotaError(error)) {
      console.warn("Gemini Quote: Quota exceeded, serving fallback.");
    } else {
      console.error("Gemini Quote Error:", error);
    }
    return FALLBACK_QUOTES[Math.floor(Math.random() * FALLBACK_QUOTES.length)];
  }
};

export const analyzeSubscriptions = async (subscriptions: any[]) => {
  const prompt = `Analyze these business subscriptions and provide 3 brief strategic suggestions to save money or optimize the tech stack. Subscriptions: ${JSON.stringify(subscriptions)}`;

  try {
    const ai = getAiClient();
    // Using gemini-2.0-flash for summarization tasks
    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: prompt,
      config: {
        temperature: 0.7,
      }
    });
    return response.text;
  } catch (error: any) {
    if (isQuotaError(error)) {
      console.warn("Gemini Analysis: Quota exceeded.");
      return "We are experiencing high traffic. Please manually review your subscriptions for unused seats or opportunities to switch to annual billing for discounts.";
    }
    console.error("Gemini Error:", error);
    return "Could not generate insights at this time.";
  }
};

export const parseRawTextToAccount = async (text: string) => {
  try {
    const ai = getAiClient();
    // Using gemini-2.0-flash for extraction tasks
    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: `Parse the following raw text into a structured JSON account object. Text: "${text}"`,
      config: {
        responseMimeType: "application/json",
        responseSchema: {
          type: Type.OBJECT,
          properties: {
            platform: { type: Type.STRING },
            email: { type: Type.STRING },
            twoFactorAuth: { type: Type.STRING },
            pricingModel: { type: Type.STRING, description: 'One of: free, paid' },
            notes: { type: Type.STRING }
          },
          required: ["platform", "email"]
        }
      }
    });

    return JSON.parse(response.text || '{}');
  } catch (error) {
    console.error("Gemini Parse Error:", error);
    return null;
  }
};

export const askPortfolioQuestion = async (data: any, question: string) => {
  const prompt = `
  You are a smart portfolio manager assistant for an entrepreneur. 
  
  Here is the minified data of all companies, accounts, and subscriptions:
  ${JSON.stringify(data)}
  
  User Question: "${question}"
  
  Instructions:
  1. Answer briefly and directly (max 2 sentences).
  2. If the user asks about costs, sum them up across relevant companies.
  3. If the user asks for a login/email, specify which company it belongs to.
  4. Be helpful and professional.
  `;

  try {
    const ai = getAiClient();
    // Using gemini-1.5-pro for complex reasoning tasks over portfolio data
    const response = await ai.models.generateContent({
      model: 'gemini-2.5-pro',
      contents: prompt,
    });
    return response.text;
  } catch (error: any) {
    if (isQuotaError(error)) {
      return "I'm momentarily unavailable due to high request volume. Please try again shortly.";
    }
    console.error("Gemini Search Error:", error);
    return "I couldn't process that query right now.";
  }
};

export const generateSubscriptionEmailPurpose = async (subscriptionName: string) => {
  const prompt = `Provide a very short (max 12 words), professional, and strategic explanation of what the primary account email for "${subscriptionName}" is typically used for in a company. 
  Focus on things like 'Primary Admin', 'Billing notifications', 'Team invites', 'SSO ownership', etc. 
  Example for GitHub: "Receives all pull request notifications, team invites, and security alerts."
  Example for AWS: "Root account owner for billing, console access, and IAM escalation."
  Return ONLY the purpose text, no quotes or prefix.`;

  try {
    const ai = getAiClient();
    const response = await ai.models.generateContent({
      model: 'gemini-2.0-flash',
      contents: prompt,
      config: {
        temperature: 0.7,
      }
    });
    return response.text ? response.text.trim() : "";
  } catch (error) {
    console.error("Gemini Email Purpose Error:", error);
    return "";
  }
};