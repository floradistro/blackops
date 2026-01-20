const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://mlwvzpdxsmzkcvuojeat.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sd3Z6cGR4c216a2N2dW9qZWF0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcxNjY5MzI5MiwiZXhwIjoyMDMyMjY5MjkyfQ.j9y-HQ7-Ye5VNKSvE5rJLhejSR4YzpjRnBb4q2tCEYg';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkStore() {
  const storeId = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';
  
  const { data, error } = await supabase
    .from('stores')
    .select('*')
    .eq('id', storeId)
    .single();
  
  if (error) {
    console.log('❌ Error:', error);
  } else {
    console.log('✅ Store:', data);
  }
}

checkStore();
