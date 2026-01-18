-- Function to safely delete a creation and all its dependencies
CREATE OR REPLACE FUNCTION safe_delete_creation(creation_uuid UUID)
RETURNS TABLE (
    deleted_table TEXT,
    deleted_count INTEGER
) AS $$
DECLARE
    result RECORD;
BEGIN
    -- Delete from all dependent tables first (in order)
    
    -- Delete creation_collection_items
    DELETE FROM creation_collection_items WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'creation_collection_items';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete creation_location_bindings
    DELETE FROM creation_location_bindings WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'creation_location_bindings';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete creation_runtime_context
    DELETE FROM creation_runtime_context WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'creation_runtime_context';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete browser_sessions
    DELETE FROM browser_sessions WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'browser_sessions';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete loyalty_transactions first (they reference user_creation_relationships)
    DELETE FROM loyalty_transactions WHERE customer_id IN 
        (SELECT id FROM user_creation_relationships WHERE creation_id = creation_uuid);
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'loyalty_transactions';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete user_creation_relationships
    DELETE FROM user_creation_relationships WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'user_creation_relationships';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete api_keys
    DELETE FROM api_keys WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'api_keys';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete creation_builds
    DELETE FROM creation_builds WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'creation_builds';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete creation_installs
    DELETE FROM creation_installs WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'creation_installs';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete agents
    DELETE FROM agents WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'agents';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete templates
    DELETE FROM templates WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'templates';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete creation_reviews
    DELETE FROM creation_reviews WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'creation_reviews';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Delete revenue_events
    DELETE FROM revenue_events WHERE creation_id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'revenue_events';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
    -- Finally delete the creation itself
    DELETE FROM creations WHERE id = creation_uuid;
    GET DIAGNOSTICS result.deleted_count = ROW_COUNT;
    deleted_table := 'creations';
    deleted_count := result.deleted_count;
    RETURN NEXT;
    
END;
$$ LANGUAGE plpgsql;