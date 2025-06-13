-- Create the database
CREATE DATABASE social_db;

-- Connect to the new database
\c social_db

-- Install Apache AGE extension
CREATE EXTENSION age;

-- Load the AGE library
LOAD 'age';

-- Set the appropriate search path
SET search_path = ag_catalog, "$user", public;

-- Create the graph
SELECT * FROM ag_catalog.create_graph('social_network');

ALTER DATABASE partitioning_test SET search_path = ag_catalog, public;


-- Step 1.1: Create tables with standard relational integrity
CREATE TABLE IF NOT EXISTS ag_catalog.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ag_catalog.follows (
    id SERIAL PRIMARY KEY,
    follower_id INTEGER REFERENCES ag_catalog.users(id),
    following_id INTEGER REFERENCES ag_catalog.users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, following_id)
);

-- Step 1.2: Create B-Tree indexes for performance on the join table
CREATE INDEX IF NOT EXISTS idx_follows_follower ON ag_catalog.follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following ON ag_catalog.follows(following_id);

-- Step 1.3: Set a fixed seed for reproducible random results
SELECT setseed(0.12345);

-- Step 1.4: Clear existing data for a clean run
TRUNCATE ag_catalog.follows, ag_catalog.users RESTART IDENTITY CASCADE;

-- Step 1.5: Insert 100 users
INSERT INTO ag_catalog.users (username, email)
SELECT
    'user_' || i,
    'user_' || i || '@example.com'
FROM generate_series(1, 100) i;

-- Step 1.6: Create SPECIFIC follow relationships for predictable testing
INSERT INTO ag_catalog.follows (follower_id, following_id) VALUES
-- user_1's direct follows
(1, 17), (1, 19), (1, 33), (1, 34), (1, 41), (1, 48), (1, 50), (1, 65), (1, 72), (1, 74), (1, 25),
-- user_2's mutual connections
(2, 16), (2, 62), (16, 2), (62, 2),
-- Make user_62 popular
(10, 62), (11, 62), (12, 62), (13, 62), (14, 62), (15, 62),
(17, 62), (18, 62), (19, 62), (20, 62), (21, 62), (22, 62), (23, 62), (24, 62),
-- Make user_93 popular
(26, 93), (27, 93), (28, 93), (29, 93), (30, 93), (31, 93), (32, 93), (35, 93),
(36, 93), (37, 93), (38, 93), (39, 93), (40, 93),
-- Create 2-hop connections for user_1 (friend-of-friends)
(17, 10), (17, 11), (17, 13), (17, 14), (17, 15), (17, 16), (17, 18), (17, 100),
(19, 20), (19, 21), (19, 22), (19, 23),
(33, 30), (33, 31), (33, 32),
-- Create a known shortest path from user_1 to user_50 (3 hops)
(25, 45), (45, 50),
-- Add some chain relationships
(41, 42), (42, 43), (43, 44), (44, 45),
(50, 51), (51, 52), (52, 53), (53, 54),
(60, 61), (61, 62), (63, 64), (64, 65),
(90, 91), (91, 92), (92, 93), (93, 94);

-- Step 1.7: Add some more semi-random (but deterministic) relationships
INSERT INTO ag_catalog.follows (follower_id, following_id)
SELECT DISTINCT
    (i % 100) + 1,
    ((i * 7) % 100) + 1
FROM generate_series(1, 150) i
WHERE (i % 100) + 1 != ((i * 7) % 100) + 1
ON CONFLICT (follower_id, following_id) DO NOTHING;

-- RAISE NOTICE 'Relational model setup complete.';

-- =========== PART 2: GRAPH MODEL SETUP (APACHE AGE) ===========

-- Step 2.1: Load AGE extension and set search path
LOAD 'age';
SET search_path = ag_catalog, "$user", public;

-- Step 2.2: Drop graph if it exists for a clean run, then create it
SELECT drop_graph('social_network', true);
SELECT create_graph('social_network');
-- RAISE NOTICE 'Graph schema created.';

-- Step 2.3: Create 100 User nodes using the Cypher query language
SELECT * FROM cypher('social_network', $$
    UNWIND range(1, 100) AS i
    CREATE (u:User {
        id: i,
        username: 'user_' + toString(i),
        email: 'user_' + toString(i) + '@example.com'
    })
$$) AS (result agtype);
-- RAISE NOTICE 'Graph nodes created.';

-- Step 2.4: Create FOLLOWS edges using a list of relationships directly in Cypher
SELECT * FROM cypher('social_network', $$
    UNWIND [
        {follower: 1, following: 17}, {follower: 1, following: 19}, {follower: 1, following: 33},
        {follower: 1, following: 34}, {follower: 1, following: 41}, {follower: 1, following: 48},
        {follower: 1, following: 50}, {follower: 1, following: 65}, {follower: 1, following: 72},
        {follower: 1, following: 74}, {follower: 1, following: 25}, {follower: 2, following: 16},
        {follower: 2, following: 62}, {follower: 16, following: 2}, {follower: 62, following: 2},
        {follower: 10, following: 62}, {follower: 11, following: 62}, {follower: 12, following: 62},
        {follower: 13, following: 62}, {follower: 14, following: 62}, {follower: 15, following: 62},
        {follower: 17, following: 62}, {follower: 18, following: 62}, {follower: 19, following: 62},
        {follower: 20, following: 62}, {follower: 21, following: 62}, {follower: 22, following: 62},
        {follower: 23, following: 62}, {follower: 24, following: 62}, {follower: 26, following: 93},
        {follower: 27, following: 93}, {follower: 28, following: 93}, {follower: 29, following: 93},
        {follower: 30, following: 93}, {follower: 31, following: 93}, {follower: 32, following: 93},
        {follower: 35, following: 93}, {follower: 36, following: 93}, {follower: 37, following: 93},
        {follower: 38, following: 93}, {follower: 39, following: 93}, {follower: 40, following: 93},
        {follower: 17, following: 10}, {follower: 17, following: 11}, {follower: 17, following: 13},
        {follower: 17, following: 14}, {follower: 17, following: 15}, {follower: 17, following: 16},
        {follower: 17, following: 18}, {follower: 17, following: 100}, {follower: 19, following: 20},
        {follower: 19, following: 21}, {follower: 19, following: 22}, {follower: 19, following: 23},
        {follower: 33, following: 30}, {follower: 33, following: 31}, {follower: 33, following: 32},
        {follower: 25, following: 45}, {follower: 45, following: 50}, {follower: 41, following: 42},
        {follower: 42, following: 43}, {follower: 43, following: 44}, {follower: 44, following: 45},
        {follower: 50, following: 51}, {follower: 51, following: 52}, {follower: 52, following: 53},
        {follower: 53, following: 54}, {follower: 60, following: 61}, {follower: 61, following: 62},
        {follower: 63, following: 64}, {follower: 64, following: 65}, {follower: 90, following: 91},
        {follower: 91, following: 92}, {follower: 92, following: 93}, {follower: 93, following: 94}
    ] AS rel
    MATCH (u1:User {id: rel.follower}), (u2:User {id: rel.following})
    CREATE (u1)-[:FOLLOWS]->(u2)
$$) AS (result agtype);
-- RAISE NOTICE 'Graph edges created.';

-- Final confirmation
-- RAISE NOTICE 'Setup complete! The social_db database is ready for the blog post queries.';

ALTER DATABASE social_db SET search_path = ag_catalog, "$user", public;
ALTER DATABASE social_db SET session_preload_libraries = 'age';
