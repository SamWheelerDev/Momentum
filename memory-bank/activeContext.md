# Chefy - Active Context

## Current Work Focus

The current focus is on establishing the foundational data model for the Chefy application. We've created a comprehensive PostgreSQL schema that supports the core features outlined in the MVP:

1. **User Management System**
   - User profiles with preferences
   - Authentication integration with Supabase
   - XP and leveling system

2. **Recipe Management**
   - Recipe storage with difficulty levels and time estimates
   - Ingredient relationships
   - Structured instructions

3. **Gamification Elements**
   - Achievement system
   - Daily challenges
   - Streak tracking
   - XP rewards

4. **AI Assistant Integration**
   - Conversation history tracking
   - Context-aware interactions
   - Recipe and ingredient references

## Recent Changes

### Database Schema Development
- Created initial SQL schema with all core tables
- Added AI conversation tables to support the cooking assistant feature
- Implemented proper relationships between entities
- Added indexes for performance optimization

### Schema Improvements
- Added JSONB columns for flexible data storage (dietary preferences, recipe instructions)
- Implemented UUID primary keys for better scalability
- Created junction tables for many-to-many relationships
- Added appropriate constraints and defaults

### AI Conversation Feature
- Added tables to track conversation sessions and messages
- Implemented references to recipes and ingredients within conversations
- Added metadata support for advanced AI features
- Created indexes for efficient querying

### Row Level Security Implementation
- Added `is_admin` field to users table to identify administrators
- Added `user_id`, `visibility`, `created_by_admin`, and `featured` fields to recipes table
- Created new `user_relationships` table to support friend relationships
- Implemented helper functions for admin checks and recipe access control
- Created comprehensive RLS policies for all tables
- Added appropriate indexes to support efficient filtering with RLS

## Next Steps

### Immediate Tasks
1. **Database Implementation**
   - Deploy schema to Supabase project
   - ✅ Create row-level security policies
   - Set up initial seed data for testing

2. **API Layer Development**
   - Create Supabase functions for complex operations
   - Define API endpoints for frontend consumption
   - Implement real-time subscription handlers

3. **Frontend Foundation**
   - Set up React project with TypeScript
   - Implement authentication flow
   - Create core UI components
   - Establish state management pattern

### Short-term Goals
1. **MVP Feature Implementation**
   - User onboarding flow
   - Recipe browsing and filtering
   - Basic achievement system
   - Daily challenge mechanism
   - Simple AI assistant integration

2. **Testing Infrastructure**
   - Unit tests for core functionality
   - Integration tests for key user flows
   - Test data generation

## Active Decisions and Considerations

### Security Model Decisions
- **Decision**: Implementing multi-level recipe visibility (public, friends, private)
  - **Pros**: Gives users fine-grained control over recipe sharing
  - **Cons**: More complex queries and access control logic
  - **Status**: Implemented with RLS policies

- **Decision**: Creating admin role with full access
  - **Pros**: Simplifies maintenance and support operations
  - **Cons**: Potential security risk if admin accounts are compromised
  - **Status**: Implemented with is_admin flag and helper function

- **Decision**: Using RLS policies at the database level
  - **Pros**: Security enforced at data layer, consistent across all access points
  - **Cons**: More complex database setup, potential performance impact
  - **Status**: Implemented for all tables

### Data Model Decisions
- **Decision**: Using JSONB for recipe instructions instead of a separate steps table
  - **Pros**: Flexibility in instruction format, easier to update all at once
  - **Cons**: Less structured querying, potential for inconsistent formats
  - **Status**: Implemented, but may revisit if we need more structured query capabilities

- **Decision**: Storing dietary preferences as JSONB
  - **Pros**: Can accommodate any diet type without schema changes
  - **Cons**: Less validation at the database level
  - **Status**: Implemented, will add application-level validation

- **Decision**: Using UUID primary keys
  - **Pros**: Better for distributed systems, no sequence contention, security
  - **Cons**: Slightly larger storage, potentially slower joins
  - **Status**: Implemented across all tables

### AI Assistant Implementation
- **Decision**: Creating dedicated tables for AI conversations
  - **Pros**: Enables history tracking, context awareness, and analytics
  - **Cons**: Additional complexity, storage requirements
  - **Status**: Implemented with session and message tables

- **Consideration**: Integration with external AI service
  - **Options**: OpenAI API, self-hosted model, or hybrid approach
  - **Status**: Evaluating options, leaning toward OpenAI API for MVP

### Gamification Strategy
- **Decision**: XP-based leveling system with achievements and challenges
  - **Pros**: Familiar to users, scalable, flexible reward mechanism
  - **Cons**: Requires careful balance to maintain engagement
  - **Status**: Database structure implemented, need to define XP curves and level requirements

- **Consideration**: Achievement unlocking strategy
  - **Options**: Automatic based on criteria vs. manual claim by user
  - **Status**: Planning to implement automatic unlocking with notifications

### Technical Architecture
- **Decision**: Using Supabase for backend services
  - **Pros**: Integrated auth, database, storage, and serverless functions
  - **Cons**: Less control than custom backend, potential vendor lock-in
  - **Status**: Proceeding with Supabase for MVP, will evaluate scaling needs

- **Consideration**: Frontend framework selection
  - **Options**: Next.js vs. Create React App vs. Vite
  - **Status**: Leaning toward Next.js for SSR capabilities and routing

## Open Questions

1. How will we handle recipe versioning if users want to save their modifications?
2. What strategy should we use for implementing the AI cooking assistant's learning capabilities?
3. How will we structure the meal planning feature to be flexible yet user-friendly?
4. What metrics should we track to measure the effectiveness of the gamification features?
5. How should we implement the social features in future iterations?
6. How will we handle performance optimization for RLS policies as the database grows?
7. Should we implement more granular permission levels beyond the current admin/regular user distinction?

## Current Blockers

1. Need to finalize the AI service integration approach
2. Need to establish XP and leveling curves for gamification
3. Need to create seed data for testing the initial implementation
4. Need to test RLS policies with realistic user scenarios
