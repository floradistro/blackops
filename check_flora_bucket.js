const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://uaednwpxursknmwdeejn.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI'
);

async function check() {
  // List ALL stores first with all columns
  const { data: allStores, error: allErr } = await supabase
    .from('stores')
    .select('*')
    .limit(20);

  console.log('=== ALL STORES ===');
  if (allErr) console.log('Error:', allErr.message);
  if (allStores && allStores.length > 0) {
    console.log('Columns:', Object.keys(allStores[0]).join(', '));
    for (const s of allStores) {
      console.log('- id:' + s.id + ' slug:' + s.slug + ' business:' + (s.business_name || s.display_name || 'N/A'));
    }
  }

  // Find Flora Distro store by slug
  const { data: stores, error: storeErr } = await supabase
    .from('stores')
    .select('*')
    .ilike('slug', '%flora%');

  console.log('\n=== FLORA DISTRO STORE ===');
  console.log(JSON.stringify(stores, null, 2));

  if (stores && stores.length > 0) {
    const storeId = stores[0].id;
    console.log('\nStore ID:', storeId);

    // List buckets
    const { data: buckets } = await supabase.storage.listBuckets();
    console.log('\n=== ALL BUCKETS ===');
    if (buckets) {
      for (const b of buckets) {
        console.log('- ' + b.name + ' (' + b.id + ')');
      }
    }

    // Check the correct bucket: store-coas (vendor-coas)
    const coaBucket = 'store-coas';
    const { data: files, error: listErr } = await supabase.storage
      .from(coaBucket)
      .list(storeId, { limit: 20 });

    console.log('\n=== FILES IN store-coas/' + storeId + '/ ===');
    if (listErr) {
      console.log('Error:', listErr.message);
    } else if (!files || files.length === 0) {
      console.log('(empty - no files)');
    } else {
      for (const f of files) {
        console.log('- ' + f.name);
      }
    }

    // Also check root of store-coas bucket
    const { data: rootFiles } = await supabase.storage
      .from(coaBucket)
      .list('', { limit: 30 });

    console.log('\n=== ROOT OF store-coas/ BUCKET (all store folders) ===');
    if (rootFiles) {
      for (const f of rootFiles) {
        console.log('- ' + f.name);
      }
    }

    // Check Quantix Analytics store-coas as well (the lab)
    const quantixId = 'bb73275b-edeb-4d1f-9c51-ddc57fa3a19b';
    const { data: quantixFiles } = await supabase.storage
      .from(coaBucket)
      .list(quantixId, { limit: 20 });

    console.log('\n=== FILES IN store-coas/' + quantixId + '/ (Quantix Analytics) ===');
    if (!quantixFiles || quantixFiles.length === 0) {
      console.log('(empty)');
    } else {
      for (const f of quantixFiles) {
        console.log('- ' + f.name);
      }
    }

    // Check recent COA documents in database
    const { data: docs } = await supabase
      .from('coa_documents')
      .select('id, store_id, slug, file_path, created_at')
      .eq('store_id', storeId)
      .order('created_at', { ascending: false })
      .limit(5);

    console.log('\n=== RECENT COA DOCUMENTS FOR FLORA DISTRO ===');
    if (!docs || docs.length === 0) {
      console.log('(none found)');
    } else {
      for (const d of docs) {
        console.log('- ' + d.slug + ': ' + d.file_path + ' (' + d.created_at + ')');
      }
    }

    // Check store_documents table for recent COAs
    const { data: storeDocs, error: storeDocsErr } = await supabase
      .from('store_documents')
      .select('id, store_id, document_type, document_name, file_url, created_at')
      .eq('document_type', 'coa')
      .order('created_at', { ascending: false })
      .limit(20);

    console.log('\n=== ALL RECENT COAs IN store_documents TABLE ===');
    if (storeDocsErr) console.log('Error:', storeDocsErr.message);
    else if (!storeDocs || storeDocs.length === 0) console.log('(none found)');
    else {
      for (const d of storeDocs) {
        console.log('- store:' + d.store_id + ' name:' + (d.document_name || 'unnamed') + ' url:' + (d.file_url || 'no-url'));
      }
    }

    // Check coa_documents table too
    const { data: coaDocs } = await supabase
      .from('coa_documents')
      .select('id, store_id, slug, file_path, created_at')
      .order('created_at', { ascending: false })
      .limit(10);

    console.log('\n=== ALL RECENT coa_documents ===');
    if (!coaDocs || coaDocs.length === 0) console.log('(none found)');
    else {
      for (const d of coaDocs) {
        console.log('- store:' + d.store_id + ' slug:' + d.slug + ' path:' + d.file_path);
      }
    }
  }
}

check().catch(console.error);
