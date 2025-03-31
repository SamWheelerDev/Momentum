# Chefy - Technical Context

## Technologies Used

### Frontend
- **Framework**: React with TypeScript
- **State Management**: React Context API (with potential Redux integration for complex state)
- **Styling**: Tailwind CSS for utility-first styling
- **UI Components**: Either Material UI or custom components with Tailwind
- **Routing**: React Router for client-side navigation
- **Form Handling**: React Hook Form for efficient form state management
- **API Client**: Supabase JS client for data fetching and real-time subscriptions
- **Testing**: Jest and React Testing Library

### Backend
- **Database**: PostgreSQL via Supabase
- **API Layer**: Supabase REST and real-time APIs
- **Authentication**: Supabase Auth with JWT
- **Storage**: Supabase Storage for media files
- **Serverless Functions**: Supabase Edge Functions (Deno runtime)
- **Security**: Row-level security policies in PostgreSQL

### DevOps
- **Version Control**: Git with GitHub
- **CI/CD**: GitHub Actions for automated testing and deployment
- **Hosting**: Vercel for frontend, Supabase for backend
- **Environment Management**: dotenv for environment variables
- **Monitoring**: Supabase built-in monitoring and logging

## Development Setup

### Local Environment Requirements
- Node.js (v16+)
- npm or yarn
- Git
- Supabase CLI
- PostgreSQL (optional, for local development without Supabase)

### Environment Variables
```
# Supabase Configuration
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key (server-side only)

# API Keys for Third-Party Services
AI_SERVICE_API_KEY=your-ai-service-key

# Configuration
NODE_ENV=development|production
```

### Repository Structure
```
home-chef-hero/
├── public/                  # Static assets
├── src/
│   ├── components/          # Reusable UI components
│   │   ├── common/          # Shared components
│   │   ├── layout/          # Layout components
│   │   ├── recipes/         # Recipe-related components
│   │   ├── challenges/      # Challenge-related components
│   │   ├── achievements/    # Achievement-related components
│   │   └── profile/         # User profile components
│   ├── hooks/               # Custom React hooks
│   ├── pages/               # Page components
│   ├── services/            # API service layer
│   ├── store/               # State management
│   ├── types/               # TypeScript type definitions
│   ├── utils/               # Utility functions
│   └── styles/              # Global styles
├── supabase/
│   ├── functions/           # Supabase Edge Functions
│   ├── migrations/          # Database migrations
│   └── seed-data/           # Seed data for development
├── tests/                   # Test files
├── .env.local               # Local environment variables
├── .env.example             # Example environment variables
├── package.json             # Dependencies and scripts
└── tsconfig.json            # TypeScript configuration
```

### Database Schema
The PostgreSQL database schema includes the following key tables:
- users
- recipes
- ingredients
- recipe_ingredients
- achievements
- user_achievements
- daily_challenges
- user_challenges
- cooking_logs
- user_preferences
- user_streaks
- ai_conversation_sessions
- ai_conversation_messages

See `backend/scripts.sql` for the complete schema definition.

## Technical Constraints

### Performance Requirements
- Initial page load < 2 seconds
- Time to interactive < 3 seconds
- API response time < 500ms
- Support for at least 10,000 concurrent users

### Security Requirements
- All user data must be protected by row-level security
- Authentication required for all non-public endpoints
- Input validation on all user inputs
- Content security policy implementation
- Regular security audits

### Scalability Considerations
- Horizontal scaling for the frontend via Vercel
- Database connection pooling
- Efficient indexing strategy
- Caching strategy for frequently accessed data
- Pagination for large data sets

### Accessibility Requirements
- WCAG 2.1 AA compliance
- Keyboard navigation support
- Screen reader compatibility
- Color contrast requirements
- Responsive design for all device sizes

## Dependencies

### Core Dependencies
- react
- react-dom
- react-router-dom
- @supabase/supabase-js
- typescript
- tailwindcss
- react-hook-form
- zod (for validation)
- date-fns (for date manipulation)
- uuid

### Development Dependencies
- eslint
- prettier
- jest
- @testing-library/react
- typescript
- vite (for development server)
- postcss
- autoprefixer

### Third-Party Services
- Supabase (database, auth, storage, functions)
- Vercel (frontend hosting)
- OpenAI API or similar (for AI cooking assistant)
- Unsplash API (for recipe images)
- Sentry (error tracking)

## Integration Points

### Authentication Flow
Supabase Auth handles user registration, login, and session management. JWT tokens are used for API authentication.

### Data Access Patterns
The application uses a combination of REST API calls and real-time subscriptions:
- REST for CRUD operations and complex queries
- Real-time for live updates (achievements, challenges, etc.)

### File Storage
Supabase Storage is used for:
- Recipe images
- User profile photos
- Cooking log photos
- Achievement badges

### External APIs
- AI service API for cooking assistant functionality
- Potential integration with recipe APIs for initial data seeding
- Potential integration with nutrition data APIs

## Development Workflow

### Git Workflow
- `main` branch for production
- `develop` branch for staging
- Feature branches for development
- Pull request workflow with code reviews

### Testing Strategy
- Unit tests for utility functions and hooks
- Component tests for UI components
- Integration tests for key user flows
- E2E tests for critical paths

### Deployment Process
1. Automated tests run on pull requests
2. Merge to develop triggers deployment to staging
3. Merge to main triggers deployment to production
4. Database migrations run automatically

### Monitoring and Maintenance
- Error tracking via Sentry
- Performance monitoring via Vercel Analytics
- Database monitoring via Supabase Dashboard
- Regular dependency updates
- Scheduled database backups
