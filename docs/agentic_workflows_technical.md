# Chefy - Agentic Workflows Technical Implementation

## Architecture Overview

This document provides the technical specifications for implementing the agentic workflows outlined in the implementation plan. It focuses on code structure, frameworks, and specific implementation details.

## Technology Stack

### Core Components
- **Language**: Python 3.10+
- **Framework**: FastAPI for agent API endpoints
- **AI Integration**: OpenAI API (GPT-4) with instructor for structured outputs
- **Database**: PostgreSQL via Supabase
- **Frontend Integration**: React with TypeScript

### Key Libraries
- `instructor`: For structured outputs from LLMs
- `opentelemetry`: For tracing and monitoring agent performance
- `pydantic`: For data validation and settings management
- `mcp-agent`: For agent workflow orchestration
- `sqlalchemy`: For database interactions
- `supabase`: For Supabase integration

## Core Components Design

### 1. Agent Coordinator

```python
from typing import Dict, List, Optional, Union
from pydantic import BaseModel
from mcp_agent import Agent, AgentContext

class AgentResponse(BaseModel):
    """Structured response from an agent"""
    content: str
    confidence: float
    suggested_actions: Optional[List[Dict]] = None
    metadata: Optional[Dict] = None

class AgentCoordinator:
    """Coordinates multiple specialized agents and manages workflow"""
    
    def __init__(self, agents: Dict[str, Agent], context_manager):
        self.agents = agents
        self.context_manager = context_manager
        self.response_generator = ResponseGenerator()
    
    async def process_request(self, user_id: str, input_text: str) -> AgentResponse:
        """Process a user request and return a response"""
        
        # Get user context
        context = await self.context_manager.get_context(user_id)
        
        # Determine intent and select appropriate agent(s)
        intent = await self._classify_intent(input_text, context)
        selected_agent = self._select_agent(intent)
        
        # Get response from selected agent
        agent_response = await selected_agent.execute(input_text, context)
        
        # Update context with new information
        await self.context_manager.update_context(user_id, agent_response)
        
        # Generate final response
        final_response = self.response_generator.generate(agent_response, context)
        
        return final_response
    
    async def _classify_intent(self, input_text: str, context: AgentContext) -> str:
        """Classify the user's intent"""
        # Implementation will use a classifier model or LLM
        pass
    
    def _select_agent(self, intent: str) -> Agent:
        """Select the appropriate agent based on intent"""
        return self.agents.get(intent, self.agents["fallback"])
```

### 2. Context Manager

```python
from typing import Dict, Any, Optional
from pydantic import BaseModel
import json
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession

class UserProfile(BaseModel):
    """User profile information"""
    user_id: str
    dietary_preferences: Dict[str, bool] = {}
    cooking_skill_level: str = "beginner"
    favorite_cuisines: list[str] = []
    disliked_ingredients: list[str] = []

class CookingState(BaseModel):
    """Current cooking activity state"""
    active_recipe_id: Optional[str] = None
    current_step: Optional[int] = None
    started_at: Optional[datetime] = None
    timer_end_times: Dict[str, datetime] = {}

class AgentContext(BaseModel):
    """Complete context for agent operations"""
    user_profile: UserProfile
    cooking_state: Optional[CookingState] = None
    conversation_history: list[Dict[str, Any]] = []
    session_id: Optional[str] = None

class ContextManager:
    """Manages context for agent interactions"""
    
    def __init__(self, db_session: AsyncSession):
        self.db = db_session
        self.cache = {}  # Simple in-memory cache
    
    async def get_context(self, user_id: str) -> AgentContext:
        """Retrieve the current context for a user"""
        # Check cache first
        if user_id in self.cache:
            return self.cache[user_id]
        
        # Otherwise load from database
        user_profile = await self._load_user_profile(user_id)
        cooking_state = await self._load_cooking_state(user_id)
        conversation_history = await self._load_conversation_history(user_id)
        session_id = await self._get_or_create_session(user_id)
        
        context = AgentContext(
            user_profile=user_profile,
            cooking_state=cooking_state,
            conversation_history=conversation_history,
            session_id=session_id
        )
        
        # Update cache
        self.cache[user_id] = context
        
        return context
    
    async def update_context(self, user_id: str, agent_response: Dict[str, Any]):
        """Update context with new information from an agent response"""
        context = await self.get_context(user_id)
        
        # Add to conversation history
        context.conversation_history.append({
            "role": "assistant",
            "content": agent_response["content"],
            "timestamp": datetime.now().isoformat(),
            "metadata": agent_response.get("metadata", {})
        })
        
        # Update cooking state if changed
        if agent_response.get("cooking_state_update"):
            context.cooking_state = self._merge_cooking_state(
                context.cooking_state, 
                agent_response["cooking_state_update"]
            )
        
        # Save to database
        await self._save_context(user_id, context)
        
        # Update cache
        self.cache[user_id] = context
    
    # Helper methods to interact with database
    async def _load_user_profile(self, user_id: str) -> UserProfile:
        """Load user profile from database"""
        # Implementation with SQL queries
        pass
    
    async def _load_cooking_state(self, user_id: str) -> Optional[CookingState]:
        """Load current cooking state from database"""
        # Implementation with SQL queries
        pass
    
    async def _load_conversation_history(self, user_id: str, limit: int = 20) -> list:
        """Load recent conversation history"""
        # Implementation with SQL queries
        pass
    
    async def _get_or_create_session(self, user_id: str) -> str:
        """Get current session ID or create new one"""
        # Implementation with SQL queries
        pass
    
    async def _save_context(self, user_id: str, context: AgentContext):
        """Save context to database"""
        # Implementation with SQL queries
        pass
    
    def _merge_cooking_state(self, current: CookingState, update: Dict) -> CookingState:
        """Merge updates into current cooking state"""
        # Implementation to handle merging
        pass
```

### 3. Specialized Agents

#### Recipe Assistant Agent

```python
from typing import Dict, List, Optional
from pydantic import BaseModel
import instructor
from openai import AsyncOpenAI
from mcp_agent import Agent, AgentContext

class RecipeRecommendation(BaseModel):
    """Structured recipe recommendation"""
    recipe_id: str
    title: str
    reasoning: str
    matches_preferences: List[str]
    preparation_time: int  # minutes
    skill_level: str

class RecipeAssistantAgent(Agent):
    """Agent specialized in recipe recommendations"""
    
    def __init__(self, openai_client: AsyncOpenAI):
        self.client = instructor.patch(openai_client)
    
    async def execute(self, input_text: str, context: AgentContext) -> Dict:
        """Generate recipe recommendations based on user input and context"""
        
        # Create a prompt with user context and input
        system_prompt = self._create_system_prompt(context)
        
        # Get structured recommendations from LLM
        recommendations = await self.client.chat.completions.create(
            model="gpt-4",
            response_model=List[RecipeRecommendation],
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": input_text}
            ],
            temperature=0.7,
            max_tokens=1000
        )
        
        # Check if recommendations exist in database
        valid_recommendations = await self._validate_recipes(recommendations)
        
        # Create response
        response = {
            "content": self._format_recommendations(valid_recommendations),
            "confidence": 0.9 if valid_recommendations else 0.5,
            "metadata": {
                "recommendations": [r.model_dump() for r in valid_recommendations],
                "recommendation_count": len(valid_recommendations)
            }
        }
        
        return response
    
    def _create_system_prompt(self, context: AgentContext) -> str:
        """Create a system prompt with user context"""
        user_profile = context.user_profile
        
        return f"""You are a helpful cooking assistant that recommends recipes.
        
User Profile:
- Cooking skill: {user_profile.cooking_skill_level}
- Dietary preferences: {', '.join(k for k, v in user_profile.dietary_preferences.items() if v)}
- Favorite cuisines: {', '.join(user_profile.favorite_cuisines)}
- Disliked ingredients: {', '.join(user_profile.disliked_ingredients)}

Your task is to recommend recipes that match the user's preferences and skill level.
Provide reasoning for each recommendation.
"""
    
    async def _validate_recipes(self, recommendations: List[RecipeRecommendation]) -> List[RecipeRecommendation]:
        """Validate that recommended recipes exist in the database"""
        # Implementation with database check
        pass
    
    def _format_recommendations(self, recommendations: List[RecipeRecommendation]) -> str:
        """Format recommendations as a user-friendly message"""
        if not recommendations:
            return "I'm sorry, I couldn't find recipes matching your criteria. Could you tell me more about what you're looking for?"
        
        response = "Here are some recipes you might enjoy:\n\n"
        for i, rec in enumerate(recommendations, 1):
            response += f"{i}. **{rec.title}** ({rec.skill_level}, {rec.preparation_time} min)\n"
            response += f"   {rec.reasoning}\n\n"
        
        response += "Would you like to see more details about any of these recipes?"
        return response
```

### 4. Response Generator

```python
from typing import Dict, Any
from mcp_agent import AgentContext

class ResponseGenerator:
    """Generates final responses from agent outputs"""
    
    def generate(self, agent_response: Dict[str, Any], context: AgentContext) -> Dict[str, Any]:
        """Format the response according to user preferences and UI context"""
        
        # Basic implementation just returns the agent response
        # More advanced implementations would handle:
        # - Adding personality based on user preferences
        # - Formatting for different UI contexts (chat, cards, etc.)
        # - Adding suggestions for follow-up actions
        # - Incorporating multimedia elements
        
        return agent_response
```

## API Endpoints

```python
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from typing import Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession

from .database import get_db_session
from .agents.coordinator import AgentCoordinator
from .agents.context import ContextManager

app = FastAPI()

class UserInput(BaseModel):
    user_id: str
    input_text: str
    session_id: Optional[str] = None

class AgentResponseModel(BaseModel):
    content: str
    suggested_actions: Optional[List[Dict[str, Any]]] = None
    metadata: Optional[Dict[str, Any]] = None

# Dependency to get agent coordinator
async def get_agent_coordinator(db: AsyncSession = Depends(get_db_session)):
    context_manager = ContextManager(db)
    # Initialize all specialized agents
    agents = {
        "recipe": RecipeAssistantAgent(),
        "cooking": CookingAssistantAgent(),
        "planning": MealPlanningAgent(),
        "fallback": FallbackAgent(),
    }
    return AgentCoordinator(agents, context_manager)

@app.post("/api/agent/chat", response_model=AgentResponseModel)
async def agent_chat(
    user_input: UserInput,
    coordinator: AgentCoordinator = Depends(get_agent_coordinator)
):
    """Process a user chat message and return agent response"""
    try:
        response = await coordinator.process_request(
            user_input.user_id, 
            user_input.input_text
        )
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/agent/action/{action_type}")
async def agent_action(
    action_type: str,
    user_input: UserInput,
    coordinator: AgentCoordinator = Depends(get_agent_coordinator)
):
    """Handle specific agent actions like starting a recipe, setting timers, etc."""
    # Implementation specific to different action types
    pass
```

## Database Schema Extensions

To support the agentic workflows, we need to extend the existing database schema with the following tables:

```sql
-- Agent conversation sessions
CREATE TABLE agent_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE,
  session_type VARCHAR(50) DEFAULT 'general'
);

-- Agent messages
CREATE TABLE agent_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES agent_sessions(id) ON DELETE CASCADE,
  is_from_user BOOLEAN NOT NULL,
  content TEXT NOT NULL,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Context references
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  challenge_id UUID REFERENCES daily_challenges(id) ON DELETE SET NULL,
  
  -- Metadata
  intent VARCHAR(100),
  confidence DECIMAL,
  metadata JSONB DEFAULT '{}'::JSONB
);

-- Agent actions (for tracking agent-suggested actions)
CREATE TABLE agent_actions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  message_id UUID REFERENCES agent_messages(id) ON DELETE CASCADE,
  action_type VARCHAR(50) NOT NULL,
  action_data JSONB NOT NULL,
  suggested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(20) DEFAULT 'pending'
);

-- User cooking sessions (for tracking active cooking)
CREATE TABLE cooking_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  current_step INTEGER DEFAULT 0,
  status VARCHAR(20) DEFAULT 'active',
  notes TEXT,
  agent_session_id UUID REFERENCES agent_sessions(id) ON DELETE SET NULL
);
```

## Frontend Integration

The frontend will integrate with the agent system through a React context provider:

```typescript
// AgentContext.tsx
import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase } from '../utils/supabaseClient';

interface AgentContextType {
  sendMessage: (message: string) => Promise<void>;
  messages: AgentMessage[];
  isLoading: boolean;
  suggestedActions: SuggestedAction[];
  executeAction: (actionId: string) => Promise<void>;
}

interface AgentMessage {
  id: string;
  content: string;
  isFromUser: boolean;
  timestamp: Date;
}

interface SuggestedAction {
  id: string;
  label: string;
  actionType: string;
  actionData: any;
}

const AgentContext = createContext<AgentContextType | undefined>(undefined);

export const AgentProvider: React.FC = ({ children }) => {
  const [messages, setMessages] = useState<AgentMessage[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [suggestedActions, setSuggestedActions] = useState<SuggestedAction[]>([]);
  
  // Load conversation history on mount
  useEffect(() => {
    loadConversationHistory();
    
    // Subscribe to real-time updates
    const subscription = supabase
      .channel('agent_messages')
      .on('INSERT', { event: '*', schema: 'public', table: 'agent_messages' }, handleNewMessage)
      .subscribe();
      
    return () => {
      subscription.unsubscribe();
    };
  }, []);
  
  const loadConversationHistory = async () => {
    // Implementation to load history from Supabase
  };
  
  const handleNewMessage = (payload: any) => {
    // Handle real-time message updates
  };
  
  const sendMessage = async (message: string) => {
    setIsLoading(true);
    
    try {
      // Add user message to UI immediately
      const userMessage: AgentMessage = {
        id: 'temp-' + Date.now(),
        content: message,
        isFromUser: true,
        timestamp: new Date()
      };
      
      setMessages(prev => [...prev, userMessage]);
      
      // Send to API
      const response = await fetch('/api/agent/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          user_id: getCurrentUserId(),
          input_text: message
        })
      });
      
      const data = await response.json();
      
      // Add agent response
      const agentMessage: AgentMessage = {
        id: data.id || 'temp-response-' + Date.now(),
        content: data.content,
        isFromUser: false,
        timestamp: new Date()
      };
      
      setMessages(prev => [...prev, agentMessage]);
      
      // Update suggested actions
      if (data.suggested_actions) {
        setSuggestedActions(data.suggested_actions);
      }
    } catch (error) {
      console.error('Error sending message:', error);
      // Add error message
      setMessages(prev => [
        ...prev, 
        {
          id: 'error-' + Date.now(),
          content: 'Sorry, there was an error processing your request.',
          isFromUser: false,
          timestamp: new Date()
        }
      ]);
    } finally {
      setIsLoading(false);
    }
  };
  
  const executeAction = async (actionId: string) => {
    // Implementation to execute a suggested action
  };
  
  const getCurrentUserId = () => {
    // Get current user ID from auth
    return supabase.auth.user()?.id;
  };
  
  return (
    <AgentContext.Provider
      value={{
        sendMessage,
        messages,
        isLoading,
        suggestedActions,
        executeAction
      }}
    >
      {children}
    </AgentContext.Provider>
  );
};

export const useAgent = () => {
  const context = useContext(AgentContext);
  if (context === undefined) {
    throw new Error('useAgent must be used within an AgentProvider');
  }
  return context;
};
```

## Deployment Considerations

1. **API Hosting**
   - Deploy agent API as serverless functions in Supabase Edge Functions
   - Consider separate deployment for high-traffic components

2. **Model Optimization**
   - Implement caching for common queries
   - Consider fine-tuning models for specific tasks
   - Implement fallback to smaller models during high load

3. **Monitoring**
   - Set up OpenTelemetry for tracing agent operations
   - Implement logging for agent decisions
   - Create dashboards for agent performance metrics

4. **Security**
   - Implement rate limiting for agent API
   - Validate all user inputs before processing
   - Filter sensitive information from agent logs

## Development Workflow

1. **Local Development**
   - Create development environment with Supabase local instance
   - Implement mock LLM responses for testing
   - Set up unit tests for agent components

2. **Testing**
   - Unit tests for individual agent components
   - Integration tests for agent coordinator
   - End-to-end tests for complete workflows
   - Performance testing under load

3. **CI/CD**
   - Automated testing on pull requests
   - Deployment pipeline for agent API
   - Versioning system for agent components

## Next Steps for Implementation

1. Set up the basic agent framework
   - Implement Agent Coordinator class
   - Create Context Manager
   - Set up basic API endpoints

2. Implement Recipe Assistant
   - Define structured output models
   - Create system prompts
   - Integrate with recipe database

3. Set up database schema extensions
   - Create new tables for agent interactions
   - Implement migration scripts
   - Set up RLS policies

4. Create frontend integration
   - Implement React context provider
   - Create message UI components
   - Set up real-time message subscription