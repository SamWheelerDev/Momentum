# Chefy - Backend Documentation

## Backend Setup and Configuration

This document covers the setup and configuration of the Chefy backend services.

## Supabase Integration

Chefy uses Supabase as the backend platform, which provides:
- PostgreSQL database
- Serverless functions
- Real-time subscriptions
- Row-level security

## Authentication and File Storage

### Authentication
The application uses Supabase Auth for user authentication, which supports:
- Email/password authentication
- OAuth providers (Google, Facebook, etc.)
- Magic link authentication

### File Storage
Supabase Storage is used for:
- Recipe images
- User profile pictures
- Achievement badge images