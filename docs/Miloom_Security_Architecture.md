# Miloom Security & Privacy Architecture

This document outlines the security, privacy, and data-handling architecture for the Miloom app (Zifr iOS). 
It serves as a reference for all AI agents and developers working on the codebase to ensure no new features inadvertently expose sensitive user data.

## 1. Authentication & Backend

- **Provider**: Supabase.
- **Mechanism**: JWT-based authentication. All network requests to Supabase APIs and Edge Functions pass the active session's `accessToken`.
- **Data Isolation**: PostgreSQL Row Level Security (RLS) is strictly enforced. A user can only read, update, or delete data (companies, accounts, documents) that is explicitly tied to their `auth.uid()`. 

## 2. Document Scanning & OCR (ID Documents)

- **On-Device Processing**: Document scanning and Optical Character Recognition (OCR) are performed **100% locally on-device** using Apple's native `VisionKit` and `VNRecognizeTextRequest`.
- **Privacy Guarantee**: Sensitive text extracted from IDs, passports, or financial documents is **never** sent to a third-party API (like Gemini or Google Cloud Vision) for OCR processing.

## 3. Document Storage & Deletion

- **Storage**: Documents are securely uploaded to Supabase Storage.
- **Access**: Files are strictly access-controlled. The app retrieves temporary, short-lived Signed URLs (`expiresIn: 60` seconds) to display or download documents securely.
- **Deletion**: When a user deletes a document from their vault, the app permanently deletes the file from the Supabase Storage bucket. It is completely removed and unrecoverable, ensuring data sovereignty.

## 4. AI Features & The Gemini API

- **Proxy Architecture**: The app does not communicate directly with the Gemini API. All AI requests pass through a Supabase Edge Function (`gemini-rest-proxy` or `gemini-live-proxy`), which validates the user's Supabase authentication token before forwarding the request.
- **What gets sent**: Only highly specific metadata needed for the feature (e.g., a minified string of portfolio stats or a generic question like "what is an admin email used for") is sent to Gemini.
- **What DOES NOT get sent**: Raw financial documents, IDs, or sensitive OCR extractions are **never** passed to Gemini. 
