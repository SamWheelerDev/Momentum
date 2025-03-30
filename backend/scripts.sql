-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  auth_id UUID UNIQUE REFERENCES auth.users NOT NULL,
  username VARCHAR(50) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_login TIMESTAMP WITH TIME ZONE,
  xp_points INTEGER DEFAULT 0,
  level INTEGER DEFAULT 1,
  dietary_preferences JSONB DEFAULT '{}'::JSONB,
  cooking_skill_level VARCHAR(20) DEFAULT 'beginner',
  is_admin BOOLEAN DEFAULT FALSE
);

-- Recipes table
CREATE TABLE recipes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(100) NOT NULL,
  description TEXT,
  difficulty_level VARCHAR(20) NOT NULL,
  prep_time_minutes INTEGER NOT NULL,
  cook_time_minutes INTEGER NOT NULL,
  servings INTEGER NOT NULL,
  image_url VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  xp_reward INTEGER DEFAULT 10,
  instructions JSONB NOT NULL,
  visibility VARCHAR(20) DEFAULT 'public',
  created_by_admin BOOLEAN DEFAULT FALSE,
  featured BOOLEAN DEFAULT FALSE
);

-- Ingredients table
CREATE TABLE ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) UNIQUE NOT NULL,
  category VARCHAR(50)
);

-- Recipe ingredients junction table
CREATE TABLE recipe_ingredients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE CASCADE,
  quantity DECIMAL NOT NULL,
  unit VARCHAR(30),
  notes VARCHAR(255),
  UNIQUE(recipe_id, ingredient_id)
);

-- Achievements table
CREATE TABLE achievements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  badge_image_url VARCHAR(255),
  xp_reward INTEGER DEFAULT 25,
  category VARCHAR(50) NOT NULL
);

-- User achievements junction table
CREATE TABLE user_achievements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  achievement_id UUID REFERENCES achievements(id) ON DELETE CASCADE,
  earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, achievement_id)
);

-- Daily challenges table
CREATE TABLE daily_challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  xp_reward INTEGER DEFAULT 15,
  difficulty VARCHAR(20) DEFAULT 'beginner',
  is_active BOOLEAN DEFAULT TRUE
);

-- User challenges junction table
CREATE TABLE user_challenges (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  challenge_id UUID REFERENCES daily_challenges(id) ON DELETE CASCADE,
  started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  completed_at TIMESTAMP WITH TIME ZONE,
  status VARCHAR(20) DEFAULT 'active',
  UNIQUE(user_id, challenge_id)
);

-- Cooking logs table
CREATE TABLE cooking_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  cooked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  notes TEXT,
  rating SMALLINT,
  xp_earned INTEGER,
  photo_url VARCHAR(255)
);

-- User preferences table
CREATE TABLE user_preferences (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  notification_enabled BOOLEAN DEFAULT TRUE,
  theme VARCHAR(20) DEFAULT 'light',
  measurement_system VARCHAR(10) DEFAULT 'metric'
);

-- User streaks table
CREATE TABLE user_streaks (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  current_streak INTEGER DEFAULT 0,
  longest_streak INTEGER DEFAULT 0,
  last_activity_date DATE,
  streak_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User relationships table for friends feature
CREATE TABLE user_relationships (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  related_user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  relationship_type VARCHAR(20) NOT NULL, -- 'friend', 'blocked', etc.
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, related_user_id)
);

-- Create indexes for frequent queries
CREATE INDEX idx_recipes_difficulty ON recipes(difficulty_level);
CREATE INDEX idx_recipes_user_visibility ON recipes(user_id, visibility);
CREATE INDEX idx_cooking_logs_user ON cooking_logs(user_id);
CREATE INDEX idx_cooking_logs_date ON cooking_logs(cooked_at);
CREATE INDEX idx_user_challenges_status ON user_challenges(user_id, status);
CREATE INDEX idx_user_relationships ON user_relationships(user_id, relationship_type);

-- AI conversation sessions table
CREATE TABLE ai_conversation_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(100),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_activity TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  context JSONB DEFAULT '{}'::JSONB, -- Store session context like current recipe, cooking state
  is_active BOOLEAN DEFAULT TRUE
);

-- Individual messages within conversations
CREATE TABLE ai_conversation_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID REFERENCES ai_conversation_sessions(id) ON DELETE CASCADE,
  is_from_user BOOLEAN NOT NULL, -- TRUE if user message, FALSE if AI response
  message_text TEXT NOT NULL,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Optional references to app entities
  recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL,
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE SET NULL,
  
  -- For tracking AI performance and improvement
  helpful_rating SMALLINT, -- User can rate AI responses
  
  -- For advanced features
  message_type VARCHAR(50) DEFAULT 'text', -- text, image, action, etc.
  metadata JSONB DEFAULT '{}'::JSONB -- Store additional data like detected intents, entities
);

-- Create indexes for performance
CREATE INDEX idx_ai_sessions_user ON ai_conversation_sessions(user_id);
CREATE INDEX idx_ai_sessions_active ON ai_conversation_sessions(user_id, is_active);
CREATE INDEX idx_ai_messages_session ON ai_conversation_messages(session_id);
CREATE INDEX idx_ai_messages_timestamp ON ai_conversation_messages(sent_at);

-- Helper functions for RLS

-- Admin check function
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM users
    WHERE auth_id = auth.uid() AND is_admin = TRUE
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has access to a recipe
CREATE OR REPLACE FUNCTION has_recipe_access(recipe_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id
    AND (
      recipes.user_id = auth.uid() OR
      recipes.visibility = 'public' OR
      (recipes.visibility = 'friends' AND EXISTS (
        SELECT 1 FROM user_relationships
        WHERE user_id = recipes.user_id
        AND related_user_id = auth.uid()
        AND relationship_type = 'friend'
      ))
    )
  ) OR is_admin();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Row Level Security Policies

-- Users table
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

CREATE POLICY users_select_policy ON users
FOR SELECT USING (id = auth.uid() OR is_admin());

CREATE POLICY users_update_policy ON users
FOR UPDATE USING (id = auth.uid() OR is_admin());

-- Recipes table
ALTER TABLE recipes ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipes_select_policy ON recipes
FOR SELECT USING (
  user_id = auth.uid() OR
  visibility = 'public' OR
  (visibility = 'friends' AND EXISTS (
    SELECT 1 FROM user_relationships
    WHERE user_id = recipes.user_id
    AND related_user_id = auth.uid()
    AND relationship_type = 'friend'
  )) OR
  is_admin()
);

CREATE POLICY recipes_insert_policy ON recipes
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY recipes_update_policy ON recipes
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY recipes_delete_policy ON recipes
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- Recipe ingredients junction table
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipe_ingredients_select_policy ON recipe_ingredients
FOR SELECT USING (has_recipe_access(recipe_id));

CREATE POLICY recipe_ingredients_insert_policy ON recipe_ingredients
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_ingredients_update_policy ON recipe_ingredients
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_ingredients_delete_policy ON recipe_ingredients
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

-- Ingredients table (reference data)
ALTER TABLE ingredients ENABLE ROW LEVEL SECURITY;

CREATE POLICY ingredients_select_policy ON ingredients
FOR SELECT USING (true);

CREATE POLICY ingredients_insert_policy ON ingredients
FOR INSERT WITH CHECK (is_admin() OR auth.uid() IS NOT NULL);

CREATE POLICY ingredients_update_policy ON ingredients
FOR UPDATE USING (is_admin());

CREATE POLICY ingredients_delete_policy ON ingredients
FOR DELETE USING (is_admin());

-- Achievements table (reference data)
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY achievements_select_policy ON achievements
FOR SELECT USING (true);

CREATE POLICY achievements_insert_policy ON achievements
FOR INSERT WITH CHECK (is_admin());

CREATE POLICY achievements_update_policy ON achievements
FOR UPDATE USING (is_admin());

CREATE POLICY achievements_delete_policy ON achievements
FOR DELETE USING (is_admin());

-- User achievements junction table
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_achievements_select_policy ON user_achievements
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_achievements_insert_policy ON user_achievements
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY user_achievements_update_policy ON user_achievements
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_achievements_delete_policy ON user_achievements
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- Daily challenges table (reference data)
ALTER TABLE daily_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY daily_challenges_select_policy ON daily_challenges
FOR SELECT USING (true);

CREATE POLICY daily_challenges_insert_policy ON daily_challenges
FOR INSERT WITH CHECK (is_admin());

CREATE POLICY daily_challenges_update_policy ON daily_challenges
FOR UPDATE USING (is_admin());

CREATE POLICY daily_challenges_delete_policy ON daily_challenges
FOR DELETE USING (is_admin());

-- User challenges junction table
ALTER TABLE user_challenges ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_challenges_select_policy ON user_challenges
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_challenges_insert_policy ON user_challenges
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY user_challenges_update_policy ON user_challenges
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_challenges_delete_policy ON user_challenges
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- Cooking logs table
ALTER TABLE cooking_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY cooking_logs_select_policy ON cooking_logs
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY cooking_logs_insert_policy ON cooking_logs
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY cooking_logs_update_policy ON cooking_logs
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY cooking_logs_delete_policy ON cooking_logs
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- User preferences table
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_preferences_select_policy ON user_preferences
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_preferences_insert_policy ON user_preferences
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY user_preferences_update_policy ON user_preferences
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_preferences_delete_policy ON user_preferences
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- User streaks table
ALTER TABLE user_streaks ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_streaks_select_policy ON user_streaks
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_streaks_insert_policy ON user_streaks
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY user_streaks_update_policy ON user_streaks
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_streaks_delete_policy ON user_streaks
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- AI conversation sessions table
ALTER TABLE ai_conversation_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_sessions_select_policy ON ai_conversation_sessions
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY ai_sessions_insert_policy ON ai_conversation_sessions
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY ai_sessions_update_policy ON ai_conversation_sessions
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY ai_sessions_delete_policy ON ai_conversation_sessions
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- AI conversation messages table
ALTER TABLE ai_conversation_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_messages_select_policy ON ai_conversation_messages
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM ai_conversation_sessions
    WHERE ai_conversation_sessions.id = ai_conversation_messages.session_id
    AND (ai_conversation_sessions.user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY ai_messages_insert_policy ON ai_conversation_messages
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM ai_conversation_sessions
    WHERE ai_conversation_sessions.id = session_id
    AND (ai_conversation_sessions.user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY ai_messages_update_policy ON ai_conversation_messages
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM ai_conversation_sessions
    WHERE ai_conversation_sessions.id = session_id
    AND (ai_conversation_sessions.user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY ai_messages_delete_policy ON ai_conversation_messages
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM ai_conversation_sessions
    WHERE ai_conversation_sessions.id = session_id
    AND (ai_conversation_sessions.user_id = auth.uid() OR is_admin())
  )
);

-- User relationships table
ALTER TABLE user_relationships ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_relationships_select_policy ON user_relationships
FOR SELECT USING (user_id = auth.uid() OR related_user_id = auth.uid() OR is_admin());

CREATE POLICY user_relationships_insert_policy ON user_relationships
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY user_relationships_update_policy ON user_relationships
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_relationships_delete_policy ON user_relationships
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- ENHANCEMENT 1: Recipe Versioning

-- Recipe versions table
CREATE TABLE recipe_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  version_number INTEGER NOT NULL,
  modification_notes TEXT,
  modified_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modified_by UUID REFERENCES users(id) ON DELETE SET NULL,
  instructions JSONB NOT NULL,
  UNIQUE(recipe_id, version_number)
);

-- ENHANCEMENT 2: Nutrition Information

-- Nutrition information table for recipes
CREATE TABLE recipe_nutrition (
  recipe_id UUID PRIMARY KEY REFERENCES recipes(id) ON DELETE CASCADE,
  calories INTEGER,
  protein_grams DECIMAL,
  carbs_grams DECIMAL,
  fat_grams DECIMAL,
  fiber_grams DECIMAL,
  sugar_grams DECIMAL,
  sodium_mg DECIMAL,
  calculated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_verified BOOLEAN DEFAULT FALSE,
  additional_nutrients JSONB DEFAULT '{}'::JSONB
);

-- ENHANCEMENT 3: Pantry Management

-- User pantry table
CREATE TABLE user_pantry (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE CASCADE,
  quantity DECIMAL,
  unit VARCHAR(30),
  purchase_date DATE,
  expiry_date DATE,
  storage_location VARCHAR(50),
  notes TEXT,
  UNIQUE(user_id, ingredient_id)
);

-- ENHANCEMENT 4: Shopping Lists

-- Shopping lists table
CREATE TABLE shopping_lists (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  is_active BOOLEAN DEFAULT TRUE
);

-- Shopping list items table
CREATE TABLE shopping_list_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  list_id UUID REFERENCES shopping_lists(id) ON DELETE CASCADE,
  ingredient_id UUID REFERENCES ingredients(id) ON DELETE CASCADE,
  quantity DECIMAL,
  unit VARCHAR(30),
  is_purchased BOOLEAN DEFAULT FALSE,
  added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  notes TEXT,
  UNIQUE(list_id, ingredient_id)
);

-- ENHANCEMENT 5: Recipe Tags/Categories

-- Recipe tags table
CREATE TABLE recipe_tags (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  recipe_id UUID REFERENCES recipes(id) ON DELETE CASCADE,
  tag VARCHAR(50) NOT NULL,
  UNIQUE(recipe_id, tag)
);

-- Tag categories for organization
CREATE TABLE tag_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  parent_category_id UUID REFERENCES tag_categories(id) ON DELETE SET NULL
);

-- ENHANCEMENT 6: Skill Trees

-- Skill categories table
CREATE TABLE skill_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(50) UNIQUE NOT NULL,
  description TEXT,
  icon_url VARCHAR(255),
  prerequisite_skill_id UUID REFERENCES skill_categories(id) ON DELETE SET NULL
);

-- User skills table
CREATE TABLE user_skills (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  skill_category_id UUID REFERENCES skill_categories(id) ON DELETE CASCADE,
  level INTEGER DEFAULT 1,
  xp_points INTEGER DEFAULT 0,
  unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, skill_category_id)
);

-- =============================================
-- SECTION: CONSTRAINTS AND VALIDATIONS
-- =============================================

-- Add check constraint for JSON schema validation
ALTER TABLE recipes
ADD CONSTRAINT validate_recipe_instructions
CHECK (jsonb_typeof(instructions) = 'array');

ALTER TABLE user_preferences
ADD CONSTRAINT validate_preferences_json
CHECK (jsonb_typeof(dietary_preferences) = 'object');

-- =============================================
-- SECTION: INDEXES
-- =============================================

-- Create additional indexes for new tables
CREATE INDEX idx_recipe_versions_recipe ON recipe_versions(recipe_id);
CREATE INDEX idx_user_pantry_user ON user_pantry(user_id);
CREATE INDEX idx_user_pantry_expiry ON user_pantry(expiry_date);
CREATE INDEX idx_shopping_lists_user ON shopping_lists(user_id, is_active);
CREATE INDEX idx_shopping_list_items_list ON shopping_list_items(list_id);
CREATE INDEX idx_shopping_list_items_purchased ON shopping_list_items(list_id, is_purchased);
CREATE INDEX idx_recipe_tags ON recipe_tags(recipe_id);
CREATE INDEX idx_recipe_tags_search ON recipe_tags(tag);
CREATE INDEX idx_user_skills_user ON user_skills(user_id);
CREATE INDEX idx_user_skills_category ON user_skills(skill_category_id);

-- =============================================
-- SECTION: ROW LEVEL SECURITY POLICIES
-- =============================================

-- ROW LEVEL SECURITY POLICIES FOR NEW TABLES

-- Recipe versions
ALTER TABLE recipe_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipe_versions_select_policy ON recipe_versions
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_versions.recipe_id AND has_recipe_access(recipes.id)
  )
);

CREATE POLICY recipe_versions_insert_policy ON recipe_versions
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_versions_update_policy ON recipe_versions
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_versions_delete_policy ON recipe_versions
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

-- Recipe nutrition
ALTER TABLE recipe_nutrition ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipe_nutrition_select_policy ON recipe_nutrition
FOR SELECT USING (has_recipe_access(recipe_id));

CREATE POLICY recipe_nutrition_insert_policy ON recipe_nutrition
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_nutrition_update_policy ON recipe_nutrition
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_nutrition_delete_policy ON recipe_nutrition
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

-- User pantry
ALTER TABLE user_pantry ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_pantry_select_policy ON user_pantry
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_pantry_insert_policy ON user_pantry
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY user_pantry_update_policy ON user_pantry
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_pantry_delete_policy ON user_pantry
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- Shopping lists
ALTER TABLE shopping_lists ENABLE ROW LEVEL SECURITY;

CREATE POLICY shopping_lists_select_policy ON shopping_lists
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY shopping_lists_insert_policy ON shopping_lists
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY shopping_lists_update_policy ON shopping_lists
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY shopping_lists_delete_policy ON shopping_lists
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- Shopping list items
ALTER TABLE shopping_list_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY shopping_list_items_select_policy ON shopping_list_items
FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM shopping_lists
    WHERE shopping_lists.id = shopping_list_items.list_id
    AND (shopping_lists.user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY shopping_list_items_insert_policy ON shopping_list_items
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM shopping_lists
    WHERE shopping_lists.id = list_id
    AND (shopping_lists.user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY shopping_list_items_update_policy ON shopping_list_items
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM shopping_lists
    WHERE shopping_lists.id = list_id
    AND (shopping_lists.user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY shopping_list_items_delete_policy ON shopping_list_items
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM shopping_lists
    WHERE shopping_lists.id = list_id
    AND (shopping_lists.user_id = auth.uid() OR is_admin())
  )
);

-- Recipe tags
ALTER TABLE recipe_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY recipe_tags_select_policy ON recipe_tags
FOR SELECT USING (has_recipe_access(recipe_id));

CREATE POLICY recipe_tags_insert_policy ON recipe_tags
FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_tags_update_policy ON recipe_tags
FOR UPDATE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

CREATE POLICY recipe_tags_delete_policy ON recipe_tags
FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM recipes
    WHERE recipes.id = recipe_id AND (user_id = auth.uid() OR is_admin())
  )
);

-- Tag categories (reference data)
ALTER TABLE tag_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY tag_categories_select_policy ON tag_categories
FOR SELECT USING (true);

CREATE POLICY tag_categories_insert_policy ON tag_categories
FOR INSERT WITH CHECK (is_admin());

CREATE POLICY tag_categories_update_policy ON tag_categories
FOR UPDATE USING (is_admin());

CREATE POLICY tag_categories_delete_policy ON tag_categories
FOR DELETE USING (is_admin());

-- Skill categories (reference data)
ALTER TABLE skill_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY skill_categories_select_policy ON skill_categories
FOR SELECT USING (true);

CREATE POLICY skill_categories_insert_policy ON skill_categories
FOR INSERT WITH CHECK (is_admin());

CREATE POLICY skill_categories_update_policy ON skill_categories
FOR UPDATE USING (is_admin());

CREATE POLICY skill_categories_delete_policy ON skill_categories
FOR DELETE USING (is_admin());

-- User skills
ALTER TABLE user_skills ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_skills_select_policy ON user_skills
FOR SELECT USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_skills_insert_policy ON user_skills
FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin());

CREATE POLICY user_skills_update_policy ON user_skills
FOR UPDATE USING (user_id = auth.uid() OR is_admin());

CREATE POLICY user_skills_delete_policy ON user_skills
FOR DELETE USING (user_id = auth.uid() OR is_admin());

-- Additional useful functions

-- Function to calculate if ingredient is in user's pantry
CREATE OR REPLACE FUNCTION is_ingredient_in_pantry(user_uuid UUID, ingredient_uuid UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM user_pantry
    WHERE user_id = user_uuid
    AND ingredient_id = ingredient_uuid
    AND quantity > 0
    AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if user has all ingredients for a recipe
CREATE OR REPLACE FUNCTION has_all_recipe_ingredients(user_uuid UUID, recipe_uuid UUID)
RETURNS BOOLEAN AS $$
DECLARE
  missing_count INTEGER;
BEGIN
  SELECT COUNT(*)
  INTO missing_count
  FROM recipe_ingredients ri
  WHERE ri.recipe_id = recipe_uuid
  AND NOT EXISTS (
    SELECT 1 FROM user_pantry up
    WHERE up.user_id = user_uuid
    AND up.ingredient_id = ri.ingredient_id
    AND up.quantity > 0
    AND (up.expiry_date IS NULL OR up.expiry_date >= CURRENT_DATE)
  );
  
  RETURN missing_count = 0;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user streak when logging cooking activity
CREATE OR REPLACE FUNCTION update_user_streak() 
RETURNS TRIGGER AS $$
DECLARE
  last_date DATE;
  current_date DATE := CURRENT_DATE;
BEGIN
  -- Get the user's last activity date
  SELECT last_activity_date INTO last_date
  FROM user_streaks
  WHERE user_id = NEW.user_id;
  
  -- If this is their first activity, initialize streak
  IF last_date IS NULL THEN
    INSERT INTO user_streaks (user_id, current_streak, longest_streak, last_activity_date)
    VALUES (NEW.user_id, 1, 1, current_date);
  ELSE
    -- If activity is on the same day, do nothing
    IF last_date = current_date THEN
      RETURN NEW;
    -- If activity is on the next day, increase streak
    ELSIF last_date = current_date - INTERVAL '1 day' THEN
      UPDATE user_streaks
      SET 
        current_streak = current_streak + 1,
        longest_streak = GREATEST(longest_streak, current_streak + 1),
        last_activity_date = current_date,
        streak_updated_at = NOW()
      WHERE user_id = NEW.user_id;
    -- If they missed a day, reset streak
    ELSE
      UPDATE user_streaks
      SET 
        current_streak = 1,
        last_activity_date = current_date,
        streak_updated_at = NOW()
      WHERE user_id = NEW.user_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update streak when logging cooking activity
CREATE TRIGGER update_streak_trigger
AFTER INSERT ON cooking_logs
FOR EACH ROW
EXECUTE FUNCTION update_user_streak();

-- Function to award XP and check for level up
CREATE OR REPLACE FUNCTION award_xp_and_check_level_up(user_uuid UUID, xp_amount INTEGER)
RETURNS BOOLEAN AS $$
DECLARE
  current_xp INTEGER;
  current_level INTEGER;
  xp_threshold INTEGER;
  leveled_up BOOLEAN := FALSE;
BEGIN
  -- Get current user stats
  SELECT xp_points, level INTO current_xp, current_level
  FROM users
  WHERE id = user_uuid;
  
  -- Update XP
  UPDATE users
  SET xp_points = xp_points + xp_amount
  WHERE id = user_uuid;
  
  -- Simple level up logic (can be customized)
  xp_threshold := current_level * 100;
  
  IF (current_xp + xp_amount) >= xp_threshold THEN
    UPDATE users
    SET level = level + 1
    WHERE id = user_uuid;
    
    leveled_up := TRUE;
  END IF;
  
  RETURN leveled_up;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- SECTION: ANALYTICS VIEWS
-- =============================================
-- These views provide valuable metrics for analyzing user behavior, recipe popularity,
-- gamification effectiveness, and overall platform engagement.

-- User activity summary view
CREATE VIEW user_activity_summary AS
SELECT
  u.id AS user_id,
  u.username,
  u.level,
  u.xp_points,
  COUNT(DISTINCT cl.id) AS total_cooking_sessions,
  COUNT(DISTINCT cl.recipe_id) AS unique_recipes_cooked,
  COALESCE(AVG(cl.rating), 0) AS average_recipe_rating,
  MAX(cl.cooked_at) AS last_cooking_date,
  us.current_streak,
  us.longest_streak,
  COUNT(DISTINCT ua.achievement_id) AS achievements_earned,
  COUNT(DISTINCT uc.challenge_id) FILTER (WHERE uc.status = 'completed') AS challenges_completed,
  COUNT(DISTINCT acs.id) AS ai_conversation_count,
  COUNT(DISTINCT acm.id) FILTER (WHERE acm.is_from_user = true) AS user_messages_count,
  COALESCE(AVG(acm.helpful_rating) FILTER (WHERE acm.is_from_user = false), 0) AS avg_ai_helpfulness
FROM
  users u
LEFT JOIN cooking_logs cl ON u.id = cl.user_id
LEFT JOIN user_streaks us ON u.id = us.user_id
LEFT JOIN user_achievements ua ON u.id = ua.user_id
LEFT JOIN user_challenges uc ON u.id = uc.user_id
LEFT JOIN ai_conversation_sessions acs ON u.id = acs.user_id
LEFT JOIN ai_conversation_messages acm ON acs.id = acm.session_id
GROUP BY u.id, u.username, u.level, u.xp_points, us.current_streak, us.longest_streak;

-- Recipe popularity metrics view
CREATE VIEW recipe_popularity_metrics AS
SELECT
  r.id AS recipe_id,
  r.title,
  r.difficulty_level,
  r.user_id AS creator_id,
  u.username AS creator_name,
  COUNT(DISTINCT cl.id) AS times_cooked,
  COUNT(DISTINCT cl.user_id) AS unique_users_cooked,
  COALESCE(AVG(cl.rating), 0) AS average_rating,
  COUNT(cl.rating) AS rating_count,
  MAX(cl.cooked_at) AS last_cooked_date,
  COUNT(DISTINCT rt.tag) AS tag_count,
  r.featured,
  r.created_at,
  r.xp_reward
FROM
  recipes r
LEFT JOIN users u ON r.user_id = u.id
LEFT JOIN cooking_logs cl ON r.id = cl.recipe_id
LEFT JOIN recipe_tags rt ON r.id = rt.recipe_id
WHERE
  r.visibility = 'public' OR r.created_by_admin = true
GROUP BY
  r.id, r.title, r.difficulty_level, r.user_id, u.username, r.featured, r.created_at, r.xp_reward;

-- Daily user engagement metrics view
CREATE VIEW daily_user_engagement AS
SELECT
  DATE(cl.cooked_at) AS activity_date,
  COUNT(DISTINCT cl.user_id) AS active_users,
  COUNT(cl.id) AS cooking_sessions,
  COUNT(DISTINCT cl.recipe_id) AS unique_recipes_cooked,
  COALESCE(AVG(cl.rating), 0) AS average_daily_rating,
  (SELECT COUNT(DISTINCT uc.user_id) 
   FROM user_challenges uc 
   WHERE DATE(uc.completed_at) = DATE(cl.cooked_at) AND uc.status = 'completed') AS users_completing_challenges,
  (SELECT COUNT(DISTINCT ua.user_id) 
   FROM user_achievements ua 
   WHERE DATE(ua.earned_at) = DATE(cl.cooked_at)) AS users_earning_achievements,
  (SELECT COUNT(DISTINCT acs.user_id) 
   FROM ai_conversation_sessions acs 
   WHERE DATE(acs.created_at) = DATE(cl.cooked_at)) AS users_using_ai_assistant
FROM
  cooking_logs cl
GROUP BY
  DATE(cl.cooked_at)
ORDER BY
  activity_date DESC;

-- Gamification effectiveness metrics view
CREATE VIEW gamification_effectiveness AS
SELECT
  a.id AS achievement_id,
  a.name AS achievement_name,
  a.category AS achievement_category,
  COUNT(ua.user_id) AS times_earned,
  MIN(ua.earned_at) AS first_earned_at,
  MAX(ua.earned_at) AS last_earned_at,
  a.xp_reward,
  dc.id AS challenge_id,
  dc.title AS challenge_title,
  dc.difficulty AS challenge_difficulty,
  COUNT(uc.user_id) FILTER (WHERE uc.status = 'completed') AS times_completed,
  COUNT(uc.user_id) FILTER (WHERE uc.status = 'active') AS currently_active,
  COALESCE(
    COUNT(uc.user_id) FILTER (WHERE uc.status = 'completed')::float / 
    NULLIF(COUNT(uc.user_id), 0), 
    0
  ) AS completion_rate,
  dc.xp_reward AS challenge_xp_reward
FROM
  achievements a
FULL OUTER JOIN user_achievements ua ON a.id = ua.achievement_id
FULL OUTER JOIN daily_challenges dc ON true
FULL OUTER JOIN user_challenges uc ON dc.id = uc.challenge_id
GROUP BY
  a.id, a.name, a.category, a.xp_reward, dc.id, dc.title, dc.difficulty, dc.xp_reward;

-- Ingredient popularity metrics view
CREATE VIEW ingredient_popularity AS
SELECT
  i.id AS ingredient_id,
  i.name AS ingredient_name,
  i.category AS ingredient_category,
  COUNT(DISTINCT ri.recipe_id) AS recipes_count,
  COUNT(DISTINCT cl.id) AS times_used_in_cooking,
  COUNT(DISTINCT cl.user_id) AS unique_users_cooked_with,
  COUNT(DISTINCT up.user_id) AS users_in_pantry,
  COALESCE(AVG(up.quantity), 0) AS avg_pantry_quantity,
  COUNT(DISTINCT sli.id) AS times_in_shopping_lists
FROM
  ingredients i
LEFT JOIN recipe_ingredients ri ON i.id = ri.ingredient_id
LEFT JOIN recipes r ON ri.recipe_id = r.id
LEFT JOIN cooking_logs cl ON r.id = cl.recipe_id
LEFT JOIN user_pantry up ON i.id = up.ingredient_id
LEFT JOIN shopping_list_items sli ON i.id = sli.ingredient_id
GROUP BY
  i.id, i.name, i.category;

-- User progression metrics view
CREATE VIEW user_progression_metrics AS
WITH user_monthly_activity AS (
  SELECT
    u.id AS user_id,
    DATE_TRUNC('month', cl.cooked_at) AS month,
    COUNT(cl.id) AS cooking_sessions,
    COUNT(DISTINCT cl.recipe_id) AS unique_recipes,
    SUM(r.xp_reward) AS xp_earned_from_recipes,
    COUNT(DISTINCT ua.achievement_id) AS achievements_earned,
    COUNT(DISTINCT uc.challenge_id) FILTER (WHERE uc.status = 'completed') AS challenges_completed
  FROM
    users u
  LEFT JOIN cooking_logs cl ON u.id = cl.user_id
  LEFT JOIN recipes r ON cl.recipe_id = r.id
  LEFT JOIN user_achievements ua ON u.id = ua.user_id AND DATE_TRUNC('month', ua.earned_at) = DATE_TRUNC('month', cl.cooked_at)
  LEFT JOIN user_challenges uc ON u.id = uc.user_id AND DATE_TRUNC('month', uc.completed_at) = DATE_TRUNC('month', cl.cooked_at)
  WHERE
    cl.cooked_at IS NOT NULL
  GROUP BY
    u.id, DATE_TRUNC('month', cl.cooked_at)
)
SELECT
  u.id AS user_id,
  u.username,
  u.level,
  u.xp_points,
  u.created_at AS join_date,
  COALESCE(AVG(uma.cooking_sessions), 0) AS avg_monthly_cooking_sessions,
  COALESCE(MAX(uma.cooking_sessions), 0) AS max_monthly_cooking_sessions,
  COALESCE(SUM(uma.cooking_sessions), 0) AS total_cooking_sessions,
  COALESCE(SUM(uma.unique_recipes), 0) AS total_unique_recipes,
  COALESCE(SUM(uma.xp_earned_from_recipes), 0) AS total_xp_from_recipes,
  COALESCE(COUNT(DISTINCT uma.month), 0) AS active_months,
  EXTRACT(MONTH FROM AGE(NOW(), u.created_at)) AS months_since_joining,
  COALESCE(COUNT(DISTINCT uma.month) / NULLIF(EXTRACT(MONTH FROM AGE(NOW(), u.created_at)), 0), 0) AS monthly_activity_rate,
  us.current_streak,
  us.longest_streak,
  (SELECT COUNT(*) FROM user_skills WHERE user_id = u.id) AS skills_unlocked,
  (SELECT AVG(level) FROM user_skills WHERE user_id = u.id) AS avg_skill_level
FROM
  users u
LEFT JOIN user_monthly_activity uma ON u.id = uma.user_id
LEFT JOIN user_streaks us ON u.id = us.user_id
GROUP BY
  u.id, u.username, u.level, u.xp_points, u.created_at, us.current_streak, us.longest_streak;

-- AI assistant effectiveness metrics view
CREATE VIEW ai_assistant_effectiveness AS
SELECT
  acs.id AS session_id,
  acs.user_id,
  u.username,
  acs.title AS conversation_title,
  acs.created_at AS session_start,
  MAX(acm.sent_at) AS session_last_activity,
  COUNT(acm.id) AS total_messages,
  COUNT(acm.id) FILTER (WHERE acm.is_from_user = true) AS user_messages,
  COUNT(acm.id) FILTER (WHERE acm.is_from_user = false) AS ai_responses,
  COALESCE(AVG(acm.helpful_rating) FILTER (WHERE acm.is_from_user = false), 0) AS avg_helpfulness_rating,
  COUNT(acm.helpful_rating) FILTER (WHERE acm.is_from_user = false) AS ratings_count,
  COUNT(DISTINCT acm.recipe_id) FILTER (WHERE acm.recipe_id IS NOT NULL) AS recipes_referenced,
  COUNT(DISTINCT acm.ingredient_id) FILTER (WHERE acm.ingredient_id IS NOT NULL) AS ingredients_referenced,
  EXTRACT(EPOCH FROM (MAX(acm.sent_at) - acs.created_at))/60 AS conversation_duration_minutes,
  (SELECT COUNT(*) FROM cooking_logs cl 
   WHERE cl.user_id = acs.user_id AND cl.cooked_at > acs.created_at AND cl.cooked_at < MAX(acm.sent_at) + interval '2 hours') AS cooking_sessions_after_conversation
FROM
  ai_conversation_sessions acs
JOIN users u ON acs.user_id = u.id
LEFT JOIN ai_conversation_messages acm ON acs.id = acm.session_id
GROUP BY
  acs.id, acs.user_id, u.username, acs.title, acs.created_at;

-- User retention cohort analysis view
CREATE VIEW user_retention_cohorts AS
WITH user_cohorts AS (
  SELECT
    id AS user_id,
    DATE_TRUNC('month', created_at) AS cohort_month
  FROM
    users
),
user_monthly_activity AS (
  SELECT
    u.id AS user_id,
    DATE_TRUNC('month', cl.cooked_at) AS activity_month
  FROM
    users u
  JOIN cooking_logs cl ON u.id = cl.user_id
  GROUP BY
    u.id, DATE_TRUNC('month', cl.cooked_at)
)
SELECT
  uc.cohort_month,
  COUNT(DISTINCT uc.user_id) AS cohort_size,
  uma.activity_month,
  COUNT(DISTINCT uma.user_id) AS active_users,
  EXTRACT(MONTH FROM AGE(uma.activity_month, uc.cohort_month)) AS months_since_join,
  ROUND(COUNT(DISTINCT uma.user_id)::numeric / COUNT(DISTINCT uc.user_id) * 100, 2) AS retention_percentage
FROM
  user_cohorts uc
LEFT JOIN user_monthly_activity uma ON uc.user_id = uma.user_id
WHERE
  uma.activity_month >= uc.cohort_month
GROUP BY
  uc.cohort_month, uma.activity_month
ORDER BY
  uc.cohort_month, uma.activity_month;

-- Recipe difficulty analysis view
CREATE VIEW recipe_difficulty_analysis AS
SELECT
  r.difficulty_level,
  COUNT(DISTINCT r.id) AS recipe_count,
  COALESCE(AVG(r.prep_time_minutes + r.cook_time_minutes), 0) AS avg_total_time_minutes,
  COALESCE(AVG(r.xp_reward), 0) AS avg_xp_reward,
  COUNT(DISTINCT cl.id) AS times_cooked,
  COUNT(DISTINCT cl.user_id) AS unique_users,
  COALESCE(AVG(cl.rating), 0) AS avg_rating,
  (SELECT COUNT(*) FROM recipes r2 WHERE r2.difficulty_level = r.difficulty_level AND r2.featured = true) AS featured_count,
  COALESCE(
    COUNT(DISTINCT cl.id)::float / NULLIF(COUNT(DISTINCT r.id), 0),
    0
  ) AS avg_cooks_per_recipe
FROM
  recipes r
LEFT JOIN cooking_logs cl ON r.id = cl.recipe_id
GROUP BY
  r.difficulty_level
ORDER BY
  CASE
    WHEN r.difficulty_level = 'beginner' THEN 1
    WHEN r.difficulty_level = 'intermediate' THEN 2
    WHEN r.difficulty_level = 'advanced' THEN 3
    ELSE 4
  END;

-- User skill development view
CREATE VIEW user_skill_development AS
SELECT
  sc.id AS skill_category_id,
  sc.name AS skill_name,
  sc.description,
  COUNT(DISTINCT us.user_id) AS users_with_skill,
  COALESCE(AVG(us.level), 0) AS avg_skill_level,
  MAX(us.level) AS max_skill_level,
  MIN(us.unlocked_at) AS first_unlocked_at,
  MAX(us.unlocked_at) AS last_unlocked_at,
  COUNT(DISTINCT us.user_id) FILTER (WHERE us.level > 1) AS users_advanced_skill,
  COALESCE(
    COUNT(DISTINCT us.user_id) FILTER (WHERE us.level > 1)::float / 
    NULLIF(COUNT(DISTINCT us.user_id), 0),
    0
  ) AS skill_advancement_rate,
  (SELECT COUNT(DISTINCT r.id) 
   FROM recipes r 
   JOIN cooking_logs cl ON r.id = cl.recipe_id
   JOIN users u ON cl.user_id = u.id
   JOIN user_skills us2 ON u.id = us2.user_id
   WHERE us2.skill_category_id = sc.id) AS recipes_cooked_with_skill
FROM
  skill_categories sc
LEFT JOIN user_skills us ON sc.id = us.skill_category_id
GROUP BY
  sc.id, sc.name, sc.description;
