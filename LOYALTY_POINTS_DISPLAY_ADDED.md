# Loyalty Points Display Added to iOS App

## Changes Made

Added loyalty points display in **two locations** where customers are shown:

### 1. ✅ Find Customer Sheet (Search/Match Results)

**File**: `ManualCustomerEntrySheet.swift`

#### Scanned Match Rows (ID Scanner Matches)
Added loyalty points badge showing points earned next to phone/email:

```swift
// Loyalty points badge
if let points = match.customer.loyaltyPoints, points > 0 {
    HStack(spacing: 2) {
        Image(systemName: "star.fill")
            .font(.system(size: 8, weight: .bold))
        Text("\(points)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
    }
    .foregroundStyle(.white.opacity(0.5))
    .padding(.horizontal, 5)
    .padding(.vertical, 2)
    .background(.white.opacity(0.08), in: .capsule)
}
```

#### Search Results Rows
**Already had loyalty points display** - showing star icon with points count and bag icon with order count.

### 2. ✅ Cart/Queue Tab (Selected Customer Display)

**File**: `DockCartContent.swift` - `DockCustomerOnlyContent`

Added loyalty points badge in the customer pill next to their name:

```swift
// Loyalty points badge
if let points = customer.loyaltyPoints, points > 0 {
    HStack(spacing: 3) {
        Image(systemName: "star.fill")
            .font(.system(size: 10, weight: .bold))
        Text("\(points)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
    }
    .foregroundStyle(.yellow.opacity(0.9))
    .padding(.horizontal, 7)
    .padding(.vertical, 4)
    .background(.white.opacity(0.15), in: .capsule)
}
```

**Design**: Yellow star with points count in a glass pill next to customer name.

---

## Visual Design

### Find Customer Sheet
- **Location**: Below customer name/phone in match rows
- **Style**: White star + points in subtle white glass pill
- **Size**: Small (8pt icon, 10pt text)
- **Opacity**: 50% white for subtle appearance

### Cart/Queue Tab
- **Location**: Inside customer pill, after their first name
- **Style**: Yellow star + points in white glass pill
- **Size**: Medium (10pt icon, 12pt text)
- **Color**: Yellow (0.9 opacity) for visibility and reward emphasis

---

## Build Status

✅ **iOS App Built Successfully**

---

## Testing

After restarting the iOS app:

### 1. Find Customer / Scan ID
- Open Find Customer sheet
- Search for a customer
- **Expected**: Should see star icon with points count next to phone number
- Scan an ID to see matched customers
- **Expected**: Should see loyalty points badge in match results

### 2. Cart/Queue Tab
- Select a customer
- View the dock/cart area
- **Expected**: Customer pill shows name with yellow star badge showing points

---

## Data Source

Loyalty points come from the `Customer` model:
- Field: `loyaltyPoints: Int?`
- Computed property: `formattedLoyaltyPoints: String`

The data is already being fetched from the database via:
- `v_store_customers` view (joins platform_users + user_creation_relationships + store_customer_profiles)
- Field: `loyalty_points` from `store_customer_profiles` table

Points are updated in real-time as orders are completed via the `award_loyalty_points` RPC function.

---

## Summary

Customer loyalty points are now visible in:
1. ✅ Customer search results (was already there)
2. ✅ ID scan match results (newly added)
3. ✅ Cart/queue customer pill (newly added)

This gives staff immediate visibility into customer loyalty status at all interaction points.
