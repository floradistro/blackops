# SwagManager POS Integration Design

## Vision: Subtle, Beautiful Desktop POS

Transform SwagManager into a **full-capability POS** without adding clutter. The queue system becomes transactional.

---

## UI Integration Map

### 1. Sidebar Enhancement (Minimal Changes)

```
┌─────────────────────────┐
│ QUEUES              ▼  │ ← Already exists
├─────────────────────────┤
│ 📍 Blowing Rock        │
│   👤 JD·2  $45  🟢     │ ← Green = ready to checkout
│   👤 SM·5  $78  ⚪     │ ← White = browsing
│   👤 AM·1  $12  ⚪     │
│                         │
│ 📍 Charlotte           │
│   👤 RW·3  $156 🟢     │
└─────────────────────────┘
```

**Changes:**
- Add item count + total to each queue entry
- Green dot = has items (clickable → checkout)
- White dot = empty cart (clickable → add products)

### 2. Cart Panel (New - Opens When Queue Item Clicked)

```
┌──────────────────────────────────────────────────────┐
│  John Doe                                      [×]   │ ← Customer header
│  john@email.com · 555-1234                           │
├──────────────────────────────────────────────────────┤
│  Cart (2 items)                          [Clear All] │
│                                                       │
│  🌿 Blue Dream 1/8oz                          $25.00 │
│     Tier: 1/8oz (3.5g) · Hybrid                      │
│     [−] 1 [+]                              [Remove]  │
│                                                       │
│  🌿 Indica Pre-Roll (2-pack)                  $15.00 │
│     Tier: 2-pack · Indica                            │
│     [−] 2 [+]                              [Remove]  │
│                                                       │
│  💰 Loyalty Discount                          -$4.50 │
│     200 points redeemed                              │
│                                                       │
├──────────────────────────────────────────────────────┤
│  Subtotal                                     $55.00 │
│  Discount                        -$4.50  [Apply...]  │ ← Discount menu
│  Tax (10.25%)                                  $5.18 │
│  Total                                        $55.68 │
├──────────────────────────────────────────────────────┤
│  [+ Add Products]              [💳 Checkout →]       │
└──────────────────────────────────────────────────────┘
```

**Features:**
- Live totals (server-calculated, realtime updates)
- Inline quantity adjust (+/− buttons)
- Per-item remove
- Clear all cart
- Apply discounts (loyalty, manual %, fixed)
- Add products button → Product Selector Modal
- Checkout button → Payment Sheet

### 3. Product Selector Modal (New)

```
┌─────────────────────────────────────────────────────────┐
│  Add Products to Cart                             [×]   │
├─────────────────────────────────────────────────────────┤
│  🔍 Search products...              [All ▾] [In Stock] │
├──────┬──────────────────────────────────────────────────┤
│ CATS │  PRODUCTS GRID                                   │
│      │                                                   │
│ All  │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐       │
│ Flow │  │ BD  │ │ GG  │ │ SC  │ │ WW  │ │ OG  │       │
│ Pre- │  │$25  │ │$28  │ │$30  │ │$22  │ │$35  │       │
│ Roll │  └─────┘ └─────┘ └─────┘ └─────┘ └─────┘       │
│ Edib │                                                   │
│      │  ┌─────┐ ┌─────┐ ┌─────┐ ┌─────┐               │
│      │  │ TG  │ │ GSC │ │ MAC │ │ GDP │               │
│      │  │$26  │ │$32  │ │$40  │ │$24  │               │
│      │  └─────┘ └─────┘ └─────┘ └─────┘               │
│      │                                                   │
├──────┴──────────────────────────────────────────────────┤
│  2 items added                          [Done]          │
└─────────────────────────────────────────────────────────┘
```

**Features:**
- Category sidebar (same as POS)
- Search bar
- Grid view with images
- Click product → Tier selector sheet (if multi-tier)
- Click tier → Add to cart + update count badge
- Live "X items added" counter
- Done closes modal

### 4. Tier Selector Sheet (Nested Modal)

```
┌────────────────────────────────┐
│  Blue Dream                [×] │
│  Select Quantity               │
├────────────────────────────────┤
│  ⚪ 1g        $10 · In Stock   │
│  🔵 1/8oz     $25 · 12 left    │ ← Selected
│  ⚪ 1/4oz     $45 · 8 left     │
│  ⚪ 1/2oz     $80 · 3 left     │
│  ⚪ 1oz       $150 · 2 left    │
├────────────────────────────────┤
│           [Add to Cart]        │
└────────────────────────────────┘
```

### 5. Checkout Sheet (New - macOS Native)

```
┌─────────────────────────────────────────────────┐
│  Checkout                                  [×]  │
├─────────────────────────────────────────────────┤
│  Customer: John Doe                             │
│  Cart: 2 items                                  │
│                                                  │
│  Payment Method                                 │
│  ⚪ Card        🔵 Cash        ⚪ Split          │
│  ⚪ Invoice     ⚪ Multi-Card                    │
│                                                  │
│  Cash Tendered                                  │
│  ┌────────────────────────────────────┐         │
│  │ $ 60.00                            │         │
│  └────────────────────────────────────┘         │
│  Suggested: $60  $75  $100                      │
│                                                  │
│  Change Due: $4.32                              │
│                                                  │
├─────────────────────────────────────────────────┤
│  Subtotal                         $55.00        │
│  Discount                         -$4.50        │
│  Tax (10.25%)                      $5.18        │
│  Total                            $55.68        │
├─────────────────────────────────────────────────┤
│              [Process Payment →]                │
└─────────────────────────────────────────────────┘
```

**Payment Methods:**

**Card:**
- "Process Payment" → backend creates payment intent
- Shows terminal instructions
- Waits for authorization
- Success → order created

**Cash:**
- Enter cash tendered
- Shows change due
- "Process Payment" → instant success

**Split:**
- Enter cash amount + card amount
- Process cash first, then card

**Multi-Card:**
- Multiple card transactions
- Progress indicator for each

**Invoice:**
- Email input
- Due date picker
- Send invoice → email sent
- Shows payment link to copy

### 6. Processing State

```
┌─────────────────────────────────────┐
│  Processing Payment             [×] │
├─────────────────────────────────────┤
│                                      │
│         ⏳                           │
│                                      │
│   Processing Card Payment            │
│   $55.68                             │
│                                      │
│   Please complete on terminal...     │
│                                      │
└─────────────────────────────────────┘
```

### 7. Success State

```
┌─────────────────────────────────────┐
│  Payment Successful             [×] │
├─────────────────────────────────────┤
│                                      │
│         ✓                            │
│                                      │
│   Order #ORD-123456                  │
│   $55.68 - Paid                      │
│                                      │
│   Receipt sent to john@email.com     │
│                                      │
│              [Done]                  │
│                                      │
└─────────────────────────────────────┘
```

---

## Data Flow

### 1. Customer Added to Queue

```
POS Tablet OR Mac App
        ↓
LocationQueueService.addToQueue()
        ↓
Backend creates queue entry + cart
        ↓
Realtime broadcast to all apps
        ↓
SwagManager sidebar shows: JD·0 ⚪
```

### 2. Add Products (Mac)

```
User clicks queue entry
        ↓
CartPanel opens (fetches cart via CartService)
        ↓
User clicks "Add Products"
        ↓
ProductSelectorModal opens
        ↓
User clicks product → tier selector
        ↓
CartService.addToCart() → Edge Function
        ↓
Backend calculates totals, returns cart
        ↓
CartPanel updates with new total
        ↓
Realtime broadcast
        ↓
POS Tablet sees: JD·2 $45 🟢
Mac sidebar sees: JD·2 $45 🟢
```

### 3. Checkout (Mac)

```
User clicks "Checkout" button
        ↓
CheckoutSheet presented
        ↓
User selects payment method (e.g., Cash)
        ↓
User enters $60 cash tendered
        ↓
User clicks "Process Payment"
        ↓
PaymentStore.processCashPayment()
        ↓
Backend creates payment intent
        ↓
Backend state machine runs
        ↓
Order created atomically
        ↓
Realtime completion
        ↓
Success sheet shown
        ↓
Cart cleared, queue advanced
        ↓
POS Tablet sees queue update
```

### 4. Realtime Sync (All Apps)

```
Cart updated on Mac
        ↓
Edge Function updates carts table
        ↓
Supabase Realtime fires
        ↓
All subscribed apps receive update
        ↓
POS Tablet: cart updates instantly
SwagManager: CartPanel refreshes
Other Mac: sees same cart state
```

---

## Architecture Decisions

### 1. Server-Driven, Thin Client

**✅ Do:**
- Call Edge Functions for all cart operations
- Render backend-calculated totals
- Subscribe to Realtime for sync
- Never calculate prices/tax locally

**❌ Don't:**
- Calculate totals in Swift
- Store cart state locally
- Create orders directly
- Manage inventory holds

### 2. Reuse POS Backend

**Shared Services:**
- `/cart` Edge Function (create, add, update, remove, discount)
- `/payment-intent` Edge Function (process payments)
- `/send-invoice` Edge Function (invoice emails)
- `location_queue` table (queue management)
- `carts` table (cart state)
- `payment_intents` table (payment state machine)

### 3. macOS-Native UI

**SwiftUI + AppKit:**
- Use `.sheet()` for modals
- Native macOS controls (NSTextField, NSButton)
- Keyboard navigation (Tab, Enter, Escape)
- Menu bar integration (File → New Sale)
- Dock integration (badge count for queue)

### 4. Realtime Everything

**Critical subscriptions:**
- `location_queue` - Queue changes
- `carts` - Cart updates
- `cart_items` - Item changes
- `payment_intents` - Payment state

---

## Implementation Phases

### Phase 1: Cart Management ✓
- [x] Port CartService
- [ ] Create CartPanel UI
- [ ] Integrate with queue sidebar
- [ ] Realtime cart updates

### Phase 2: Product Selection
- [ ] Create ProductSelectorModal
- [ ] Grid view with images
- [ ] Category filtering
- [ ] Search
- [ ] Tier selector sheet
- [ ] Add to cart flow

### Phase 3: Checkout
- [ ] Create CheckoutSheet
- [ ] Payment method selection
- [ ] Cash/card/split inputs
- [ ] Port PaymentStore (state machine)
- [ ] Payment processing UI

### Phase 4: Payments
- [ ] Invoice generation
- [ ] Payment intent creation
- [ ] Terminal integration (optional - Mac likely cash/invoice only)
- [ ] Success/failure states

### Phase 5: Polish
- [ ] Keyboard shortcuts
- [ ] Print receipt integration
- [ ] Loyalty points UI
- [ ] Discount menu
- [ ] Error handling
- [ ] Loading states

---

## Keyboard Shortcuts

```
⌘N      New Customer (scan ID / search)
⌘P      Add Products to Cart
⌘⏎      Checkout
⌘⌫      Remove Selected Item
⌘⇧⌫     Clear Cart
⌘1-5    Switch Payment Method
⌘D      Apply Discount
Esc     Close Modal
⏎       Confirm/Next
```

---

## Visual Design Language

**Match SwagManager's existing style:**

**Colors:**
- Primary: DesignSystem.Colors.textPrimary
- Secondary: DesignSystem.Colors.textSecondary
- Accent: Purple (queue), Green (success), Red (remove)
- Background: DesignSystem.Colors.surface

**Typography:**
- Titles: DesignSystem.Typography.headline
- Body: DesignSystem.Typography.body
- Captions: DesignSystem.Typography.caption1

**Spacing:**
- Padding: DesignSystem.Spacing.md (12px)
- Section gaps: DesignSystem.Spacing.lg (16px)
- Inline: DesignSystem.Spacing.sm (8px)

**Animations:**
- Fast: DesignSystem.Animation.fast (0.15s)
- Spring: DesignSystem.Animation.spring

---

## Testing Checklist

### Multi-Device Sync
- [ ] Add item on Mac → appears on POS instantly
- [ ] Remove item on POS → disappears on Mac instantly
- [ ] Checkout on Mac → queue updates on POS
- [ ] Two Macs editing same cart → conflict resolution

### Edge Cases
- [ ] Customer with no email (invoice)
- [ ] Product out of stock
- [ ] Negative inventory
- [ ] Duplicate payment (idempotency)
- [ ] Network loss during checkout
- [ ] Terminal timeout

### Performance
- [ ] Cart loads < 100ms
- [ ] Product grid renders smoothly
- [ ] Realtime latency < 200ms
- [ ] Checkout completes < 3s

---

## Success Metrics

**User Experience:**
- Mac app feels as fast as POS tablet
- Zero training required (intuitive)
- Keyboard-driven for power users
- Beautiful, polished, professional

**Technical:**
- 100% backend parity with POS
- Zero local state (fully server-driven)
- Realtime sync < 200ms
- No race conditions (actor locks)

**Business:**
- Staff can serve customers from Mac
- Queue management from desktop
- Analytics dashboard with POS integration
- Remote store management
