-- ==========================================
-- 阿德莱德老年大学校园论坛 数据库
-- Supabase SQL Schema
-- ==========================================

-- 1. 版块分类
CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT UNIQUE NOT NULL,
    icon TEXT NOT NULL,
    sort_order INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO categories (name, slug, icon, sort_order) VALUES
('活动报名', 'events', '📢', 1),
('生活互助', 'life-help', '🏠', 2),
('健康养生', 'health', '🩺', 3),
('儿孙天地', 'family', '👨‍👩‍👧‍👦', 4),
('才艺晒晒', 'talent', '🎨', 5),
('二手转让', 'market', '🛒', 6);

-- 2. 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nickname TEXT NOT NULL,
    login_type TEXT DEFAULT 'guest' CHECK (login_type IN ('guest','wechat','phone')),
    wechat_id TEXT UNIQUE,
    phone TEXT UNIQUE,
    avatar_emoji TEXT DEFAULT '🐼',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ DEFAULT NOW(),
    login_streak INT DEFAULT 0,
    total_posts INT DEFAULT 0,
    total_replies INT DEFAULT 0,
    total_likes_received INT DEFAULT 0
);

-- 3. 帖子表
CREATE TABLE posts (
    id SERIAL PRIMARY KEY,
    category_id INT REFERENCES categories(id),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    guest_nickname TEXT,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    likes INT DEFAULT 0,
    reply_count INT DEFAULT 0,
    is_pinned BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_posts_category ON posts(category_id);
CREATE INDEX idx_posts_created ON posts(created_at DESC);

-- 4. 回复表
CREATE TABLE replies (
    id SERIAL PRIMARY KEY,
    post_id INT REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    guest_nickname TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_replies_post ON replies(post_id);

-- 5. 点赞表
CREATE TABLE post_likes (
    post_id INT REFERENCES posts(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- 6. 成就系统
CREATE TABLE achievements (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    icon TEXT NOT NULL,
    category TEXT NOT NULL,
    condition_type TEXT NOT NULL,
    condition_value INT NOT NULL
);

INSERT INTO achievements (id, name, description, icon, category, condition_type, condition_value) VALUES
-- 参与类
('first-post', '冒个泡', '发布了第一条帖子', '💬', 'post', 'total_posts', 1),
('talker-5', '话匣子', '发布了 5 条帖子', '🗣️', 'post', 'total_posts', 5),
('star-20', '社区明星', '发布了 20 条帖子', '⭐', 'post', 'total_posts', 20),
('legend-50', '灵魂人物', '发布了 50 条帖子', '👑', 'post', 'total_posts', 50),
-- 回复类
('first-reply', '热心肠', '回复了第一条帖子', '💛', 'reply', 'total_replies', 1),
('helper-10', '捧场王', '回复了 10 条帖子', '👏', 'reply', 'total_replies', 10),
('helper-30', '知心大姐', '回复了 30 条帖子', '🤝', 'reply', 'total_replies', 30),
-- 点赞类
('liked-20', '点赞达人', '累计获得 20 个赞', '👍', 'likes', 'total_likes_received', 20),
('liked-100', '万人迷', '累计获得 100 个赞', '🌟', 'likes', 'total_likes_received', 100),
-- 坚持类
('streak-3', '常回家看看', '连续 3 天登录', '📅', 'streak', 'login_streak', 3),
('streak-7', '风雨无阻', '连续 7 天登录', '🌧️', 'streak', 'login_streak', 7),
('streak-30', '铁粉', '连续 30 天登录', '💪', 'streak', 'login_streak', 30),
-- 分享类
('first-photo', '有图有真相', '发了第一条带照片的帖子', '📷', 'photo', 'photo_posts', 1),
('photo-10', '摄影师', '发了 10 条带图的帖子', '📸', 'photo', 'photo_posts', 10),
-- 专属类
('early-bird', '早起鸟', '早上 6-8 点发过帖', '🌅', 'time', 'early_posts', 1),
('night-owl', '夜猫子', '晚上 8-10 点发过帖', '🌙', 'time', 'night_posts', 1),
-- 注册
('member-90', '老会员', '注册满 90 天', '🎂', 'member', 'days_registered', 90),
('member-365', '元老级', '注册满 365 天', '🏆', 'member', 'days_registered', 365);

-- 7. 用户成就关联
CREATE TABLE user_achievements (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    achievement_id TEXT REFERENCES achievements(id),
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, achievement_id)
);

-- 8. 游客临时身份（浏览器关闭失效）
-- 由前端 SessionStorage 管理，不存数据库

-- ==========================================
-- 索引和权限
-- ==========================================

-- 启用 RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE replies ENABLE ROW LEVEL SECURITY;
ALTER TABLE post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;

-- 公开读取
CREATE POLICY "Public read" ON posts FOR SELECT USING (true);
CREATE POLICY "Public read" ON replies FOR SELECT USING (true);
CREATE POLICY "Public read" ON users FOR SELECT USING (true);
CREATE POLICY "Public read" ON categories FOR SELECT USING (true);
CREATE POLICY "Public read" ON achievements FOR SELECT USING (true);

-- 任何人都可以创建帖子（包括游客）
CREATE POLICY "Anyone can post" ON posts FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can reply" ON replies FOR INSERT WITH CHECK (true);

-- 用户只能编辑自己的帖子
CREATE POLICY "Own post update" ON posts FOR UPDATE USING (user_id = auth.uid() OR user_id IS NULL);
CREATE POLICY "Own reply update" ON replies FOR UPDATE USING (user_id = auth.uid() OR user_id IS NULL);

-- 任何人都可以点赞
CREATE POLICY "Anyone can like" ON post_likes FOR INSERT WITH CHECK (true);
CREATE POLICY "Anyone can unlike" ON post_likes FOR DELETE USING (true);
