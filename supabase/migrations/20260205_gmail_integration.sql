-- Gmail Integration Tables
-- Store OAuth tokens and sync state for connected Gmail accounts

-- Connected email accounts (Gmail, Outlook, etc.)
CREATE TABLE IF NOT EXISTS store_email_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Account info
    email_address TEXT NOT NULL,
    display_name TEXT,
    provider TEXT NOT NULL DEFAULT 'gmail', -- gmail, outlook, imap

    -- OAuth tokens (encrypted in practice, stored as-is for now)
    access_token TEXT,
    refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,

    -- Sync state
    is_active BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMPTZ,
    last_history_id TEXT, -- Gmail history ID for incremental sync
    sync_error TEXT,

    -- Settings
    sync_enabled BOOLEAN DEFAULT true,
    auto_reply_enabled BOOLEAN DEFAULT false,
    ai_enabled BOOLEAN DEFAULT true,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(store_id, email_address)
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_email_accounts_store ON store_email_accounts(store_id);
CREATE INDEX IF NOT EXISTS idx_email_accounts_email ON store_email_accounts(email_address);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_email_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS email_accounts_updated_at ON store_email_accounts;
CREATE TRIGGER email_accounts_updated_at
    BEFORE UPDATE ON store_email_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_email_accounts_updated_at();

-- Store Google OAuth state for CSRF protection
CREATE TABLE IF NOT EXISTS oauth_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    state TEXT UNIQUE NOT NULL,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    provider TEXT NOT NULL DEFAULT 'gmail',
    redirect_uri TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ DEFAULT NOW() + INTERVAL '10 minutes'
);

-- Clean up expired states
CREATE INDEX IF NOT EXISTS idx_oauth_states_expires ON oauth_states(expires_at);

-- Function to clean expired oauth states (call periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_oauth_states()
RETURNS void AS $$
BEGIN
    DELETE FROM oauth_states WHERE expires_at < NOW();
END;
$$ LANGUAGE plpgsql;

-- RLS Policies
ALTER TABLE store_email_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE oauth_states ENABLE ROW LEVEL SECURITY;

-- Allow service role full access
CREATE POLICY "Service role can manage email accounts"
    ON store_email_accounts FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role can manage oauth states"
    ON oauth_states FOR ALL
    USING (true)
    WITH CHECK (true);

-- Comments
COMMENT ON TABLE store_email_accounts IS 'Connected email accounts for stores (Gmail, Outlook, etc.)';
COMMENT ON TABLE oauth_states IS 'Temporary OAuth state tokens for CSRF protection';

-- ============================================================================
-- Add Gmail-specific columns to email tables
-- ============================================================================

-- Add external_thread_id for Gmail thread tracking
ALTER TABLE email_threads ADD COLUMN IF NOT EXISTS external_thread_id TEXT;
CREATE INDEX IF NOT EXISTS idx_email_threads_external ON email_threads(store_id, external_thread_id) WHERE external_thread_id IS NOT NULL;

-- Add external_id and source columns to email_inbox
ALTER TABLE email_inbox ADD COLUMN IF NOT EXISTS external_id TEXT;
ALTER TABLE email_inbox ADD COLUMN IF NOT EXISTS source TEXT DEFAULT 'resend';
ALTER TABLE email_inbox ADD COLUMN IF NOT EXISTS is_inbound BOOLEAN;
ALTER TABLE email_inbox ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;
ALTER TABLE email_inbox ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ;

-- Index for Gmail message deduplication
CREATE UNIQUE INDEX IF NOT EXISTS idx_email_inbox_external_id ON email_inbox(external_id) WHERE external_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_inbox_source ON email_inbox(store_id, source);

COMMENT ON COLUMN email_threads.external_thread_id IS 'External thread ID (Gmail threadId, etc.)';
COMMENT ON COLUMN email_inbox.external_id IS 'External message ID (Gmail message id, etc.)';
COMMENT ON COLUMN email_inbox.source IS 'Email source: gmail, outlook, resend, imap';
