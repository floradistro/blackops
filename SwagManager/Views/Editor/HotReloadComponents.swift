import SwiftUI
import WebKit

// MARK: - Hot Reload Components
// Extracted from EditorView.swift to reduce file size
// These components provide live React rendering for creations

// MARK: - Hot Reload Renderer

struct HotReloadRenderer: View {
    let code: String
    let creationId: String
    let refreshTrigger: UUID

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var currentCode: String = ""
    @State private var hasInitialized = false
    @State private var opacity: Double = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            HotReloadWebView(
                html: buildRenderHTML(code: currentCode),
                isLoading: $isLoading,
                loadError: $loadError
            )
            .id(currentCode.hashValue)
            .opacity(opacity)

            if isLoading && !hasInitialized {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .colorScheme(.dark)
                    Text("Rendering...")
                        .foregroundStyle(.white)
                }
            }

            if currentCode.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundStyle(.gray)
                    Text("No code to preview")
                        .foregroundStyle(.gray)
                }
            }

            if let error = loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Render Error")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .onAppear {
            currentCode = code
        }
        .onChange(of: code) { oldCode, newCode in
            if oldCode != newCode && !newCode.isEmpty {
                hasInitialized = true
                loadError = nil
                withAnimation(.easeOut(duration: 0.1)) { opacity = 0.7 }
                currentCode = newCode
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeIn(duration: 0.15)) { opacity = 1.0 }
                }
            }
        }
        .onChange(of: refreshTrigger) { _, _ in
            loadError = nil
            withAnimation(.easeOut(duration: 0.1)) { opacity = 0.7 }
            let temp = currentCode
            currentCode = ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                currentCode = temp
                withAnimation(.easeIn(duration: 0.15)) { opacity = 1.0 }
            }
        }
    }

    private func buildRenderHTML(code: String) -> String {
        let safeCode = code
            .replacingOccurrences(of: "\\(", with: "\\\\(")

        let codeWithoutImports = safeCode
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("import ") }
            .joined(separator: "\n")

        // Extract LOCATION_ID from code if present
        var locationIdInit = ""
        if let range = code.range(of: #"(?:const|let|var)\s+LOCATION_ID\s*=\s*["\']([^"\']+)["\']"#, options: .regularExpression) {
            let match = code[range]
            if let idRange = match.range(of: #"["\']([^"\']+)["\']"#, options: .regularExpression) {
                let idWithQuotes = String(match[idRange])
                let locationId = idWithQuotes.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                locationIdInit = "window.LOCATION_ID = '\(locationId)'; nativeLog('Pre-set LOCATION_ID: ' + window.LOCATION_ID);"
            }
        }

        // Extract STORE_ID from code if present
        var storeIdInit = ""
        if let range = code.range(of: #"(?:const|let|var)\s+STORE_ID\s*=\s*["\']([^"\']+)["\']"#, options: .regularExpression) {
            let match = code[range]
            if let idRange = match.range(of: #"["\']([^"\']+)["\']"#, options: .regularExpression) {
                let idWithQuotes = String(match[idRange])
                let storeId = idWithQuotes.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                storeIdInit = "window.STORE_ID = '\(storeId)'; nativeLog('Pre-set STORE_ID: ' + window.STORE_ID);"
            }
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">

            <!-- React 18 (dev mode for better errors) -->
            <script src="https://unpkg.com/react@18/umd/react.development.js" crossorigin></script>
            <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js" crossorigin></script>

            <!-- Babel for JSX -->
            <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>

            <!-- Tailwind CSS -->
            <script src="https://cdn.tailwindcss.com"></script>

            <!-- Animation - Framer Motion -->
            <script src="https://unpkg.com/framer-motion@11/dist/framer-motion.js" crossorigin></script>

            <!-- GSAP -->
            <script src="https://unpkg.com/gsap@3/dist/gsap.min.js" crossorigin></script>

            <!-- 3D -->
            <script src="https://unpkg.com/three@0.160.0/build/three.min.js" crossorigin></script>

            <!-- Charts -->
            <script src="https://unpkg.com/recharts@2.10.3/umd/Recharts.js" crossorigin></script>

            <!-- React Router -->
            <script src="https://unpkg.com/react-router-dom@6/dist/umd/react-router-dom.production.min.js" crossorigin></script>

            <!-- Lucide Icons -->
            <script src="https://unpkg.com/lucide@latest/dist/umd/lucide.min.js" crossorigin></script>

            <!-- Fonts -->
            <link rel="preconnect" href="https://fonts.googleapis.com">
            <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
            <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600&family=Space+Grotesk:wght@400;500;600;700&display=swap" rel="stylesheet">

            <script>
                tailwind.config = {
                    theme: {
                        extend: {
                            fontFamily: {
                                sans: ['Inter', '-apple-system', 'BlinkMacSystemFont', 'sans-serif'],
                                mono: ['JetBrains Mono', 'SF Mono', 'monospace'],
                                display: ['Space Grotesk', 'Inter', 'sans-serif'],
                            },
                        },
                    },
                };
            </script>

            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; }
                html, body, #root {
                    width: 100%; height: 100%;
                    background: #000; color: #fff;
                    font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
                    overflow-x: hidden;
                    -webkit-font-smoothing: antialiased;
                    -moz-osx-font-smoothing: grayscale;
                }
                .error-boundary {
                    display: flex; flex-direction: column;
                    align-items: center; justify-content: center;
                    height: 100%; color: #ff6b6b; padding: 20px;
                    text-align: center; background: #000;
                }
                .error-boundary pre {
                    background: #1a1a1a; padding: 16px; border-radius: 8px;
                    max-width: 90%; overflow-x: auto; margin-top: 16px;
                    font-family: 'JetBrains Mono', monospace; font-size: 12px;
                    text-align: left; white-space: pre-wrap; word-break: break-word;
                }
            </style>
        </head>
        <body>
            <div id="root"><div style="display:flex;align-items:center;justify-content:center;height:100%;color:#666">Loading...</div></div>
            <!-- Global library setup (AFTER CDN loads, BEFORE Babel) -->
            <script>
                // Console bridge to Swift
                window.nativeLog = function(msg) {
                    try { window.webkit.messageHandlers.consoleLog.postMessage(String(msg)); } catch(e) { console.log(msg); }
                };
                window.onerror = function(msg, url, line, col, error) {
                    var fullMsg = error ? (error.stack || error.message || msg) : msg;
                    nativeLog('ERROR: ' + fullMsg);
                    return true; // Don't show error in UI for CDN errors
                };

                nativeLog('Setting up libraries...');

                try {
                    // Framer Motion
                    if (window.Motion) {
                        nativeLog('Motion found');
                        window.motion = window.Motion.motion;
                        window.AnimatePresence = window.Motion.AnimatePresence;
                        window.useAnimation = window.Motion.useAnimation;
                        window.useMotionValue = window.Motion.useMotionValue;
                        window.useTransform = window.Motion.useTransform;
                        window.useSpring = window.Motion.useSpring;
                        window.useInView = window.Motion.useInView;
                        window.useScroll = window.Motion.useScroll;
                    }
                } catch(e) { nativeLog('Motion setup error: ' + e.message); }

                try {
                    // Recharts
                    if (window.Recharts) {
                        nativeLog('Recharts found');
                        window.LineChart = window.Recharts.LineChart;
                        window.BarChart = window.Recharts.BarChart;
                        window.PieChart = window.Recharts.PieChart;
                        window.AreaChart = window.Recharts.AreaChart;
                        window.XAxis = window.Recharts.XAxis;
                        window.YAxis = window.Recharts.YAxis;
                        window.CartesianGrid = window.Recharts.CartesianGrid;
                        window.Tooltip = window.Recharts.Tooltip;
                        window.Legend = window.Recharts.Legend;
                        window.Line = window.Recharts.Line;
                        window.Bar = window.Recharts.Bar;
                        window.Pie = window.Recharts.Pie;
                        window.Area = window.Recharts.Area;
                        window.Cell = window.Recharts.Cell;
                        window.ResponsiveContainer = window.Recharts.ResponsiveContainer;
                        nativeLog('ResponsiveContainer: ' + !!window.ResponsiveContainer);
                    } else {
                        nativeLog('Recharts NOT found');
                    }
                } catch(e) { nativeLog('Recharts setup error: ' + e.message); }

                try {
                    // React Router - skip if causing issues
                    if (window.ReactRouterDOM) {
                        nativeLog('ReactRouterDOM found');
                        window.HashRouter = window.ReactRouterDOM.HashRouter;
                        window.BrowserRouter = window.ReactRouterDOM.BrowserRouter;
                        window.Routes = window.ReactRouterDOM.Routes;
                        window.Route = window.ReactRouterDOM.Route;
                        window.Link = window.ReactRouterDOM.Link;
                        window.Navigate = window.ReactRouterDOM.Navigate;
                        window.Outlet = window.ReactRouterDOM.Outlet;
                        window.useNavigate = window.ReactRouterDOM.useNavigate;
                        window.useLocation = window.ReactRouterDOM.useLocation;
                        window.useParams = window.ReactRouterDOM.useParams;
                        window.Router = window.HashRouter;
                    }
                } catch(e) { nativeLog('Router setup error: ' + e.message); }

                nativeLog('Library setup complete');
            </script>
            <script type="text/babel" data-presets="react">
                nativeLog('Babel executing...');

                // ========== SUPABASE CONFIG ==========
                const SUPABASE_URL = 'https://uaednwpxursknmwdeejn.supabase.co';
                const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVhZWRud3B4dXJza25td2RlZWpuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDk5NzIzMywiZXhwIjoyMDc2NTczMjMzfQ.l0NvBbS2JQWPObtWeVD2M2LD866A2tgLmModARYNnbI';
                const POLL_INTERVAL = 5000;

                // ========== WHALE STORE HOOKS ==========
                window.useStore = {
                    // Generic query hook
                    useQuery: function(table, options) {
                        options = options || {};
                        const [data, setData] = React.useState([]);
                        const [loading, setLoading] = React.useState(true);
                        const [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            async function fetchData() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/' + table + '?select=' + encodeURIComponent(options.select || '*');
                                    if (options.filter) url += '&' + options.filter;
                                    if (options.order) url += '&order=' + options.order;
                                    if (options.limit) url += '&limit=' + options.limit;

                                    nativeLog('Fetching: ' + table);
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                            'Content-Type': 'application/json'
                                        }
                                    });
                                    var json = await res.json();
                                    nativeLog('Response for ' + table + ': ' + (Array.isArray(json) ? json.length + ' items' : JSON.stringify(json).substring(0, 100)));
                                    if (Array.isArray(json)) {
                                        setData(json);
                                        setError(null);
                                    } else if (json.message) {
                                        nativeLog('Error: ' + json.message);
                                        setError(json.message);
                                    } else if (json.error) {
                                        setError(json.error);
                                    }
                                } catch (e) {
                                    nativeLog('Fetch error: ' + e.message);
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchData();
                            var interval = setInterval(fetchData, options.pollInterval || POLL_INTERVAL);
                            return function() { clearInterval(interval); };
                        }, [table, JSON.stringify(options)]);

                        return { data: data, loading: loading, error: error, refetch: function() {} };
                    },

                    // Products with inventory - uses RPC for location-specific (real-time), view for global
                    productsWithInventory: function(storeId, locationId) {
                        var locId = locationId || window.LOCATION_ID || null;
                        nativeLog('productsWithInventory called, locId=' + locId);
                        if (locId) {
                            // Use RPC for real-time location inventory
                            return window.useStore.productsForLocation(locId);
                        }
                        // Fallback to view for global queries
                        return window.useStore.useQuery('v_products_with_inventory', {
                            select: '*',
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Products - same as productsWithInventory
                    useProducts: function(storeId, locationId) {
                        var locId = locationId || window.LOCATION_ID || null;
                        nativeLog('useProducts called, locId=' + locId);
                        if (locId) {
                            return window.useStore.productsForLocation(locId);
                        }
                        return window.useStore.useQuery('v_products_with_inventory', {
                            select: '*',
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Products for specific location - uses RPC (real-time inventory)
                    productsForLocation: function(locationId) {
                        var [data, setData] = React.useState([]);
                        var [loading, setLoading] = React.useState(true);
                        var [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            if (!locationId) { setLoading(false); return; }
                            async function fetchProducts() {
                                try {
                                    nativeLog('RPC: get_products_for_location(' + locationId + ')');
                                    var url = SUPABASE_URL + '/rest/v1/rpc/get_products_for_location';
                                    var res = await fetch(url, {
                                        method: 'POST',
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                            'Content-Type': 'application/json'
                                        },
                                        body: JSON.stringify({ p_location_id: locationId })
                                    });
                                    var json = await res.json();
                                    nativeLog('RPC response: ' + (Array.isArray(json) ? json.length + ' products' : JSON.stringify(json).substring(0, 100)));
                                    if (Array.isArray(json)) {
                                        // Filter out products with tiny quantities (< 1 unit) - these are "ghost products"
                                        // that show up in inventory but aren't really sellable
                                        var filtered = json.filter(function(p) {
                                            return (p.quantity || 0) >= 1;
                                        });
                                        nativeLog('Filtered from ' + json.length + ' to ' + filtered.length + ' products (removed qty < 1)');

                                        // Add stock_by_location compatibility for existing creation code
                                        // RPC returns 'quantity' for this location, convert to stock_by_location format
                                        var enhanced = filtered.map(function(p) {
                                            var stockByLoc = {};
                                            stockByLoc[locationId] = p.quantity || 0;
                                            return Object.assign({}, p, { stock_by_location: stockByLoc });
                                        });
                                        setData(enhanced);
                                    } else if (json.message || json.error) {
                                        setError(json.message || json.error);
                                    }
                                } catch (e) {
                                    nativeLog('RPC error: ' + e.message);
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchProducts();
                            var interval = setInterval(fetchProducts, POLL_INTERVAL);
                            return function() { clearInterval(interval); };
                        }, [locationId]);

                        return { data: data, loading: loading, error: error };
                    },

                    // Orders
                    useOrders: function(storeId, days) {
                        days = days || 30;
                        var since = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();
                        return window.useStore.useQuery('orders', {
                            select: '*,order_items(*,product:products(name,sku))',
                            filter: storeId ? 'store_id=eq.' + storeId + '&created_at=gte.' + since : 'created_at=gte.' + since,
                            order: 'created_at.desc'
                        });
                    },

                    // Orders with items
                    ordersWithItems: function(storeId, days) {
                        return window.useStore.useOrders(storeId, days);
                    },

                    // Stores
                    useStores: function() {
                        return window.useStore.useQuery('stores', { order: 'name.asc' });
                    },

                    // Store locations
                    storeLocations: function(storeId) {
                        return window.useStore.useQuery('locations', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Creations
                    useCreations: function(type) {
                        return window.useStore.useQuery('creations', {
                            filter: type ? 'creation_type=eq.' + type : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Collections
                    useCollections: function() {
                        return window.useStore.useQuery('creation_collections', { order: 'created_at.desc' });
                    },

                    // Customers
                    customers: function(storeId) {
                        return window.useStore.useQuery('customers', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Revenue stats
                    revenueStats: function(storeId, days) {
                        return window.useStore.useOrders(storeId, days);
                    },

                    // Store (single store by ID)
                    store: function(storeId) {
                        var [data, setData] = React.useState(null);
                        var [loading, setLoading] = React.useState(true);
                        var [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            if (!storeId) { setLoading(false); return; }
                            async function fetchStore() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/stores?id=eq.' + storeId + '&select=*';
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                        }
                                    });
                                    var json = await res.json();
                                    setData(json && json[0] ? json[0] : null);
                                } catch (e) {
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchStore();
                        }, [storeId]);

                        return { data: data, loading: loading, error: error };
                    },

                    // Location (single location by ID)
                    location: function(locationId) {
                        var [data, setData] = React.useState(null);
                        var [loading, setLoading] = React.useState(true);
                        var [error, setError] = React.useState(null);

                        React.useEffect(function() {
                            if (!locationId) { setLoading(false); return; }
                            async function fetchLocation() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/locations?id=eq.' + locationId + '&select=*';
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                        }
                                    });
                                    var json = await res.json();
                                    setData(json && json[0] ? json[0] : null);
                                } catch (e) {
                                    setError(e.message);
                                } finally {
                                    setLoading(false);
                                }
                            }
                            fetchLocation();
                        }, [locationId]);

                        return { data: data, loading: loading, error: error };
                    },

                    // Product (single product by ID)
                    product: function(productId) {
                        var [data, setData] = React.useState(null);
                        var [loading, setLoading] = React.useState(true);

                        React.useEffect(function() {
                            if (!productId) { setLoading(false); return; }
                            async function fetchProduct() {
                                try {
                                    var url = SUPABASE_URL + '/rest/v1/products?id=eq.' + productId + '&select=*,variants(*,inventory(*))';
                                    var res = await fetch(url, {
                                        headers: {
                                            'apikey': SUPABASE_KEY,
                                            'Authorization': 'Bearer ' + SUPABASE_KEY,
                                        }
                                    });
                                    var json = await res.json();
                                    setData(json && json[0] ? json[0] : null);
                                } catch (e) {}
                                finally { setLoading(false); }
                            }
                            fetchProduct();
                        }, [productId]);

                        return { data: data, loading: loading };
                    },

                    // Categories
                    categories: function(storeId) {
                        return window.useStore.useQuery('categories', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Inventory
                    inventory: function(locationId) {
                        return window.useStore.useQuery('inventory', {
                            select: '*,variant:variants(*,product:products(*))',
                            filter: locationId ? 'location_id=eq.' + locationId : undefined,
                            order: 'updated_at.desc'
                        });
                    },

                    // Locations
                    locations: function(storeId) {
                        return window.useStore.useQuery('locations', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Variants
                    variants: function(productId) {
                        return window.useStore.useQuery('variants', {
                            select: '*,inventory(*)',
                            filter: productId ? 'product_id=eq.' + productId : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Staff/Employees
                    staff: function(storeId) {
                        return window.useStore.useQuery('staff', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Discounts/Promos
                    discounts: function(storeId) {
                        return window.useStore.useQuery('discounts', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'created_at.desc'
                        });
                    },

                    // Taxes
                    taxes: function(storeId) {
                        return window.useStore.useQuery('taxes', {
                            filter: storeId ? 'store_id=eq.' + storeId : undefined,
                            order: 'name.asc'
                        });
                    },

                    // Analytics/Stats
                    analytics: function(storeId, days) {
                        return window.useStore.useOrders(storeId, days || 30);
                    },
                };

                // Global aliases for useStore
                var useStore = window.useStore;
                var useQuery = window.useStore.useQuery;
                var useProducts = window.useStore.useProducts;
                var useOrders = window.useStore.useOrders;
                var useStores = window.useStore.useStores;
                var useCreations = window.useStore.useCreations;
                var useCollections = window.useStore.useCollections;
                var productsForLocation = window.useStore.productsForLocation;

                // Stub component for when libraries don't load
                var StubComponent = function(props) { return React.createElement('div', { style: { padding: '20px', background: '#1a1a1a', borderRadius: '8px', color: '#888', textAlign: 'center' } }, 'Loading chart...'); };

                // Recharts aliases (ensure available in babel scope)
                var LineChart = window.LineChart || (window.Recharts && window.Recharts.LineChart) || StubComponent;
                var BarChart = window.BarChart || (window.Recharts && window.Recharts.BarChart) || StubComponent;
                var PieChart = window.PieChart || (window.Recharts && window.Recharts.PieChart) || StubComponent;
                var AreaChart = window.AreaChart || (window.Recharts && window.Recharts.AreaChart) || StubComponent;
                var XAxis = window.XAxis || (window.Recharts && window.Recharts.XAxis) || function() { return null; };
                var YAxis = window.YAxis || (window.Recharts && window.Recharts.YAxis) || function() { return null; };
                var CartesianGrid = window.CartesianGrid || (window.Recharts && window.Recharts.CartesianGrid) || function() { return null; };
                var Tooltip = window.Tooltip || (window.Recharts && window.Recharts.Tooltip) || function() { return null; };
                var Legend = window.Legend || (window.Recharts && window.Recharts.Legend) || function() { return null; };
                var Line = window.Line || (window.Recharts && window.Recharts.Line) || function() { return null; };
                var Bar = window.Bar || (window.Recharts && window.Recharts.Bar) || function() { return null; };
                var Pie = window.Pie || (window.Recharts && window.Recharts.Pie) || function() { return null; };
                var Area = window.Area || (window.Recharts && window.Recharts.Area) || function() { return null; };
                var Cell = window.Cell || (window.Recharts && window.Recharts.Cell) || function() { return null; };
                var ResponsiveContainer = window.ResponsiveContainer || (window.Recharts && window.Recharts.ResponsiveContainer) || function(props) { return props.children; };
                var RadialBarChart = (window.Recharts && window.Recharts.RadialBarChart) || StubComponent;
                var RadialBar = (window.Recharts && window.Recharts.RadialBar) || function() { return null; };
                var ComposedChart = (window.Recharts && window.Recharts.ComposedChart) || StubComponent;
                var Scatter = (window.Recharts && window.Recharts.Scatter) || function() { return null; };

                // Framer Motion aliases (with div fallback if not loaded)
                var motion = window.motion || { div: 'div', span: 'span', p: 'p', button: 'button', a: 'a', ul: 'ul', li: 'li', img: 'img', h1: 'h1', h2: 'h2', h3: 'h3', section: 'section', article: 'article', header: 'header', footer: 'footer', nav: 'nav', main: 'main' };
                var AnimatePresence = window.AnimatePresence || function(props) { return props.children; };
                var useAnimation = window.useAnimation || function() { return {}; };
                var useMotionValue = window.useMotionValue || function(v) { return { get: function() { return v; }, set: function() {} }; };
                var useTransform = window.useTransform || function(v) { return v; };
                var useSpring = window.useSpring || function(v) { return v; };
                var useInView = window.useInView || function() { return true; };
                var useScroll = window.useScroll || function() { return { scrollY: 0, scrollX: 0 }; };

                // Router aliases
                var HashRouter = window.HashRouter;
                var BrowserRouter = window.BrowserRouter;
                var Routes = window.Routes;
                var Route = window.Route;
                var Link = window.Link;
                var Navigate = window.Navigate;
                var Outlet = window.Outlet;
                var useNavigate = window.useNavigate;
                var useLocation = window.useLocation;
                var useParams = window.useParams;
                var Router = window.Router;

                // ========== UTILITY FUNCTIONS ==========
                const formatCurrency = (amount, currency = 'USD') => {
                    return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount || 0);
                };

                const formatNumber = (num) => {
                    return new Intl.NumberFormat('en-US').format(num || 0);
                };

                const formatDate = (date) => {
                    return new Date(date).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
                };

                // ========== LOCATION INVENTORY HELPERS ==========
                // Get stock quantity for a specific location from stock_by_location JSONB
                const getStockForLocation = (product, locationId) => {
                    if (!product || !locationId) return 0;
                    // If product has quantity field (from RPC), use it directly
                    if (typeof product.quantity === 'number') return product.quantity;
                    // Otherwise check stock_by_location JSONB (from view)
                    if (product.stock_by_location && product.stock_by_location[locationId]) {
                        return product.stock_by_location[locationId];
                    }
                    return 0;
                };

                // Filter products to only those with stock at location
                const filterByLocationStock = (products, locationId, minQty = 0) => {
                    if (!products || !locationId) return products || [];
                    return products.filter(p => getStockForLocation(p, locationId) > minQty);
                };

                // Check if product is in stock at location
                const isInStockAt = (product, locationId) => {
                    return getStockForLocation(product, locationId) > 0;
                };

                // Get location name by ID from product
                const getLocationName = (product, locationId) => {
                    if (!product || !product.location_ids || !product.location_names) return '';
                    const idx = product.location_ids.indexOf(locationId);
                    return idx >= 0 ? product.location_names[idx] : '';
                };

                const formatRelativeTime = (date) => {
                    const now = new Date();
                    const diff = now - new Date(date);
                    const minutes = Math.floor(diff / 60000);
                    const hours = Math.floor(minutes / 60);
                    const days = Math.floor(hours / 24);
                    if (days > 0) return days + 'd ago';
                    if (hours > 0) return hours + 'h ago';
                    if (minutes > 0) return minutes + 'm ago';
                    return 'now';
                };

                // ========== ERROR BOUNDARY ==========
                class ErrorBoundary extends React.Component {
                    constructor(props) { super(props); this.state = { hasError: false, error: null }; }
                    static getDerivedStateFromError(error) { return { hasError: true, error }; }
                    componentDidCatch(error, info) { nativeLog('React Error: ' + error.message); }
                    render() {
                        if (this.state.hasError) {
                            return React.createElement('div', { className: 'error-boundary' },
                                React.createElement('h2', { style: { fontSize: '24px', marginBottom: '8px' } }, 'Render Error'),
                                React.createElement('pre', null, this.state.error?.message || 'Unknown error'),
                                React.createElement('button', {
                                    onClick: () => this.setState({ hasError: false, error: null }),
                                    style: { marginTop: '16px', padding: '8px 16px', background: '#333', border: 'none', borderRadius: '6px', color: '#fff', cursor: 'pointer' }
                                }, 'Try Again')
                            );
                        }
                        return this.props.children;
                    }
                }

                // ========== PRE-SET IDS FROM CODE ==========
                \(locationIdInit)
                \(storeIdInit)

                // ========== USER CODE ==========
                nativeLog('Executing user code...');
                try {
                    \(codeWithoutImports)

                    // Auto-export LOCATION_ID to window if defined
                    if (typeof LOCATION_ID !== 'undefined') {
                        window.LOCATION_ID = LOCATION_ID;
                        nativeLog('Exported LOCATION_ID to window: ' + LOCATION_ID);
                    }
                    // Also export STORE_ID if defined
                    if (typeof STORE_ID !== 'undefined') {
                        window.STORE_ID = STORE_ID;
                        nativeLog('Exported STORE_ID to window: ' + STORE_ID);
                    }

                    nativeLog('User code executed, rendering...');
                    const rootEl = document.getElementById('root');
                    const root = ReactDOM.createRoot(rootEl);

                    if (typeof App !== 'undefined') {
                        nativeLog('Rendering App component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(App)));
                    } else if (typeof Main !== 'undefined') {
                        nativeLog('Rendering Main component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Main)));
                    } else if (typeof Component !== 'undefined') {
                        nativeLog('Rendering Component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Component)));
                    } else if (typeof Page !== 'undefined') {
                        nativeLog('Rendering Page component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Page)));
                    } else if (typeof Dashboard !== 'undefined') {
                        nativeLog('Rendering Dashboard component');
                        root.render(React.createElement(ErrorBoundary, null, React.createElement(Dashboard)));
                    } else {
                        nativeLog('No component found!');
                        rootEl.innerHTML = '<div class="error-boundary"><h2>No Component Found</h2><p style="color:#888;margin-top:8px">Export: App, Main, Component, Page, or Dashboard</p></div>';
                    }
                    nativeLog('Render complete');
                } catch (e) {
                    nativeLog('Parse error: ' + e.message + '\\n' + e.stack);
                    document.getElementById('root').innerHTML = '<div class="error-boundary"><h2>Parse Error</h2><pre>' + e.message + '\\n\\n' + (e.stack || '') + '</pre></div>';
                }
            </script>
        </body>
        </html>
        """
    }
}

// MARK: - Hot Reload WebView

struct HotReloadWebView: NSViewRepresentable {
    let html: String
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        // Add script message handler for console logs
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "consoleLog")
        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        isLoading = true
        // Load HTML with HTTPS base URL to allow CDN script loading
        webView.loadHTMLString(html, baseURL: URL(string: "https://unpkg.com/"))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HotReloadWebView

        init(_ parent: HotReloadWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "consoleLog", let msg = message.body as? String {
                print("[WebView] \(msg)")
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.loadError = error.localizedDescription
            }
        }
    }
}
