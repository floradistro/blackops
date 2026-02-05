-- Multi-tenant email domain management
-- Allows each store to have their own email domain(s) managed through the platform's Resend account

-- Store Email Domains: tracks domains registered for each store
CREATE TABLE IF NOT EXISTS store_email_domains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,

    -- Domain configuration
    domain TEXT NOT NULL,                    -- e.g., "floradistro.com"
    inbound_subdomain TEXT DEFAULT 'in',     -- e.g., "in" for in.floradistro.com

    -- Resend integration
    resend_domain_id TEXT,                   -- Resend API domain ID
    resend_region TEXT DEFAULT 'us-east-1',

    -- Status tracking
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verifying', 'verified', 'failed')),
    receiving_enabled BOOLEAN DEFAULT false,
    sending_verified BOOLEAN DEFAULT false,

    -- DNS records (stored for display to user)
    dns_records JSONB DEFAULT '[]'::jsonb,   -- Array of {type, name, value, priority, status}

    -- Timestamps
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    UNIQUE(domain),  -- Each domain can only belong to one store
    UNIQUE(store_id, domain)
);

-- Store Email Addresses: mailboxes configured for each store
CREATE TABLE IF NOT EXISTS store_email_addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
    domain_id UUID NOT NULL REFERENCES store_email_domains(id) ON DELETE CASCADE,

    -- Address configuration
    address TEXT NOT NULL,                   -- e.g., "support", "orders", "returns"
    display_name TEXT,                       -- e.g., "Flora Distro Support"

    -- Mailbox type for routing/categorization
    mailbox_type TEXT DEFAULT 'general' CHECK (mailbox_type IN ('support', 'orders', 'returns', 'info', 'general', 'custom')),

    -- AI configuration
    ai_enabled BOOLEAN DEFAULT true,         -- Whether AI can draft replies
    ai_auto_reply BOOLEAN DEFAULT false,     -- Whether AI can send without approval

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints: unique address per domain
    UNIQUE(domain_id, address)
);

-- Indexes for efficient lookups
CREATE INDEX idx_store_email_domains_store ON store_email_domains(store_id);
CREATE INDEX idx_store_email_domains_domain ON store_email_domains(domain);
CREATE INDEX idx_store_email_domains_status ON store_email_domains(status);
CREATE INDEX idx_store_email_addresses_store ON store_email_addresses(store_id);
CREATE INDEX idx_store_email_addresses_domain ON store_email_addresses(domain_id);
CREATE INDEX idx_store_email_addresses_type ON store_email_addresses(mailbox_type);

-- Function to get store_id from inbound email address
-- Used by inbound-email webhook to route emails to correct store
CREATE OR REPLACE FUNCTION get_store_from_email_address(email_address TEXT)
RETURNS TABLE(store_id UUID, domain_id UUID, address_id UUID, mailbox_type TEXT, ai_enabled BOOLEAN) AS $$
DECLARE
    v_local_part TEXT;
    v_domain_part TEXT;
    v_subdomain TEXT;
    v_base_domain TEXT;
BEGIN
    -- Parse email: support@in.floradistro.com
    v_local_part := split_part(email_address, '@', 1);      -- "support"
    v_domain_part := split_part(email_address, '@', 2);     -- "in.floradistro.com"

    -- Extract subdomain and base domain
    -- e.g., "in.floradistro.com" → subdomain="in", base_domain="floradistro.com"
    v_subdomain := split_part(v_domain_part, '.', 1);       -- "in"
    v_base_domain := substr(v_domain_part, length(v_subdomain) + 2);  -- "floradistro.com"

    RETURN QUERY
    SELECT
        d.store_id,
        d.id as domain_id,
        a.id as address_id,
        COALESCE(a.mailbox_type, 'general')::TEXT as mailbox_type,
        COALESCE(a.ai_enabled, true) as ai_enabled
    FROM store_email_domains d
    LEFT JOIN store_email_addresses a ON a.domain_id = d.id AND a.address = v_local_part AND a.is_active = true
    WHERE d.domain = v_base_domain
      AND d.inbound_subdomain = v_subdomain
      AND d.status = 'verified'
      AND d.receiving_enabled = true
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update timestamps
CREATE OR REPLACE FUNCTION update_email_domain_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_store_email_domains_updated
    BEFORE UPDATE ON store_email_domains
    FOR EACH ROW
    EXECUTE FUNCTION update_email_domain_timestamp();

CREATE TRIGGER trigger_store_email_addresses_updated
    BEFORE UPDATE ON store_email_addresses
    FOR EACH ROW
    EXECUTE FUNCTION update_email_domain_timestamp();

-- Enable RLS
ALTER TABLE store_email_domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE store_email_addresses ENABLE ROW LEVEL SECURITY;

-- RLS policies (service role bypasses, anon blocked)
CREATE POLICY "Service role full access to domains" ON store_email_domains
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Service role full access to addresses" ON store_email_addresses
    FOR ALL USING (auth.role() = 'service_role');

-- Seed Flora Distro's existing domain
INSERT INTO store_email_domains (store_id, domain, inbound_subdomain, resend_domain_id, status, receiving_enabled, sending_verified, dns_records, verified_at)
SELECT
    id,
    'floradistro.com',
    'in',
    '3f6e0e81-86c8-43fb-ac42-1e94c4b23b00',
    'verified',
    true,
    false,  -- sending records still pending
    '[
        {"record": "Receiving", "name": "in", "type": "MX", "value": "inbound-smtp.us-east-1.amazonaws.com", "priority": 10, "status": "verified"},
        {"record": "DKIM", "name": "resend._domainkey.in", "type": "TXT", "value": "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDMHK5jJcjzby7He6lUWGwNkycAsKaMf30CfWyDf+Wo9IVHckEgL45LV7qmQ2fXFCxwDDjZf3E0gR/VCVRJk2opgqX63bL+4Mo/JV03C+roxnlDA1jZ0YG3sRdRTmE+mDFcS1TfHhwyp7U8wf2pabBcWIENpvmHAW1Uz2NLfjmK4wIDAQAB", "status": "pending"},
        {"record": "SPF", "name": "send.in", "type": "MX", "value": "feedback-smtp.us-east-1.amazonses.com", "priority": 10, "status": "pending"},
        {"record": "SPF", "name": "send.in", "type": "TXT", "value": "v=spf1 include:amazonses.com ~all", "status": "pending"}
    ]'::jsonb,
    NOW()
FROM stores
WHERE store_name ILIKE '%flora%'
LIMIT 1
ON CONFLICT (domain) DO NOTHING;

-- Seed default email addresses for Flora Distro
INSERT INTO store_email_addresses (store_id, domain_id, address, display_name, mailbox_type, ai_enabled)
SELECT
    d.store_id,
    d.id,
    addr.address,
    addr.display_name,
    addr.mailbox_type,
    true
FROM store_email_domains d
CROSS JOIN (VALUES
    ('support', 'Flora Distro Support', 'support'),
    ('orders', 'Flora Distro Orders', 'orders'),
    ('returns', 'Flora Distro Returns', 'returns'),
    ('info', 'Flora Distro Info', 'info')
) AS addr(address, display_name, mailbox_type)
WHERE d.domain = 'floradistro.com'
ON CONFLICT (domain_id, address) DO NOTHING;

COMMENT ON TABLE store_email_domains IS 'Email domains registered for each store via platform Resend account';
COMMENT ON TABLE store_email_addresses IS 'Email addresses/mailboxes configured per store domain';
COMMENT ON FUNCTION get_store_from_email_address IS 'Routes inbound emails to correct store based on recipient address';
