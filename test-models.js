import { GoogleGenAI } from "@google/genai";

const run = async () => {
    const genAI = new GoogleGenAI({ apiKey: "AIzaSyDp8-Vv1TCoPgGm6OB-KAv8If2v3XPo1-w" });
    try {
        const models = await genAI.models.list();
        console.log("Available Models:");
        console.log(JSON.stringify(models, null, 2));
    } catch (error) {
        console.error("Error listing models:", error);
    }
};

run();
