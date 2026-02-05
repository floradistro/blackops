-- Migration: AI-Powered Email Inbox System
-- Created: 2026-02-06
-- Purpose: Add email_threads and email_inbox tables for inbound email handling
--          with AI-powered classification, threading, and customer/order matching

-- ============================================================================
-- 1. email_threads - Groups related emails into conversations
-- ============================================================================
CREATE TABLE IF NOT EXISTS email_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    customer_id UUID REFERENCES customers(id),
    order_id UUID REFERENCES orders(id),
    subject TEXT,
    mailbox TEXT NOT NULL DEFAULT 'support' CHECK (mailbox IN ('support', 'orders', 'returns', 'info', 'general')),
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'awaiting_reply', 'resolved', 'closed')),
    priority TEXT NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    intent TEXT,
    ai_summary TEXT,
    assigned_to TEXT,
    message_count INT NOT NULL DEFAULT 0,
    unread_count INT NOT NULL DEFAULT 0,
    last_message_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE email_threads IS 'Conversation threads grouping related inbound/outbound emails';
COMMENT ON COLUMN email_threads.mailbox IS 'Derived from to-address prefix: support@, orders@, returns@, info@, or general';
COMMENT ON COLUMN email_threads.intent IS 'AI-classified intent: refund_request, tracking_inquiry, complaint, question, feedback, etc.';
COMMENT ON COLUMN email_threads.ai_summary IS 'AI-generated summary of the thread conversation';

-- ============================================================================
-- 2. email_inbox - Individual messages within threads
-- ============================================================================
CREATE TABLE IF NOT EXISTS email_inbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID REFERENCES stores(id) ON DELETE CASCADE,
    thread_id UUID REFERENCES email_threads(id) ON DELETE CASCADE,
    resend_email_id TEXT,
    direction TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
    from_email TEXT NOT NULL,
    from_name TEXT,
    to_email TEXT NOT NULL,
    to_name TEXT,
    cc TEXT[] DEFAULT '{}',
    bcc TEXT[] DEFAULT '{}',
    subject TEXT,
    body_html TEXT,
    body_text TEXT,
    message_id TEXT,
    in_reply_to TEXT,
    "references" TEXT[] DEFAULT '{}',
    has_attachments BOOLEAN NOT NULL DEFAULT false,
    attachments JSONB DEFAULT '[]'::jsonb,
    status TEXT NOT NULL DEFAULT 'new' CHECK (status IN (
        'new', 'read', 'ai_processing', 'ai_drafted', 'human_review', 'replied', 'closed'
    )),
    ai_draft TEXT,
    ai_intent TEXT,
    ai_confidence FLOAT,
    ai_context JSONB,
    customer_id UUID REFERENCES customers(id),
    order_id UUID REFERENCES orders(id),
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    read_at TIMESTAMPTZ,
    replied_at TIMESTAMPTZ
);

COMMENT ON TABLE email_inbox IS 'Individual inbound and outbound email messages within conversation threads';
COMMENT ON COLUMN email_inbox.resend_email_id IS 'Resend email ID for fetching full content via Receiving API';
COMMENT ON COLUMN email_inbox.message_id IS 'RFC 2822 Message-ID header for threading';
COMMENT ON COLUMN email_inbox.in_reply_to IS 'RFC 2822 In-Reply-To header for thread matching';
COMMENT ON COLUMN email_inbox.ai_draft IS 'AI-generated reply draft for human review';
COMMENT ON COLUMN email_inbox.ai_confidence IS 'AI confidence score 0.0-1.0 for auto-reply decisions';

-- ============================================================================
-- 3. Indexes
-- ============================================================================

-- Thread queries
CREATE INDEX IF NOT EXISTS idx_email_threads_store_status ON email_threads(store_id, status, last_message_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_threads_mailbox ON email_threads(store_id, mailbox, status);
CREATE INDEX IF NOT EXISTS idx_email_threads_customer ON email_threads(customer_id) WHERE customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_threads_order ON email_threads(order_id) WHERE order_id IS NOT NULL;

-- Inbox queries
CREATE INDEX IF NOT EXISTS idx_email_inbox_thread ON email_inbox(thread_id, created_at);
CREATE INDEX IF NOT EXISTS idx_email_inbox_store ON email_inbox(store_id, direction, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_email_inbox_message_id ON email_inbox(message_id) WHERE message_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_inbox_in_reply_to ON email_inbox(in_reply_to) WHERE in_reply_to IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_inbox_customer ON email_inbox(customer_id) WHERE customer_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_email_inbox_resend ON email_inbox(resend_email_id) WHERE resend_email_id IS NOT NULL;

-- ============================================================================
-- 4. Row Level Security
-- ============================================================================
ALTER TABLE email_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_inbox ENABLE ROW LEVEL SECURITY;

-- Service role has full access (edge functions use service role key)
DROP POLICY IF EXISTS "Service role full access on email_threads" ON email_threads;
CREATE POLICY "Service role full access on email_threads"
    ON email_threads FOR ALL USING (true);

DROP POLICY IF EXISTS "Service role full access on email_inbox" ON email_inbox;
CREATE POLICY "Service role full access on email_inbox"
    ON email_inbox FOR ALL USING (true);

-- ============================================================================
-- 5. Realtime
-- ============================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'email_threads'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE email_threads;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'email_inbox'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE email_inbox;
    END IF;
END $$;

-- ============================================================================
-- 6. Helper function: update thread counters after inbox insert
-- ============================================================================
CREATE OR REPLACE FUNCTION update_thread_on_message()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE email_threads SET
            message_count = message_count + 1,
            unread_count = CASE
                WHEN NEW.direction = 'inbound' THEN unread_count + 1
                ELSE unread_count
            END,
            last_message_at = NEW.created_at,
            status = CASE
                WHEN NEW.direction = 'inbound' AND status IN ('resolved', 'awaiting_reply') THEN 'open'
                WHEN NEW.direction = 'outbound' AND status = 'open' THEN 'awaiting_reply'
                ELSE status
            END,
            updated_at = now()
        WHERE id = NEW.thread_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_update_thread_on_message ON email_inbox;
CREATE TRIGGER trg_update_thread_on_message
    AFTER INSERT ON email_inbox
    FOR EACH ROW
    EXECUTE FUNCTION update_thread_on_message();

COMMENT ON FUNCTION update_thread_on_message IS 'Auto-updates thread counters and status when new messages are inserted';
