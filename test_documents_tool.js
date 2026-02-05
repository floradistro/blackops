/**
 * Test Documents Tool - COA Generation
 * Tests the full end-to-end COA generation via the documents API
 */

const DOCUMENTS_API_URL = 'http://localhost:3102/api/tools';

// Flora Distro store ID (from check_flora_bucket.js context)
const STORE_ID = 'cd2e1122-d511-4edb-be5d-98ef274b4baf';

async function testDocuments() {
  console.log('=== Testing Documents Tool ===\n');

  // Test 1: List templates
  console.log('1. Listing available templates...');
  try {
    const listRes = await fetch(DOCUMENTS_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tool: 'documents',
        input: { action: 'list_templates' }
      })
    });
    const listData = await listRes.json();

    if (listData.success && listData.data) {
      const templates = Array.isArray(listData.data) ? listData.data : listData.data.templates || [];
      console.log(`   Found ${templates.length} templates:`);
      templates.forEach(t => {
        console.log(`   - ${t.name} (${t.slug}) - ${t.document_type}`);
      });
    } else {
      console.log('   Response:', JSON.stringify(listData, null, 2));
    }
  } catch (err) {
    console.log('   Error:', err.message);
  }

  console.log('\n2. Testing full COA creation with action=create (generates PDF + uploads)...');

  // Test COA data - cannabis flower sample (matching old COA format)
  const coaData = {
    // Sample identification
    sampleName: 'Lemon Tree',
    clientName: 'Flora Distribution Group LLC',
    clientAddress: '4111 E Rose Lake Dr\nCharlotte, NC 28213',
    strain: 'Lemon Tree',
    sampleType: 'Flower - Cured',
    sampleSize: '1g',
    licenseNumber: 'USDA_37_0979',
    clientState: 'NC',

    // Dates
    dateCollected: '2025-10-12',
    dateReceived: '2025-10-13',
    dateTested: '2025-10-22',

    // ALL cannabinoids (percentages) - include zeros for ND display
    'thca': 29.90,
    'd9_thc': 0.29,
    'd8_thc': 0,        // ND
    'thcv': 0,          // ND
    'cbda': 0,          // ND
    'cbd': 0,           // ND
    'cbn': 0,           // ND
    'cbga': 0.55,
    'cbg': 0.15,
    'cbc': 0,           // ND

    // Moisture
    moisture: 11.18,

    // Lab info
    labDirector: 'Dr. Sarah Mitchell',
    directorTitle: 'Laboratory Director',
  };

  try {
    const genRes = await fetch(DOCUMENTS_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tool: 'documents',
        input: {
          action: 'create',
          data: coaData
        },
        context: {
          storeId: STORE_ID
        }
      })
    });

    const genData = await genRes.json();

    if (genData.success) {
      console.log('   SUCCESS! COA generated:');
      // Log full response structure
      console.log('   Full response data keys:', Object.keys(genData.data || {}));
      console.log(`   - Sample ID: ${genData.data?.sampleId || 'N/A'}`);
      console.log(`   - Batch ID: ${genData.data?.batchId || 'N/A'}`);
      console.log(`   - File URL: ${genData.data?.fileUrl || genData.data?.file_url || 'N/A'}`);
      console.log(`   - Document ID: ${genData.data?.documentId || genData.data?.document_id || 'N/A'}`);

      const fileUrl = genData.data?.fileUrl || genData.data?.file_url;
      // Check if QR code URL is correct
      if (fileUrl) {
        const expectedUrlPattern = `https://www.quantixanalytics.com/coa/${STORE_ID}/`;
        const urlMatch = fileUrl.includes(STORE_ID);
        console.log(`\n   QR URL Check: ${urlMatch ? 'PASS' : 'FAIL'}`);
        console.log(`   File URL: ${fileUrl}`);
      }
    } else {
      console.log('   FAILED:', genData.error || JSON.stringify(genData, null, 2));
    }
  } catch (err) {
    console.log('   Error:', err.message);
  }

  console.log('\n3. Testing with action=generate_pdf (PDF only, no storage)...');
  try {
    const pdfRes = await fetch(DOCUMENTS_API_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        tool: 'documents',
        input: {
          action: 'generate_pdf',
          data: {
            ...coaData,
            sampleName: 'Purple Haze Test',
            strain: 'Purple Haze',
          }
        },
        context: {
          storeId: STORE_ID
        }
      })
    });

    const pdfData = await pdfRes.json();

    if (pdfData.success) {
      const pdfOutput = pdfData.data;
      console.log('   SUCCESS! PDF generated:');
      console.log(`   - Size: ${pdfOutput?.size ? Math.round(pdfOutput.size / 1024) + ' KB' : 'N/A'}`);
      console.log(`   - Has base64 data: ${pdfOutput?.data ? 'Yes (' + pdfOutput.data.length + ' chars)' : 'No'}`);
    } else {
      console.log('   FAILED:', pdfData.error || JSON.stringify(pdfData));
    }
  } catch (err) {
    console.log('   Error:', err.message);
  }

  console.log('\n=== Test Complete ===');
}

testDocuments().catch(console.error);
